provider "aws" {
  region = "us-east-1"
}

locals {
  name   = "prod-microservices"
  region = "us-east-1"
  vpc_cidr = "10.0.0.0/16"
  azs      = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr
  azs  = local.azs

  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 4)]

  enable_nat_gateway = true
  single_nat_gateway = true

  # CRITICAL for Karpenter discovery
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = local.name
  }
}

# https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/main.tf
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = "1.33"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Access Entry (New K8s 1.30+ API default over configmaps)
  authentication_mode                         = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  # System Managed Node Group (Hosts CoreDNS and Karpenter)
  eks_managed_node_groups = {
    system = {
      ami_family     = "AL2023"
      instance_types = ["t3.medium"]
      min_size     = 2
      max_size     = 4
      desired_size = 2

      labels = { workload = "system" }
      taints = [{ key = "CriticalAddonsOnly", value = "true", effect = "NO_SCHEDULE" }]
    }
  }
}