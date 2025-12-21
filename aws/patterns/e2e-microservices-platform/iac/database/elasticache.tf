resource "aws_elasticache_subnet_group" "main" {
  name       = "redis-subnet-group"
  subnet_ids = module.vpc.subnet_ids
}

resource "aws_elasticache_replication_group" "redis" {
  description = "Redis cluster for caching"
  replication_group_id       = "mycomp-redis"
  
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = "cache.r6g.large"
  num_cache_clusters   = 3
  parameter_group_name = "default.redis7.cluster.on"
  port                 = 6379
  
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]
  
  automatic_failover_enabled = true
  multi_az_enabled          = true
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                = random_password.redis_auth.result
  
  snapshot_retention_limit = 5
  snapshot_window         = "03:00-05:00"
  
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }
}