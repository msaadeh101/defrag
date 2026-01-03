# CRD: ServiceMonitor for Prometheus to define scrape targets
resource "kubectl_manifest" "user_service_monitor" {
  yaml_body = <<-YAML
    apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor               
    metadata:
      name: user-service-metrics
      namespace: microservices 
    spec:
      selector:
        matchLabels:
          app: user-service 
      endpoints:
        - port: http                   
          path: /actuator/prometheus  
          interval: 30s                  
  YAML

  # Finds Services with app: user-service label in namespace microservices
  # Ensures Prometheus Operator CRDs exist before trying to create this
  # /actuator/prometheus is the endpoint exposing prometheus metrics (micrometer-registry-prometheus for Spring Boot)
  depends_on = [module.eks_blueprints_addons] 
}