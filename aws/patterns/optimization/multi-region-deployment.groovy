stage('Multi-Region Deployment') {
    when {
        branch 'main'
        environment name: 'ENABLE_DR', value: 'true'
    }
    parallel {
        stage('Primary Region') {
            steps {
                script {
                    deployToRegion('us-west-2', 'primary', imageTag)
                }
            }
        }
        stage('DR Region') {
            steps {
                script {
                    deployToRegion('us-east-1', 'dr', imageTag)
                }
            }
        }
    }
    post {
        success {
            script {
                // Update Route 53 health checks
                updateRoute53HealthChecks()
                
                // Verify cross-region replication
                verifyCrossRegionReplication()
            }
        }
    }
}

def deployToRegion(region, type, imageTag) {
    container('kubectl') {
        sh """
            # Update kubeconfig for region
            aws eks update-kubeconfig --region ${region} --name eks-cluster-${type}
            
            # Deploy to region
            export AWS_DEFAULT_REGION=${region}
            export REGION_TYPE=${type}
            
            envsubst < k8s/multi-region-deployment.yaml | kubectl apply -f -
            kubectl rollout status deployment/microservice-app -n production --timeout=600s
        """
    }
}

def updateRoute53HealthChecks() {
    sh """
        # Update Route 53 health checks for both regions
        aws route53 change-resource-record-sets \
            --hosted-zone-id \${HOSTED_ZONE_ID} \
            --change-batch file://route53-health-check-config.json
    """
}