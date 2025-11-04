variable "count_workers" { type = number }
variable "subnet_ids" { type = list(string) }
variable "sg_ids" { type = list(string) }
variable "iam_instance_profile" { type = string }
variable "key_name" { type = string }
variable "ami_id" { type = string }
variable "instance_type" { type = string }
variable "ignition_b64" { type = string }
variable "name_prefix" { type = string }
variable "tags" { type = map(string) }

resource "aws_instance" "worker" {
  count                      = var.count_workers
  ami                        = var.ami_id
  instance_type              = var.instance_type
  subnet_id                  = element(var.subnet_ids, count.index % length(var.subnet_ids))
  vpc_security_group_ids     = var.sg_ids
  iam_instance_profile       = var.iam_instance_profile
  key_name                   = var.key_name
  user_data_base64           = var.ignition_b64
  monitoring                 = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-${count.index}" })
}

output "instance_ids" { value = aws_instance.worker[*].id }
output "private_ips"  { value = aws_instance.worker[*].private_ip }
