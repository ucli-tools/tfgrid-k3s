#!/usr/bin/env bash
set -euo pipefail

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEPLOYMENT_DIR="$SCRIPT_DIR/../infrastructure"
OUTPUT_FILE="$SCRIPT_DIR/../platform/inventory.ini"

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

# Check dependencies
command -v jq >/dev/null 2>&1 || {
    log_error "jq required but not found. Install with:"
    echo "    sudo apt install jq || brew install jq"
    exit 1
}

command -v tofu >/dev/null 2>&1 || {
    log_error "tofu (OpenTofu) required but not found."
    exit 1
}

# Check if infrastructure is deployed
if [ ! -f "$DEPLOYMENT_DIR/terraform.tfstate" ] && [ ! -f "$DEPLOYMENT_DIR/terraform.tfstate.backup" ]; then
    log_error "No infrastructure state found"
    log_error "Run: make infrastructure"
    exit 1
fi

log_info "Generating inventory from Terraform outputs..."

# Get Terraform outputs
terraform_output=$(tofu -chdir="$DEPLOYMENT_DIR" show -json)

# Extract node information
management_ip=$(echo "$terraform_output" | jq -r '.values.outputs.management_node_wireguard_ip.value // empty')
wireguard_ips=$(echo "$terraform_output" | jq -r '.values.outputs.wireguard_ips.value // {}')

# Validate we have the required information
if [ -z "$management_ip" ]; then
    log_error "Failed to extract management node IP from Terraform outputs"
    exit 1
fi

# Read node configuration from credentials file
CREDENTIALS_FILE="$DEPLOYMENT_DIR/credentials.auto.tfvars"
if [ ! -f "$CREDENTIALS_FILE" ]; then
    log_error "Credentials file not found: $CREDENTIALS_FILE"
    exit 1
fi

# Parse control and worker node counts from credentials
control_count=$(grep -oP 'control_nodes\s*=\s*\[\K[^\]]+' "$CREDENTIALS_FILE" | grep -o ',' | wc -l)
control_count=$((control_count + 1))  # Add 1 for the first node

worker_count=$(grep -oP 'worker_nodes\s*=\s*\[\K[^\]]+' "$CREDENTIALS_FILE" | grep -o ',' | wc -l)
worker_count=$((worker_count + 1))  # Add 1 for the first node

log_info "Detected configuration: 1 management + $control_count control + $worker_count worker nodes"

# Clear existing file and generate new inventory
cat > "$OUTPUT_FILE" << EOF
# TFGrid K3s Cluster Ansible Inventory
# Generated on $(date)
# Configuration: 1 management + ${control_count} control + ${worker_count} worker nodes

# Management Nodes
[k3s_management]
mgmt_host ansible_host=${management_ip} ansible_user=root ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

# K3s Control Plane Nodes
[k3s_control]
EOF

# Add control plane nodes (first N nodes from wireguard_ips)
control_idx=0
echo "$wireguard_ips" | jq -r 'to_entries | sort_by(.key) | .[] | select(.key | test("node_\\d+")) | .key + " " + .value' | \
while read -r key ip; do
    if [ $control_idx -lt $control_count ]; then
        node_num=$((control_idx + 1))
        echo "node${node_num} ansible_host=${ip} ansible_user=root ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" >> "$OUTPUT_FILE"
        control_idx=$((control_idx + 1))
    fi
done

# Add worker nodes section
cat >> "$OUTPUT_FILE" << EOF

# K3s Worker Nodes
[k3s_worker]
EOF

# Add worker nodes (remaining nodes from wireguard_ips)
worker_idx=0
echo "$wireguard_ips" | jq -r 'to_entries | sort_by(.key) | .[] | select(.key | test("node_\\d+")) | .key + " " + .value' | \
while read -r key ip; do
    if [ $worker_idx -ge $control_count ] && [ $worker_idx -lt $((control_count + worker_count)) ]; then
        node_num=$((worker_idx + 1))
        echo "node${node_num} ansible_host=${ip} ansible_user=root ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" >> "$OUTPUT_FILE"
    fi
    worker_idx=$((worker_idx + 1))
done

# Add cluster group
cat >> "$OUTPUT_FILE" << EOF

# All K3s Nodes
[k3s_cluster:children]
k3s_management
k3s_control
k3s_worker

# Global Variables
[all:vars]
ansible_python_interpreter=/usr/bin/python3
k3s_version=v1.32.3+k3s1
primary_control_node=node1
EOF

# Extract first control plane node's IP for use as the primary control node
first_control_ip=$(echo "$wireguard_ips" | jq -r 'to_entries | sort_by(.key) | .[0].value // empty')
if [ -n "$first_control_ip" ]; then
    echo "primary_control_ip=${first_control_ip}" >> "$OUTPUT_FILE"
fi

log_success "Ansible inventory generated: $OUTPUT_FILE"
log_info "Inventory contains:"
echo "  - 1 management node"
echo "  - ${control_count} control plane node(s)"
echo "  - ${worker_count} worker node(s)"
