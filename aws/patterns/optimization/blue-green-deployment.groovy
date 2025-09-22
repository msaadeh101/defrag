stage('Blue-Green Deployment') {
    when {
        branch 'main'
        environment name: 'DEPLOYMENT_STRATEGY', value: 'blue-green'
    }
    steps {
        script {
            def currentColor = getCurrentActiveColor(environment)
            def targetColor = currentColor == 'blue' ? 'green' : 'blue'
            
            echo "Current active: ${currentColor}, deploying to: ${targetColor}"
            
            // Deploy to target environment
            deployToColoredEnvironment(environment, targetColor, imageTag)
            
            // Run smoke tests on target
            runSmokeTests(environment, targetColor)
            
            // Switch traffic
            timeout(time: 5, unit: 'MINUTES') {
                input message: "Switch traffic to ${targetColor}?", 
                      ok: 'Switch Traffic',
                      submitterParameter: 'APPROVER'
            }
            
            switchTraffic(environment, targetColor)
            
            // Verify switch
            runProductionVerification(environment)
            
            // Scale down old environment
            scaleDownOldEnvironment(environment, currentColor)
        }
    }
    post {
        failure {
            script {
                // Rollback on failure
                def currentColor = getCurrentActiveColor(environment)
                def previousColor = currentColor == 'blue' ? 'green' : 'blue'
                
                echo "Rolling back to ${previousColor}"
                switchTraffic(environment, previousColor)
                
                sendSlackAlert("🔴 Blue-Green deployment failed, rolled back to ${previousColor}")
            }
        }
        success {
            sendSlackAlert("🟢 Blue-Green deployment successful, switched to ${targetColor}")
        }
    }
}

def getCurrentActiveColor(environment) {
    return sh(
        script: """
            kubectl get service microservice-app -n ${environment} \
                -o jsonpath='{.spec.selector.color}' || echo 'blue'
        """,
        returnStdout: true
    ).trim() ?: 'blue'
}

def deployToColoredEnvironment(environment, color, imageTag) {
    container('kubectl') {
        sh """
            export NAMESPACE=${environment}
            export IMAGE_TAG=${imageTag}
            export COLOR=${color}
            
            envsubst < k8s/deployment-${color}.yaml | kubectl apply -f -
            kubectl rollout status deployment/microservice-app-${color} -n ${environment} --timeout=600s
        """
    }
}

def switchTraffic(environment, targetColor) {
    container('kubectl') {
        sh """
            kubectl patch service microservice-app -n ${environment} \
                -p '{"spec":{"selector":{"color":"${targetColor}"}}}'
        """
    }
}

def scaleDownOldEnvironment(environment, oldColor) {
    container('kubectl') {
        sh """
            kubectl scale deployment microservice-app-${oldColor} \
                --replicas=0 -n ${environment}
        """
    }
}