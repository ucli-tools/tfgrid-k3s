#!/bin/bash

# Don't exit on errors, instead continue and report issues
set +e

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
  "state.json"
)

# Check deployment directory exists
if [ ! -d "$DEPLOYMENT_DIR" ]; then
  echo "Warning: Deployment directory not found at $DEPLOYMENT_DIR"
  # Create it so we can continue
  mkdir -p "$DEPLOYMENT_DIR" || { echo "Failed to create directory. Exiting."; exit 1; }
fi

# Change to deployment directory
cd "$DEPLOYMENT_DIR" || { echo "Failed to change to $DEPLOYMENT_DIR. Exiting."; exit 1; }

# Run tofu destroy with timeout to prevent hanging
echo "Running 'tofu destroy' (with 5-minute timeout)..."
timeout 300 tofu destroy -auto-approve >/dev/null 2>&1 || {
  echo "Note: 'tofu destroy' command exited with non-zero status. Continuing with cleanup..."
}

# Remove files and directories with feedback
echo "Removing Terraform/OpenTofu files and directories..."
for item in "${TO_REMOVE[@]}"; do
  echo "  Finding and removing: $item"
  # Use -depth to process contents before directory itself
  find . -name "$item" -depth -print -exec rm -rf {} \; 2>/dev/null || true
  echo "  Done."
done

# Check and bring down wireguard if it exists
if [ -f "/etc/wireguard/k3s.conf" ]; then
  echo "Bringing down WireGuard interface..."
  # Add timeout to prevent hanging
  timeout 30 sudo wg-quick down k3s 2>/dev/null || {
    echo "Note: Failed to bring down WireGuard with wg-quick. Trying alternative method..."
    sudo ip link delete k3s 2>/dev/null || true
  }
  sudo rm -f /etc/wireguard/k3s.conf 2>/dev/null || echo "Warning: Could not remove WireGuard config file."
fi

# Remove inventory file
INVENTORY_PATH="$SCRIPT_DIR/../platform/inventory.ini"
if [ -f "$INVENTORY_PATH" ]; then
  echo "Removing Ansible inventory..."
  rm -f "$INVENTORY_PATH" 2>/dev/null || echo "Warning: Could not remove Ansible inventory file."
fi

echo "Cleanup completed successfully!"
