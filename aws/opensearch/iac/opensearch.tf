terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  name = "opensearch-vpc"
  cidr = "10.0.0.0/16"
  
  azs              = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = false
  
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "opensearch" = "private"
  }
}

resource "aws_security_group" "opensearch_sg" {
  name        = "opensearch-sg"
  description = "Security group for OpenSearch cluster"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
    description = "HTTPS from VPC"
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] # Corporate network
    description = "HTTPS from corporate network"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Environment = "production"
  }
}

resource "aws_opensearch_domain" "production" {
  domain_name    = "production-logs"
  engine_version = "OpenSearch_2.11"
  
  cluster_config {
    instance_type            = "r6g.2xlarge.search"
    instance_count           = 3
    dedicated_master_enabled = true
    dedicated_master_type    = "r6g.large.search"
    dedicated_master_count   = 3
    zone_awareness_enabled   = true

    cold_storage_options {
      enabled = true
    }
    zone_awareness_config {
      availability_zone_count = 3
    }
    warm_enabled            = true
    warm_type               = "ultrawarm1.medium.search"
    warm_count              = 2
  }
  
  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = 500
    iops        = 3000
    throughput  = 125
  }
  
  vpc_options {
    subnet_ids = [
      module.vpc.private_subnets[0],
      module.vpc.private_subnets[1]
    ]
    security_group_ids = [aws_security_group.opensearch_sg.id]
  }

  advanced_security_options {
    enabled                        = true
    anonymous_auth_enabled         = false
    internal_user_database_enabled = false
    master_user_options {
      master_user_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Admin"
    }
  }
  
  node_to_node_encryption {
    enabled = true
  }
  
  encrypt_at_rest {
    enabled = true
  }
  
  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
    custom_endpoint_enabled = true
    custom_endpoint         = "logs.company.com"
    custom_endpoint_certificate_arn = aws_acm_certificate.opensearch.arn
  }
  
  # Logging
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_audit.arn
    log_type                 = "AUDIT_LOGS"
    enabled                  = true
  }
  
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_slow.arn
    log_type                 = "SLOW_LOGS"
    enabled                  = true
  }
  
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_error.arn
    log_type                 = "ES_APPLICATION_LOGS"
    enabled                  = true
  }
  
  # Auto-Tune
  auto_tune_options {
    desired_state = "ENABLED"
    maintenance_schedule {
      start_at = "2024-01-01T22:00:00Z"
      duration {
        value = 2
        unit  = "HOURS"
      }
      cron_expression_for_recurrence = "cron(0 22 ? * 6 *)" # Saturdays 10 PM
    }
    rollback_on_disable = "NO_ROLLBACK"
  }
  
  tags = {
    Environment = "production"
    Owner       = "DevOps"
    CostCenter  = "12345"
  }
}

# CloudWatch Alarms for Monitoring
resource "aws_cloudwatch_metric_alarm" "cluster_status_red" {
  alarm_name          = "opensearch-cluster-status-red"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ClusterStatus.red"
  namespace           = "AWS/ES"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "OpenSearch cluster status is RED"
  alarm_actions       = [aws_sns_topic.opensearch_alerts.arn]
  
  dimensions = {
    DomainName = aws_opensearch_domain.production.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }
}

resource "aws_cloudwatch_metric_alarm" "free_storage_space" {
  alarm_name          = "opensearch-free-storage-space-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/ES"
  period              = "300"
  statistic           = "Minimum"
  threshold           = "20480" # 20GB
  alarm_description   = "OpenSearch free storage space is below 20GB"
  alarm_actions       = [aws_sns_topic.opensearch_alerts.arn]
  
  dimensions = {
    DomainName = aws_opensearch_domain.production.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }
}