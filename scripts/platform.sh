#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLATFORM_DIR="${REPO_ROOT}/platform"

# Check if infrastructure exists by looking for WireGuard configuration
if [ ! -f "/etc/wireguard/k3s.conf" ]; then
  echo "⚠️ WireGuard configuration not found!"
  echo "Infrastructure must be deployed first. Run:"
  echo "  make infrastructure"
  exit 1
fi

# Get management node WireGuard IP
MGMT_HOST=$(grep "mgmt_host ansible_host" "${PLATFORM_DIR}/inventory.ini" | awk '{print $2}' | cut -d= -f2)
if [ -z "$MGMT_HOST" ]; then
  echo "Error: Could not retrieve management node IP from inventory."
  exit 1
fi

# --- Configure Management Node ---
echo "=== Configuring Management Node ==="
echo "Installing required software and copying deployment files..."
cd "${PLATFORM_DIR}" || exit 1
if ! ansible-playbook site.yml -t management; then
  echo "Management node configuration failed!"
  exit 1
fi

# --- Deploy K3s Cluster ---
echo "=== Deploying K3s Cluster ==="
echo "Note: We're now deploying K3s from the management node!"

# Deploy K3s cluster from the management node
echo "Running deployment from management node..."
ssh -o StrictHostKeyChecking=no root@$MGMT_HOST "cd ~/tfgrid-k3s/platform && ansible-playbook site.yml -t common,control,worker"

# Check if deployment was successful
if [ $? -ne 0 ]; then
  echo "K3s deployment from management node failed!"
  exit 1
fi

# Wait for K3s to stabilize
echo "Waiting for K3s cluster to stabilize (60 seconds)..."
sleep 60

# Setup kubectl configuration on management node
echo "Setting up kubectl configuration on management node..."
ssh -o StrictHostKeyChecking=no root@$MGMT_HOST "cd ~/tfgrid-k3s/platform && ansible-playbook site.yml -t kubeconfig"

echo "=== K3s Platform Deployment Completed Successfully! ==="
echo ""
echo "Your K3s cluster is now running and managed by the management node at: $MGMT_HOST"
echo ""
echo "To deploy applications on your cluster:"
echo "  make app"
echo ""
echo "To connect to the management node:"
echo "  make connect-management"
echo "  or: ssh root@$MGMT_HOST"
