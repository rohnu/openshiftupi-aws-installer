variable "aws_region" { type = string }
variable "cluster_name" { type = string }
variable "infrastructure_name" { type = string }

variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }

variable "hosted_zone_id" { type = string, description = "Public Route53 hosted zone ID for the base domain" }
variable "hosted_zone_name" { type = string, description = "Base domain, e.g., example.com" }

variable "api_cidr_allow" { type = list(string), default = [] }
variable "ssh_cidr_allow" { type = list(string), default = [] }
variable "nodeport_cidr"  { type = list(string), default = [] }

variable "ssh_key_name" { type = string }
variable "rhcos_ami_id" { type = string }

variable "bootstrap_instance_type" { type = string, default = "m6i.large" }
variable "master_instance_type"    { type = string, default = "m6i.xlarge" }
variable "worker_instance_type"    { type = string, default = "m6i.xlarge" }

variable "master_count"  { type = number, default = 3 }
variable "worker_count"  { type = number, default = 3 }

# Ignition (base64) for each role
variable "bootstrap_ignition_b64" { type = string }
variable "master_ignition_b64"    { type = string }
variable "worker_ignition_b64"    { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}
