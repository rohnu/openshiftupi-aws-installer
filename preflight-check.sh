#!/bin/bash

###############################################################################
# OpenShift UPI Preflight Check Script
# Validates environment before installation
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

log_ok() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
log_error() { echo -e "${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }
log_info() { echo -e "  $1"; }

echo "=================================="
echo "OpenShift UPI Preflight Checks"
echo "=================================="
echo ""

# Check 1: Config file exists
echo "1. Checking configuration file..."
if [[ -f "config.env" ]]; then
    log_ok "config.env found"
    source config.env
else
    log_error "config.env not found!"
    log_info "Copy config.env.example to config.env and fill in your values"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check 2: Required tools
echo "2. Checking required tools..."
for tool in aws terraform jq wget curl base64; do
    if command -v $tool &> /dev/null; then
        log_ok "$tool installed"
    else
        log_error "$tool not found!"
    fi
done
echo ""

# Check 3: AWS credentials
echo "3. Checking AWS credentials..."
if aws sts get-caller-identity &>/dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    log_ok "AWS credentials valid (Account: $ACCOUNT_ID)"
else
    log_error "AWS credentials not configured!"
    log_info "Run: aws configure"
fi
echo ""

# Check 4: AWS permissions
echo "4. Checking AWS permissions..."
if aws ec2 describe-vpcs --region ${AWS_REGION:-us-east-1} &>/dev/null; then
    log_ok "EC2 permissions OK"
else
    log_error "EC2 permissions insufficient"
fi

if aws s3 ls &>/dev/null; then
    log_ok "S3 permissions OK"
else
    log_error "S3 permissions insufficient"
fi

if aws route53 list-hosted-zones &>/dev/null; then
    log_ok "Route53 permissions OK"
else
    log_error "Route53 permissions insufficient"
fi
echo ""

# Check 5: Required variables
echo "5. Checking required variables..."
REQUIRED_VARS=(
    "CLUSTER_NAME"
    "BASE_DOMAIN"
    "AWS_REGION"
    "RHCOS_AMI"
    "PULL_SECRET_FILE"
    "SSH_KEY_PATH"
    "SSH_KEY_NAME"
    "VPC_CIDR"
    "ROUTE53_ZONE_ID"
    "AVAILABILITY_ZONES"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [[ -n "${!var:-}" ]]; then
        log_ok "$var is set"
    else
        log_error "$var is not set!"
    fi
done
echo ""

# Check 6: Pull secret file
echo "6. Checking pull secret..."
if [[ -f "${PULL_SECRET_FILE:-}" ]]; then
    if jq empty "$PULL_SECRET_FILE" 2>/dev/null; then
        log_ok "Pull secret is valid JSON"
    else
        log_error "Pull secret is not valid JSON"
    fi
else
    log_error "Pull secret file not found: ${PULL_SECRET_FILE:-not set}"
fi
echo ""

# Check 7: SSH keys
echo "7. Checking SSH keys..."
if [[ -f "${SSH_KEY_PATH:-}" ]]; then
    log_ok "SSH private key found"
    
    # Check permissions
    PERMS=$(stat -c %a "${SSH_KEY_PATH}" 2>/dev/null || stat -f %A "${SSH_KEY_PATH}" 2>/dev/null)
    if [[ "$PERMS" == "600" ]] || [[ "$PERMS" == "400" ]]; then
        log_ok "SSH key permissions correct ($PERMS)"
    else
        log_warn "SSH key permissions should be 600 (current: $PERMS)"
        log_info "Run: chmod 600 ${SSH_KEY_PATH}"
    fi
else
    log_error "SSH private key not found: ${SSH_KEY_PATH:-not set}"
fi

if [[ -f "${SSH_KEY_PATH:-}.pub" ]]; then
    log_ok "SSH public key found"
else
    log_error "SSH public key not found: ${SSH_KEY_PATH:-not set}.pub"
fi
echo ""

# Check 8: AWS SSH key pair
echo "8. Checking AWS EC2 key pair..."
if aws ec2 describe-key-pairs --key-names "${SSH_KEY_NAME:-}" --region "${AWS_REGION:-us-east-1}" &>/dev/null; then
    log_ok "AWS key pair '${SSH_KEY_NAME}' exists"
else
    log_error "AWS key pair '${SSH_KEY_NAME:-not set}' not found!"
    log_info "Create it or import your public key to AWS EC2"
fi
echo ""

# Check 9: Route53 hosted zone
echo "9. Checking Route53 hosted zone..."
if [[ -n "${ROUTE53_ZONE_ID:-}" ]]; then
    ZONE_NAME=$(aws route53 get-hosted-zone --id "${ROUTE53_ZONE_ID}" --query 'HostedZone.Name' --output text 2>/dev/null | sed 's/\.$//')
    if [[ -n "$ZONE_NAME" ]]; then
        log_ok "Route53 zone exists: $ZONE_NAME"
        
        if [[ "$ZONE_NAME" == "${BASE_DOMAIN:-}" ]]; then
            log_ok "Zone name matches BASE_DOMAIN"
        else
            log_warn "Zone name ($ZONE_NAME) doesn't match BASE_DOMAIN (${BASE_DOMAIN:-not set})"
        fi
    else
        log_error "Route53 zone not found: ${ROUTE53_ZONE_ID}"
    fi
else
    log_error "ROUTE53_ZONE_ID not set"
fi
echo ""

# Check 10: RHCOS AMI
echo "10. Checking RHCOS AMI..."
if aws ec2 describe-images --image-ids "${RHCOS_AMI:-}" --region "${AWS_REGION:-us-east-1}" &>/dev/null; then
    log_ok "RHCOS AMI exists in ${AWS_REGION}"
else
    log_error "RHCOS AMI not found: ${RHCOS_AMI:-not set}"
    log_info "Get AMI from: https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/"
fi
echo ""

# Check 11: Disk space
echo "11. Checking disk space..."
AVAILABLE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [[ $AVAILABLE -gt 50 ]]; then
    log_ok "Sufficient disk space (${AVAILABLE}GB available)"
else
    log_warn "Low disk space (${AVAILABLE}GB available, recommend 50GB+)"
fi
echo ""

# Summary
echo "=================================="
echo "Preflight Check Summary"
echo "=================================="
if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}All checks passed! ✓${NC}"
    echo "You're ready to run the installation."
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}Checks completed with $WARNINGS warning(s)${NC}"
    echo "You can proceed, but review warnings above."
    exit 0
else
    echo -e "${RED}Checks failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo "Please fix errors before proceeding with installation."
    exit 1
fi
