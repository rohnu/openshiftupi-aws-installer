output "api_public_fqdn" {
  value = module.load_balancer.api_public_fqdn
}

output "private_zone_id" {
  value = module.load_balancer.private_zone_id
}

output "master_private_ips" {
  value = module.control_plane.private_ips
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
