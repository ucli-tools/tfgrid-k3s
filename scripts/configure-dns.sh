#!/bin/bash
set -e

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
KUBERNETES_DIR="$SCRIPT_DIR/../platform"

# Get domain from command line argument
DOMAIN=${1:-"onlineschool.com"}

# Source the inventory file to get variables
if [ -f "$KUBERNETES_DIR/inventory.ini" ]; then
    # Extract first control plane IP from inventory
    PRIMARY_CONTROL_IP=$(grep -E "^primary_control_ip=" "$KUBERNETES_DIR/inventory.ini" | cut -d'=' -f2)
    PRIMARY_CONTROL_NODE=$(grep -E "^primary_control_node=" "$KUBERNETES_DIR/inventory.ini" | cut -d'=' -f2)
    
    if [ -z "$PRIMARY_CONTROL_IP" ]; then
        echo "Cannot find primary_control_ip in inventory.ini"
        exit 1
    fi
    if [ -z "$PRIMARY_CONTROL_NODE" ]; then
        PRIMARY_CONTROL_NODE="node1"
    fi
else
    echo "Inventory file not found. Make sure deployment was successful."
    exit 1
fi

# Use the control plane IP for DNS
CLUSTER_IP=$PRIMARY_CONTROL_IP

echo "Setting up DNS for domain: $DOMAIN with IP: $CLUSTER_IP"

# For demonstration purposes, output how to configure DNS
cat << EOF
===================== DNS Configuration =======================
To access your K3s cluster, configure the following DNS records:

$DOMAIN             IN A     $CLUSTER_IP
*.${DOMAIN}         IN A     $CLUSTER_IP

Alternatively, for testing purposes, add these entries to your local /etc/hosts file:

$CLUSTER_IP  $DOMAIN
$CLUSTER_IP  apps.${DOMAIN}

To access your applications, you can set up Ingress resources using the domain:
- Main domain: https://${DOMAIN}
- Apps subdomain: https://apps.${DOMAIN}
================================================================
EOF
