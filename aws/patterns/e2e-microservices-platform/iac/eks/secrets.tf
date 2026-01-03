resource "kubectl_manifest" "aws_cluster_secret_store" {
  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ClusterSecretStore
    metadata:
      name: aws-secrets-manager
    spec:
      provider:
        aws:
          service: SecretsManager
          region: ${local.region}
          auth:
            jwt:
              serviceAccountRef:
                name: external-secrets-sa
                namespace: external-secrets-system
  YAML

  # Wait for the operator to be installed before applying CRDs
  depends_on = [module.eks_blueprints_addons]
}

resource "kubectl_manifest" "db_external_secret" {
  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: db-credentials
      namespace: microservices
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: aws-secrets-manager
        kind: ClusterSecretStore
      target:
        name: db-credentials
        creationPolicy: Owner
      data:
        - secretKey: host
          remoteRef:
            key: rds/postgres/credentials
            property: host
        - secretKey: username
          remoteRef:
            key: rds/postgres/credentials
            property: username
        - secretKey: password
          remoteRef:
            key: rds/postgres/credentials
            property: password
  YAML

  depends_on = [kubectl_manifest.aws_cluster_secret_store]
}