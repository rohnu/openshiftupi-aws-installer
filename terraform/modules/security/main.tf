variable "vpc_id" { type = string }
variable "cluster_name" { type = string }
variable "api_cidr_allow" { type = list(string) }
variable "ssh_cidr_allow" { type = list(string) }
variable "nodeport_cidr"  { type = list(string) }
variable "tags" { type = map(string) }

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-sg"
  description = "OpenShift cluster SG"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.cluster_name}-sg" })

  # Intra-cluster allow all
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # API server (6443) from allowed CIDRs
  dynamic "ingress" {
    for_each = var.api_cidr_allow
    content {
      from_port   = 6443
      to_port     = 6443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "kube-apiserver"
    }
  }

  # SSH (22) optional
  dynamic "ingress" {
    for_each = var.ssh_cidr_allow
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "ssh"
    }
  }

  # NodePort range (optional)
  dynamic "ingress" {
    for_each = var.nodeport_cidr
    content {
      from_port   = 30000
      to_port     = 32767
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "NodePort"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "sg_cluster_id" { value = aws_security_group.cluster.id }
