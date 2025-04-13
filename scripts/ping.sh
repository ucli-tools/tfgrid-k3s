#!/bin/bash
set -e

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
KUBERNETES_DIR="$SCRIPT_DIR/../platform"

# Check if inventory exists
if [ ! -f "$KUBERNETES_DIR/inventory.ini" ]; then
    echo "Inventory file not found. Run generate-inventory.sh first."
    exit 1
fi

# Test SSH connectivity to all hosts
echo "Testing SSH connectivity to all hosts..."

# Define retry variables
MAX_RETRIES=5
RETRY_DELAY=5  # seconds

# Function to ping a host with retries
ping_host() {
    local host=$1
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        echo -n "Pinging $host... "
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $host "echo 'Success'" &>/dev/null; then
            echo "Success!"
            return 0
        else
            echo "Failed (attempt $((retries+1))/$MAX_RETRIES)"
            retries=$((retries+1))
            
            if [ $retries -lt $MAX_RETRIES ]; then
                echo "Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            fi
        fi
    done
    
    echo "ERROR: Failed to connect to $host after $MAX_RETRIES attempts"
    return 1
}

# Extract hosts from inventory
HOSTS=$(grep -E "^node[0-9]+ ansible_host=" "$KUBERNETES_DIR/inventory.ini" | \
        sed -E 's/^node[0-9]+ ansible_host=([^ ]+) ansible_user=([^ ]+).*/\2@\1/g')

# Ping each host
echo "Found $(echo "$HOSTS" | wc -l) hosts in inventory"
FAILED=0

for HOST in $HOSTS; do
    if ! ping_host "$HOST"; then
        FAILED=$((FAILED+1))
    fi
done

# Report results
if [ $FAILED -eq 0 ]; then
    echo -e "\n✅ All hosts are reachable via SSH"
    exit 0
else
    echo -e "\n❌ Failed to connect to $FAILED hosts"
    exit 1
fi
