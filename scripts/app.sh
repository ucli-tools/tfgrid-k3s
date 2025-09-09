#!/bin/bash
set -e

# Application Dispatcher Script
# This script dispatches to app-specific deployment scripts

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLATFORM_DIR="${REPO_ROOT}/platform"
APPS_DIR="${REPO_ROOT}/apps"

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
    # Check if platform exists by checking inventory
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

    # Check if we can connect to the management node
    if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$MGMT_HOST "echo 'Connection successful'" >/dev/null 2>&1; then
        log_error "Cannot connect to management node at $MGMT_HOST"
        log_error "Please ensure the platform is deployed and WireGuard is connected."
        exit 1
    fi
}

# List available apps
list_apps() {
    log_info "Available applications:"
    if [ -d "${APPS_DIR}" ]; then
        for app_dir in "${APPS_DIR}"/*/; do
            if [ -d "$app_dir" ] && [ -f "${app_dir}deploy.sh" ]; then
                app_name=$(basename "$app_dir")
                echo "  - $app_name"
            fi
        done
    else
        log_warning "No apps directory found"
    fi
}

# Deploy specific app
deploy_app() {
    local app_name=$1
    local app_dir="${APPS_DIR}/${app_name}"
    local deploy_script="${app_dir}/deploy.sh"

    if [ ! -d "$app_dir" ]; then
        log_error "Application '${app_name}' not found in ${APPS_DIR}"
        log_info "Available applications:"
        list_apps
        exit 1
    fi

    if [ ! -f "$deploy_script" ]; then
        log_error "Deployment script not found: ${deploy_script}"
        exit 1
    fi

    if [ ! -x "$deploy_script" ]; then
        log_warning "Making deployment script executable: ${deploy_script}"
        chmod +x "$deploy_script"
    fi

    log_info "=== Deploying ${app_name} ==="
    cd "$app_dir"
    bash deploy.sh
}

# Deploy all apps
deploy_all_apps() {
    log_info "=== Deploying all applications ==="

    if [ ! -d "${APPS_DIR}" ]; then
        log_warning "No apps directory found at ${APPS_DIR}"
        return
    fi

    local deployed_count=0
    for app_dir in "${APPS_DIR}"/*/; do
        if [ -d "$app_dir" ] && [ -f "${app_dir}deploy.sh" ]; then
            app_name=$(basename "$app_dir")
            log_info "Deploying ${app_name}..."
            cd "$app_dir"
            if bash deploy.sh; then
                log_success "${app_name} deployed successfully"
                ((deployed_count++))
            else
                log_error "Failed to deploy ${app_name}"
            fi
        fi
    done

    if [ $deployed_count -eq 0 ]; then
        log_warning "No applications found to deploy"
    else
        log_success "Deployed ${deployed_count} application(s)"
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [app-name]"
    echo ""
    echo "Deploy applications to the K3s cluster."
    echo ""
    echo "Arguments:"
    echo "  app-name    Deploy specific application (e.g., nextcloud)"
    echo "  (no args)   Deploy all available applications"
    echo ""
    echo "Examples:"
    echo "  $0 nextcloud    # Deploy Nextcloud"
    echo "  $0              # Deploy all apps"
    echo ""
    list_apps
}

# Main script logic
check_prerequisites

if [ $# -eq 0 ]; then
    # No arguments - deploy all apps
    deploy_all_apps
elif [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_usage
else
    # Deploy specific app
    deploy_app "$1"
fi

log_success "Application deployment process completed"
