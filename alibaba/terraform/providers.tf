# Compatible with Terraform >= 0.13 and OpenTofu

terraform {
  required_version = ">= 0.13"
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.248.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  # Backend configuration - uncomment and configure for production
  # backend "oss" {
  #   bucket   = "your-terraform-state-bucket"
  #   key      = "production/terraform.tfstate"
  #   region   = "us-west-1"
  #   encrypt  = true
  # }
}

# Configure the Alibaba Cloud Provider
provider "alicloud" {
  region = var.region
  # Credentials should be set via environment variables:
  # ALICLOUD_ACCESS_KEY, ALICLOUD_SECRET_KEY
}