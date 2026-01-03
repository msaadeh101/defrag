resource "kubectl_manifest" "letsencrypt_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: admin@yourdomain.com # Change this to your email
        privateKeySecretRef:
          name: letsencrypt-prod-account-key
        solvers:
        - dns01:
            route53:
              region: ${local.region}
              # If using IRSA, cert-manager uses the role assigned via Terraform automatically
  YAML

  depends_on = [module.eks_blueprints_addons]
}

resource "kubectl_manifest" "istio_ingress_cert" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: istio-ingress-cert
      namespace: istio-ingress # Must match your gateway namespace
    spec:
      secretName: istio-ingress-certs-tls # Istio will mount this
      issuerRef:
        name: letsencrypt-prod
        kind: ClusterIssuer
      dnsNames:
        - "api.yourdomain.com"
        - "*.yourdomain.com"
  YAML

  depends_on = [kubectl_manifest.letsencrypt_issuer]
}