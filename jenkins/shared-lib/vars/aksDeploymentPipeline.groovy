def call(Map config = [:]) { // Declaring a config map of key value pairs
    pipeline {
        agent {
            label config.agentLabel ?: "linux"
        }

        environment {
            DOCKER_REGISTRY    = config.dockerRegistry
            IMAGE_NAME         = config.imageName
            IMAGE_TAG          = "${env.BUILD_ID}"
            AKS_CLUSTER_NAME   = config.aksClusterName
            AKS_RESOURCE_GROUP = config.aksResourceGroup
            NAMESPACE          = config.namespace ?: "default"
            KUBECONFIG         = "/tmp/kubeconfig"
            TEAMS_WEBHOOK_URL  = credentials(config.teamsWebhookCred)
            EMAIL_RECIPIENTS   = config.emailRecipients
            AZURE_CREDENTIALS  = credentials(config.azureCredId)
        }

        stages {
            stage('Checkout Code') {
                steps {
                    checkout scm
                }
            }

            stage('Build Docker Image') {
                steps {
                    script {
                        echo "Building Docker image..."
                        sh """
                            docker build -t ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} .
                        """
                    }
                }
            }

            stage('Login to ACR') {
                steps {
                    script {
                        echo "Logging into Azure Container Registry..."
                        withCredentials([azureServicePrincipal(
                            credentialsId: config.azureCredId,
                            subscriptionIdVariable: 'AZURE_SUBSCRIPTION_ID',
                            clientIdVariable:        'AZURE_CLIENT_ID',
                            clientSecretVariable:    'AZURE_CLIENT_SECRET',
                            tenantIdVariable:        'AZURE_TENANT_ID'
                        )]) {
                            sh """
                                az acr login --name ${DOCKER_REGISTRY}
                            """
                        }
                    }
                }
            }

            stage('Push Docker Image') {
                steps {
                    script {
                        echo "Pushing Docker image to ACR..."
                        sh """
                            docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        """
                    }
                }
            }

            stage('Deploy to AKS') {
                steps {
                    script {
                        echo "Deploying to AKS..."
                        withCredentials([file(credentialsId: config.kubeconfigCredId, variable: 'KUBECONFIG')]) {
                            sh """
                                kubectl --kubeconfig=${KUBECONFIG} apply -f k8s/deployment.yaml
                                kubectl --kubeconfig=${KUBECONFIG} set image deployment/${IMAGE_NAME} ${IMAGE_NAME}=${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} -n ${NAMESPACE}
                                kubectl --kubeconfig=${KUBECONFIG} rollout status deployment/${IMAGE_NAME} -n ${NAMESPACE}
                            """
                        }
                    }
                }
            }

            stage('Verify Deployment') {
                steps {
                    script {
                        echo "Verifying deployment..."
                        withCredentials([file(credentialsId: config.kubeconfigCredId, variable: 'KUBECONFIG')]) {
                            sh """
                                kubectl --kubeconfig=${KUBECONFIG} get pods -n ${NAMESPACE}
                                kubectl --kubeconfig=${KUBECONFIG} get services -n ${NAMESPACE}
                            """
                        }
                    }
                }
            }
        }

        post {
            always {
                echo "Cleaning up resources..."
                sh 'docker system prune -f'
            }

            success {
                script {
                    echo "Deployment successful, notifying team..."
                    httpRequest(
                        url: "${TEAMS_WEBHOOK_URL}",
                        httpMode: 'POST',
                        contentType: 'APPLICATION_JSON',
                        body: """
                        { "text": "Deployment successful for ${IMAGE_NAME}:${IMAGE_TAG} on AKS" }
                        """
                    )
                }
            }

            failure {
                script {
                    echo "Deployment failed, notifying team..."
                    httpRequest(
                        url: "${TEAMS_WEBHOOK_URL}",
                        httpMode: 'POST',
                        contentType: 'APPLICATION_JSON',
                        body: """
                        { "text": "Deployment failed for ${IMAGE_NAME}:${IMAGE_TAG} on AKS" }
                        """
                    )

                    emailext(
                        subject: "Build failed: ${JOB_NAME} - Build #${BUILD_NUMBER}",
                        body: "The build ${JOB_NAME} - Build #${BUILD_NUMBER} failed. Please check the Jenkins console for details.",
                        to: "${EMAIL_RECIPIENTS}"
                    )
                }
            }
        }
    }
}
