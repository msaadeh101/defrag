module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # Standard Managed EKS Addons using latest compatible version, (NOT raw helm charts)
  eks_addons = {
    vpc-cni    = { most_recent = true }          # CNI plugin wires pods into VPC IP space
    coredns    = { most_recent = true }          # Provides cluster DNS resolution for Services and pod names
    kube-proxy = { most_recent = true }          # Service and cluster-IP routing on nodes
    aws-ebs-csi-driver = { most_recent = true }  # Dynamic provisioning of EVS volumes via CSI interface
  }

  # Enable Karpenter
  enable_karpenter = true
  
  karpenter = {
    repository_username = "public.ecr.aws" # Avoid rate limits due to stricter anonymous pill rate
  }

  # Cert Manager for Ingress (Ref: your original request)
  enable_cert_manager = true          # Issues and renews TLS certs for K8 resources such as Ingresses
  cert_manager_route53_hosted_zone_arns = ["arn:aws:route53:::hostedzone/*"] 
  # Defines IAM scope cert-manager needs to manage DNS records in Route53 for DNS-01 challenges
  # Wildcard means cert-managers IAM role can create and update DNS records in ANY hosted zone
}