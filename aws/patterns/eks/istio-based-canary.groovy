stage('Canary Deployment') {
    when {
        branch 'main'
        environment name: 'DEPLOYMENT_STRATEGY', value: 'canary'
    }
    steps {
        script {
            // Deploy canary version from separate function.
            deployCanaryVersion(environment, imageTag)
            
            // Start with 5% traffic
            setCanaryTrafficPercentage(environment, 5)
            
            // Monitor for 10 minutes
            monitorCanaryMetrics(environment, 10)
            
            // Gradually increase traffic
            [10, 25, 50, 100].each { percentage ->
                timeout(time: 2, unit: 'MINUTES') {
                    input message: "Increase canary traffic to ${percentage}%?", 
                          ok: 'Increase Traffic'
                }
                
                setCanaryTrafficPercentage(environment, percentage)
                monitorCanaryMetrics(environment, 5)
            }
            
            // Promote canary to stable
            promoteCanaryToStable(environment)
        }
    }
    post {
        failure {
            script {
                // Rollback canary on failure
                rollbackCanary(environment)
                sendSlackAlert("🔴 Canary deployment failed and rolled back")
            }
        }
        success {
            sendSlackAlert("🟢 Canary deployment completed successfully")
        }
    }
}


// Define functions inside Jenkinsfile/Shared Groovy libs
// Ensure kubectl and other CLI tools available on Jenkins agent
def deployCanaryVersion(environment, imageTag) {
    container('kubectl') { // Runs shell command inside kubectl container context
        sh """
            export NAMESPACE=${environment}
            export IMAGE_TAG=${imageTag}
            
            # Deploy canary deployment, envsubst to replace ENV variables
            envsubst < k8s/canary-deployment.yaml | kubectl apply -f -
            kubectl rollout status deployment/microservice-app-canary -n ${environment}
            
            # Apply Istio VirtualService for traffic splitting
            envsubst < istio/canary-virtualservice.yaml | kubectl apply -f -
        """
    }
}

def setCanaryTrafficPercentage(environment, percentage) {
    container('kubectl') {
        sh """
            kubectl patch virtualservice microservice-app -n ${environment} \
                --type='merge' -p='{"spec":{"http":[{"route":[
                    {"destination":{"host":"microservice-app","subset":"stable"},"weight":$((100-percentage))},
                    {"destination":{"host":"microservice-app","subset":"canary"},"weight":${percentage}}
                ]}]}}'
        """
    }
    echo "Set canary traffic to ${percentage}%"
}

def monitorCanaryMetrics(environment, durationMinutes) {
    script {
        def startTime = System.currentTimeMillis()
        def endTime = startTime + (durationMinutes * 60 * 1000)
        
        while (System.currentTimeMillis() < endTime) {
            // Check error rates
            def errorRate = getCanaryErrorRate(environment)
            if (errorRate > 5.0) {
                error("Canary error rate ${errorRate}% exceeds threshold of 5%")
            }
            
            // Check response times
            def responseTime = getCanaryResponseTime(environment)
            if (responseTime > 2000) {
                error("Canary response time ${responseTime}ms exceeds threshold of 2000ms")
            }
            
            sleep(30) // Check every 30 seconds
        }
        
        echo "Canary metrics within acceptable range for ${durationMinutes} minutes"
    }
}

def getCanaryErrorRate(environment) {
    // Query Prometheus for canary error rate
    def prometheusQuery = """
        (rate(http_server_requests_seconds_count{status=~"5..",version="canary",namespace="${environment}"}[5m]) / 
         rate(http_server_requests_seconds_count{version="canary",namespace="${environment}"}[5m])) * 100
    """
    
    def result = sh(
        script: """
            curl -s "http://prometheus:9090/api/v1/query?query=${prometheusQuery.replaceAll(/\s/, '%20')}" | \
            jq -r '.data.result[0].value[1] // "0"'
        """,
        returnStdout: true
    ).trim().toDouble()
    
    return result
}