.PHONY: help init plan apply destroy validate fmt lint clean

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	terraform init
	terraform workspace select production || terraform workspace new production

validate: ## Validate Terraform configuration
	terraform validate
	terraform fmt -check

fmt: ## Format Terraform files
	terraform fmt -recursive

plan: validate ## Create execution plan
	terraform plan -var-file="terraform.tfvars" -out=tfplan

apply: ## Apply the Terraform plan
	terraform apply tfplan

plan-destroy: ## Plan destruction of resources
	terraform plan -destroy -var-file="terraform.tfvars" -out=tfplan-destroy

destroy: ## Destroy infrastructure (with confirmation)
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	terraform apply tfplan-destroy

output: ## Show Terraform outputs
	terraform output

lint: ## Lint Terraform files (requires tflint)
	tflint --init
	tflint

clean: ## Clean temporary files
	rm -f tfplan tfplan-destroy
	rm -rf .terraform/providers

refresh: ## Refresh Terraform state
	terraform refresh -var-file="terraform.tfvars"

show: ## Show current state
	terraform show

# Development targets
dev-plan: ## Plan for development environment
	terraform workspace select development || terraform workspace new development
	terraform plan -var-file="dev.tfvars"

dev-apply: ## Apply development environment
	terraform workspace select development
	terraform apply -var-file="dev.tfvars" -auto-approve