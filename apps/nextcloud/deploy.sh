#!/bin/bash
set -e

# Nextcloud Deployment Script
# This script handles the complete deployment of Nextcloud AIO on K3s

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PLATFORM_DIR="${REPO_ROOT}/platform"

# Load configuration
source "${REPO_ROOT}/scripts/nextcloud-config.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if platform exists
    if [ ! -f "${PLATFORM_DIR}/inventory.ini" ]; then
        log_error "Ansible inventory not found!"
        log_error "Platform must be deployed first. Run: make platform"
        exit 1
    fi

    # Get management node IP
    MGMT_HOST=$(grep "mgmt_host ansible_host" "${PLATFORM_DIR}/inventory.ini" | awk '{print $2}' | cut -d= -f2)
    if [ -z "$MGMT_HOST" ]; then
        log_error "Could not retrieve management node IP from inventory."
        exit 1
    fi

    # Check SSH connectivity
    if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$MGMT_HOST "echo 'SSH connection successful'" >/dev/null 2>&1; then
        log_error "Cannot connect to management node at $MGMT_HOST"
        log_error "Please ensure the platform is deployed and WireGuard is connected."
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Deploy function that runs commands on management node
deploy_on_management() {
    local yaml_file=$1
    local description=$2
    log_info "Deploying ${description}..."

    # Copy file to management node
    scp -o StrictHostKeyChecking=no "${yaml_file}" root@${MGMT_HOST}:/tmp/ >/dev/null 2>&1

    # Apply the manifest
    if ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "kubectl apply -f /tmp/$(basename ${yaml_file})" >/dev/null 2>&1; then
        log_success "${description} deployed successfully"
    else
        log_error "Failed to deploy ${description}"
        exit 1
    fi
}

# Main deployment function
deploy_nextcloud() {
    log_info "=== Starting Nextcloud AIO Deployment ==="

    # Step 1: Create namespace
    deploy_on_management "${SCRIPT_DIR}/namespace.yaml" "Nextcloud namespace"

    # Step 2: Install MetalLB for load balancing (no-SPOF)
    log_info "Installing MetalLB for multi-IP load balancing..."
    ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        # Install MetalLB
        kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml >/dev/null 2>&1

        # Wait for MetalLB to be ready
        echo 'Waiting for MetalLB to be ready...'
        kubectl wait --for=condition=available --timeout=300s deployment/controller -n metallb-system >/dev/null 2>&1
    "
    log_success "MetalLB installed for no-SPOF load balancing"

    # Step 3: Deploy cert-manager if not present
    log_info "Checking cert-manager installation..."
    if ! ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "kubectl get deployment -n cert-manager cert-manager >/dev/null 2>&1"; then
        log_info "Installing cert-manager..."
        ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
            kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml >/dev/null 2>&1
            echo 'Waiting for cert-manager to be ready...'
            kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager >/dev/null 2>&1
        "
        log_success "cert-manager installed"
    else
        log_success "cert-manager already installed"
    fi

    # Step 4: Configure MetalLB IP pools for no-SPOF
    log_info "Configuring MetalLB IP pools for multi-IP load balancing..."
    envsubst < "${SCRIPT_DIR}/metallb/ipaddresspool.yaml" | ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "kubectl apply -f - >/dev/null 2>&1"
    log_success "MetalLB IP pools configured for no-SPOF"

    # Step 5: Deploy storage configuration
    deploy_on_management "${SCRIPT_DIR}/storage/storageclass.yaml" "StorageClass"
    envsubst < "${SCRIPT_DIR}/storage/pvcs.yaml" | ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "kubectl apply -f - >/dev/null 2>&1"
    log_success "Storage configuration deployed"

    # Step 6: Deploy ingress configuration
    envsubst < "${SCRIPT_DIR}/ingress/ingress.yaml" | ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "kubectl apply -f - >/dev/null 2>&1"
    log_success "Ingress configuration deployed"

    # Step 7: Deploy Nextcloud AIO using Helm
    log_info "Deploying Nextcloud AIO..."
    ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        # Add Nextcloud AIO Helm repository
        helm repo add nextcloud https://nextcloud.github.io/helm/ >/dev/null 2>&1
        helm repo update >/dev/null 2>&1

        # Create temporary values file with substitutions
        cat > /tmp/nextcloud-values.yaml << EOF
$(envsubst < ${SCRIPT_DIR}/values/nextcloud-aio.yaml)
EOF

        # Install/upgrade Nextcloud AIO
        helm upgrade --install nextcloud-aio nextcloud/nextcloud \\
            --namespace nextcloud \\
            --values /tmp/nextcloud-values.yaml \\
            --wait --timeout 600s >/dev/null 2>&1
    "

    if [ $? -eq 0 ]; then
        log_success "Nextcloud AIO deployed successfully"
    else
        log_error "Failed to deploy Nextcloud AIO"
        exit 1
    fi

    # Step 8: Wait for deployment to be ready
    log_info "Waiting for Nextcloud to be fully ready..."
    ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        kubectl wait --for=condition=available --timeout=600s \\
            deployment/nextcloud-aio -n nextcloud >/dev/null 2>&1
    "

    # Step 9: Get admin credentials
    log_success "=== Nextcloud Deployment Complete ==="
    echo ""
    log_info "Nextcloud Access Information:"
    echo "  URL: https://${NEXTCLOUD_DOMAIN}"
    echo ""

    # Get admin password
    ADMIN_PASSWORD=$(ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        kubectl get secret -n nextcloud nextcloud-aio -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d
    ")

    if [ -n "$ADMIN_PASSWORD" ]; then
        log_info "Admin Credentials:"
        echo "  Username: admin"
        echo "  Password: ${ADMIN_PASSWORD}"
        echo ""
    else
        log_warning "Could not retrieve admin password automatically"
        log_info "Check the Nextcloud logs for initial setup:"
        echo "  kubectl logs -n nextcloud deployment/nextcloud-aio"
    fi

    log_success "Nextcloud is ready at: https://${NEXTCLOUD_DOMAIN}"
}

# Status check function
check_status() {
    log_info "=== Nextcloud Status Check ==="

    ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        echo 'Pods:'
        kubectl get pods -n nextcloud
        echo ''
        echo 'Services:'
        kubectl get svc -n nextcloud
        echo ''
        echo 'Ingress:'
        kubectl get ingress -n nextcloud
        echo ''
        echo 'PVCs:'
        kubectl get pvc -n nextcloud
    "
}

# Cleanup function
cleanup_nextcloud() {
    log_warning "=== Cleaning up Nextcloud Deployment ==="
    read -p "Are you sure you want to delete Nextcloud? This will remove all data! (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
            helm uninstall nextcloud-aio -n nextcloud >/dev/null 2>&1 || true
            kubectl delete namespace nextcloud >/dev/null 2>&1 || true
        "
        log_success "Nextcloud cleanup completed"
    else
        log_info "Cleanup cancelled"
    fi
}

# Main script logic
case "${1:-deploy}" in
    deploy)
        check_prerequisites
        deploy_nextcloud
        ;;
    status)
        check_prerequisites
        check_status
        ;;
    clean)
        check_prerequisites
        cleanup_nextcloud
        ;;
    *)
        echo "Usage: $0 {deploy|status|clean}"
        echo "  deploy - Deploy Nextcloud AIO"
        echo "  status - Check Nextcloud status"
        echo "  clean  - Remove Nextcloud deployment"
        exit 1
        ;;
esac