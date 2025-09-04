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
    vpc_id                = alicloud_vpc.main.id
    vswitch_count         = length(alicloud_vswitch.main)
    instance_count        = length(alicloud_instance.main)
    load_balancer_created = var.instance_count > 1
    monitoring_enabled    = var.enable_monitoring
    backup_enabled        = true
    environment           = var.environment
    project_name          = var.project_name
  }
}