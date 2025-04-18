#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_CONFIG_DIR="${REPO_ROOT}/infrastructure"  # Absolute path to infrastructure directory

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
  echo ""
  echo "See docs/security.md for more information on secure credential handling."
  exit 1
fi

# Always clean up first when redeploying infrastructure
# This is required when changing node ordering to avoid IP conflicts
echo "Cleaning up previous infrastructure deployment..."
bash "${SCRIPT_DIR}/cleantf.sh"

# --- Infrastructure Deployment ---
echo "=== Deploying Infrastructure ==="
cd "$TF_CONFIG_DIR" || exit 1  # Ensure we're in the correct directory

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
echo "=== Testing connectivity to nodes ==="
bash "${SCRIPT_DIR}/ping.sh"

echo "=== Infrastructure deployment completed successfully! ==="
echo ""
echo "Management node has been assigned WireGuard IP 10.1.3.2"
echo ""
echo "To continue with platform deployment:"
echo "  make platform"
