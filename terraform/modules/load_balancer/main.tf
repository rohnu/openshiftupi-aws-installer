variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "infrastructure_name" { type = string }
variable "cluster_name" { type = string }
variable "hosted_zone_id" { type = string }
variable "hosted_zone_name" { type = string }
variable "api_ip_targets" { type = list(string) }
variable "service_ip_targets" { type = list(string) }
variable "tags" { type = map(string) }

locals {
  name_ext = "${var.infrastructure_name}-ext"
  name_int = "${var.infrastructure_name}-int"
}

resource "aws_lb" "ext_api" {
  name               = local.name_ext
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids
  tags               = merge(var.tags, { Name = local.name_ext })
}

resource "aws_lb" "int_api" {
  name               = local.name_int
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids
  tags               = merge(var.tags, { Name = local.name_int })
}

resource "aws_lb_target_group" "ext_api" {
  name        = substr("${var.infrastructure_name}-api-ext", 0, 32)
  port        = 6443
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    port                = "6443"
    protocol            = "HTTPS"
    path                = "/readyz"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }
  tags = var.tags
}

resource "aws_lb_target_group" "int_api" {
  name        = substr("${var.infrastructure_name}-api-int", 0, 32)
  port        = 6443
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check { port = "6443" protocol = "HTTPS" path = "/readyz" healthy_threshold = 2 unhealthy_threshold = 2 interval = 10 }
  tags = var.tags
}

resource "aws_lb_target_group" "int_mcs" {
  name        = substr("${var.infrastructure_name}-mcs-int", 0, 32)
  port        = 22623
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check { port = "22623" protocol = "HTTPS" path = "/healthz" healthy_threshold = 2 unhealthy_threshold = 2 interval = 10 }
  tags = var.tags
}

resource "aws_lb_listener" "ext_api" {
  load_balancer_arn = aws_lb.ext_api.arn
  port              = 6443
  protocol          = "TCP"
  default_action { type = "forward" target_group_arn = aws_lb_target_group.ext_api.arn }
}

resource "aws_lb_listener" "int_api" {
  load_balancer_arn = aws_lb.int_api.arn
  port              = 6443
  protocol          = "TCP"
  default_action { type = "forward" target_group_arn = aws_lb_target_group.int_api.arn }
}

resource "aws_lb_listener" "int_mcs" {
  load_balancer_arn = aws_lb.int_api.arn
  port              = 22623
  protocol          = "TCP"
  default_action { type = "forward" target_group_arn = aws_lb_target_group.int_mcs.arn }
}

resource "aws_lb_target_group_attachment" "ext_api" {
  for_each         = toset(var.api_ip_targets)
  target_group_arn = aws_lb_target_group.ext_api.arn
  target_id        = each.value
}

resource "aws_lb_target_group_attachment" "int_api" {
  for_each         = toset(var.api_ip_targets)
  target_group_arn = aws_lb_target_group.int_api.arn
  target_id        = each.value
}

resource "aws_lb_target_group_attachment" "int_mcs" {
  for_each         = toset(var.service_ip_targets)
  target_group_arn = aws_lb_target_group.int_mcs.arn
  target_id        = each.value
}

# Public alias
resource "aws_route53_record" "api_public" {
  zone_id = var.hosted_zone_id
  name    = "api.${var.cluster_name}.${var.hosted_zone_name}"
  type    = "A"
  alias {
    name                   = aws_lb.ext_api.dns_name
    zone_id                = aws_lb.ext_api.zone_id
    evaluate_target_health = false
  }
}

# Private zone for <cluster>.<base>
resource "aws_route53_zone" "private_int" {
  name = "${var.cluster_name}.${var.hosted_zone_name}"
  vpc  { vpc_id = var.vpc_id }
  tags = var.tags
}

# Private api + api-int aliases -> internal NLB
resource "aws_route53_record" "api_private" {
  zone_id = aws_route53_zone.private_int.zone_id
  name    = "api.${var.cluster_name}.${var.hosted_zone_name}"
  type    = "A"
  alias { name = aws_lb.int_api.dns_name zone_id = aws_lb.int_api.zone_id evaluate_target_health = false }
}

resource "aws_route53_record" "api_int_private" {
  zone_id = aws_route53_zone.private_int.zone_id
  name    = "api-int.${var.cluster_name}.${var.hosted_zone_name}"
  type    = "A"
  alias { name = aws_lb.int_api.dns_name zone_id = aws_lb.int_api.zone_id evaluate_target_health = false }
}

output "api_public_fqdn" { value = "api.${var.cluster_name}.${var.hosted_zone_name}" }
output "private_zone_id"  { value = aws_route53_zone.private_int.zone_id }
output "internal_lb_dns"  { value = aws_lb.int_api.dns_name }
output "internal_lb_zone_id" { value = aws_lb.int_api.zone_id }
