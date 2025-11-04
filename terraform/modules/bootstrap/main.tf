variable "subnet_id" { type = string }
variable "sg_ids" { type = list(string) }
variable "iam_instance_profile" { type = string }
variable "key_name" { type = string }
variable "ami_id" { type = string }
variable "instance_type" { type = string }
variable "ignition_b64" { type = string }
variable "name_prefix" { type = string }
variable "tags" { type = map(string) }

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.sg_ids
  iam_instance_profile        = var.iam_instance_profile
  key_name                    = var.key_name
  user_data_base64            = var.ignition_b64
  monitoring                  = true
  disable_api_termination     = false

  tags = merge(var.tags, { Name = var.name_prefix })
}

output "instance_id" { value = aws_instance.this.id }
output "private_ip"  { value = aws_instance.this.private_ip }
