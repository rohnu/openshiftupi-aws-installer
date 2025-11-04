aws_region          = "us-east-1"
cluster_name        = "myocp"
infrastructure_name = "myocp-xyz12"

vpc_cidr            = "10.0.0.0/16"
azs                 = ["us-east-1a","us-east-1b","us-east-1c"]
public_subnet_cidrs = ["10.0.0.0/20","10.0.16.0/20","10.0.32.0/20"]
private_subnet_cidrs= ["10.0.128.0/20","10.0.144.0/20","10.0.160.0/20"]

hosted_zone_id      = "Zxxxxxxxxxxxxx"     # public base-zone ID
hosted_zone_name    = "example.com"        # base domain (no trailing dot)

api_cidr_allow      = ["0.0.0.0/0"]        # tighten as needed
ssh_cidr_allow      = ["x.x.x.x/32"]       # your jump host
nodeport_cidr       = []                   # optional

ssh_key_name        = "my-keypair"
rhcos_ami_id        = "ami-xxxxxxxx"       # RHCOS AMI for your region

bootstrap_instance_type = "m6i.large"
master_instance_type    = "m6i.xlarge"
worker_instance_type    = "m6i.xlarge"

master_count = 3
worker_count = 3

# paste base64-encoded Ignition payloads
bootstrap_ignition_b64 = "eyJpZ25pdGlvbiI6IC4uLn0=" 
master_ignition_b64    = "eyJpZ25pdGlvbiI6IC4uLn0=" 
worker_ignition_b64    = "eyJpZ25pdGlvbiI6IC4uLn0=" 

tags = { Environment = "dev", Owner = "platform" }
