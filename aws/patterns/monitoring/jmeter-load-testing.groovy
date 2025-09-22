stage('Performance Testing') {
    when {
        anyOf {
            branch 'main'
            changeRequest target: 'main'
        }
    }
    steps {
        script {
            // Run JMeter tests
            container('jmeter') {
                sh """
                    # Run performance tests
                    jmeter -n -t performance-tests/load-test.jmx \
                           -l performance-results.jtl \
                           -e -o performance-report \
                           -Jhost=\${SERVICE_URL} \
                           -Jusers=\${LOAD_TEST_USERS:-100} \
                           -Jrampup=\${LOAD_TEST_RAMPUP:-300} \
                           -Jduration=\${LOAD_TEST_DURATION:-600}
                           
                    # Generate trend report
                    jmeter -g performance-results.jtl -o trend-report
                """
            }
            
            // Parse results
            def perfResults = readFile('performance-results.jtl')
            def avgResponseTime = parsePerformanceResults(perfResults)
            
            // Fail if performance degradation
            if (avgResponseTime > env.MAX_RESPONSE_TIME?.toInteger() ?: 2000) {
                error("Performance test failed: Average response time ${avgResponseTime}ms exceeds threshold")
            }
            
            // Store results for trending
            storePerformanceResults(avgResponseTime, env.BUILD_NUMBER)
        }
    }
    post {
        always {
            publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'performance-report',
                reportFiles: 'index.html',
                reportName: 'Performance Test Report'
            ])
            archiveArtifacts artifacts: 'performance-results.jtl', fingerprint: true
        }
    }
}

def parsePerformanceResults(results) {
    // Parse JMeter results to extract metrics
    def lines = results.split('\n')
    def responseTimes = []
    
    lines.each { line ->
        if (line && !line.startsWith('timeStamp')) {
            def parts = line.split(',')
            if (parts.length > 1) {
                responseTimes.add(parts[1] as Integer)
            }
        }
    }
    
    return responseTimes.sum() / responseTimes.size()
}