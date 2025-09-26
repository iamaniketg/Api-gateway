pipeline {
    agent any

    environment {
        PROJECT_ID = 'thinking-anthem-471805-a1'
        IMAGE_NAME = "captainaniii/eureka-server"
        REGION = 'asia-southeast1'
        ZONE = 'asia-southeast1-a'
        CLUSTER_NAME = 'cluster-1'
        K8S_DEPLOYMENT = 'api-gateway'
        K8S_NAMESPACE = 'backend'
        MAVEN_HOME = tool name: 'maven'
        PATH = "${MAVEN_HOME}/bin:${env.PATH}"
        GCLOUD_PATH = "${WORKSPACE}/google-cloud-sdk/bin/gcloud"
    }

    stages {
        stage('Checkout') {
            steps {
                git(
                    branch: 'main',
                    credentialsId: 'github-credentials',
                    url: 'https://github.com/iamaniketg/Api-gateway.git'
                )
            }
        }

        stage('Install gcloud') {
            steps {
                script {
                    def gcloudInstalled = false
                    if (fileExists(GCLOUD_PATH)) {
                        try {
                            sh "${GCLOUD_PATH} --version"
                            gcloudInstalled = true
                        } catch (err) {
                            echo "Invalid gcloud; reinstalling."
                        }
                    }
                    if (!gcloudInstalled) {
                        sh 'rm -rf google-cloud-sdk'
                        sh 'curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz'
                        sh 'tar -xf google-cloud-cli-linux-x86_64.tar.gz'
                        sh './google-cloud-sdk/install.sh --quiet --usage-reporting false --path-update false --bash-completion false'
                        sh "${GCLOUD_PATH} components install kubectl --quiet"
                        sh "${GCLOUD_PATH} components install gke-gcloud-auth-plugin --quiet"
                    }
                    sh "${GCLOUD_PATH} --version"
                }
            }
        }

        stage('Set up GCP') {
            steps {
                withCredentials([file(credentialsId: 'gcp-service-account', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                    script {
                        sh """
                            export PATH=${WORKSPACE}/google-cloud-sdk/bin:\$PATH
                            gcloud auth activate-service-account --key-file=\$GOOGLE_APPLICATION_CREDENTIALS
                            gcloud config set project ${PROJECT_ID}
                            gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${ZONE} --project ${PROJECT_ID}
                        """
                    }
                }
            }
        }

        stage('Build and Test') {
            parallel {
                stage('Maven Build') {
                    steps {
                        // Assuming agent has Maven cache mounted; if not, consider Jenkins Maven plugin for caching
                        sh 'mvn clean package -DskipTests'  // Add tests if needed: remove -DskipTests
                    }
                }
                stage('Unit Tests') {  // Optional: Enable if you want tests
                    when { expression { false } }  // Toggle to true for testing
                    steps {
                        sh 'mvn test'
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    env.IMAGE_TAG = "${BUILD_NUMBER}"
                    def fullImage = "${IMAGE_NAME}:${IMAGE_TAG}"
                    sh "docker build --cache-from ${IMAGE_NAME}:latest -t ${fullImage} ."  // Use cache from previous image
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-cred', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    script {
                        retry(3) {
                            def fullImage = "${IMAGE_NAME}:${IMAGE_TAG}"
                            sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                            sh "docker push ${fullImage}"
                            sh "docker tag ${fullImage} ${IMAGE_NAME}:latest && docker push ${IMAGE_NAME}:latest"  // Optional: Push latest tag
                        }
                    }
                }
            }
        }

        stage('Deploy to GKE') {
            steps {
                withCredentials([file(credentialsId: 'gcp-service-account', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                    script {
                        def fullImage = "${IMAGE_NAME}:${IMAGE_TAG}"
                        sh """
                            export PATH=${WORKSPACE}/google-cloud-sdk/bin:\$PATH
                            gcloud auth activate-service-account --key-file=\$GOOGLE_APPLICATION_CREDENTIALS  // Only if needed; already done earlier
                            kubectl create namespace ${K8S_NAMESPACE} || true
                            kubectl apply -f eureka-configmap.yaml -n ${K8S_NAMESPACE}
                            kubectl set image deployment/${K8S_DEPLOYMENT} ${K8S_DEPLOYMENT}=${fullImage} -n ${K8S_NAMESPACE}  // Better than sed
                            kubectl apply -f eureka-deployment.yaml -n ${K8S_NAMESPACE}  // Apply after set image
                            kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} --timeout=5m
                        """
                    }
                }
            }
            post {
                success {
                    echo 'Deployment successful!'
                }
                failure {
                    echo 'Deployment failed! Rolling back...'
                    sh """
                        export PATH=${WORKSPACE}/google-cloud-sdk/bin:\$PATH
                        kubectl rollout undo deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} || true
                    """
                }
            }
        }
    }

    post {
        always {
            sh 'docker system prune -f'  // Clean up Docker artifacts
            archiveArtifacts artifacts: 'target/*.jar', allowEmptyArchive: true  // Save JAR for debugging
            echo "Pipeline finished - cleaning up..."
        }
        success {
            echo "✅ Deployment successful!"
            // Add notification: slackSend(channel: '#ci-cd', message: "Build ${BUILD_NUMBER} succeeded!")
        }
        failure {
            echo "❌ Deployment failed!"
            // Add notification: slackSend(channel: '#ci-cd', message: "Build ${BUILD_NUMBER} failed!")
        }
    }
}