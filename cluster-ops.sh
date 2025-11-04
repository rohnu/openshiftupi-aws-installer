#!/bin/bash

###############################################################################
# OpenShift Cluster Operations Utility Script
###############################################################################

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
WORK_DIR="${WORK_DIR:-./openshift-install}"
TERRAFORM_DIR="${TERRAFORM_DIR:-./terraform}"
KUBECONFIG="${WORK_DIR}/auth/kubeconfig"

# Functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

###############################################################################
# Check Cluster Health
###############################################################################
check_health() {
    log_info "Checking cluster health..."
    
    export KUBECONFIG="${WORK_DIR}/auth/kubeconfig"
    
    echo ""
    log_info "=== Cluster Version ==="
    oc get clusterversion
    
    echo ""
    log_info "=== Cluster Operators ==="
    oc get co
    
    echo ""
    log_info "=== Nodes ==="
    oc get nodes -o wide
    
    echo ""
    log_info "=== Cluster Resources ==="
    oc adm top nodes 2>/dev/null || echo "Metrics not available yet"
    
    echo ""
    log_info "=== Pending CSRs ==="
    PENDING_CSR=$(oc get csr | grep Pending | wc -l)
    if [ "$PENDING_CSR" -gt 0 ]; then
        log_warn "Found $PENDING_CSR pending CSRs"
        oc get csr | grep Pending
    else
        log_info "No pending CSRs"
    fi
    
    echo ""
    log_info "=== Problem Pods ==="
    oc get pods --all-namespaces | grep -vE 'Running|Completed' || log_info "All pods running"
}

###############################################################################
# Approve All Pending CSRs
###############################################################################
approve_csrs() {
    log_info "Approving pending CSRs..."
    
    export KUBECONFIG="${WORK_DIR}/auth/kubeconfig"
    
    APPROVED=0
    for i in {1..10}; do
        log_info "Approval round $i..."
        PENDING=$(oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}')
        
        if [ -n "$PENDING" ]; then
            echo "$PENDING" | xargs oc adm certificate approve
            APPROVED=$((APPROVED + $(echo "$PENDING" | wc -l)))
        fi
        
        sleep 5
    done
    
    log_info "Approved $APPROVED CSRs"
}

###############################################################################
# Get Cluster Credentials
###############################################################################
get_credentials() {
    log_info "Cluster Credentials"
    echo ""
    echo "Kubeconfig: ${WORK_DIR}/auth/kubeconfig"
    echo "Username: kubeadmin"
    echo "Password: $(cat ${WORK_DIR}/auth/kubeadmin-password 2>/dev/null || echo 'Not found')"
    echo ""
    echo "API Endpoint: $(oc whoami --show-server 2>/dev/null || echo 'Not available')"
    echo "Console URL: $(oc whoami --show-console 2>/dev/null || echo 'Not available')"
}

###############################################################################
# Shutdown Cluster
###############################################################################
shutdown_cluster() {
    log_warn "Shutting down cluster..."
    
    export KUBECONFIG="${WORK_DIR}/auth/kubeconfig"
    
    # Check certificate expiration
    log_info "Certificate expires:"
    oc -n openshift-kube-apiserver-operator get secret kube-apiserver-to-kubelet-signer \
        -o jsonpath='{.metadata.annotations.auth\.openshift\.io/certificate-not-after}' || true
    echo ""
    
    read -p "Continue with shutdown? (yes/no): " -r
    if [[ ! $REPLY =~ ^yes$ ]]; then
        log_info "Shutdown cancelled"
        return
    fi
    
    log_info "Shutting down all nodes..."
    for node in $(oc get nodes -o jsonpath='{.items[*].metadata.name}'); do
        log_info "Shutting down node: $node"
        oc debug node/${node} -- chroot /host shutdown -h 1 &
    done
    
    wait
    log_info "Shutdown initiated for all nodes"
}

###############################################################################
# Start Cluster
###############################################################################
start_cluster() {
    log_info "Starting cluster..."
    
    cd "$TERRAFORM_DIR"
    
    # Get infrastructure name
    INFRA_NAME=$(terraform output -raw infrastructure_name 2>/dev/null)
    
    if [ -z "$INFRA_NAME" ]; then
        log_error "Cannot determine infrastructure name"
        return 1
    fi
    
    # Start all instances
    log_info "Starting EC2 instances..."
    aws ec2 start-instances --instance-ids $(aws ec2 describe-instances \
        --filters "Name=tag:kubernetes.io/cluster/${INFRA_NAME},Values=owned" \
                  "Name=instance-state-name,Values=stopped" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text)
    
    log_info "Waiting for nodes to start (2 minutes)..."
    sleep 120
    
    cd - > /dev/null
    
    # Approve CSRs
    log_info "Approving CSRs..."
    approve_csrs
    
    # Check health
    check_health
}

###############################################################################
# Scale Workers
###############################################################################
scale_workers() {
    local COUNT=$1
    
    if [ -z "$COUNT" ]; then
        log_error "Usage: $0 scale-workers <count>"
        return 1
    fi
    
    log_info "Scaling workers to $COUNT..."
    
    cd "$TERRAFORM_DIR"
    
    # Update terraform.tfvars
    sed -i "s/worker_count = .*/worker_count = $COUNT/" terraform.tfvars
    
    # Apply changes
    terraform plan -target=module.workers -out=tfplan
    terraform apply tfplan
    
    cd - > /dev/null
    
    log_info "Waiting for new workers..."
    sleep 30
    
    # Approve CSRs
    approve_csrs
    
    # Check nodes
    export KUBECONFIG="${WORK_DIR}/auth/kubeconfig"
    oc get nodes
}

###############################################################################
# Destroy Cluster
###############################################################################
destroy_cluster() {
    log_warn "This will destroy the entire cluster!"
    read -p "Are you sure? Type 'yes' to continue: " -r
    
    if [[ ! $REPLY =~ ^yes$ ]]; then
        log_info "Destroy cancelled"
        return
    fi
    
    cd "$TERRAFORM_DIR"
    
    log_info "Destroying cluster infrastructure..."
    terraform destroy -auto-approve
    
    cd - > /dev/null
    
    # Clean up S3 buckets
    log_info "Cleaning up S3 buckets..."
    INFRA_NAME=$(jq -r .infraID "${WORK_DIR}/metadata.json" 2>/dev/null || echo "")
    
    if [ -n "$INFRA_NAME" ]; then
        aws s3 rb "s3://${INFRA_NAME}-bootstrap-ignition" --force 2>/dev/null || true
        aws s3 rb "s3://${INFRA_NAME}-image-registry" --force 2>/dev/null || true
    fi
    
    log_info "Cluster destroyed"
}

###############################################################################
# Backup ETCD
###############################################################################
backup_etcd() {
    log_info "Backing up etcd..."
    
    export KUBECONFIG="${WORK_DIR}/auth/kubeconfig"
    
    # Create backup job
    cat <<EOF | oc create -f -
apiVersion: v1
kind: Pod
metadata:
  name: etcd-backup
  namespace: openshift-etcd
spec:
  containers:
  - name: backup
    image: quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:6a2378154881e6f9a4638f41242518d850e19b0d7d9ef74a2be55b87f4625e87
    command:
    - /usr/local/bin/cluster-backup.sh
    - /home/core/backup
    volumeMounts:
    - name: backup-dir
      mountPath: /home/core/backup
  volumes:
  - name: backup-dir
    hostPath:
      path: /home/core/backup
      type: DirectoryOrCreate
  restartPolicy: Never
  nodeName: $(oc get nodes -l node-role.kubernetes.io/master -o jsonpath='{.items[0].metadata.name}')
EOF
    
    log_info "ETCD backup initiated. Check status with: oc logs -n openshift-etcd etcd-backup"
}

###############################################################################
# Upgrade Cluster
###############################################################################
upgrade_cluster() {
    local VERSION=$1
    
    if [ -z "$VERSION" ]; then
        log_info "Available updates:"
        export KUBECONFIG="${WORK_DIR}/auth/kubeconfig"
        oc adm upgrade
        return
    fi
    
    log_info "Upgrading cluster to version $VERSION..."
    export KUBECONFIG="${WORK_DIR}/auth/kubeconfig"
    
    oc adm upgrade --to="$VERSION"
    
    log_info "Upgrade initiated. Monitor with: oc get clusterversion"
}

###############################################################################
# Main Menu
###############################################################################
show_menu() {
    echo ""
    echo "OpenShift Cluster Operations"
    echo "============================="
    echo "1. Check Health"
    echo "2. Approve CSRs"
    echo "3. Get Credentials"
    echo "4. Shutdown Cluster"
    echo "5. Start Cluster"
    echo "6. Scale Workers"
    echo "7. Backup ETCD"
    echo "8. Upgrade Cluster"
    echo "9. Destroy Cluster"
    echo "0. Exit"
    echo ""
}

###############################################################################
# Main
###############################################################################
main() {
    if [ $# -eq 0 ]; then
        # Interactive mode
        while true; do
            show_menu
            read -p "Select option: " choice
            
            case $choice in
                1) check_health ;;
                2) approve_csrs ;;
                3) get_credentials ;;
                4) shutdown_cluster ;;
                5) start_cluster ;;
                6) read -p "Enter worker count: " count; scale_workers "$count" ;;
                7) backup_etcd ;;
                8) read -p "Enter version (or press enter to see available): " ver; upgrade_cluster "$ver" ;;
                9) destroy_cluster ;;
                0) log_info "Goodbye!"; exit 0 ;;
                *) log_error "Invalid option" ;;
            esac
            
            read -p "Press enter to continue..."
        done
    else
        # Command line mode
        case $1 in
            check-health) check_health ;;
            approve-csrs) approve_csrs ;;
            get-credentials) get_credentials ;;
            shutdown) shutdown_cluster ;;
            start) start_cluster ;;
            scale-workers) scale_workers "${2:-}" ;;
            backup-etcd) backup_etcd ;;
            upgrade) upgrade_cluster "${2:-}" ;;
            destroy) destroy_cluster ;;
            *)
                echo "Usage: $0 {check-health|approve-csrs|get-credentials|shutdown|start|scale-workers|backup-etcd|upgrade|destroy}"
                exit 1
                ;;
        esac
    fi
}

main "$@"
