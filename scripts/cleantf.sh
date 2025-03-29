#!/bin/bash
set -e

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEPLOYMENT_DIR="$SCRIPT_DIR/../infrastructure"

echo "Cleaning Terraform/OpenTofu state and related files..."

# Define files and directories to clean
TO_REMOVE=(
  ".terraform"
  ".terraform.lock.hcl"
  "terraform.tfstate"
  "terraform.tfstate.backup"
  "*.tfstate.*"
  "crash.log"
)

# Change to deployment directory
cd "$DEPLOYMENT_DIR" || exit 1

# Remove files and directories
for item in "${TO_REMOVE[@]}"; do
  find . -name "$item" -exec rm -rf {} \; 2>/dev/null || true
done

# Down wireguard if it exists
if [ -f "/etc/wireguard/k3s.conf" ]; then
  echo "Bringing down WireGuard interface..."
  sudo wg-quick down k3s 2>/dev/null || true
  sudo rm -f /etc/wireguard/k3s.conf
fi

# Remove inventory
if [ -f "$SCRIPT_DIR/../platform/inventory.ini" ]; then
  echo "Removing Ansible inventory..."
  rm -f "$SCRIPT_DIR/../platform/inventory.ini"
fi

echo "Cleanup completed!"
