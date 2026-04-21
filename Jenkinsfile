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
                    aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.ap-south-1.amazonaws.com
                '''
            }
        }

        stage('Build & Push Frontend') {
            steps {
                sh '''
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
                        git config user.name "Jenkins"
                        git add helm-charts/frontend/values.yaml helm-charts/backend/values.yaml
                        git commit -m "Update image tags to ${BUILD_NUMBER}"
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
    }
}