def deployToEKS(environment, imageTag) {
    script {
        // Update kubeconfig
        sh """
            aws eks update-kubeconfig \
                --region ${AWS_DEFAULT_REGION} \
                --name eks-cluster-${environment}
        """

        // Apply ConfigMap and Secrets
        sh """
            envsubst < k8s/configmap.yaml | kubectl apply -f -
            envsubst < k8s/secrets.yaml | kubectl apply -f -
        """

        // Apply deployment
        sh """
            export NAMESPACE=${environment}
            export IMAGE_TAG=${imageTag}
            export REPLICA_COUNT=\$(kubectl get deployment microservice-app -n ${environment} -o jsonpath='{.spec.replicas}' 2>/dev/null || echo '3')
            export MIN_REPLICAS=\$(if [ "${environment}" = "production" ]; then echo 5; else echo 3; fi)
            export MAX_REPLICAS=\$(if [ "${environment}" = "production" ]; then echo 20; else echo 10; fi)
            
            envsubst < k8s/deployment.yaml | kubectl apply -f -
        """

        // Wait for rollout to complete
        sh """
            kubectl rollout status deployment/microservice-app -n ${environment} --timeout=600s
        """

        // Verify deployment
        sh """
            kubectl get pods -n ${environment} -l app=microservice-app
            kubectl get service microservice-app -n ${environment}
        """

        // Run health check
        def serviceUrl = sh(
            script: """
                kubectl get service microservice-app -n ${environment} \
                    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
            """,
            returnStdout: true
        ).trim()

        if (serviceUrl) {
            sh """
                timeout 300 bash -c 'until curl -f http://${serviceUrl}:8081/actuator/health; do sleep 10; done'
            """
            echo "Health check passed for ${serviceUrl}"
        }
    }
}