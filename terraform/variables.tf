# Cluster identification
variable "cluster_name" {
  type        = string
  description = "OpenShift cluster name"
}

variable "infrastructure_name" {
  type        = string
  description = "OpenShift infrastructure ID (from metadata.json)"
}

variable "aws_region" {
  type        = string
  description = "AWS region for deployment"
}

# Network configuration
variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
}

variable "azs" {
  type        = list(string)
  description = "List of availability zones"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets"
}

# DNS configuration
variable "hosted_zone_id" {
  type        = string
  description = "Route53 hosted zone ID for base domain"
}

variable "hosted_zone_name" {
  type        = string
  description = "Base domain name (e.g., example.com)"
}

# Security configuration
variable "api_cidr_allow" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDR blocks allowed to access API"
}

variable "ssh_cidr_allow" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDR blocks allowed SSH access"
}

variable "nodeport_cidr" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDR blocks allowed to access NodePort services"
}

# SSH configuration
variable "ssh_key_name" {
  type        = string
  description = "AWS EC2 key pair name"
}

# AMI configuration
variable "rhcos_ami_id" {
  type        = string
  description = "RHCOS AMI ID for the region"
}

# Instance configuration
variable "bootstrap_instance_type" {
  type        = string
  default     = "m4.xlarge"
  description = "EC2 instance type for bootstrap node"
}

variable "master_instance_type" {
  type        = string
  default     = "m4.xlarge"
  description = "EC2 instance type for master nodes"
}

variable "worker_instance_type" {
  type        = string
  default     = "r5a.4xlarge"
  description = "EC2 instance type for worker nodes"
}

variable "master_count" {
  type        = number
  default     = 3
  description = "Number of master nodes"
}

variable "worker_count" {
  type        = number
  default     = 4
  description = "Number of worker nodes"
}

# Ignition configuration (base64 encoded)
variable "bootstrap_ignition_b64" {
  type        = string
  description = "Base64 encoded bootstrap ignition config"
}

variable "master_ignition_b64" {
  type        = string
  description = "Base64 encoded master ignition config"
}

variable "worker_ignition_b64" {
  type        = string
  description = "Base64 encoded worker ignition config"
}

# Tags
variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
