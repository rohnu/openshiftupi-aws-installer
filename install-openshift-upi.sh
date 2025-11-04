#!/bin/bash

###############################################################################
# OpenShift 4.17 UPI Installation Automation Script
# For Cloudera Data Services
# Based on: Openshift_Installation_4_17_for_Cloudera_Data_Services_1_5_5.pdf
###############################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration file
CONFIG_FILE="${CONFIG_FILE:-./config.env}"

# Default OpenShift version if not set
DEFAULT_OPENSHIFT_VERSION="4.17"

# Load configuration
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    log_info "Loaded configuration from $CONFIG_FILE"
else
    log_error "Configuration file $CONFIG_FILE not found!"
    log_info "Please create a config.env file. See config.env.example"
    exit 1
fi

# Required variables check
required_vars=(
    "CLUSTER_NAME"
    "BASE_DOMAIN"
    "AWS_REGION"
    "RHCOS_AMI"
    "PULL_SECRET_FILE"
    "SSH_KEY_PATH"
    "VPC_CIDR"
)

for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        log_error "Required variable $var is not set!"
        exit 1
    fi
done

# Set OpenShift version with default
OPENSHIFT_VERSION="${OPENSHIFT_VERSION:-$DEFAULT_OPENSHIFT_VERSION}"
log_info "Using OpenShift version: $OPENSHIFT_VERSION"

# Directories
WORK_DIR="${WORK_DIR:-./openshift-install}"
TERRAFORM_DIR="${TERRAFORM_DIR:-./terraform}"
IGNITION_DIR="$WORK_DIR/ignition"
AUTH_DIR="$WORK_DIR/auth"

# Create working directories
mkdir -p "$WORK_DIR" "$IGNITION_DIR" "$AUTH_DIR" "$TERRAFORM_DIR"

###############################################################################
# Function: Install Prerequisites
###############################################################################
install_prerequisites() {
    log_info "Installing prerequisites..."
    
    # Install wget
    if ! command -v wget &> /dev/null; then
        sudo yum install -y wget
    fi
    
    # Install jq
    if ! command -v jq &> /dev/null; then
        sudo yum install -y jq
    fi
    
    # Install AWS CLI
    if ! command -v aws &> /dev/null; then
        log_info "Installing AWS CLI..."
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip
        sudo ./aws/install
        rm -rf aws awscliv2.zip
    fi
    
    # Install Terraform
    if ! command -v terraform &> /dev/null; then
        log_info "Installing Terraform..."
        TERRAFORM_VERSION="1.5.7"
        wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
        unzip -q "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
        sudo mv terraform /usr/local/bin/
        rm "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    fi
    
    # Download OpenShift Installer with specified version
    if [[ ! -f "/usr/local/bin/openshift-install" ]]; then
        log_info "Downloading OpenShift Installer ${OPENSHIFT_VERSION}..."
        
        # Determine download URL based on version format
        if [[ "$OPENSHIFT_VERSION" == stable-* ]] || [[ "$OPENSHIFT_VERSION" == latest-* ]]; then
            DOWNLOAD_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OPENSHIFT_VERSION}/openshift-install-linux.tar.gz"
        else
            DOWNLOAD_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OPENSHIFT_VERSION}/openshift-install-linux.tar.gz"
        fi
        
        log_info "Download URL: $DOWNLOAD_URL"
        wget -q "$DOWNLOAD_URL" -O openshift-install-linux.tar.gz || {
            log_error "Failed to download OpenShift installer version ${OPENSHIFT_VERSION}"
            log_error "Please check if the version exists at: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
            exit 1
        }
        
        tar -xzf openshift-install-linux.tar.gz
        sudo mv openshift-install /usr/local/bin/
        rm openshift-install-linux.tar.gz README.md
        
        # Verify version
        openshift-install version
    else
        log_info "OpenShift installer already installed: $(openshift-install version | head -1)"
    fi
    
    # Download oc CLI with matching version
    if [[ ! -f "/usr/local/bin/oc" ]]; then
        log_info "Downloading oc CLI ${OPENSHIFT_VERSION}..."
        
        # Determine download URL based on version format
        if [[ "$OPENSHIFT_VERSION" == stable-* ]] || [[ "$OPENSHIFT_VERSION" == latest-* ]]; then
            DOWNLOAD_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OPENSHIFT_VERSION}/openshift-client-linux.tar.gz"
        else
            DOWNLOAD_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OPENSHIFT_VERSION}/openshift-client-linux.tar.gz"
        fi
        
        wget -q "$DOWNLOAD_URL" -O openshift-client-linux.tar.gz || {
            log_error "Failed to download oc CLI version ${OPENSHIFT_VERSION}"
            exit 1
        }
        
        tar -xzf openshift-client-linux.tar.gz
        sudo mv oc kubectl /usr/local/bin/
        rm openshift-client-linux.tar.gz README.md
        
        # Verify version
        oc version --client
    else
        log_info "oc CLI already installed: $(oc version --client 2>&1 | head -1)"
    fi
    
    log_info "Prerequisites installed successfully"
}

###############################################################################
# Function: Generate install-config.yaml
###############################################################################
generate_install_config() {
    log_info "Generating install-config.yaml..."
    
    cat > "$WORK_DIR/install-config.yaml" <<EOF
apiVersion: v1
baseDomain: ${BASE_DOMAIN}
metadata:
  name: ${CLUSTER_NAME}
compute:
- hyperthreading: Enabled
  name: worker
  platform:
    aws:
      type: ${WORKER_INSTANCE_TYPE:-r5a.4xlarge}
  replicas: 0  # We'll create workers via CloudFormation/Terraform
controlPlane:
  hyperthreading: Enabled
  name: master
  platform:
    aws:
      type: ${MASTER_INSTANCE_TYPE:-m4.xlarge}
  replicas: 3
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: ${VPC_CIDR}
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
platform:
  aws:
    region: ${AWS_REGION}
    subnets:
$(for subnet in ${SUBNET_IDS}; do echo "    - $subnet"; done)
publish: External
pullSecret: '$(cat ${PULL_SECRET_FILE})'
sshKey: '$(cat ${SSH_KEY_PATH}.pub)'
EOF

    # Backup install-config.yaml
    cp "$WORK_DIR/install-config.yaml" "$WORK_DIR/install-config.yaml.backup"
    
    log_info "install-config.yaml generated successfully"
}

###############################################################################
# Function: Generate Ignition Configs
###############################################################################
generate_ignition_configs() {
    log_info "Generating Ignition configuration files..."
    
    cd "$WORK_DIR"
    openshift-install create ignition-configs --dir=.
    
    log_info "Ignition configs generated:"
    ls -lh bootstrap.ign master.ign worker.ign
    
    # Extract infrastructure name
    INFRA_NAME=$(jq -r .infraID metadata.json)
    export INFRA_NAME
    log_info "Infrastructure name: $INFRA_NAME"
    
    cd - > /dev/null
}

###############################################################################
# Function: Upload Ignition Files to S3
###############################################################################
upload_ignition_to_s3() {
    log_info "Creating S3 bucket for ignition files..."
    
    S3_BUCKET="${INFRA_NAME}-bootstrap-ignition"
    
    # Create S3 bucket
    if aws s3 ls "s3://${S3_BUCKET}" 2>&1 | grep -q 'NoSuchBucket'; then
        aws s3 mb "s3://${S3_BUCKET}" --region "${AWS_REGION}"
        log_info "Created S3 bucket: ${S3_BUCKET}"
    else
        log_info "S3 bucket already exists: ${S3_BUCKET}"
    fi
    
    # Upload bootstrap ignition file
    aws s3 cp "$WORK_DIR/bootstrap.ign" "s3://${S3_BUCKET}/bootstrap.ign"
    log_info "Uploaded bootstrap.ign to S3"
    
    # Get S3 URL
    BOOTSTRAP_IGN_URL="s3://${S3_BUCKET}/bootstrap.ign"
    export BOOTSTRAP_IGN_URL
    
    log_info "Bootstrap ignition URL: $BOOTSTRAP_IGN_URL"
}

###############################################################################
# Function: Deploy Infrastructure with Terraform
###############################################################################
deploy_terraform_infrastructure() {
    log_info "Deploying AWS infrastructure with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    terraform init
    
    # Create terraform.tfvars
    cat > terraform.tfvars <<EOF
cluster_name = "${CLUSTER_NAME}"
base_domain = "${BASE_DOMAIN}"
aws_region = "${AWS_REGION}"
vpc_cidr = "${VPC_CIDR}"
availability_zones = ${AVAILABILITY_ZONES}
infra_name = "${INFRA_NAME}"
rhcos_ami = "${RHCOS_AMI}"
bootstrap_ign_url = "${BOOTSTRAP_IGN_URL}"
master_ign = $(cat "$WORK_DIR/master.ign" | jq -c .)
worker_ign = $(cat "$WORK_DIR/worker.ign" | jq -c .)
master_count = ${MASTER_COUNT:-3}
worker_count = ${WORKER_COUNT:-4}
master_instance_type = "${MASTER_INSTANCE_TYPE:-m4.xlarge}"
worker_instance_type = "${WORKER_INSTANCE_TYPE:-r5a.4xlarge}"
ssh_public_key = "$(cat ${SSH_KEY_PATH}.pub)"
EOF
    
    # Plan
    terraform plan -out=tfplan
    
    # Apply
    terraform apply tfplan
    
    log_info "Infrastructure deployed successfully"
    
    # Export outputs
    export API_ENDPOINT=$(terraform output -raw api_endpoint)
    export CONSOLE_URL=$(terraform output -raw console_url)
    
    cd - > /dev/null
}

###############################################################################
# Function: Wait for Bootstrap Complete
###############################################################################
wait_for_bootstrap() {
    log_info "Waiting for bootstrap to complete..."
    
    export KUBECONFIG="$WORK_DIR/auth/kubeconfig"
    
    openshift-install wait-for bootstrap-complete \
        --dir="$WORK_DIR" \
        --log-level=info
    
    log_info "Bootstrap complete!"
}

###############################################################################
# Function: Approve CSRs
###############################################################################
approve_csrs() {
    log_info "Approving pending CSRs..."
    
    export KUBECONFIG="$WORK_DIR/auth/kubeconfig"
    
    # Approve all pending CSRs
    for i in {1..10}; do
        log_info "Approval round $i..."
        oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' \
            | xargs --no-run-if-empty oc adm certificate approve
        sleep 10
    done
    
    log_info "CSRs approved"
}

###############################################################################
# Function: Destroy Bootstrap
###############################################################################
destroy_bootstrap() {
    log_info "Destroying bootstrap resources..."
    
    cd "$TERRAFORM_DIR"
    terraform destroy -target=module.bootstrap -auto-approve
    cd - > /dev/null
    
    # Delete S3 bucket
    aws s3 rm "s3://${S3_BUCKET}" --recursive
    aws s3 rb "s3://${S3_BUCKET}"
    
    log_info "Bootstrap resources destroyed"
}

###############################################################################
# Function: Configure Image Registry
###############################################################################
configure_image_registry() {
    log_info "Configuring image registry..."
    
    export KUBECONFIG="$WORK_DIR/auth/kubeconfig"
    
    # For production, configure S3 storage
    # For testing, use emptyDir
    if [[ "${USE_REGISTRY_EMPTYDIR:-false}" == "true" ]]; then
        oc patch configs.imageregistry.operator.openshift.io cluster \
            --type merge \
            --patch '{"spec":{"storage":{"emptyDir":{}},"managementState":"Managed"}}'
    else
        # Configure S3 for image registry
        REGISTRY_BUCKET="${INFRA_NAME}-image-registry"
        aws s3 mb "s3://${REGISTRY_BUCKET}" --region "${AWS_REGION}"
        
        oc patch configs.imageregistry.operator.openshift.io cluster \
            --type merge \
            --patch "{\"spec\":{\"storage\":{\"s3\":{\"bucket\":\"${REGISTRY_BUCKET}\",\"region\":\"${AWS_REGION}\"}},\"managementState\":\"Managed\"}}"
    fi
    
    log_info "Image registry configured"
}

###############################################################################
# Function: Wait for Installation Complete
###############################################################################
wait_for_install_complete() {
    log_info "Waiting for installation to complete..."
    
    openshift-install wait-for install-complete \
        --dir="$WORK_DIR" \
        --log-level=info
    
    log_info "Installation complete!"
}

###############################################################################
# Function: Display Cluster Info
###############################################################################
display_cluster_info() {
    log_info "=========================================="
    log_info "OpenShift Cluster Installation Complete!"
    log_info "=========================================="
    log_info ""
    log_info "Cluster Name: ${CLUSTER_NAME}"
    log_info "API Endpoint: ${API_ENDPOINT}"
    log_info "Console URL: ${CONSOLE_URL}"
    log_info ""
    log_info "Credentials:"
    log_info "  Username: kubeadmin"
    log_info "  Password: $(cat $WORK_DIR/auth/kubeadmin-password)"
    log_info ""
    log_info "Kubeconfig: $WORK_DIR/auth/kubeconfig"
    log_info ""
    log_info "To use oc CLI:"
    log_info "  export KUBECONFIG=$WORK_DIR/auth/kubeconfig"
    log_info "  oc whoami"
    log_info ""
}

###############################################################################
# Main Installation Flow
###############################################################################
main() {
    log_info "Starting OpenShift UPI Installation..."
    log_info "OpenShift Version: ${OPENSHIFT_VERSION}"
    log_info "Cluster: ${CLUSTER_NAME}.${BASE_DOMAIN}"
    log_info "Region: ${AWS_REGION}"
    
    # Step 1: Install prerequisites
    install_prerequisites
    
    # Step 2: Generate install config
    generate_install_config
    
    # Step 3: Generate ignition configs
    generate_ignition_configs
    
    # Step 4: Upload ignition files to S3
    upload_ignition_to_s3
    
    # Step 5: Deploy infrastructure with Terraform
    deploy_terraform_infrastructure
    
    # Step 6: Wait for bootstrap complete
    wait_for_bootstrap
    
    # Step 7: Approve CSRs
    approve_csrs
    
    # Step 8: Destroy bootstrap
    destroy_bootstrap
    
    # Step 9: Approve more CSRs for workers
    approve_csrs
    
    # Step 10: Configure image registry
    configure_image_registry
    
    # Step 11: Wait for installation complete
    wait_for_install_complete
    
    # Step 12: Display cluster info
    display_cluster_info
    
    log_info "Installation completed successfully!"
}

# Run main function
main "$@"
