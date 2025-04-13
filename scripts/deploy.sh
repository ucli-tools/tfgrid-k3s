#!/bin/bash

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Configuration ---
# Define the path to your configuration directories
TF_CONFIG_DIR_DEPLOYMENT="${REPO_ROOT}/infrastructure"  # Absolute path to infrastructure directory
TF_CONFIG_DIR_KUBERNETES="${REPO_ROOT}/platform"  # Absolute path to platform directory

# Check for sensitive environment variables
if env | grep -q TF_VAR_mnemonic; then
  # Variable is already set using the secure terminal approach
  echo "Found TF_VAR_mnemonic in environment (good)."
else
  echo "⚠️ WARNING: TF_VAR_mnemonic not found in environment variables!"
  echo "Please set it securely using:"
  echo "set +o history"
  echo "export TF_VAR_mnemonic=\"your_mnemonic_phrase\""
  echo "set -o history"
  echo "\nSee docs/security.md for more information on secure credential handling."
  exit 1
fi

# --- Cleanup (if needed) ---
cd "$TF_CONFIG_DIR_DEPLOYMENT" || exit 1  # Exit if cd fails
# Example: Destroy the 'clean' resources (adapt to your actual setup)
tofu destroy -auto-approve >/dev/null 2>&1 || true
bash "${SCRIPT_DIR}/cleantf.sh"

# --- Infrastructure Deployment ---
echo "=== Deploying Infrastructure ==="
cd "$TF_CONFIG_DIR_DEPLOYMENT" || exit 1  # Ensure we're in the correct directory

echo "Initializing Terraform/OpenTofu..."
tofu init

echo "Applying infrastructure configuration..."
if ! tofu apply -auto-approve; then
  echo "Infrastructure deployment failed!"
  exit 1
fi

# --- WireGuard Setup ---
echo "=== Setting up WireGuard connection ==="
bash "${SCRIPT_DIR}/wg.sh"

# --- Generate Ansible Inventory ---
echo "=== Generating Ansible inventory ==="
bash "${SCRIPT_DIR}/generate-inventory.sh"

# --- Initial Connectivity Test ---
cd "$TF_CONFIG_DIR_KUBERNETES" || exit 1  # Ensure we're in the correct directory

# Get management node IP from Terraform output
MANAGEMENT_IP=$(tofu -chdir="$TF_CONFIG_DIR_DEPLOYMENT" output -raw management_node_ip)

if [ -z "$MANAGEMENT_IP" ]; then
    echo "Error: Could not retrieve management node IP."
    exit 1
fi

echo "Management node public IP: $MANAGEMENT_IP"

# Robust Ansible Ping with Retry
MAX_RETRIES=5
RETRY_DELAY=5  # seconds

ansible_ping() {
  local retries=0
  while [[ $retries -lt $MAX_RETRIES ]]; do
    ansible all -m ping
    if [[ $? -eq 0 ]]; then
      echo "Ansible ping successful!"
      return 0  # Exit the function successfully
    fi
    retries=$((retries + 1))
    echo "Ansible ping failed (attempt $retries/$MAX_RETRIES). Retrying in $RETRY_DELAY seconds..."
    sleep "$RETRY_DELAY"
  done

  echo "Ansible ping failed after $MAX_RETRIES attempts."
  return 1  # Indicate failure after all retries
}

echo "Testing connectivity to all nodes..."
if ! ansible_ping; then
    echo "Failed to establish Ansible connection after multiple retries."
    exit 1
fi

# --- Configure Management Node ---
echo "=== Configuring Management Node ==="
echo "Installing required software and copying deployment files..."
if ! ansible-playbook site.yml -t management; then
  echo "Management node configuration failed!"
  exit 1
fi

# --- Deploy K3s Cluster ---
echo "=== Deploying K3s Cluster ==="
echo "Note: We're now deploying K3s from the management node!"

# Deploy K3s cluster from the management node
echo "Running deployment from management node..."
ssh -o StrictHostKeyChecking=no root@$MANAGEMENT_IP "cd ~/tfgrid-k3s/platform && ansible-playbook site.yml -t common,control,worker"

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
ssh -o StrictHostKeyChecking=no root@$MANAGEMENT_IP "cd ~/tfgrid-k3s/platform && ansible-playbook site.yml -t kubeconfig"

# Configure a default domain for testing
DOMAIN_NAME="k3s.example.com"

# Configure DNS
echo "=== Setting up DNS information ==="
bash "${SCRIPT_DIR}/configure-dns.sh" "${DOMAIN_NAME}"

echo "=== Deployment Completed Successfully! ==="
echo ""
echo "Your K3s cluster is now managed by the management node at: $MANAGEMENT_IP"
echo ""
echo "To connect to the management node:"
echo "  ssh root@$MANAGEMENT_IP"
echo ""
echo "Once connected to the management node, you can:"
echo "  - Check cluster status: kubectl get nodes"
echo "  - View pods: kubectl get pods -A"
echo "  - Deploy applications using kubectl or Helm"
echo ""
echo "The management node has all necessary tools installed:"
echo "  - kubectl: For managing Kubernetes resources"
echo "  - Ansible: For cluster configuration management"
echo "  - OpenTofu: For infrastructure management"
echo "  - Helm: For Kubernetes package management"
echo ""
echo "All deployment files are copied to ~/tfgrid-k3s/ on the management node"
echo ""
echo "To update your cluster configuration, connect to the management node and run:"
echo "  cd ~/tfgrid-k3s/platform"
echo "  ansible-playbook site.yml"
