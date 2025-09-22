stage('Resource Optimization') {
    when {
        branch 'main'
    }
    steps {
        script {
            // Analyze current resource usage
            analyzeResourceUsage(environment)
            
            // Optimize based on usage patterns
            optimizeResources(environment)
            
            // Update cost tracking tags
            updateCostTags(environment, imageTag)
        }
    }
}

def analyzeResourceUsage(environment) {
    container('kubectl') {
        sh """
            # Get current resource usage
            kubectl top pods -n ${environment} --sort-by=memory
            kubectl top pods -n ${environment} --sort-by=cpu
            
            # Generate resource utilization report
            kubectl describe nodes | grep -A 5 "Allocated resources" > resource-usage-report.txt
        """
    }
    
    // Archive resource usage report
    archiveArtifacts artifacts: 'resource-usage-report.txt'
}

def optimizeResources(environment) {
    script {
        // Get resource recommendations from VPA
        def recommendations = sh(
            script: """
                kubectl get vpa microservice-app-vpa -n ${environment} \
                    -o jsonpath='{.status.recommendation.containerRecommendations[0]}'
            """,
            returnStdout: true
        ).trim()
        
        if (recommendations) {
            echo "VPA Recommendations: ${recommendations}"
            
            // Apply recommendations if within bounds
            def cpuRequest = extractRecommendation(recommendations, 'cpu', 'target')
            def memoryRequest = extractRecommendation(recommendations, 'memory', 'target')
            
            if (shouldApplyRecommendation(cpuRequest, memoryRequest)) {
                sh """
                    kubectl patch deployment microservice-app -n ${environment} \
                        -p '{"spec":{"template":{"spec":{"containers":[{
                            "name":"microservice-app",
                            "resources":{"requests":{"cpu":"${cpuRequest}","memory":"${memoryRequest}"}}
                        }]}}}}'
                """
                echo "Applied resource optimization recommendations"
            }
        }
    }
}