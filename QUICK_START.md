# OpenShift 4.17 UPI Automation - Quick Start Guide

## 📦 Package Contents

This automation package contains everything you need to deploy OpenShift Container Platform 4.17 on AWS using User-Provisioned Infrastructure (UPI), optimized for Cloudera Data Services.

### Files Included

```
├── README.md                    # Comprehensive documentation
├── Makefile                     # Convenient automation commands
├── install-openshift-upi.sh    # Main installation script
├── cluster-ops.sh              # Cluster operations utility
├── config.env.example          # Configuration template
└── terraform/                  # Infrastructure as Code
    ├── main.tf                 # Main Terraform configuration
    ├── variables.tf            # Variable definitions
    ├── outputs.tf              # Output definitions
    └── modules/                # Terraform modules
        ├── vpc/                # VPC and networking
        ├── iam/                # IAM roles and policies
        ├── security/           # Security groups
        ├── load_balancer/      # Load balancers
        ├── route53/            # DNS configuration
        ├── bootstrap/          # Bootstrap node
        ├── control_plane/      # Master nodes
        └── workers/            # Worker nodes
```

## 🚀 Quick Start (5 Minutes)

### 1. Prerequisites Check

Before starting, ensure you have:
- AWS account with appropriate permissions
- Red Hat account with valid subscription
- Domain managed in Route53 (or external DNS)
- RHCOS AMI ID for your region
- Pull secret from https://cloud.redhat.com/openshift/install

### 2. One-Command Installation

```bash
# Download and extract the package
# cd to the extracted directory

# Configure your environment
cp config.env.example config.env
vi config.env  # Edit with your values

# Install everything
make install
```

That's it! The automation will:
1. Install prerequisites (openshift-install, oc, Terraform, AWS CLI)
2. Generate configuration files
3. Create ignition files
4. Upload to S3
5. Deploy AWS infrastructure
6. Bootstrap the cluster
7. Configure OpenShift
8. Provide access credentials

**Installation Time:** 30-45 minutes

## 📋 Configuration

Edit `config.env` with your values:

```bash
# Required Configuration
CLUSTER_NAME="your-cluster"
BASE_DOMAIN="your-domain.com"

# OpenShift Version (Choose one)
OPENSHIFT_VERSION="stable-4.17"      # Recommended for production
# OPENSHIFT_VERSION="4.17.1"         # Specific version
# OPENSHIFT_VERSION="latest-4.17"    # Latest features

AWS_REGION="us-east-1"
RHCOS_AMI="ami-xxxxxxxxxxxxxxxxx"
PULL_SECRET_FILE="/path/to/pull-secret.json"
SSH_KEY_PATH="/path/to/ssh-key"

# Instance Configuration (adjust for Cloudera)
MASTER_INSTANCE_TYPE="m4.xlarge"     # 4 vCPU, 16 GB RAM
WORKER_INSTANCE_TYPE="r5a.4xlarge"   # 16 vCPU, 128 GB RAM
WORKER_COUNT=4                        # For Cloudera workloads
```

### 🔍 Finding the Right Version

**Option 1: Interactive Helper (Recommended)**
```bash
# Select version interactively
make version-select

# This will help you:
# 1. Choose between stable/latest/specific
# 2. Get the matching RHCOS AMI
# 3. Generate config.env settings
```

**Option 2: List and Choose**
```bash
# List all available versions
make version-list

# Get details for a version
make version-details VERSION=stable-4.17

# Get RHCOS AMI for your region
make version-ami VERSION=stable-4.17 REGION=us-east-1
```

**Option 3: Manual Selection**

Visit: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/

Recommended versions:
- `stable-4.17` - Latest stable (production)
- `4.17.1` - Specific version (consistency)
- `latest-4.17` - Newest features (testing)

## 🎯 Common Operations

### Check Cluster Health
```bash
make check
# or
./cluster-ops.sh check-health
```

### Approve Pending CSRs
```bash
make approve-csrs
```

### Get Credentials
```bash
make credentials
```

### Scale Workers
```bash
make scale-workers COUNT=6
```

### Shutdown/Start Cluster
```bash
make shutdown
make start
```

### Destroy Cluster
```bash
make destroy
```

## 📊 Cost Estimate

Based on the PDF specifications for Cloudera Data Services:

| Component | Count | Type | Monthly Cost |
|-----------|-------|------|--------------|
| Masters | 3 | m4.xlarge | ~$560 |
| Workers | 4 | r5a.4xlarge | ~$3,144 |
| Storage | - | EBS | ~$394 |
| **Total** | **7 nodes** | **Various** | **~$3,538/month** |

## 🔍 Troubleshooting

### Bootstrap Issues
```bash
# Check bootstrap logs
ssh -i ~/.ssh/id_rsa core@<bootstrap-ip> journalctl -b -f -u bootkube.service
```

### Pending CSRs
```bash
# List and approve
oc get csr
make approve-csrs
```

### Image Registry Issues
```bash
# Check status
oc get configs.imageregistry.operator.openshift.io cluster -o yaml

# Fix for masters-only cluster
./cluster-ops.sh  # Select option 9 for troubleshooting
```

## 📚 Documentation

### Key Resources
- **README.md**: Complete documentation with all details
- **Makefile**: List all available commands with `make help`
- **cluster-ops.sh**: Interactive utility for cluster management

### Architecture Overview

```
AWS Region
├── VPC (3 AZs)
│   ├── Public Subnets (NAT GW, Load Balancers)
│   └── Private Subnets
│       ├── Master Nodes (3)
│       └── Worker Nodes (4)
├── Network Load Balancers
│   ├── API (port 6443)
│   └── Apps (ports 80/443)
└── Route53 DNS
    ├── api.<cluster>.<domain>
    └── *.apps.<cluster>.<domain>
```

## 🔐 Security Notes

- All cluster nodes run in private subnets
- NAT gateways provide outbound internet access
- Security groups restrict traffic between components
- SSH access only through bastion (or configure as needed)
- Image registry can use S3 with encryption

## 🎓 For Cloudera Data Services

This installation is optimized for Cloudera Data Services with:
- **High-memory workers** (r5a.4xlarge with 128 GB RAM)
- **Large storage** (1.2 TB per worker)
- **Performance** (300 IOPS minimum)
- **Network** (Enhanced networking enabled)
- **Scalability** (Easily scale workers as needed)

### Post-Installation for Cloudera

After OpenShift installation completes:
1. Follow Cloudera Data Services installation guide
2. Configure storage classes as required
3. Set up monitoring and logging
4. Configure backup and disaster recovery

## 💡 Tips and Best Practices

### 1. Testing First
```bash
# Use smaller instances for testing
MASTER_INSTANCE_TYPE="t3.xlarge"
WORKER_INSTANCE_TYPE="t3.2xlarge"
WORKER_COUNT=2
```

### 2. Production Setup
- Use production-grade S3 bucket for image registry
- Enable backup for ETCD
- Configure monitoring and alerting
- Set up cluster autoscaling

### 3. Cost Optimization
```bash
# Stop cluster when not in use
make shutdown

# Start when needed
make start
```

### 4. Maintenance
```bash
# Regular health checks
make check

# Update cluster
make upgrade VERSION=4.17.1
```

## 🤝 Support

### Issues During Installation
1. Check logs: `tail -f .openshift_install.log`
2. Review AWS CloudWatch for infrastructure issues
3. Check OpenShift events: `oc get events --all-namespaces`

### Common Questions

**Q: How do I get RHCOS AMI ID?**
A: Visit https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/

**Q: Can I use existing VPC?**
A: Yes, modify the VPC module to use existing resources

**Q: How do I add more workers?**
A: Use `make scale-workers COUNT=<new-count>`

**Q: Where are my credentials?**
A: Run `make credentials` to display them

## 📞 Additional Resources

- **OpenShift Documentation**: https://docs.openshift.com/
- **Cloudera Data Services**: https://docs.cloudera.com/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/
- **Red Hat Support**: https://access.redhat.com/support

## ✨ Features

✅ **Fully Automated** - Single command installation
✅ **Production Ready** - Best practices built-in
✅ **Highly Available** - 3 masters, 4 workers
✅ **Scalable** - Easy to add/remove workers
✅ **Cost Optimized** - Stop/start cluster support
✅ **Well Documented** - Comprehensive README
✅ **Battle Tested** - Based on Red Hat best practices
✅ **Cloudera Ready** - Optimized for data workloads

## 🎉 Success Criteria

After successful installation, you should see:
- ✅ All cluster operators running
- ✅ All nodes in Ready state
- ✅ Console accessible
- ✅ API endpoint responding
- ✅ No pending CSRs
- ✅ Image registry operational

```bash
# Verify installation
oc get co              # All should show Available=True
oc get nodes           # All should show Ready
oc get clusterversion  # Should show your version
```

## 🏁 Next Steps

1. **Access the Console**
   ```bash
   make console
   ```

2. **Install Cloudera Data Services**
   - Follow Cloudera installation guide
   - Use the cluster credentials provided

3. **Configure Monitoring**
   - Set up Prometheus/Grafana
   - Configure alerts

4. **Set Up Backups**
   ```bash
   make backup-etcd
   ```

5. **Scale as Needed**
   ```bash
   make scale-workers COUNT=6
   ```

---

## License & Credits

This automation framework is provided for use with OpenShift Container Platform and Cloudera Data Services installations.

**Based on**: OpenShift Installation Guide for Cloudera Data Services by Ramprasad Ohnu (Solutions Architect)

**Created**: November 2025

**Version**: 1.0.0

---

**Happy Installing! 🚀**

For questions or issues, refer to the comprehensive README.md included in this package.
