pipeline {
    agent any

    environment {
        DOCKER_HUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKER_HUB_USERNAME = 'aishwini08'
        GITHUB_REPO = 'https://github.com/Aishwini08/End-to-End-Kubernetes-Three-Tier-Project.git'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', credentialsId: 'github-credentials', url: "${GITHUB_REPO}"
            }
        }

        stage('Build & Push Frontend') {
            steps {
                sh '''
                    echo $DOCKER_HUB_CREDENTIALS_PSW | docker login -u $DOCKER_HUB_CREDENTIALS_USR --password-stdin
                    docker build -t ${DOCKER_HUB_USERNAME}/frontend:${BUILD_NUMBER} Application-Code/frontend/
                    docker push ${DOCKER_HUB_USERNAME}/frontend:${BUILD_NUMBER}
                    docker tag ${DOCKER_HUB_USERNAME}/frontend:${BUILD_NUMBER} ${DOCKER_HUB_USERNAME}/frontend:latest
                    docker push ${DOCKER_HUB_USERNAME}/frontend:latest
                '''
            }
        }

        stage('Build & Push Backend') {
            steps {
                sh '''
                    echo $DOCKER_HUB_CREDENTIALS_PSW | docker login -u $DOCKER_HUB_CREDENTIALS_USR --password-stdin
                    docker build -t ${DOCKER_HUB_USERNAME}/backend:${BUILD_NUMBER} Application-Code/backend/
                    docker push ${DOCKER_HUB_USERNAME}/backend:${BUILD_NUMBER}
                    docker tag ${DOCKER_HUB_USERNAME}/backend:${BUILD_NUMBER} ${DOCKER_HUB_USERNAME}/backend:latest
                    docker push ${DOCKER_HUB_USERNAME}/backend:latest
                '''
            }
        }

        stage('Update Helm Chart Tags') {
            steps {
                sh '''
                    sed -i "s|tag: .*|tag: \"${BUILD_NUMBER}\"|g" helm-charts/frontend/values.yaml
                    sed -i "s|tag: .*|tag: \"${BUILD_NUMBER}\"|g" helm-charts/backend/values.yaml
                '''
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
