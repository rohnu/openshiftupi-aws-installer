#!/bin/bash

###############################################################################
# OpenShift Version Helper Script
# Lists available OpenShift versions and helps select the right one
###############################################################################

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

###############################################################################
# List available versions
###############################################################################
list_versions() {
    log_info "Fetching available OpenShift versions..."
    echo ""
    
    # Get versions from mirror
    curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/ | \
        grep -oP 'href="\K[0-9]+\.[0-9]+\.[0-9]+(?=/)' | \
        sort -V | \
        tail -20
    
    echo ""
    log_info "Stable channels:"
    echo "  - stable-4.17 (recommended for production)"
    echo "  - stable-4.16"
    echo "  - stable-4.15"
    echo ""
    log_info "Latest channels:"
    echo "  - latest-4.17 (latest in 4.17)"
    echo "  - latest-4.16"
    echo ""
}

###############################################################################
# Show version details
###############################################################################
show_version_details() {
    local VERSION=$1
    
    log_info "Checking version: $VERSION"
    echo ""
    
    # Determine URL based on version format
    if [[ "$VERSION" == stable-* ]] || [[ "$VERSION" == latest-* ]]; then
        BASE_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${VERSION}"
    else
        BASE_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${VERSION}"
    fi
    
    # Check if version exists
    if curl -s -f -I "$BASE_URL/release.txt" > /dev/null 2>&1; then
        log_info "Version found! Details:"
        echo ""
        curl -s "$BASE_URL/release.txt" | head -20
        echo ""
        
        log_info "Available downloads:"
        echo "  - OpenShift Installer: ${BASE_URL}/openshift-install-linux.tar.gz"
        echo "  - OpenShift Client (oc): ${BASE_URL}/openshift-client-linux.tar.gz"
        echo ""
        
        # Get RHCOS information
        log_info "Checking RHCOS images..."
        if [[ "$VERSION" == stable-* ]] || [[ "$VERSION" == latest-* ]]; then
            RHCOS_VERSION=$(echo "$VERSION" | sed 's/stable-//' | sed 's/latest-//')
        else
            RHCOS_VERSION=$(echo "$VERSION" | cut -d. -f1-2)
        fi
        
        echo "  RHCOS images: https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${RHCOS_VERSION}/"
        echo ""
    else
        log_warn "Version $VERSION not found!"
        echo "Please check: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
        return 1
    fi
}

###############################################################################
# Get RHCOS AMI for region
###############################################################################
get_rhcos_ami() {
    local VERSION=$1
    local REGION=${2:-us-east-1}
    
    log_info "Finding RHCOS AMI for OpenShift $VERSION in region $REGION"
    echo ""
    
    # Determine RHCOS version
    if [[ "$VERSION" == stable-* ]] || [[ "$VERSION" == latest-* ]]; then
        RHCOS_VERSION=$(echo "$VERSION" | sed 's/stable-//' | sed 's/latest-//')
    else
        RHCOS_VERSION=$(echo "$VERSION" | cut -d. -f1-2)
    fi
    
    # Get latest RHCOS for that version
    RHCOS_URL="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${RHCOS_VERSION}/latest/"
    
    log_info "Checking RHCOS images at: $RHCOS_URL"
    echo ""
    
    # Try to get AWS AMI info
    if curl -s -f "${RHCOS_URL}rhcos-aws.x86_64.json" > /dev/null 2>&1; then
        log_info "RHCOS AMI for $REGION:"
        AMI_ID=$(curl -s "${RHCOS_URL}rhcos-aws.x86_64.json" | jq -r ".amis[\"${REGION}\"].hvm")
        
        if [[ "$AMI_ID" != "null" ]] && [[ -n "$AMI_ID" ]]; then
            echo -e "  ${BLUE}${AMI_ID}${NC}"
            echo ""
            log_info "Add this to your config.env:"
            echo "  RHCOS_AMI=\"${AMI_ID}\""
        else
            log_warn "No AMI found for region $REGION"
            log_info "Available regions:"
            curl -s "${RHCOS_URL}rhcos-aws.x86_64.json" | jq -r '.amis | keys[]' | sort
        fi
    else
        log_warn "Could not fetch RHCOS AMI information"
        log_info "Please check manually at: $RHCOS_URL"
    fi
    echo ""
}

###############################################################################
# Validate version compatibility
###############################################################################
validate_version() {
    local VERSION=$1
    
    log_info "Validating version: $VERSION"
    echo ""
    
    # Check format
    if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_info "Format: Specific version (e.g., 4.17.1)"
    elif [[ "$VERSION" =~ ^stable-[0-9]+\.[0-9]+$ ]]; then
        log_info "Format: Stable channel (recommended for production)"
    elif [[ "$VERSION" =~ ^latest-[0-9]+\.[0-9]+$ ]]; then
        log_info "Format: Latest channel (newest features)"
    elif [[ "$VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
        log_warn "Format looks like major.minor only"
        log_info "Recommended: Use 'stable-${VERSION}' for production"
        return 1
    else
        log_warn "Invalid version format!"
        log_info "Valid formats:"
        echo "  - Specific: 4.17.1, 4.16.5"
        echo "  - Stable channel: stable-4.17, stable-4.16"
        echo "  - Latest channel: latest-4.17, latest-4.16"
        return 1
    fi
    
    # Check if version exists
    show_version_details "$VERSION"
}

###############################################################################
# Interactive version selector
###############################################################################
interactive_select() {
    echo ""
    log_info "=== OpenShift Version Selector ==="
    echo ""
    
    echo "Select installation type:"
    echo "  1) Production (stable channel - recommended)"
    echo "  2) Latest features (latest channel)"
    echo "  3) Specific version"
    echo ""
    read -p "Enter choice [1-3]: " choice
    
    case $choice in
        1)
            echo ""
            echo "Available stable versions:"
            echo "  1) stable-4.17 (OpenShift 4.17 - latest stable)"
            echo "  2) stable-4.16"
            echo "  3) stable-4.15"
            echo ""
            read -p "Select version [1-3]: " ver_choice
            
            case $ver_choice in
                1) VERSION="stable-4.17" ;;
                2) VERSION="stable-4.16" ;;
                3) VERSION="stable-4.15" ;;
                *) log_warn "Invalid choice"; return 1 ;;
            esac
            ;;
        2)
            echo ""
            echo "Available latest versions:"
            echo "  1) latest-4.17"
            echo "  2) latest-4.16"
            echo ""
            read -p "Select version [1-2]: " ver_choice
            
            case $ver_choice in
                1) VERSION="latest-4.17" ;;
                2) VERSION="latest-4.16" ;;
                *) log_warn "Invalid choice"; return 1 ;;
            esac
            ;;
        3)
            echo ""
            list_versions | tail -10
            echo ""
            read -p "Enter specific version (e.g., 4.17.1): " VERSION
            ;;
        *)
            log_warn "Invalid choice"
            return 1
            ;;
    esac
    
    echo ""
    log_info "Selected version: $VERSION"
    echo ""
    
    # Validate and show details
    validate_version "$VERSION"
    
    echo ""
    read -p "Get RHCOS AMI for your region? [y/N]: " get_ami
    if [[ "$get_ami" =~ ^[Yy]$ ]]; then
        read -p "Enter AWS region (default: us-east-1): " region
        region=${region:-us-east-1}
        get_rhcos_ami "$VERSION" "$region"
    fi
    
    echo ""
    log_info "Configuration:"
    echo ""
    echo "Add to your config.env:"
    echo "  OPENSHIFT_VERSION=\"${VERSION}\""
    echo ""
}

###############################################################################
# Main menu
###############################################################################
show_menu() {
    echo ""
    echo "OpenShift Version Helper"
    echo "========================"
    echo "1. List available versions"
    echo "2. Show version details"
    echo "3. Get RHCOS AMI for region"
    echo "4. Validate version"
    echo "5. Interactive version selector"
    echo "0. Exit"
    echo ""
}

###############################################################################
# Main
###############################################################################
main() {
    if [[ $# -eq 0 ]]; then
        # Interactive mode
        while true; do
            show_menu
            read -p "Select option: " option
            
            case $option in
                1) list_versions ;;
                2)
                    read -p "Enter version to check: " version
                    show_version_details "$version"
                    ;;
                3)
                    read -p "Enter OpenShift version: " version
                    read -p "Enter AWS region: " region
                    get_rhcos_ami "$version" "$region"
                    ;;
                4)
                    read -p "Enter version to validate: " version
                    validate_version "$version"
                    ;;
                5) interactive_select ;;
                0) exit 0 ;;
                *) log_warn "Invalid option" ;;
            esac
            
            read -p "Press enter to continue..."
        done
    else
        # Command line mode
        case $1 in
            list)
                list_versions
                ;;
            details)
                show_version_details "${2:-stable-4.17}"
                ;;
            ami)
                get_rhcos_ami "${2:-stable-4.17}" "${3:-us-east-1}"
                ;;
            validate)
                validate_version "${2:-stable-4.17}"
                ;;
            select)
                interactive_select
                ;;
            *)
                echo "Usage: $0 {list|details|ami|validate|select} [version] [region]"
                echo ""
                echo "Commands:"
                echo "  list              - List available versions"
                echo "  details <version> - Show version details"
                echo "  ami <version> <region> - Get RHCOS AMI for region"
                echo "  validate <version> - Validate version"
                echo "  select            - Interactive selector"
                echo ""
                echo "Examples:"
                echo "  $0 list"
                echo "  $0 details stable-4.17"
                echo "  $0 ami stable-4.17 us-east-1"
                echo "  $0 validate 4.17.1"
                echo "  $0 select"
                exit 1
                ;;
        esac
    fi
}

main "$@"
