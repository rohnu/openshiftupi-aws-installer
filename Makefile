.PHONY: help install destroy clean check approve-csrs credentials

# Configuration
WORK_DIR := ./openshift-install
TERRAFORM_DIR := ./terraform
CONFIG_FILE := config.env

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

help:  ## Show this help message
	@echo "OpenShift UPI Automation - Available Commands"
	@echo "=============================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

check-config:  ## Check if configuration file exists
	@if [ ! -f $(CONFIG_FILE) ]; then \
		echo "$(YELLOW)[WARN]$(NC) Configuration file not found!"; \
		echo "Please create $(CONFIG_FILE) from config.env.example"; \
		exit 1; \
	fi

prerequisites:  ## Install required tools
	@echo "$(GREEN)[INFO]$(NC) Installing prerequisites..."
	@./install-openshift-upi.sh install_prerequisites

install: check-config  ## Install OpenShift cluster (full automation)
	@echo "$(GREEN)[INFO]$(NC) Starting OpenShift installation..."
	@chmod +x install-openshift-upi.sh
	@./install-openshift-upi.sh

install-config: check-config  ## Generate install-config.yaml only
	@echo "$(GREEN)[INFO]$(NC) Generating install-config.yaml..."
	@mkdir -p $(WORK_DIR)
	@source $(CONFIG_FILE) && ./install-openshift-upi.sh generate_install_config

ignition: install-config  ## Generate ignition configs only
	@echo "$(GREEN)[INFO]$(NC) Generating ignition configs..."
	@source $(CONFIG_FILE) && ./install-openshift-upi.sh generate_ignition_configs

terraform-init:  ## Initialize Terraform
	@echo "$(GREEN)[INFO]$(NC) Initializing Terraform..."
	@cd $(TERRAFORM_DIR) && terraform init

terraform-plan:  ## Plan Terraform changes
	@echo "$(GREEN)[INFO]$(NC) Planning Terraform changes..."
	@cd $(TERRAFORM_DIR) && terraform plan

terraform-apply:  ## Apply Terraform changes
	@echo "$(GREEN)[INFO]$(NC) Applying Terraform changes..."
	@cd $(TERRAFORM_DIR) && terraform apply

check:  ## Check cluster health
	@echo "$(GREEN)[INFO]$(NC) Checking cluster health..."
	@chmod +x cluster-ops.sh
	@./cluster-ops.sh check-health

approve-csrs:  ## Approve pending CSRs
	@echo "$(GREEN)[INFO]$(NC) Approving CSRs..."
	@chmod +x cluster-ops.sh
	@./cluster-ops.sh approve-csrs

credentials:  ## Display cluster credentials
	@chmod +x cluster-ops.sh
	@./cluster-ops.sh get-credentials

console:  ## Open OpenShift console in browser
	@export KUBECONFIG=$(WORK_DIR)/auth/kubeconfig && \
	xdg-open `oc whoami --show-console` 2>/dev/null || \
	open `oc whoami --show-console` 2>/dev/null || \
	echo "Console URL: `oc whoami --show-console`"

watch-operators:  ## Watch cluster operators status
	@export KUBECONFIG=$(WORK_DIR)/auth/kubeconfig && \
	watch -n 5 oc get co

watch-nodes:  ## Watch nodes status
	@export KUBECONFIG=$(WORK_DIR)/auth/kubeconfig && \
	watch -n 5 oc get nodes

watch-pods:  ## Watch all pods
	@export KUBECONFIG=$(WORK_DIR)/auth/kubeconfig && \
	watch -n 5 'oc get pods --all-namespaces | grep -vE "Running|Completed"'

logs:  ## Tail installation logs
	@tail -f .openshift_install.log

destroy-bootstrap:  ## Destroy bootstrap node only
	@echo "$(YELLOW)[WARN]$(NC) Destroying bootstrap node..."
	@cd $(TERRAFORM_DIR) && terraform destroy -target=module.bootstrap -auto-approve

destroy: check-config  ## Destroy entire cluster
	@echo "$(YELLOW)[WARN]$(NC) This will destroy the entire cluster!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	@chmod +x cluster-ops.sh
	@./cluster-ops.sh destroy

clean:  ## Clean up local files
	@echo "$(GREEN)[INFO]$(NC) Cleaning up local files..."
	@rm -rf $(WORK_DIR)
	@rm -rf $(TERRAFORM_DIR)/.terraform
	@rm -rf $(TERRAFORM_DIR)/terraform.tfstate*
	@rm -f $(TERRAFORM_DIR)/tfplan
	@rm -f .openshift_install.log

backup-etcd:  ## Backup ETCD
	@chmod +x cluster-ops.sh
	@./cluster-ops.sh backup-etcd

shutdown:  ## Shutdown cluster
	@chmod +x cluster-ops.sh
	@./cluster-ops.sh shutdown

start:  ## Start cluster
	@chmod +x cluster-ops.sh
	@./cluster-ops.sh start

scale-workers:  ## Scale worker nodes (use: make scale-workers COUNT=5)
	@if [ -z "$(COUNT)" ]; then \
		echo "Usage: make scale-workers COUNT=<number>"; \
		exit 1; \
	fi
	@chmod +x cluster-ops.sh
	@./cluster-ops.sh scale-workers $(COUNT)

upgrade:  ## Upgrade cluster (use: make upgrade VERSION=4.17.1)
	@chmod +x cluster-ops.sh
	@./cluster-ops.sh upgrade $(VERSION)

validate:  ## Validate prerequisites and configuration
	@echo "$(GREEN)[INFO]$(NC) Validating environment..."
	@command -v aws >/dev/null 2>&1 || { echo "aws CLI not found"; exit 1; }
	@command -v terraform >/dev/null 2>&1 || { echo "terraform not found"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "jq not found"; exit 1; }
	@[ -f $(CONFIG_FILE) ] || { echo "$(CONFIG_FILE) not found"; exit 1; }
	@echo "$(GREEN)[INFO]$(NC) Validation passed!"

version-list:  ## List available OpenShift versions
	@chmod +x openshift-version-helper.sh
	@./openshift-version-helper.sh list

version-select:  ## Interactive OpenShift version selector
	@chmod +x openshift-version-helper.sh
	@./openshift-version-helper.sh select

version-details:  ## Show details for OpenShift version (use: make version-details VERSION=stable-4.17)
	@chmod +x openshift-version-helper.sh
	@./openshift-version-helper.sh details $(VERSION)

version-ami:  ## Get RHCOS AMI for version and region (use: make version-ami VERSION=stable-4.17 REGION=us-east-1)
	@chmod +x openshift-version-helper.sh
	@./openshift-version-helper.sh ami $(VERSION) $(REGION)

test-aws:  ## Test AWS credentials
	@echo "$(GREEN)[INFO]$(NC) Testing AWS credentials..."
	@aws sts get-caller-identity
	@echo "$(GREEN)[INFO]$(NC) AWS credentials are valid!"

quick-install: check-config prerequisites install  ## Quick install (all steps)

.DEFAULT_GOAL := help
