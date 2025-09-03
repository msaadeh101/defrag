# Production-Ready Alibaba Cloud Terraform Configuration
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

# Common tags for all resources
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  }
  
  name_prefix = "${var.project_name}-${var.environment}"
}

# Random suffix for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Data sources
data "alicloud_zones" "available" {
  available_instance_type = var.instance_type
  available_disk_category = "cloud_ssd"
}

data "alicloud_images" "ubuntu" {
  name_regex = "^ubuntu_20_04_x64.*"
  owners     = "system"
  most_recent = true
}

# VPC
resource "alicloud_vpc" "main" {
  vpc_name   = "${local.name_prefix}-vpc"
  cidr_block = var.vpc_cidr
  description = "VPC for ${var.project_name} ${var.environment} environment"
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
    Type = "network"
  })
}

# VSwitches (Subnets)
resource "alicloud_vswitch" "main" {
  count = length(var.vswitch_cidrs)
  
  vswitch_name = "${local.name_prefix}-vswitch-${count.index + 1}"
  vpc_id       = alicloud_vpc.main.id
  cidr_block   = var.vswitch_cidrs[count.index]
  zone_id      = data.alicloud_zones.available.zones[count.index % length(data.alicloud_zones.available.zones)].id
  description  = "VSwitch ${count.index + 1} for ${var.project_name}"
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vswitch-${count.index + 1}"
    Type = "network"
    Zone = data.alicloud_zones.available.zones[count.index % length(data.alicloud_zones.available.zones)].id
  })
}

# Security Group
resource "alicloud_security_group" "main" {
  name   = "${local.name_prefix}-sg"
  vpc_id = alicloud_vpc.main.id
  description = "Security group for ${var.project_name} ${var.environment}"
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg"
    Type = "security"
  })
}

# Security Group Rules
resource "alicloud_security_group_rule" "ssh" {
  count = length(var.allowed_ssh_cidrs)
  
  type              = "ingress"
  ip_protocol       = "tcp"
  port_range        = "22/22"
  security_group_id = alicloud_security_group.main.id
  cidr_ip           = var.allowed_ssh_cidrs[count.index]
  description       = "SSH access from ${var.allowed_ssh_cidrs[count.index]}"
}

resource "alicloud_security_group_rule" "http" {
  type              = "ingress"
  ip_protocol       = "tcp"
  port_range        = "80/80"
  security_group_id = alicloud_security_group.main.id
  cidr_ip           = "0.0.0.0/0"
  description       = "HTTP access"
}

resource "alicloud_security_group_rule" "https" {
  type              = "ingress"
  ip_protocol       = "tcp"
  port_range        = "443/443"
  security_group_id = alicloud_security_group.main.id
  cidr_ip           = "0.0.0.0/0"
  description       = "HTTPS access"
}

resource "alicloud_security_group_rule" "internal" {
  type                     = "ingress"
  ip_protocol              = "all"
  port_range               = "-1/-1"
  security_group_id        = alicloud_security_group.main.id
  source_security_group_id = alicloud_security_group.main.id
  description              = "Internal communication"
}

resource "alicloud_security_group_rule" "outbound" {
  type              = "egress"
  ip_protocol       = "all"
  port_range        = "-1/-1"
  security_group_id = alicloud_security_group.main.id
  cidr_ip           = "0.0.0.0/0"
  description       = "All outbound traffic"
}

# Key Pair
resource "alicloud_ecs_key_pair" "main" {
  key_pair_name = "${local.name_prefix}-keypair-${random_id.suffix.hex}"
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-keypair"
    Type = "security"
  })
}

# ECS Instances
resource "alicloud_instance" "main" {
  count = var.instance_count
  
  instance_name   = "${local.name_prefix}-instance-${count.index + 1}"
  image_id        = data.alicloud_images.ubuntu.images.0.id
  instance_type   = var.instance_type
  vswitch_id      = alicloud_vswitch.main[count.index % length(alicloud_vswitch.main)].id
  security_groups = [alicloud_security_group.main.id]
  key_name        = alicloud_ecs_key_pair.main.key_pair_name
  
  # Internet access
  internet_max_bandwidth_out = var.internet_max_bandwidth_out
  internet_charge_type       = "PayByTraffic"
  
  # Storage
  system_disk_category = "cloud_ssd"
  system_disk_size     = var.system_disk_size
  
  # Basic configuration
  description = "Instance ${count.index + 1} for ${var.project_name} ${var.environment}"
  
  # User data for initial setup
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    hostname = "${local.name_prefix}-instance-${count.index + 1}"
  }))
  
  tags = merge(local.common_tags, {
    Name     = "${local.name_prefix}-instance-${count.index + 1}"
    Type     = "compute"
    Instance = "primary"
  })
  
  # Lifecycle management
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      image_id,  # Prevent recreation on image updates
      user_data, # Prevent recreation on user_data changes
    ]
  }
}

# Elastic IP addresses for instances
resource "alicloud_eip_address" "main" {
  count = var.instance_count
  
  address_name         = "${local.name_prefix}-eip-${count.index + 1}"
  bandwidth            = var.internet_max_bandwidth_out
  internet_charge_type = "PayByTraffic"
  description          = "EIP for ${local.name_prefix}-instance-${count.index + 1}"
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eip-${count.index + 1}"
    Type = "network"
  })
}

# Associate EIP with instances
resource "alicloud_eip_association" "main" {
  count = var.instance_count
  
  allocation_id = alicloud_eip_address.main[count.index].id
  instance_id   = alicloud_instance.main[count.index].id
}

# Application Load Balancer (if multiple instances)
resource "alicloud_slb_load_balancer" "main" {
  count = var.instance_count > 1 ? 1 : 0
  
  load_balancer_name = "${local.name_prefix}-alb"
  load_balancer_spec = "slb.s2.small"
  vswitch_id         = alicloud_vswitch.main[0].id
  address_type       = "intranet"
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
    Type = "load-balancer"
  })
}

# Load Balancer Listener
resource "alicloud_slb_listener" "http" {
  count = var.instance_count > 1 ? 1 : 0
  
  load_balancer_id          = alicloud_slb_load_balancer.main[0].id
  backend_port              = 80
  frontend_port             = 80
  protocol                  = "http"
  bandwidth                 = var.internet_max_bandwidth_out
  health_check              = "on"
  health_check_type         = "http"
  health_check_domain       = "$_ip"
  health_check_uri          = "/health"
  health_check_connect_port = 80
  healthy_threshold         = 2
  unhealthy_threshold       = 2
  health_check_timeout      = 5
  health_check_interval     = 2
  
  depends_on = [alicloud_slb_load_balancer.main]
}

# Load Balancer Backend Server Group
resource "alicloud_slb_backend_server" "main" {
  count = var.instance_count > 1 ? var.instance_count : 0
  
  load_balancer_id = alicloud_slb_load_balancer.main[0].id
  backend_servers {
    server_id = alicloud_instance.main[count.index].id
    weight    = 100
  }
  
  depends_on = [
    alicloud_slb_load_balancer.main,
    alicloud_instance.main
  ]
}

# CloudMonitor Dashboard (if monitoring enabled)
resource "alicloud_cms_group_metric_rule" "cpu_alert" {
  count = var.enable_monitoring ? var.instance_count : 0
  
  group_id         = alicloud_cms_monitor_group.main[0].id
  rule_name        = "${local.name_prefix}-cpu-alert-${count.index + 1}"
  metric_name      = "CPUUtilization"
  namespace        = "acs_ecs_dashboard"
  period           = "300"
  statistics       = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold        = "80"
  evaluation_count = 3
  
  dimensions = {
    instanceId = alicloud_instance.main[count.index].id
  }
  
  contact_groups = [alicloud_cms_contact_group.main[0].contact_group_name]
  effective_interval = "00:00-23:59"
  
  depends_on = [
    alicloud_cms_monitor_group.main,
    alicloud_cms_contact_group.main
  ]
}

# CloudMonitor Group
resource "alicloud_cms_monitor_group" "main" {
  count = var.enable_monitoring ? 1 : 0
  
  monitor_group_name = "${local.name_prefix}-monitor-group"
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-monitor-group"
    Type = "monitoring"
  })
}

# CloudMonitor Contact Group
resource "alicloud_cms_contact_group" "main" {
  count = var.enable_monitoring ? 1 : 0
  
  contact_group_name = "${local.name_prefix}-contact-group"
  describe          = "Contact group for ${var.project_name} ${var.environment} alerts"
}

# Auto Snapshot Policy
resource "alicloud_ecs_auto_snapshot_policy" "main" {
  auto_snapshot_policy_name = "${local.name_prefix}-snapshot-policy"
  repeat_weekdays          = ["1", "2", "3", "4", "5", "6", "7"]
  time_points              = ["2"]  # 2 AM
  retention_days           = var.backup_retention_days
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-snapshot-policy"
    Type = "backup"
  })
}

# Apply snapshot policy to system disks
resource "alicloud_ecs_auto_snapshot_policy_attachment" "main" {
  count = var.instance_count
  
  auto_snapshot_policy_id = alicloud_ecs_auto_snapshot_policy.main.id
  disk_id                = alicloud_instance.main[count.index].system_disk_id
}

# RAM Role for ECS instances (for accessing other Alibaba Cloud services)
resource "alicloud_ram_role" "ecs_role" {
  name        = "${local.name_prefix}-ecs-role-${random_id.suffix.hex}"
  description = "RAM role for ECS instances in ${var.project_name} ${var.environment}"
  
  assume_role_policy = jsonencode({
    Version = "1"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs.aliyuncs.com"
        }
      }
    ]
  })
  
  force = true
}

# RAM Policy for basic ECS operations
resource "alicloud_ram_policy" "ecs_policy" {
  policy_name = "${local.name_prefix}-ecs-policy-${random_id.suffix.hex}"
  description = "Policy for ECS instances basic operations"
  
  policy_document = jsonencode({
    Version = "1"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeInstances",
          "ecs:DescribeDisks",
          "ecs:CreateSnapshot",
          "ecs:DescribeSnapshots",
          "cms:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
  
  force = true
}

# Attach policy to role
resource "alicloud_ram_role_policy_attachment" "ecs_attachment" {
  role_name   = alicloud_ram_role.ecs_role.name
  policy_name = alicloud_ram_policy.ecs_policy.policy_name
  policy_type = "Custom"
}

# RAM Instance Profile
resource "alicloud_ecs_instance_attachment" "ram_attachment" {
  count = var.instance_count
  
  instance_id = alicloud_instance.main[count.index].id
  ram_role    = alicloud_ram_role.ecs_role.name
}

# Network ACL for additional security
resource "alicloud_network_acl" "main" {
  network_acl_name = "${local.name_prefix}-nacl"
  vpc_id          = alicloud_vpc.main.id
  description     = "Network ACL for ${var.project_name} ${var.environment}"
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nacl"
    Type = "security"
  })
}

# Network ACL Rules
resource "alicloud_network_acl_entries" "main" {
  network_acl_id = alicloud_network_acl.main.id
  
  # Ingress rules
  ingress {
    rule_action   = "accept"
    protocol      = "tcp"
    port          = "80/80"
    cidr_ip       = "0.0.0.0/0"
    description   = "Allow HTTP"
  }
  
  ingress {
    rule_action   = "accept"
    protocol      = "tcp"
    port          = "443/443"
    cidr_ip       = "0.0.0.0/0"
    description   = "Allow HTTPS"
  }
  
  ingress {
    rule_action   = "accept"
    protocol      = "tcp"
    port          = "22/22"
    cidr_ip       = var.vpc_cidr
    description   = "Allow SSH from VPC"
  }
  
  # Egress rules
  egress {
    rule_action   = "accept"
    protocol      = "all"
    port          = "-1/-1"
    cidr_ip       = "0.0.0.0/0"
    description   = "Allow all outbound"
  }
}

# Associate Network ACL with VSwitches
resource "alicloud_network_acl_attachment" "main" {
  count = length(alicloud_vswitch.main)
  
  network_acl_id = alicloud_network_acl.main.id
  vswitch_id     = alicloud_vswitch.main[count.index].id
}

# Output values
output "vpc_id" {
  description = "ID of the VPC"
  value       = alicloud_vpc.main.id
}

output "vswitch_ids" {
  description = "IDs of the VSwitches"
  value       = alicloud_vswitch.main[*].id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = alicloud_security_group.main.id
}

output "instance_ids" {
  description = "IDs of the ECS instances"
  value       = alicloud_instance.main[*].id
}

output "instance_public_ips" {
  description = "Public IP addresses of the instances"
  value       = alicloud_eip_address.main[*].ip_address
  sensitive   = false
}

output "instance_private_ips" {
  description = "Private IP addresses of the instances"
  value       = alicloud_instance.main[*].private_ip
}

output "load_balancer_address" {
  description = "Load balancer address (if created)"
  value       = var.instance_count > 1 ? alicloud_slb_load_balancer.main[0].address : null
}

output "key_pair_name" {
  description = "Name of the SSH key pair"
  value       = alicloud_ecs_key_pair.main.key_pair_name
}

output "ssh_connection_commands" {
  description = "SSH connection commands for instances"
  value = [
    for i, ip in alicloud_eip_address.main[*].ip_address :
    "ssh -i ~/.ssh/${alicloud_ecs_key_pair.main.key_pair_name}.pem ubuntu@${ip}"
  ]
}

output "resource_summary" {
  description = "Summary of created resources"
  value = {
    vpc_id              = alicloud_vpc.main.id
    vswitch_count       = length(alicloud_vswitch.main)
    instance_count      = length(alicloud_instance.main)
    load_balancer_created = var.instance_count > 1
    monitoring_enabled  = var.enable_monitoring
    backup_enabled     = true
    environment        = var.environment
    project_name       = var.project_name
  }
}