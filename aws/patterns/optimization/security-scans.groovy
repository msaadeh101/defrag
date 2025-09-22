stage('Security Scans') {
    parallel {
        stage('SAST Scan') {
            steps {
                container('maven') {
                    sh '''
                        # SonarQube security analysis
                        mvn sonar:sonar \
                            -Dsonar.projectKey=${JOB_NAME} \
                            -Dsonar.qualitygate.wait=true \
                            -Dsonar.security.hotspots.maxIssues=0
                    '''
                }
            }
        }
        
        stage('Container Security') {
            steps {
                container('docker') {
                    sh '''
                        # Trivy vulnerability scan
                        trivy image --severity HIGH,CRITICAL \
                            --format sarif --output trivy-results.sarif \
                            ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                            
                        # Dockle security check
                        dockle --format json --output dockle-results.json \
                            ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-results.sarif,dockle-results.json'
                }
            }
        }
        
        stage('Dependency Check') {
            steps {
                container('maven') {
                    sh '''
                        # OWASP Dependency Check
                        mvn org.owasp:dependency-check-maven:check \
                            -DfailBuildOnCVSS=7 \
                            -DsuppressionFile=owasp-suppressions.xml
                    '''
                }
            }
            post {
                always {
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'target',
                        reportFiles: 'dependency-check-report.html',
                        reportName: 'OWASP Dependency Check Report'
                    ])
                }
            }
        }
    }
}