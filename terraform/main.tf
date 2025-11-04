terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- VPC & subnets ---
module "vpc" {
  source              = "./modules/vpc"
  name                = var.cluster_name
  cidr_block          = var.vpc_cidr
  azs                 = var.azs
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs= var.private_subnet_cidrs
  tags                = var.tags
}

# --- IAM (instance roles/profiles) ---
module "iam" {
  source         = "./modules/iam"
  cluster_name   = var.cluster_name
  tags           = var.tags
}

# --- Security groups ---
module "security" {
  source            = "./modules/security"
  vpc_id            = module.vpc.vpc_id
  cluster_name      = var.cluster_name
  api_cidr_allow    = var.api_cidr_allow
  ssh_cidr_allow    = var.ssh_cidr_allow
  nodeport_cidr     = var.nodeport_cidr
  tags              = var.tags
}

# --- Load balancers ---
module "load_balancer" {
  source              = "./modules/load_balancer"
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  infrastructure_name = var.infrastructure_name
  cluster_name        = var.cluster_name
  hosted_zone_id      = var.hosted_zone_id
  hosted_zone_name    = var.hosted_zone_name
  api_ip_targets      = concat([module.bootstrap.private_ip], module.control_plane.private_ips)
  service_ip_targets  = concat([module.bootstrap.private_ip], module.control_plane.private_ips)
  tags                = var.tags
}

# --- Route53 (private zone records like api-int, etc.) ---
module "route53" {
  source              = "./modules/route53"
  vpc_id              = module.vpc.vpc_id
  cluster_name        = var.cluster_name
  base_domain         = var.hosted_zone_name
  internal_lb_dns     = module.load_balancer.internal_lb_dns
  internal_lb_zone_id = module.load_balancer.internal_lb_zone_id
  tags                = var.tags
}

# --- Bootstrap node ---
module "bootstrap" {
  source               = "./modules/bootstrap"
  subnet_id            = module.vpc.private_subnet_ids[0]
  sg_ids               = [module.security.sg_cluster_id]
  iam_instance_profile = module.iam.instance_profile_master
  key_name             = var.ssh_key_name
  ami_id               = var.rhcos_ami_id
  instance_type        = var.bootstrap_instance_type
  ignition_b64         = var.bootstrap_ignition_b64
  name_prefix          = "${var.infrastructure_name}-bootstrap"
  tags                 = var.tags
}

# --- Control plane (masters) ---
module "control_plane" {
  source               = "./modules/control_plane"
  count_masters        = var.master_count
  subnet_ids           = module.vpc.private_subnet_ids
  sg_ids               = [module.security.sg_cluster_id]
  iam_instance_profile = module.iam.instance_profile_master
  key_name             = var.ssh_key_name
  ami_id               = var.rhcos_ami_id
  instance_type        = var.master_instance_type
  ignition_b64         = var.master_ignition_b64
  name_prefix          = "${var.infrastructure_name}-master"
  tags                 = var.tags
}

# --- Workers ---
module "workers" {
  source               = "./modules/workers"
  count_workers        = var.worker_count
  subnet_ids           = module.vpc.private_subnet_ids
  sg_ids               = [module.security.sg_cluster_id]
  iam_instance_profile = module.iam.instance_profile_worker
  key_name             = var.ssh_key_name
  ami_id               = var.rhcos_ami_id
  instance_type        = var.worker_instance_type
  ignition_b64         = var.worker_ignition_b64
  name_prefix          = "${var.infrastructure_name}-worker"
  tags                 = var.tags
}

output "api_public_fqdn" {
  value = module.load_balancer.api_public_fqdn
}

output "private_zone_id" {
  value = module.load_balancer.private_zone_id
}

output "master_private_ips" {
  value = module.control_plane.private_ips
}
