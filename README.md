# OpenShift 4.17 UPI Installation Automation for AWS

This repository contains automation scripts and Terraform modules to deploy OpenShift Container Platform 4.17 on AWS using the User-Provisioned Infrastructure (UPI) method, optimized for Cloudera Data Services.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Detailed Installation](#detailed-installation)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)
- [Additional Resources](#additional-resources)

## Overview

This automation framework simplifies the OpenShift UPI installation process by:

- Automating infrastructure provisioning with Terraform
- Managing ignition file generation and distribution
- Configuring AWS resources (VPC, load balancers, EC2 instances)
- Handling CSR approvals and cluster configuration
- Supporting both production and testing environments

### Why UPI?

User-Provisioned Infrastructure (UPI) provides:

- **Maximum Control**: Fine-tune infrastructure to meet Cloudera Data Services requirements
- **Security & Compliance**: Implement granular security controls at the infrastructure layer
- **Hybrid Cloud Support**: Consistent operational model across on-premises and cloud
- **Cost Optimization**: Precise resource allocation to match workload demands
- **Disconnected Environments**: Deploy in air-gapped or restricted networks

## Prerequisites

### Required Tools

- **RHEL 8.x or compatible Linux** (for CSAH node)
- **AWS Account** with appropriate permissions
- **Red Hat Account** with valid subscription
- **Domain** managed in Route53 or external DNS

### Required Downloads

1. **Pull Secret**: Download from https://cloud.redhat.com/openshift/install
2. **SSH Key Pair**: For cluster node access
3. **RHCOS AMI**: Get AMI ID for your region from https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/

### AWS Permissions

The AWS IAM user needs the following permissions:

- EC2 full access
- VPC full access
- ELB full access
- S3 full access
- Route53 full access
- IAM role creation

### Hardware Requirements

Based on the provided PDF for Cloudera Data Services:

| Component | Count | vCPU | RAM    | Storage | Instance Type |
| --------- | ----- | ---- | ------ | ------- | ------------- |
| Bootstrap | 1     | 4    | 16 GB  | 120 GB  | m4.xlarge     |
| Masters   | 3     | 4    | 16 GB  | 120 GB  | m4.xlarge     |
| Workers   | 4     | 16   | 128 GB | 1.2 TB  | r5a.4xlarge   |
| CSAH Node | 1     | 8    | 64 GB  | 700 GB  | r5a.2xlarge   |

**Total Monthly Cost Estimate**: ~$3,538 (730 hours)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Region                              │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                           VPC                               │ │
│  │                                                             │ │
│  │  ┌───────────────┐           ┌──────────────────────────┐ │ │
│  │  │ Public Subnet │           │   Private Subnet (AZ-1)   │ │ │
│  │  │               │           │                           │ │ │
│  │  │ - NAT GW      │           │ - Master Node 1           │ │ │
│  │  │ - Bootstrap   │  ◄────────┤ - Worker Node 1           │ │ │
│  │  │ - API LB      │           │                           │ │ │
│  │  │ - Apps LB     │           └──────────────────────────┘ │ │
│  │  └───────────────┘                                         │ │
│  │                                                             │ │
│  │  ┌──────────────────────────┐  ┌──────────────────────────┐ │ │
│  │  │   Private Subnet (AZ-2)   │  │  Private Subnet (AZ-3)   │ │ │
│  │  │                           │  │                           │ │ │
│  │  │ - Master Node 2           │  │ - Master Node 3           │ │ │
│  │  │ - Worker Node 2           │  │ - Worker Node 3           │ │ │
│  │  │                           │  │ - Worker Node 4           │ │ │
│  │  └──────────────────────────┘  └──────────────────────────┘ │ │
│  │                                                             │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

External:
- Route53 DNS (api.<cluster>.<domain>)
- Route53 DNS (*.apps.<cluster>.<domain>)
- S3 Bucket (ignition files)
```

## Quick Start

### 1. Clone and Configure

```bash
# Clone the repository
git clone <repository-url>
cd openshift-upi-automation

# Copy and edit configuration
cp config.env.example config.env
vi config.env
```

### 2. Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Verify access
aws sts get-caller-identity
```

### 3. Update Configuration

Edit `config.env` with your values:

```bash
CLUSTER_NAME="your-cluster"
BASE_DOMAIN="your-domain.com"
AWS_REGION="us-east-1"
RHCOS_AMI="ami-xxxxxxxxxxxxxxxxx"
PULL_SECRET_FILE="/path/to/pull-secret.json"
SSH_KEY_PATH="/path/to/ssh-key"
```

### 4. Run Installation

```bash
# Make script executable
chmod +x install-openshift-upi.sh

# Run installation
./install-openshift-upi.sh
```

The script will:

1. Install prerequisites (openshift-install, oc, Terraform, AWS CLI)
2. Generate installation configuration
3. Create ignition files
4. Upload ignition files to S3
5. Deploy AWS infrastructure with Terraform
6. Wait for bootstrap completion
7. Approve CSRs
8. Remove bootstrap node
9. Configure image registry
10. Complete installation

Installation typically takes 30-45 minutes.

## Detailed Installation

### Step-by-Step Manual Process

If you prefer to run steps individually:

#### 1. Install Prerequisites

```bash
# Install OpenShift installer
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.17/openshift-install-linux.tar.gz
tar -xzf openshift-install-linux.tar.gz
sudo mv openshift-install /usr/local/bin/

# Install oc CLI
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.17/openshift-client-linux.tar.gz
tar -xzf openshift-client-linux.tar.gz
sudo mv oc kubectl /usr/local/bin/

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
unzip terraform_1.5.7_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

#### 2. Generate Ignition Files

```bash
# Create install directory
mkdir -p openshift-install
cd openshift-install

# Generate install-config.yaml
openshift-install create install-config --dir=.

# Backup the config
cp install-config.yaml install-config.yaml.backup

# Generate ignition files
openshift-install create ignition-configs --dir=.
```

#### 3. Upload to S3

```bash
# Extract infrastructure name
INFRA_NAME=$(jq -r .infraID metadata.json)

# Create S3 bucket
aws s3 mb s3://${INFRA_NAME}-bootstrap-ignition

# Upload bootstrap ignition
aws s3 cp bootstrap.ign s3://${INFRA_NAME}-bootstrap-ignition/
```

#### 4. Deploy Infrastructure

```bash
cd ../terraform

# Initialize Terraform
terraform init

# Create terraform.tfvars (see configuration section)
vi terraform.tfvars

# Plan and apply
terraform plan -out=tfplan
terraform apply tfplan
```

#### 5. Wait for Bootstrap

```bash
export KUBECONFIG=../openshift-install/auth/kubeconfig
openshift-install wait-for bootstrap-complete --dir=../openshift-install --log-level=info
```

#### 6. Approve CSRs

```bash
# Approve pending CSRs (run multiple times)
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
```

#### 7. Remove Bootstrap

```bash
cd terraform
terraform destroy -target=module.bootstrap -auto-approve
```

#### 8. Configure Image Registry

```bash
# For testing (emptyDir)
oc patch configs.imageregistry.operator.openshift.io cluster \
  --type merge \
  --patch '{"spec":{"storage":{"emptyDir":{}},"managementState":"Managed"}}'

# For production (S3)
aws s3 mb s3://${INFRA_NAME}-image-registry
oc patch configs.imageregistry.operator.openshift.io cluster \
  --type merge \
  --patch "{\"spec\":{\"storage\":{\"s3\":{\"bucket\":\"${INFRA_NAME}-image-registry\",\"region\":\"us-east-1\"}},\"managementState\":\"Managed\"}}"
```

#### 9. Wait for Installation Complete

```bash
openshift-install wait-for install-complete --dir=../openshift-install --log-level=info
```

## Configuration

### config.env Options

```bash
# Cluster configuration
CLUSTER_NAME="clusterocp"            # Cluster name
BASE_DOMAIN="ocpexample.com"         # Base domain

# OpenShift Version (IMPORTANT!)
OPENSHIFT_VERSION="stable-4.17"      # Recommended for production
# Other options:
# OPENSHIFT_VERSION="4.17.1"         # Specific version
# OPENSHIFT_VERSION="latest-4.17"    # Latest in 4.17 stream
# OPENSHIFT_VERSION="stable-4.16"    # Different major version

# AWS configuration
AWS_REGION="us-east-1"               # AWS region
VPC_CIDR="172.31.0.0/16"             # VPC CIDR block

# Instance types
MASTER_INSTANCE_TYPE="m4.xlarge"     # Master: 4 vCPU, 16 GB RAM
WORKER_INSTANCE_TYPE="r5a.4xlarge"   # Worker: 16 vCPU, 128 GB RAM

# Node counts
MASTER_COUNT=3                        # Always 3 for HA
WORKER_COUNT=4                        # Adjust as needed

# Image registry
USE_REGISTRY_EMPTYDIR="false"        # true for testing, false for production
```

### OpenShift Version Selection

The automation supports multiple ways to specify the OpenShift version:

#### 1. Using the Version Helper (Recommended)

```bash
# Interactive version selector
./openshift-version-helper.sh select

# Or use command line
./openshift-version-helper.sh list                    # List all versions
./openshift-version-helper.sh details stable-4.17     # Show version details
./openshift-version-helper.sh ami stable-4.17 us-east-1  # Get RHCOS AMI
```

#### 2. Version Format Options

**Stable Channel (Recommended for Production):**

```bash
OPENSHIFT_VERSION="stable-4.17"  # Latest stable in 4.17
```

- Always gets the latest stable release in the channel
- Recommended for production deployments
- Thoroughly tested and validated

**Specific Version:**

```bash
OPENSHIFT_VERSION="4.17.1"       # Exact version
```

- Pins to a specific release
- Good for consistency across environments
- Use when you need a specific patch version

**Latest Channel:**

```bash
OPENSHIFT_VERSION="latest-4.17"  # Latest in 4.17 (including pre-release)
```

- Gets the newest features
- May include release candidates
- Good for testing and development

#### 3. Finding the Right RHCOS AMI

Each OpenShift version requires a matching RHCOS AMI. Use the helper:

```bash
# Get RHCOS AMI for your version and region
./openshift-version-helper.sh ami stable-4.17 us-east-1
```

Or manually check: https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/

#### 4. Version Compatibility

**OpenShift 4.17** (Latest as of installation):

- RHCOS: 417.x
- Kubernetes: 1.30
- Best for: New installations, Cloudera Data Services 1.5.5+

**OpenShift 4.16**:

- RHCOS: 416.x
- Kubernetes: 1.29
- Best for: Stable production workloads

**OpenShift 4.15**:

- RHCOS: 415.x
- Kubernetes: 1.28
- Best for: Long-term stable deployments

### Example Configurations

**For Production (Recommended):**

```bash
OPENSHIFT_VERSION="stable-4.17"
RHCOS_AMI="ami-0xxxxxxxxxxxxx"  # Get from version helper
MASTER_INSTANCE_TYPE="m4.xlarge"
WORKER_INSTANCE_TYPE="r5a.4xlarge"
WORKER_COUNT=4
USE_REGISTRY_EMPTYDIR="false"
```

**For Testing:**

```bash
OPENSHIFT_VERSION="latest-4.17"
RHCOS_AMI="ami-0xxxxxxxxxxxxx"
MASTER_INSTANCE_TYPE="t3.xlarge"
WORKER_INSTANCE_TYPE="t3.2xlarge"
WORKER_COUNT=2
USE_REGISTRY_EMPTYDIR="true"
```

**For Specific Version Control:**

```bash
OPENSHIFT_VERSION="4.17.1"
RHCOS_AMI="ami-0xxxxxxxxxxxxx"
# ... rest of config
```

### Terraform Module Structure

```
terraform/
├── main.tf                 # Main configuration
├── variables.tf            # Variable definitions
├── outputs.tf              # Output definitions
└── modules/
    ├── vpc/                # VPC, subnets, routing
    ├── iam/                # IAM roles and policies
    ├── security/           # Security groups
    ├── load_balancer/      # Network load balancers
    ├── route53/            # DNS configuration
    ├── bootstrap/          # Bootstrap node
    ├── control_plane/      # Master nodes
    └── workers/            # Worker nodes
```

## Troubleshooting

### Common Issues

#### 1. Bootstrap Timeout

```bash
# Check bootstrap status
ssh -i ~/.ssh/id_rsa core@<bootstrap-ip> journalctl -b -f -u bootkube.service
```

#### 2. CSR Not Approved

```bash
# List pending CSRs
oc get csr

# Approve all pending
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
```

#### 3. Nodes Not Ready

```bash
# Check node status
oc get nodes

# Check cluster operators
oc get co

# Force delete not ready node
oc delete node <node-name> --force
```

#### 4. Image Registry Not Available

```bash
# Check image registry status
oc get configs.imageregistry.operator.openshift.io cluster -o yaml

# Patch to allow running on masters
oc patch configs.imageregistry.operator.openshift.io cluster \
  --type=merge \
  --patch '{"spec":{"nodeSelector":{}}}'

# Add toleration for master nodes
oc patch configs.imageregistry.operator.openshift.io cluster \
  --type merge \
  --patch '{"spec":{"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Exists","effect":"NoSchedule"}]}}'
```

#### 5. Ingress Not Working

```bash
# Check ingress operator
oc get co ingress

# Patch to allow running on masters
oc patch ingresscontroller default \
  -n openshift-ingress-operator \
  --type=merge \
  --patch '{"spec":{"nodePlacement":{"nodeSelector":{"matchLabels":{"node-role.kubernetes.io/master":""}},"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Exists","effect":"NoSchedule"}]}}}'
```

### Debug Commands

```bash
# View cluster version
oc get clusterversion

# View cluster operators
oc get co

# View all nodes
oc get nodes -o wide

# View all pods in all namespaces
oc get pods --all-namespaces

# View installation logs
tail -f .openshift_install.log

# Check API server
curl -k https://api.${CLUSTER_NAME}.${BASE_DOMAIN}:6443/version
```

## Cleanup

### Complete Cluster Removal

```bash
# Option 1: Using Terraform
cd terraform
terraform destroy -auto-approve

# Option 2: Using openshift-install
openshift-install destroy cluster --dir=./openshift-install --log-level=info

# Clean up S3 buckets
aws s3 rb s3://${INFRA_NAME}-bootstrap-ignition --force
aws s3 rb s3://${INFRA_NAME}-image-registry --force
```

### Partial Cleanup (Bootstrap Only)

```bash
cd terraform
terraform destroy -target=module.bootstrap -auto-approve

# Delete S3 bucket
aws s3 rb s3://${INFRA_NAME}-bootstrap-ignition --force
```

## Cluster Operations

### Shutdown Cluster

```bash
# Check certificate expiration
oc -n openshift-kube-apiserver-operator get secret kube-apiserver-to-kubelet-signer \
  -o jsonpath='{.metadata.annotations.auth\.openshift\.io/certificate-not-after}'

# Shut down all nodes
for node in $(oc get nodes -o jsonpath='{.items[*].metadata.name}'); do
  oc debug node/${node} -- chroot /host shutdown -h 1
done

# Or stop via AWS console
aws ec2 stop-instances --instance-ids $(aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/${INFRA_NAME},Values=owned" \
  --query 'Reservations[*].Instances[*].InstanceId' --output text)
```

### Start Cluster

```bash
# Start all instances
aws ec2 start-instances --instance-ids $(aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/${INFRA_NAME},Values=owned" \
  --query 'Reservations[*].Instances[*].InstanceId' --output text)

# Wait for nodes to start
sleep 120

# Approve pending CSRs
export KUBECONFIG=./openshift-install/auth/kubeconfig
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
```

## Additional Resources

### Official Documentation

- [OpenShift 4.17 Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17)
- [Installing on AWS (UPI)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html/installing/installing-on-aws#installing-aws-user-infra)
- [Cloudera Data Services Documentation](https://docs.cloudera.com/)

### Useful Links

- [Red Hat OpenShift Downloads](https://cloud.redhat.com/openshift/install)
- [RHCOS AMI List](https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/)
- [AWS CloudFormation Templates](https://github.com/openshift/installer/tree/main/upi/aws/cloudformation)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Support

- Red Hat Support: https://access.redhat.com/support
- OpenShift Community: https://www.openshift.com/community
- AWS Support: https://aws.amazon.com/support

## License & Credits

### License

This OpenShift UPI Automation Framework is released under the **MIT License**.

**You are free to:**

- ✅ Use commercially
- ✅ Modify and customize
- ✅ Distribute and share
- ✅ Use privately
- ✅ Sublicense

**You must:**

- 📋 Include the license and copyright notice
- 📋 Include the NOTICE file for attribution

**See [LICENSE](LICENSE) and [LICENSING_GUIDE.md](LICENSING_GUIDE.md) for complete details.**

### Required Third-Party Licenses

While this automation is free and open-source, you **must obtain** separate licenses for:

1. **Red Hat OpenShift Container Platform**

   - Commercial subscription required for production use
   - Free developer subscription available for testing
   - 60-day trial available
   - Get it: https://www.redhat.com/en/technologies/cloud-computing/openshift

2. **Cloudera Data Services** (if using Cloudera)

   - Commercial license required
   - Contact Cloudera sales for pricing
   - Get it: https://www.cloudera.com/

3. **Amazon Web Services**
   - Active AWS account required
   - Pay-as-you-go for resources (~$3,500/month for default configuration)
   - Sign up: https://aws.amazon.com/

### Third-Party Open Source

This project uses these open-source tools (no additional licenses needed):

- **Terraform** (MPL 2.0) - Infrastructure as Code
- **OpenShift Installer** (Apache 2.0) - Cluster installation
- **AWS CLI** (Apache 2.0) - AWS management

### Attribution

**Based on**: OpenShift Installation Guide for Cloudera Data Services  
**Author**: Ramprasad Ohnu (Solutions Architect)  
**Date**: July 2025

This automation implements and extends the procedures documented in the official guide.

### Trademarks

- OpenShift® is a registered trademark of Red Hat, Inc.
- Cloudera® is a registered trademark of Cloudera, Inc.
- Amazon Web Services® and AWS® are registered trademarks of Amazon.com, Inc.
- Terraform® is a registered trademark of HashiCorp, Inc.

This software is not affiliated with, endorsed by, or sponsored by any of the above companies.

### Disclaimer

This automation framework is provided "as-is" without warranty of any kind. Users are responsible for:

- Obtaining valid subscriptions and licenses
- Testing thoroughly before production use
- Complying with security and compliance policies
- Following vendor terms of service

For official support, contact:

- **Red Hat Support**: https://access.redhat.com/support
- **Cloudera Support**: https://www.cloudera.com/support.html
- **AWS Support**: https://aws.amazon.com/support

## Contributing

Contributions are welcome! Please submit pull requests or issues to improve this automation framework.

**By contributing, you agree:**

- Your contributions will be MIT licensed
- You have rights to contribute the code
- You accept the "no warranty" terms

## Authors

Based on the OpenShift Installation Guide for Cloudera Data Services by Ramprasad Ohnu (Solutions Architect).
