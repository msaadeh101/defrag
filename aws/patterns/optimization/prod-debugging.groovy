stage('Post-Deployment Verification') {
    steps {
        script {
            // Comprehensive health checks
            runHealthChecks(environment)
            
            // Performance baseline validation
            validatePerformanceBaseline(environment)
            
            // Integration testing
            runIntegrationTests(environment)
        }
    }
    post {
        failure {
            script {
                // Collect debugging information
                collectDebugInfo(environment)
                
                // Generate troubleshooting report
                generateTroubleshootingReport(environment)
            }
        }
    }
}

def collectDebugInfo(environment) {
    container('kubectl') {
        sh """
            # Collect pod logs
            kubectl logs -l app=microservice-app -n ${environment} --tail=1000 > app-logs.txt
            
            # Collect events
            kubectl get events -n ${environment} --sort-by=.metadata.creationTimestamp > events.txt
            
            # Collect resource usage
            kubectl top pods -n ${environment} > resource-usage.txt
            
            # Collect service information
            kubectl describe service microservice-app -n ${environment} > service-info.txt
            
            # Collect deployment status
            kubectl describe deployment microservice-app -n ${environment} > deployment-info.txt
            
            # Collect ingress information
            kubectl describe ingress microservice-app -n ${environment} > ingress-info.txt || echo "No ingress found"
        """
    }
    
    // Archive debugging information
    archiveArtifacts artifacts: '*.txt', fingerprint: true
}

def generateTroubleshootingReport(environment) {
    script {
        def report = """
# Troubleshooting Report
## Build Information
- Build Number: ${env.BUILD_NUMBER}
- Git Commit: ${env.GIT_COMMIT_SHORT}
- Environment: ${environment}
- Image Tag: ${env.IMAGE_TAG}

## Failure Information
- Pipeline Stage: ${env.STAGE_NAME}
- Failure Time: ${new Date()}

## Quick Debugging Commands
\`\`\`bash
# Check pod status
kubectl get pods -n ${environment} -l app=microservice-app

# Check logs
kubectl logs -l app=microservice-app -n ${environment} --tail=100

# Check events
kubectl get events -n ${environment} --sort-by=.metadata.creationTimestamp

# Check service endpoints
kubectl get endpoints microservice-app -n ${environment}

# Port forward for local debugging
kubectl port-forward service/microservice-app 8080:80 -n ${environment}
\`\`\`

## Health Check URLs
- Health: http://service-url/actuator/health
- Info: http://service-url/actuator/info
- Metrics: http://service-url/actuator/metrics

## Logs Location
- Application logs: Check archived artifacts
- Build logs: Jenkins build console
"""
        
        writeFile file: 'troubleshooting-report.md', text: report
        archiveArtifacts artifacts: 'troubleshooting-report.md'
        
        // Send to Slack with troubleshooting information
        sendSlackAlert("🔧 Deployment failed. Troubleshooting report available in build artifacts.")
    }
}