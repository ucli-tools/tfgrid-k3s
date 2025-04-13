#!/usr/bin/env bash
set -euo pipefail

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEPLOYMENT_DIR="$SCRIPT_DIR/../infrastructure"
OUTPUT_FILE="$SCRIPT_DIR/../platform/inventory.ini"

# Check dependencies
command -v jq >/dev/null 2>&1 || {
    echo >&2 "ERROR: jq required but not found. Install with:
    sudo apt install jq || brew install jq";
    exit 1;
}

# Clear existing file and generate new inventory
echo "Generating inventory from Terraform outputs..."
echo "# K3s Control Plane Nodes" > "$OUTPUT_FILE"
echo "[k3s_control]" >> "$OUTPUT_FILE"

# Generate control plane nodes (node1, node2, node3)
tofu -chdir="$DEPLOYMENT_DIR" show -json | jq -r '
  .values.outputs.wireguard_ips.value |
  to_entries | map(select(.key | test("node_[0-2]"))) |
  .[] | "node\((.key | split("_")[1] | tonumber + 1)) ansible_host=\(.value) ansible_user=root"
' >> "$OUTPUT_FILE"

# Add worker nodes section
echo -e "\n# K3s Worker Nodes" >> "$OUTPUT_FILE"
echo "[k3s_worker]" >> "$OUTPUT_FILE"

# Generate worker nodes (node4, node5, node6)
tofu -chdir="$DEPLOYMENT_DIR" show -json | jq -r '
  .values.outputs.wireguard_ips.value |
  to_entries | map(select(.key | test("node_[3-5]"))) |
  .[] | "node\((.key | split("_")[1] | tonumber + 1)) ansible_host=\(.value) ansible_user=root"
' >> "$OUTPUT_FILE"

# Add group that includes both control and worker nodes
echo -e "\n# All K3s Nodes" >> "$OUTPUT_FILE"
echo "[k3s_cluster:children]" >> "$OUTPUT_FILE"
echo "k3s_control" >> "$OUTPUT_FILE"
echo "k3s_worker" >> "$OUTPUT_FILE"

# Add management node section
echo -e "\n# Management Node" >> "$OUTPUT_FILE"
echo "[management]" >> "$OUTPUT_FILE"

# Generate management node
tofu -chdir="$DEPLOYMENT_DIR" show -json | jq -r '
  .values.outputs.management_node_ip.value |
  "management ansible_host=\(.) ansible_user=root"
' >> "$OUTPUT_FILE"

# Add global variables
echo -e "\n# Global Variables" >> "$OUTPUT_FILE"
echo "[all:vars]" >> "$OUTPUT_FILE"
echo "ansible_python_interpreter=/usr/bin/python3" >> "$OUTPUT_FILE"
echo "k3s_version=v1.32.3+k3s1" >> "$OUTPUT_FILE"
echo "primary_control_node=node1" >> "$OUTPUT_FILE"

# Extract first control plane node's IP for use as the primary control node
NODE1_IP=$(tofu -chdir="$DEPLOYMENT_DIR" show -json | jq -r '.values.outputs.wireguard_ips.value.node_0')
echo "primary_control_ip=$NODE1_IP" >> "$OUTPUT_FILE"

echo "Inventory generated: $OUTPUT_FILE"
