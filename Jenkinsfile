pipeline {
    agent any

    environment {
        AWS_REGION   = 'ap-south-1'
        GITHUB_REPO  = 'https://github.com/Aishwini08/End-to-End-Kubernetes-Three-Tier-Project.git'
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main', credentialsId: 'github-credentials', url: "${GITHUB_REPO}"
            }
        }

        stage('Skip CI Check') {
            steps {
                script {
                    def commitMsg = sh(script: "git log -1 --pretty=%B", returnStdout: true).trim()
                    def commitAuthor = sh(script: "git log -1 --pretty=format:'%an'", returnStdout: true).trim()
                    
                    if (commitMsg.contains('[skip ci]') || 
                        commitMsg.contains('[ci skip]') || 
                        commitAuthor == 'Jenkins CI') {
                        currentBuild.result = 'NOT_BUILT'
                        error('Skipping CI - commit was made by Jenkins automation')
                    }
                }
            }
        }

        stage('OWASP Dependency Check') {
            steps {
                sh '''
                    mkdir -p reports
                    dependency-check \
                        --project "three-tier-app" \
                        --scan Application-Code/ \
                        --format HTML \
                        --out reports/ \
                        --disableYarnAudit \
                        --disableNodeAudit \
                        || true
                '''
            }
            post {
                always {
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'reports',
                        reportFiles: 'dependency-check-report.html',
                        reportName: 'OWASP Dependency Check Report'
                    ])
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
                    sh '''
                        JENKINS_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
                        docker run --rm \
                            --network host \
                            -e SONAR_HOST_URL="http://${JENKINS_IP}:9000" \
                            -e SONAR_TOKEN="${SONAR_TOKEN}" \
                            -v "${WORKSPACE}/Application-Code:/usr/src" \
                            sonarsource/sonar-scanner-cli \
                            -Dsonar.projectKey=three-tier-app \
                            -Dsonar.sources=/usr/src \
                            || true
                    '''
                }
            }
        }

        stage('Get AWS Account ID') {
            steps {
                script {
                    env.AWS_ACCOUNT_ID   = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
                    env.ECR_FRONTEND_URL = "${env.AWS_ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com/frontend"
                    env.ECR_BACKEND_URL  = "${env.AWS_ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com/backend"
                    echo "ECR Frontend: ${env.ECR_FRONTEND_URL}"
                    echo "ECR Backend:  ${env.ECR_BACKEND_URL}"
                }
            }
        }

        stage('ECR Login') {
            steps {
                sh '''
                    aws ecr get-login-password --region ap-south-1 \
                        | docker login --username AWS --password-stdin \
                        $(aws sts get-caller-identity --query Account --output text).dkr.ecr.ap-south-1.amazonaws.com
                '''
            }
        }

        stage('Build & Push Frontend') {
            steps {
                sh '''
                    docker system prune -af || true
                    docker build -t ${ECR_FRONTEND_URL}:${BUILD_NUMBER} Application-Code/frontend/
                    docker push ${ECR_FRONTEND_URL}:${BUILD_NUMBER}
                '''
            }
        }

        stage('Build & Push Backend') {
            steps {
                sh '''
                    docker build -t ${ECR_BACKEND_URL}:${BUILD_NUMBER} Application-Code/backend/
                    docker push ${ECR_BACKEND_URL}:${BUILD_NUMBER}
                '''
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh '''
                    trivy image --severity HIGH,CRITICAL --no-progress ${ECR_FRONTEND_URL}:${BUILD_NUMBER} || true
                    trivy image --severity HIGH,CRITICAL --no-progress ${ECR_BACKEND_URL}:${BUILD_NUMBER} || true
                '''
            }
        }

        stage('Update Helm Chart Tags') {
            steps {
                sh """
                    sed -i "s|repository:.*|repository: ${env.ECR_FRONTEND_URL}|g" helm-charts/frontend/values.yaml
                    sed -i "s|repository:.*|repository: ${env.ECR_BACKEND_URL}|g" helm-charts/backend/values.yaml
                    sed -i "s|tag:.*|tag: \\"${BUILD_NUMBER}\\"|g" helm-charts/frontend/values.yaml
                    sed -i "s|tag:.*|tag: \\"${BUILD_NUMBER}\\"|g" helm-charts/backend/values.yaml
                """
            }
        }

        stage('Push Updated Helm Charts') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'github-credentials', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
                    sh '''
                        git config user.email "jenkins@ci.com"
                        git config user.name "Jenkins CI"
                        git pull https://$GIT_USER:$GIT_PASS@github.com/Aishwini08/End-to-End-Kubernetes-Three-Tier-Project.git main || true
                        git add helm-charts/frontend/values.yaml helm-charts/backend/values.yaml
                        git diff --staged --quiet || git commit -m "CI: update image tags to ${BUILD_NUMBER} [skip ci] [ci skip]"
                        git push https://$GIT_USER:$GIT_PASS@github.com/Aishwini08/End-to-End-Kubernetes-Three-Tier-Project.git main
                    '''
                }
            }
        }

    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
        aborted {
            echo 'Pipeline skipped - triggered by Jenkins CI commit.'
        }
    }
}