#!/bin/bash

# Production-Ready Alibaba Cloud Bash Scripts
# Requires: Alibaba Cloud CLI (aliyun) installed and configured

set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'       # Secure Internal Field Separator

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/aliyun-operations.log"
readonly CONFIG_FILE="${SCRIPT_DIR}/aliyun-config.json"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    # Check if aliyun CLI is installed
    if ! command -v aliyun &> /dev/null; then
        error_exit "Alibaba Cloud CLI (aliyun) is not installed. Install with: curl -fsSL https://aliyuncli.alicdn.com/install.sh | bash"
    fi
    
    # Check if CLI is configured
    if ! aliyun configure list &> /dev/null; then
        error_exit "Alibaba Cloud CLI is not configured. Run: aliyun configure"
    fi
    
    # Check if jq is installed for JSON parsing
    if ! command -v jq &> /dev/null; then
        error_exit "jq is not installed. Please install jq for JSON parsing."
    fi
    
    log "All dependencies satisfied"
}

# Load configuration from JSON file
load_config() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log "Creating default configuration file: ${CONFIG_FILE}"
        cat > "${CONFIG_FILE}" << 'EOF'
{
    "region": "us-west-1",
    "vpc_cidr": "10.0.0.0/16",
    "vswitch_cidr": "10.0.1.0/24",
    "instance_type": "ecs.t6-c1m1.large",
    "image_id": "ubuntu_20_04_x64_20G_alibase_20210420.vhd",
    "security_group_name": "production-sg",
    "key_pair_name": "production-keypair",
    "tags": {
        "Environment": "Production",
        "Project": "WebApp",
        "Owner": "DevOps"
    }
}
EOF
    fi
    
    # Validate JSON
    if ! jq empty "${CONFIG_FILE}" 2>/dev/null; then
        error_exit "Invalid JSON in configuration file: ${CONFIG_FILE}"
    fi
    
    log "Configuration loaded from ${CONFIG_FILE}"
}

# Create VPC with error handling
create_vpc() {
    local vpc_name="${1:-production-vpc}"
    local cidr_block
    cidr_block=$(jq -r '.vpc_cidr' "${CONFIG_FILE}")
    
    log "Creating VPC: ${vpc_name} with CIDR: ${cidr_block}"
    
    local vpc_id
    vpc_id=$(aliyun ecs CreateVpc \
        --VpcName "${vpc_name}" \
        --CidrBlock "${cidr_block}" \
        --Description "Production VPC created by automation" \
        --output json | jq -r '.VpcId')
    
    if [[ -z "${vpc_id}" || "${vpc_id}" == "null" ]]; then
        error_exit "Failed to create VPC"
    fi
    
    log "VPC created successfully: ${vpc_id}"
    
    # Wait for VPC to be available
    log "Waiting for VPC to become available..."
    local max_attempts=30
    local attempt=0
    
    while [[ ${attempt} -lt ${max_attempts} ]]; do
        local status
        status=$(aliyun ecs DescribeVpcs \
            --VpcIds "[\"${vpc_id}\"]" \
            --output json | jq -r '.Vpcs.Vpc[0].Status')
        
        if [[ "${status}" == "Available" ]]; then
            log "VPC is now available"
            break
        fi
        
        ((attempt++))
        log "Attempt ${attempt}/${max_attempts}: VPC status is ${status}, waiting..."
        sleep 10
    done
    
    if [[ ${attempt} -eq ${max_attempts} ]]; then
        error_exit "VPC did not become available within expected time"
    fi
    
    echo "${vpc_id}"
}

# Create VSwitch (subnet)
create_vswitch() {
    local vpc_id="${1}"
    local zone_id="${2}"
    local vswitch_name="${3:-production-vswitch}"
    local cidr_block
    cidr_block=$(jq -r '.vswitch_cidr' "${CONFIG_FILE}")
    
    log "Creating VSwitch: ${vswitch_name} in zone: ${zone_id}"
    
    local vswitch_id
    vswitch_id=$(aliyun ecs CreateVSwitch \
        --VpcId "${vpc_id}" \
        --ZoneId "${zone_id}" \
        --VSwitchName "${vswitch_name}" \
        --CidrBlock "${cidr_block}" \
        --Description "Production VSwitch" \
        --output json | jq -r '.VSwitchId')
    
    if [[ -z "${vswitch_id}" || "${vswitch_id}" == "null" ]]; then
        error_exit "Failed to create VSwitch"
    fi
    
    log "VSwitch created successfully: ${vswitch_id}"
    echo "${vswitch_id}"
}

# Create Security Group with comprehensive rules
create_security_group() {
    local vpc_id="${1}"
    local sg_name
    sg_name=$(jq -r '.security_group_name' "${CONFIG_FILE}")
    
    log "Creating Security Group: ${sg_name}"
    
    local sg_id
    sg_id=$(aliyun ecs CreateSecurityGroup \
        --VpcId "${vpc_id}" \
        --SecurityGroupName "${sg_name}" \
        --Description "Production Security Group" \
        --SecurityGroupType "normal" \
        --output json | jq -r '.SecurityGroupId')
    
    if [[ -z "${sg_id}" || "${sg_id}" == "null" ]]; then
        error_exit "Failed to create Security Group"
    fi
    
    log "Security Group created successfully: ${sg_id}"
    
    # Add security group rules
    log "Adding security group rules..."
    
    # SSH access (22)
    aliyun ecs AuthorizeSecurityGroup \
        --SecurityGroupId "${sg_id}" \
        --IpProtocol "tcp" \
        --PortRange "22/22" \
        --SourceCidrIp "0.0.0.0/0" \
        --Description "SSH access" || log "WARNING: Failed to add SSH rule"
    
    # HTTP (80)
    aliyun ecs AuthorizeSecurityGroup \
        --SecurityGroupId "${sg_id}" \
        --IpProtocol "tcp" \
        --PortRange "80/80" \
        --SourceCidrIp "0.0.0.0/0" \
        --Description "HTTP access" || log "WARNING: Failed to add HTTP rule"
    
    # HTTPS (443)
    aliyun ecs AuthorizeSecurityGroup \
        --SecurityGroupId "${sg_id}" \
        --IpProtocol "tcp" \
        --PortRange "443/443" \
        --SourceCidrIp "0.0.0.0/0" \
        --Description "HTTPS access" || log "WARNING: Failed to add HTTPS rule"
    
    # Internal communication
    aliyun ecs AuthorizeSecurityGroup \
        --SecurityGroupId "${sg_id}" \
        --IpProtocol "all" \
        --SourceGroupId "${sg_id}" \
        --Description "Internal communication" || log "WARNING: Failed to add internal communication rule"
    
    echo "${sg_id}"
}

# Create ECS instance with comprehensive configuration
create_ecs_instance() {
    local vswitch_id="${1}"
    local security_group_id="${2}"
    local instance_name="${3:-production-instance}"
    
    local instance_type image_id key_pair_name
    instance_type=$(jq -r '.instance_type' "${CONFIG_FILE}")
    image_id=$(jq -r '.image_id' "${CONFIG_FILE}")
    key_pair_name=$(jq -r '.key_pair_name' "${CONFIG_FILE}")
    
    log "Creating ECS instance: ${instance_name}"
    log "Instance type: ${instance_type}, Image: ${image_id}"
    
    # Create the instance
    local instance_id
    instance_id=$(aliyun ecs CreateInstance \
        --InstanceName "${instance_name}" \
        --ImageId "${image_id}" \
        --InstanceType "${instance_type}" \
        --VSwitchId "${vswitch_id}" \
        --SecurityGroupId "${security_group_id}" \
        --KeyPairName "${key_pair_name}" \
        --InternetMaxBandwidthOut 100 \
        --InternetChargeType "PayByTraffic" \
        --SystemDiskCategory "cloud_ssd" \
        --SystemDiskSize 40 \
        --Description "Production ECS instance" \
        --output json | jq -r '.InstanceId')
    
    if [[ -z "${instance_id}" || "${instance_id}" == "null" ]]; then
        error_exit "Failed to create ECS instance"
    fi
    
    log "ECS instance created successfully: ${instance_id}"
    
    # Start the instance
    log "Starting ECS instance..."
    aliyun ecs StartInstance --InstanceId "${instance_id}" || error_exit "Failed to start instance"
    
    # Wait for instance to be running
    local max_attempts=60
    local attempt=0
    
    while [[ ${attempt} -lt ${max_attempts} ]]; do
        local status
        status=$(aliyun ecs DescribeInstances \
            --InstanceIds "[\"${instance_id}\"]" \
            --output json | jq -r '.Instances.Instance[0].Status')
        
        if [[ "${status}" == "Running" ]]; then
            log "Instance is now running"
            break
        fi
        
        ((attempt++))
        log "Attempt ${attempt}/${max_attempts}: Instance status is ${status}, waiting..."
        sleep 10
    done
    
    if [[ ${attempt} -eq ${max_attempts} ]]; then
        error_exit "Instance did not start within expected time"
    fi
    
    # Get instance public IP
    local public_ip
    public_ip=$(aliyun ecs DescribeInstances \
        --InstanceIds "[\"${instance_id}\"]" \
        --output json | jq -r '.Instances.Instance[0].PublicIpAddress.IpAddress[0]')
    
    log "Instance public IP: ${public_ip}"
    
    # Apply tags
    apply_tags "${instance_id}" "Instance"
    
    echo "${instance_id}"
}

# Apply tags to resources
apply_tags() {
    local resource_id="${1}"
    local resource_type="${2}"
    
    log "Applying tags to ${resource_type}: ${resource_id}"
    
    # Read tags from config
    local tags_json
    tags_json=$(jq -c '.tags' "${CONFIG_FILE}")
    
    # Convert to tag array format for Alibaba Cloud
    local tag_args=()
    while IFS="=" read -r key value; do
        # Remove quotes from jq output
        key=$(echo "${key}" | tr -d '"')
        value=$(echo "${value}" | tr -d '"')
        tag_args+=(--Tag.${#tag_args[@]}.Key="${key}" --Tag.${#tag_args[@]}.Value="${value}")
    done < <(echo "${tags_json}" | jq -r 'to_entries[] | "\(.key)=\(.value)"')
    
    if [[ ${#tag_args[@]} -gt 0 ]]; then
        aliyun ecs TagResources \
            --ResourceType "${resource_type}" \
            --ResourceId.1 "${resource_id}" \
            "${tag_args[@]}" || log "WARNING: Failed to apply tags to ${resource_id}"
    fi
}

# Get available zones
get_available_zones() {
    local region
    region=$(jq -r '.region' "${CONFIG_FILE}")
    
    log "Getting available zones in region: ${region}"
    
    local zones
    zones=$(aliyun ecs DescribeZones \
        --RegionId "${region}" \
        --output json | jq -r '.Zones.Zone[0].ZoneId')
    
    if [[ -z "${zones}" || "${zones}" == "null" ]]; then
        error_exit "No zones found in region: ${region}"
    fi
    
    log "Using zone: ${zones}"
    echo "${zones}"
}

# Cleanup function for error cases
cleanup_resources() {
    local vpc_id="${1:-}"
    
    if [[ -n "${vpc_id}" ]]; then
        log "Cleaning up resources for VPC: ${vpc_id}"
        
        # Note: In production, you might want more sophisticated cleanup
        # This is a basic example
        log "Manual cleanup may be required for VPC: ${vpc_id}"
    fi
}

# Main deployment function
deploy_infrastructure() {
    log "Starting infrastructure deployment..."
    
    # Get available zone
    local zone_id
    zone_id=$(get_available_zones)
    
    # Create VPC
    local vpc_id
    vpc_id=$(create_vpc "production-vpc")
    
    # Set up cleanup on error
    trap "cleanup_resources ${vpc_id}" ERR
    
    # Create VSwitch
    local vswitch_id
    vswitch_id=$(create_vswitch "${vpc_id}" "${zone_id}" "production-vswitch")
    
    # Create Security Group
    local security_group_id
    security_group_id=$(create_security_group "${vpc_id}")
    
    # Create ECS Instance
    local instance_id
    instance_id=$(create_ecs_instance "${vswitch_id}" "${security_group_id}" "production-web-server")
    
    # Output summary
    log "Infrastructure deployment completed successfully!"
    log "Resources created:"
    log "  VPC ID: ${vpc_id}"
    log "  VSwitch ID: ${vswitch_id}"
    log "  Security Group ID: ${security_group_id}"
    log "  Instance ID: ${instance_id}"
    
    # Save resource IDs for later use
    cat > "${SCRIPT_DIR}/deployed-resources.json" << EOF
{
    "deployment_date": "$(date -Iseconds)",
    "vpc_id": "${vpc_id}",
    "vswitch_id": "${vswitch_id}",
    "security_group_id": "${security_group_id}",
    "instance_id": "${instance_id}",
    "zone_id": "${zone_id}"
}
EOF
    
    log "Resource IDs saved to: ${SCRIPT_DIR}/deployed-resources.json"
}

# Health check function
health_check() {
    log "Performing health check on deployed resources..."
    
    if [[ ! -f "${SCRIPT_DIR}/deployed-resources.json" ]]; then
        error_exit "No deployed resources found. Run deployment first."
    fi
    
    local instance_id
    instance_id=$(jq -r '.instance_id' "${SCRIPT_DIR}/deployed-resources.json")
    
    if [[ -z "${instance_id}" || "${instance_id}" == "null" ]]; then
        error_exit "Invalid instance ID in deployed resources"
    fi
    
    # Check instance status
    local status
    status=$(aliyun ecs DescribeInstances \
        --InstanceIds "[\"${instance_id}\"]" \
        --output json | jq -r '.Instances.Instance[0].Status')
    
    log "Instance ${instance_id} status: ${status}"
    
    if [[ "${status}" != "Running" ]]; then
        log "WARNING: Instance is not in Running state"
        return 1
    fi
    
    log "Health check passed"
    return 0
}

# Main script logic
main() {
    case "${1:-}" in
        "deploy")
            check_dependencies
            load_config
            deploy_infrastructure
            ;;
        "health-check")
            check_dependencies
            health_check
            ;;
        "config")
            load_config
            log "Configuration file location: ${CONFIG_FILE}"
            log "Edit this file to customize deployment parameters"
            ;;
        *)
            echo "Usage: $0 {deploy|health-check|config}"
            echo ""
            echo "Commands:"
            echo "  deploy       - Deploy complete infrastructure"
            echo "  health-check - Check status of deployed resources"
            echo "  config       - Show configuration file location"
            echo ""
            echo "Configuration file: ${CONFIG_FILE}"
            echo "Log file: ${LOG_FILE}"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"