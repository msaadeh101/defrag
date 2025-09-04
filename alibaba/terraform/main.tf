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
  name_regex  = "^ubuntu_20_04_x64.*"
  owners      = "system"
  most_recent = true
}

# VPC
resource "alicloud_vpc" "main" {
  vpc_name    = "${local.name_prefix}-vpc"
  cidr_block  = var.vpc_cidr
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
  name        = "${local.name_prefix}-sg"
  vpc_id      = alicloud_vpc.main.id
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

  group_id               = alicloud_cms_monitor_group.main[0].id
  rule_id                = "${local.name_prefix}-disk-alert-rule-${count.index + 1}"
  group_metric_rule_name = "${local.name_prefix}-cpu-alert-${count.index + 1}"
  metric_name            = "CPUUtilization"
  namespace              = "acs_ecs_dashboard"
  period                 = "300"
  escalations {
    critical {
      statistics          = "Average"
      comparison_operator = "GreaterThanThreshold"
      threshold           = "95"
      times               = 1
    }

    warn {
      statistics          = "Average"
      comparison_operator = "GreaterThanThreshold"
      threshold           = "90"
      times               = 2
    }

    info {
      statistics          = "Average"
      comparison_operator = "GreaterThanThreshold"
      threshold           = "80"
      times               = 3
    }
  }

  dimensions = {
    instanceId = alicloud_instance.main[count.index].id
  }

  contact_groups     = [alicloud_cms_contact_group.main[0].contact_group_name]
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
  describe           = "Contact group for ${var.project_name} ${var.environment} alerts"
}

# Auto Snapshot Policy
resource "alicloud_ecs_auto_snapshot_policy" "main" {
  auto_snapshot_policy_name = "${local.name_prefix}-snapshot-policy"
  repeat_weekdays           = ["1", "2", "3", "4", "5", "6", "7"]
  time_points               = ["2"] # 2 AM
  retention_days            = var.backup_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-snapshot-policy"
    Type = "backup"
  })
}

# Apply snapshot policy to system disks
resource "alicloud_ecs_auto_snapshot_policy_attachment" "main" {
  count = var.instance_count

  auto_snapshot_policy_id = alicloud_ecs_auto_snapshot_policy.main.id
  disk_id                 = alicloud_instance.main[count.index].system_disk_id
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
  vpc_id           = alicloud_vpc.main.id
  description      = "Network ACL for ${var.project_name} ${var.environment}"

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
    protocol       = "tcp"
    port           = "80/80"
    source_cidr_ip = ""
    name           = ""
    description    = "Allow HTTP"
  }

  ingress {
    protocol       = "tcp"
    port           = "443/443"
    source_cidr_ip = ""
    name           = ""
    description    = "Allow HTTPS"
  }

  ingress {
    protocol       = "tcp"
    port           = "22/22"
    source_cidr_ip = ""
    name           = ""
    description    = "Allow SSH from VPC"
  }


  # Egress rules
  egress {
    policy      = "accept"
    protocol    = "all"
    port        = "-1/-1"
    description = "Allow all outbound"
  }
}

# Associate Network ACL with VSwitches
resource "alicloud_network_acl_attachment" "attachment" {
  count = length(alicloud_vswitch.main)

  network_acl_id = alicloud_network_acl.main.id

  resources {
    resource_id   = each.value
    resource_type = "VSwitch"
  }
}
