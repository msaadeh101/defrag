terraform {
  required_version = ">= 1.0"
  required_providers {
    argocd = {
      source  = "oboukili/argocd"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ArgoCD provider configuration
provider "argocd" {
  server_addr = var.argocd_server_addr  # e.g., "argocd.example.com:443"
  auth_token  = var.argocd_auth_token   # Generated via CLI or stored in AWS Secrets Manager
  insecure    = false
}