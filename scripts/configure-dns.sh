#!/usr/bin/env bash
set -euo pipefail

# Configure DNS for TFGrid VMs
# This script sets up IPv6 DNS servers for internet access in TFGrid environments

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLATFORM_DIR="$SCRIPT_DIR/../platform"
INVENTORY_FILE="$PLATFORM_DIR/inventory.ini"

# Check if inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "ERROR: Inventory file not found at $INVENTORY_FILE"
    echo "Please run 'make infrastructure' first to deploy the VMs."
    exit 1
fi

# Get management node IP
MGMT_HOST=$(grep "mgmt_host ansible_host" "$INVENTORY_FILE" | awk '{print $2}' | cut -d= -f2)
if [ -z "$MGMT_HOST" ]; then
    echo "Error: Could not retrieve management node IP from inventory."
    exit 1
fi

echo "Configuring DNS on management node ($MGMT_HOST)..."

# Configure DNS using Ansible
cd "$PLATFORM_DIR" || exit 1
ansible-playbook site.yml -t common --limit k3s_management

echo "DNS configuration completed!"
echo "The management node should now have internet access for package updates."