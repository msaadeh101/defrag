# Deploy Prometheus with Thanos sidecar
resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = "monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "52.1.0"

  values = [file("../helm/values.yaml")]
}

# For querying historical metrics
resource "helm_release" "thanos_store" {
  name       = "thanos-store"
  namespace  = "monitoring"
  repository = "https://bitnami.github.io/charts"
  chart      = "thanos"

  set {
    name  = "storeGateway.enabled"
    value = "true"
  }

  set {
    name  = "objstoreConfig.secretName"
    value = "thanos-objstore-secret"
  }

  set {
    name  = "objstoreConfig.secretKey"
    value = "objstore.yml"
  }
}

# Enables querying across multiple Prometheus instances and S3
resource "helm_release" "thanos_query" {
  name       = "thanos-query"
  namespace  = "monitoring"
  repository = "https://bitnami.github.io/charts"
  chart      = "thanos"

  set {
    name  = "query.enabled"
    value = "true"
  }

  set {
    name  = "query.replicaCount"
    value = "2"
  }
}

# Minimizes storage costs
resource "helm_release" "thanos_compactor" {
  name       = "thanos-compactor"
  namespace  = "monitoring"
  repository = "https://bitnami.github.io/charts"
  chart      = "thanos"

  set {
    name  = "compactor.enabled"
    value = "true"
  }

  set {
    name  = "compactor.retention.resolutionRaw"
    value = "30d"
  }

  set {
    name  = "objstoreConfig.secretName"
    value = "thanos-objstore-secret"
  }

  set {
    name  = "objstoreConfig.secretKey"
    value = "objstore.yml"
  }
}

# Visualization
resource "helm_release" "grafana" {
  name       = "grafana"
  namespace  = "monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"

  set {
    name  = "adminPassword"
    value = "SuperSecurePassword123"
  }

  set {
    name  = "datasources.datasources.yaml.apiVersion"
    value = "1"
  }

  set {
    name  = "datasources.datasources.yaml.datasources[0].name"
    value = "Thanos"
  }

  set {
    name  = "datasources.datasources.yaml.datasources[0].type"
    value = "prometheus"
  }

  set {
    name  = "datasources.datasources.yaml.datasources[0].url"
    value = "http://thanos-query.monitoring.svc.cluster.local:10902"
  }

  set {
    name  = "datasources.datasources.yaml.datasources[0].access"
    value = "proxy"
  }
}

