output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "api_public_fqdn" {
  description = "Public API endpoint FQDN"
  value       = module.load_balancer.api_public_fqdn
}

output "private_zone_id" {
  description = "Private Route53 zone ID"
  value       = module.route53.private_zone_id
}

output "master_private_ips" {
  description = "Master node private IP addresses"
  value       = module.control_plane.private_ips
}

output "worker_private_ips" {
  description = "Worker node private IP addresses"
  value       = module.workers.private_ips
}

output "bootstrap_private_ip" {
  description = "Bootstrap node private IP"
  value       = module.bootstrap.private_ip
}

output "infrastructure_name" {
  description = "OpenShift infrastructure name"
  value       = var.infrastructure_name
}

output "cluster_name" {
  description = "OpenShift cluster name"
  value       = var.cluster_name
}

output "api_endpoint" {
  description = "API endpoint URL"
  value       = "https://api.${var.cluster_name}.${var.hosted_zone_name}:6443"
}

output "console_url" {
  description = "Web console URL"
  value       = "https://console-openshift-console.apps.${var.cluster_name}.${var.hosted_zone_name}"
}
