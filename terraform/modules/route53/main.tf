variable "vpc_id" { type = string }
variable "cluster_name" { type = string }
variable "base_domain" { type = string }
variable "internal_lb_dns" { type = string }
variable "internal_lb_zone_id" { type = string }
variable "tags" { type = map(string) }

# Reuse existing private zone if it exists would require data sources; for simplicity assume created by LB module.
# This module is a placeholder for adding more records later (e.g., *.apps).
