def call(Map config) {
    def requiredParams = ['environment', 'application', 'version']
    def missingParams = requiredParams.findAll { !config.containsKey(it) }
    // it is groovy shorthand for current item
    
    if (missingParams) {
        error "Missing required parameters: ${missingParams.join(', ')}"
    }
    
    def environment = config.environment
    def application = config.application
    def version = config.version
    def namespace = config.namespace ?: environment
    def timeout = config.timeout ?: '5m'
    def rollbackOnFailure = config.rollbackOnFailure != false
    
    try {
        stage("Deploy to ${environment}") {
            // Validate environment
            if (!isValidEnvironment(environment)) {
                error "Invalid environment: ${environment}"
            }
            
            // Check deployment prerequisites
            validateDeploymentPrerequisites(environment, application)
            
            // Perform deployment
            deployApplication(environment, application, version, namespace)
            
            // Wait for deployment to be ready
            waitForDeployment(environment, application, timeout)
            
            // Run post-deployment tests
            if (config.healthCheck != false) {
                runHealthCheck(environment, application)
            }
            
            // Update deployment tracking
            updateDeploymentRecord(environment, application, version)
        }
    } catch (Exception e) {
        if (rollbackOnFailure) {
            echo "Deployment failed, initiating rollback..."
            rollbackDeployment(environment, application)
        }
        throw e
    }
}

private def isValidEnvironment(String env) {
    def validEnvironments = ['dev', 'staging', 'prod']
    return validEnvironments.contains(env.toLowerCase())
}

private def validateDeploymentPrerequisites(String env, String app) {
    // Check if namespace exists
    def namespaceCheck = sh(
        script: "kubectl get namespace ${env} --ignore-not-found",
        returnStatus: true
    )
    
    if (namespaceCheck != 0) {
        error "Namespace ${env} does not exist"
    }
    
    // Check if previous deployment exists
    def deploymentExists = sh(
        script: "kubectl get deployment ${app} -n ${env} --ignore-not-found",
        returnStatus: true
    )
    
    if (deploymentExists != 0 && env == 'prod') {
        error "Production deployment for ${app} not found. Cannot deploy to production without staging validation."
    }
}

private def deployApplication(String env, String app, String version, String namespace) {
    def deploymentYaml = libraryResource('templates/k8s-deployment.yaml')
    
    writeFile file: 'deployment.yaml', text: deploymentYaml
    
    sh """
        sed -i 's/\${APP_NAME}/${app}/g' deployment.yaml
        sed -i 's/\${VERSION}/${version}/g' deployment.yaml
        sed -i 's/\${NAMESPACE}/${namespace}/g' deployment.yaml
        
        kubectl apply -f deployment.yaml
    """
}

private def waitForDeployment(String env, String app, String timeout) {
    sh "kubectl rollout status deployment/${app} -n ${env} --timeout=${timeout}"
}

private def runHealthCheck(String env, String app) {
    def healthCheckScript = libraryResource('scripts/health-check.sh')
    writeFile file: 'health-check.sh', text: healthCheckScript
    sh "chmod +x health-check.sh && ./health-check.sh ${env} ${app}"
}

private def rollbackDeployment(String env, String app) {
    sh "kubectl rollout undo deployment/${app} -n ${env}"
    sh "kubectl rollout status deployment/${app} -n ${env} --timeout=3m"
}

private def updateDeploymentRecord(String env, String app, String version) {
    // Implementation would update deployment tracking system
    echo "Updated deployment record: ${app} v${version} deployed to ${env}"
}