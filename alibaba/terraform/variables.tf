# Variables
variable "region" {
  description = "Alibaba Cloud region"
  type        = string
  default     = "us-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "webapp"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "Project name must be 3-21 characters, start with letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "vswitch_cidrs" {
  description = "CIDR blocks for VSwitches (subnets)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  
  validation {
    condition     = length(var.vswitch_cidrs) >= 1
    error_message = "At least one VSwitch CIDR must be provided."
  }
}

variable "instance_type" {
  description = "ECS instance type"
  type        = string
  default     = "ecs.t6-c1m1.large"
}

variable "instance_count" {
  description = "Number of ECS instances to create"
  type        = number
  default     = 2
  
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "system_disk_size" {
  description = "System disk size in GB"
  type        = number
  default     = 40
  
  validation {
    condition     = var.system_disk_size >= 20 && var.system_disk_size <= 500
    error_message = "System disk size must be between 20 and 500 GB."
  }
}

variable "internet_max_bandwidth_out" {
  description = "Maximum outbound internet bandwidth in Mbps"
  type        = number
  default     = 100
  
  validation {
    condition     = var.internet_max_bandwidth_out >= 0 && var.internet_max_bandwidth_out <= 200
    error_message = "Internet bandwidth must be between 0 and 200 Mbps."
  }
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_monitoring" {
  description = "Enable CloudMonitor for instances"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 7
}