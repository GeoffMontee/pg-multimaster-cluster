#!/bin/bash
# PostgreSQL Multi-Master Cluster Deployment Script
# This script orchestrates the full deployment process

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=()
    
    if ! command -v terraform &> /dev/null; then
        missing+=("terraform")
    fi
    
    if ! command -v ansible-playbook &> /dev/null; then
        missing+=("ansible")
    fi
    
    if ! command -v aws &> /dev/null; then
        missing+=("aws-cli")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        echo "Please configure AWS credentials: aws configure"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    log_info "Deploying AWS infrastructure with Terraform..."
    
    cd "$PROJECT_DIR/terraform"
    
    if [ ! -f "terraform.tfvars" ]; then
        log_warn "terraform.tfvars not found, using defaults"
        log_info "Consider copying terraform.tfvars.example to terraform.tfvars"
    fi
    
    terraform init
    terraform plan -out=tfplan
    
    read -p "Apply this plan? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_warn "Deployment cancelled"
        exit 0
    fi
    
    terraform apply tfplan
    rm tfplan
    
    log_success "Infrastructure deployed successfully"
}

# Configure cluster with Ansible
configure_cluster() {
    log_info "Configuring cluster with Ansible..."
    
    cd "$PROJECT_DIR/ansible"
    
    # Install Ansible Galaxy requirements
    log_info "Installing Ansible Galaxy requirements..."
    ansible-galaxy install -r requirements.yml
    
    # Wait for instances to be ready
    log_info "Waiting for instances to be ready (60 seconds)..."
    sleep 60
    
    # Run the playbook
    log_info "Running Ansible playbook..."
    ansible-playbook -i inventory/hosts.yml site.yml
    
    log_success "Cluster configured successfully"
}

# Display connection information
show_connection_info() {
    cd "$PROJECT_DIR/terraform"
    
    echo
    echo "=========================================="
    echo "Deployment Complete!"
    echo "=========================================="
    echo
    echo "Connection Information:"
    echo "-----------------------"
    echo "HAProxy (Load Balancer):"
    terraform output haproxy_public_ip
    echo
    echo "PostgreSQL Connection String:"
    echo "  psql -h $(terraform output -raw haproxy_public_ip) -p 5000 -U appuser -d appdb"
    echo
    echo "HAProxy Statistics:"
    terraform output haproxy_stats_url
    echo "  Credentials: admin / HAProxy!Stats"
    echo
    echo "Direct PostgreSQL Node Access:"
    terraform output postgres_public_ips
    echo
    echo "SSH Access:"
    echo "  ssh -i ansible/ssh_key.pem ubuntu@<instance_ip>"
    echo
}

# Main
main() {
    echo "=========================================="
    echo "PostgreSQL Multi-Master Cluster Deployment"
    echo "=========================================="
    echo
    
    case "${1:-}" in
        infra)
            check_prerequisites
            deploy_infrastructure
            ;;
        config)
            configure_cluster
            ;;
        info)
            show_connection_info
            ;;
        destroy)
            cd "$PROJECT_DIR/terraform"
            terraform destroy
            ;;
        *)
            check_prerequisites
            deploy_infrastructure
            configure_cluster
            show_connection_info
            ;;
    esac
}

main "$@"
