variable "cluster_name" { type = string }
variable "tags" { type = map(string) }

# Minimal roles for EC2 instances (pull from S3/ECR, logs). Adjust per org policy.
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "master" {
  name               = "${var.cluster_name}-master-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

resource "aws_iam_role" "worker" {
  name               = "${var.cluster_name}-worker-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

# Attach a couple of standard AWS managed policies (tighten in production)
resource "aws_iam_role_policy_attachment" "master_ssm" {
  role       = aws_iam_role.master.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "master_ecr" {
  role       = aws_iam_role.master.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "worker_ssm" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "master" {
  name = "${var.cluster_name}-master-profile"
  role = aws_iam_role.master.name
}

resource "aws_iam_instance_profile" "worker" {
  name = "${var.cluster_name}-worker-profile"
  role = aws_iam_role.worker.name
}

output "instance_profile_master" { value = aws_iam_instance_profile.master.name }
output "instance_profile_worker" { value = aws_iam_instance_profile.worker.name }
