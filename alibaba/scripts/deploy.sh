#!/bin/bash
# deploy.sh - Production deployment script

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-production}"
TERRAFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${TERRAFORM_DIR}/deploy-${ENVIRONMENT}.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        error_exit "Terraform is not installed"
    fi
    
    # Check if required files exist
    if [[ ! -f "${TERRAFORM_DIR}/${ENVIRONMENT}.tfvars" ]]; then
        error_exit "Variables file ${ENVIRONMENT}.tfvars not found"
    fi
    
    # Check if Alibaba Cloud credentials are set
    if [[ -z "${ALICLOUD_ACCESS_KEY:-}" || -z "${ALICLOUD_SECRET_KEY:-}" ]]; then
        error_exit "Alibaba Cloud credentials not set. Set ALICLOUD_ACCESS_KEY and ALICLOUD_SECRET_KEY environment variables"
    fi
    
    log "Prerequisites check passed"
}

# Initialize Terraform
init_terraform() {
    log "Initializing Terraform..."
    
    cd "${TERRAFORM_DIR}"
    
    terraform init
    terraform workspace select "${ENVIRONMENT}" || terraform workspace new "${ENVIRONMENT}"
    
    log "Terraform initialized for environment: ${ENVIRONMENT}"
}

# Validate configuration
validate_config() {
    log "Validating Terraform configuration..."
    
    terraform validate
    terraform fmt -check=true
    
    log "Configuration validation passed"
}

# Plan deployment
plan_deployment() {
    log "Planning deployment..."
    
    terraform plan \
        -var-file="${ENVIRONMENT}.tfvars" \
        -out="${ENVIRONMENT}.tfplan"
    
    log "Deployment plan created: ${ENVIRONMENT}.tfplan"
}

# Apply deployment
apply_deployment() {
    log "Applying deployment..."
    
    terraform apply "${ENVIRONMENT}.tfplan"
    
    log "Deployment completed successfully"
}

# Show outputs
show_outputs() {
    log "Deployment outputs:"
    terraform output -json | tee "${ENVIRONMENT}-outputs.json"
    
    # Show SSH commands
    log "SSH connection commands:"
    terraform output ssh_connection_commands
}

# Main deployment workflow
main() {
    log "Starting deployment for environment: ${ENVIRONMENT}"
    
    check_prerequisites
    init_terraform
    validate_config
    plan_deployment
    
    # Ask for confirmation in production
    if [[ "${ENVIRONMENT}" == "production" ]]; then
        echo "This will deploy to PRODUCTION environment!"
        read -p "Are you sure you want to continue? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    apply_deployment
    show_outputs
    
    log "Deployment completed successfully for environment: ${ENVIRONMENT}"
    log "Log file: ${LOG_FILE}"
}

# Handle script arguments
case "${1:-}" in
    "production"|"staging"|"development")
        main
        ;;
    "destroy")
        log "Planning destruction for environment: ${2:-production}"
        terraform workspace select "${2:-production}"
        terraform plan -destroy -var-file="${2:-production}.tfvars" -out="destroy.tfplan"
        echo "Review the destroy plan above"
        read -p "Type 'yes' to proceed with destruction: " -r
        if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            terraform apply "destroy.tfplan"
            log "Resources destroyed"
        else
            log "Destruction cancelled"
        fi
        ;;
    *)
        echo "Usage: $0 {production|staging|development|destroy [environment]}"
        echo ""
        echo "Examples:"
        echo "  $0 production                    # Deploy to production"
        echo "  $0 staging                      # Deploy to staging"  
        echo "  $0 destroy production           # Destroy production environment"
        exit 1
        ;;
esac