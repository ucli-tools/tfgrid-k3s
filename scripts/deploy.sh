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

# Configuration managed through OpenTofu and Ansible

# --- Cleanup (if needed) ---
cd "$TF_CONFIG_DIR_DEPLOYMENT" || exit 1  # Exit if cd fails
# Example: Destroy the 'clean' resources (adapt to your actual setup)
tofu destroy -auto-approve >/dev/null 2>&1 || true
bash "${SCRIPT_DIR}/cleantf.sh"

# --- Terraform/Tofu ---
cd "$TF_CONFIG_DIR_DEPLOYMENT" || exit 1  # Ensure we're in the correct directory

tofu init
if ! tofu apply -auto-approve; then
  echo "Tofu apply failed!"
  # Add additional error handling/notification here
  exit 1
fi

# --- WireGuard and Inventory ---
bash "${SCRIPT_DIR}/wg.sh"
bash "${SCRIPT_DIR}/generate-inventory.sh"

# --- Ansible ---
cd "$TF_CONFIG_DIR_KUBERNETES" || exit 1  # Ensure we're in the correct directory

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

if ! ansible_ping; then
    echo "Failed to establish Ansible connection after multiple retries."
    exit 1
fi

# Deploy K3s cluster first
echo "Deploying K3s cluster..."
if ! ansible-playbook site.yml -t common,control,worker; then
  echo "K3s deployment failed!"
  # Add additional error handling/notification here
  exit 1
fi

# Wait for K3s to stabilize
echo "Waiting for K3s cluster to stabilize (60 seconds)..."
sleep 60

# Setup local kubectl configuration
echo "Setting up local kubectl configuration..."
if ! ansible-playbook site.yml -t kubeconfig; then
  echo "kubectl configuration failed!"
  exit 1
fi

# Configure a default domain for testing
DOMAIN_NAME="k3s.example.com"

# Configure DNS
echo "Setting up DNS information..."
bash "${SCRIPT_DIR}/configure-dns.sh" "${DOMAIN_NAME}"

echo "Deployment completed successfully!"
echo "Your K3s cluster is ready!"
echo "Use 'export KUBECONFIG=${REPO_ROOT}/k3s.yaml' to configure kubectl"
echo "Then 'kubectl get nodes' to verify your deployment"