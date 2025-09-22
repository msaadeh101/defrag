stage('Deploy with Metrics') {
    steps {
        script {
            // Deploy application
            deployToEnvironment(environment, imageTag)
            
            // Configure metrics collection
            configureMetrics(environment)
            
            // Set up alerts
            configureAlerts(environment)
        }
    }
}

def configureMetrics(environment) {
    container('kubectl') {
        sh """
            # Apply ServiceMonitor for Prometheus
            envsubst < monitoring/servicemonitor.yaml | kubectl apply -f -
            
            # Apply PrometheusRule for alerts
            envsubst < monitoring/prometheusrule.yaml | kubectl apply -f -
            
            # Create Grafana dashboard
            kubectl create configmap microservice-dashboard \
                --from-file=monitoring/grafana-dashboard.json \
                -n monitoring \
                --dry-run=client -o yaml | kubectl apply -f -
        """
    }
}