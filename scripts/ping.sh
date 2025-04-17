#!/bin/bash
set -e

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLATFORM_DIR="$SCRIPT_DIR/../platform"
INVENTORY_FILE="$PLATFORM_DIR/inventory.ini"

# Check if inventory exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Inventory file not found. Run generate-inventory.sh first."
    exit 1
fi

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to ping a host
ping_host() {
    local user=$1
    local ip=$2
    local name=$3

    echo -n "  $name (${user}@${ip})... "
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${user}@${ip}" "echo 'Success'" &>/dev/null; then
        echo -e "${GREEN}Success!${NC}"
        return 0
    else
        echo -e "${RED}Failed!${NC}"
        return 1
    fi
}

# Initialize counters
total_success=0
total_failed=0

# Function to test nodes in a specific section
test_nodes() {
    local section=$1
    local title=$2
    local success=0
    local failed=0

    echo -e "\n${BLUE}=== Testing $title Nodes ===${NC}"

    # Extract the section
    local capture=0
    local nodes=()

    while IFS= read -r line; do
        # Start capturing at section start
        if [[ "$line" == "[$section]" ]]; then
            capture=1
            continue
        fi
        # Stop at next section
        if [[ $capture -eq 1 && "$line" == \[* ]]; then
            capture=0
            continue
        fi
        # Capture lines with ansible_host
        if [[ $capture -eq 1 && "$line" =~ ansible_host ]]; then
            nodes+=("$line")
        fi
    done < "$INVENTORY_FILE"

    # Count and display nodes found
    local count=${#nodes[@]}
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}  No nodes found in $title section${NC}"
        return 0
    fi

    echo -e "${CYAN}  Found $count $title node(s)${NC}"

    # Process each node
    for node in "${nodes[@]}"; do
        name=$(echo "$node" | awk '{print $1}')
        ip=$(echo "$node" | grep -o "ansible_host=[^ ]*" | cut -d= -f2)
        user=$(echo "$node" | grep -o "ansible_user=[^ ]*" | cut -d= -f2)

        if ping_host "$user" "$ip" "$name"; then
            success=$((success+1))
            total_success=$((total_success+1))
        else
            failed=$((failed+1))
            total_failed=$((total_failed+1))
        fi
    done

    # Section summary
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}  ✓ All $title nodes are reachable ($success/$count)${NC}"
    else
        echo -e "${RED}  ✗ Some $title nodes are unreachable ($failed/$count failed)${NC}"
    fi
}

# Test each type of node
test_nodes "k3s_management" "Management"
test_nodes "k3s_control" "Control Plane"
test_nodes "k3s_worker" "Worker"

# Overall summary
echo -e "\n${BLUE}=== Overall Connectivity Summary ===${NC}"
total=$((total_success + total_failed))
echo "Total nodes tested: $total"
echo "Reachable nodes: $total_success"
echo "Unreachable nodes: $total_failed"

if [ $total_failed -eq 0 ]; then
    echo -e "${GREEN}✓ ALL NODES REACHABLE${NC}"
    exit 0
else
    echo -e "${RED}✗ SOME NODES ARE UNREACHABLE ($total_failed/$total)${NC}"
    exit 1
fi
