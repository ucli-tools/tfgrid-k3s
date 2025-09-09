#!/bin/bash

# Nextcloud Configuration Script
# This script manages environment variables and configuration for Nextcloud deployment

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLATFORM_DIR="${REPO_ROOT}/platform"

# Default configuration values
export NEXTCLOUD_DOMAIN="${NEXTCLOUD_DOMAIN:-nextcloud.example.com}"
export NEXTCLOUD_ADMIN_EMAIL="${NEXTCLOUD_ADMIN_EMAIL:-admin@example.com}"
export NEXTCLOUD_STORAGE_SIZE="${NEXTCLOUD_STORAGE_SIZE:-100}"
export NEXTCLOUD_DB_SIZE="${NEXTCLOUD_DB_SIZE:-20}"
export NEXTCLOUD_REDIS_SIZE="${NEXTCLOUD_REDIS_SIZE:-5}"
export NEXTCLOUD_BACKUP_RETENTION="${NEXTCLOUD_BACKUP_RETENTION:-7}"

# Function to detect cluster configuration
detect_cluster_config() {
    if [ -f "${PLATFORM_DIR}/inventory.ini" ]; then
        # Count control plane nodes
        CONTROL_COUNT=$(grep -c 'ansible_host' "${PLATFORM_DIR}/inventory.ini" | head -1)
        # Count worker nodes
        WORKER_COUNT=$(grep -c 'ansible_host' "${PLATFORM_DIR}/inventory.ini" | tail -1)

        # If we can't parse properly, use defaults
        if [ "$CONTROL_COUNT" -eq 0 ]; then CONTROL_COUNT=3; fi
        if [ "$WORKER_COUNT" -eq 0 ]; then WORKER_COUNT=3; fi
    else
        # Default to 3 masters, 3 workers if inventory not found
        CONTROL_COUNT=3
        WORKER_COUNT=3
    fi

    export CLUSTER_CONTROL_NODES=$CONTROL_COUNT
    export CLUSTER_WORKER_NODES=$WORKER_COUNT
    export CLUSTER_TOTAL_NODES=$((CONTROL_COUNT + WORKER_COUNT))
}

# Function to calculate resource allocation based on cluster size
calculate_resources() {
    # Base resources per worker node
    WORKER_CPU_BASE=8
    WORKER_MEM_BASE=16384  # 16GB

    # Calculate total available resources
    TOTAL_CPU=$((WORKER_CPU_BASE * CLUSTER_WORKER_NODES))
    TOTAL_MEM=$((WORKER_MEM_BASE * CLUSTER_WORKER_NODES))

    # Nextcloud resource allocation (60% of total resources for HA)
    NEXTCLOUD_CPU_REQUESTS=$((TOTAL_CPU * 60 / 100 / CLUSTER_WORKER_NODES))
    NEXTCLOUD_CPU_LIMITS=$((TOTAL_CPU * 80 / 100 / CLUSTER_WORKER_NODES))
    NEXTCLOUD_MEM_REQUESTS=$((TOTAL_MEM * 60 / 100 / CLUSTER_WORKER_NODES))
    NEXTCLOUD_MEM_LIMITS=$((TOTAL_MEM * 80 / 100 / CLUSTER_WORKER_NODES))

    # Ensure minimum resources
    if [ "$NEXTCLOUD_CPU_REQUESTS" -lt 2 ]; then NEXTCLOUD_CPU_REQUESTS=2; fi
    if [ "$NEXTCLOUD_CPU_LIMITS" -lt 4 ]; then NEXTCLOUD_CPU_LIMITS=4; fi
    if [ "$NEXTCLOUD_MEM_REQUESTS" -lt 4096 ]; then NEXTCLOUD_MEM_REQUESTS=4096; fi
    if [ "$NEXTCLOUD_MEM_LIMITS" -lt 8192 ]; then NEXTCLOUD_MEM_LIMITS=8192; fi

    export NEXTCLOUD_CPU_REQUESTS=$NEXTCLOUD_CPU_REQUESTS
    export NEXTCLOUD_CPU_LIMITS=$NEXTCLOUD_CPU_LIMITS
    export NEXTCLOUD_MEM_REQUESTS=$NEXTCLOUD_MEM_REQUESTS
    export NEXTCLOUD_MEM_LIMITS=$NEXTCLOUD_MEM_LIMITS
}

# Function to determine HA settings based on cluster size
configure_ha_settings() {
    if [ "$CLUSTER_WORKER_NODES" -ge 3 ]; then
        # Full HA configuration for 3+ workers
        export NEXTCLOUD_REPLICA_COUNT=1
        export NEXTCLOUD_HA_ENABLED=true
        export NEXTCLOUD_ANTI_AFFINITY_ENABLED=true
        export NEXTCLOUD_PDB_MIN_AVAILABLE=1
    elif [ "$CLUSTER_WORKER_NODES" -eq 2 ]; then
        # Basic HA for 2 workers
        export NEXTCLOUD_REPLICA_COUNT=1
        export NEXTCLOUD_HA_ENABLED=true
        export NEXTCLOUD_ANTI_AFFINITY_ENABLED=false
        export NEXTCLOUD_PDB_MIN_AVAILABLE=1
    else
        # Single node deployment
        export NEXTCLOUD_REPLICA_COUNT=1
        export NEXTCLOUD_HA_ENABLED=false
        export NEXTCLOUD_ANTI_AFFINITY_ENABLED=false
        export NEXTCLOUD_PDB_MIN_AVAILABLE=1
    fi
}

# Check for required environment variables
if [ -z "$NEXTCLOUD_DOMAIN" ]; then
  echo "Error: NEXTCLOUD_DOMAIN environment variable is not set"
  echo "Please set it in infrastructure/credentials.auto.tfvars or export it"
  exit 1
fi

if [ -z "$NEXTCLOUD_ADMIN_EMAIL" ]; then
  echo "Error: NEXTCLOUD_ADMIN_EMAIL environment variable is not set"
  echo "Please set it in infrastructure/credentials.auto.tfvars or export it"
  exit 1
fi

# Validate domain format
if ! echo "$NEXTCLOUD_DOMAIN" | grep -qE '^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'; then
  echo "Error: NEXTCLOUD_DOMAIN does not appear to be a valid domain name"
  exit 1
fi

# Validate email format
if ! echo "$NEXTCLOUD_ADMIN_EMAIL" | grep -qE '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
  echo "Error: NEXTCLOUD_ADMIN_EMAIL does not appear to be a valid email address"
  exit 1
fi

# Detect cluster configuration
detect_cluster_config

# Calculate resource allocation
calculate_resources

# Configure HA settings
configure_ha_settings

# Display configuration
echo "=== Nextcloud Configuration ==="
echo "Domain: ${NEXTCLOUD_DOMAIN}"
echo "Admin Email: ${NEXTCLOUD_ADMIN_EMAIL}"
echo "Storage Size: ${NEXTCLOUD_STORAGE_SIZE}Gi"
echo "Database Size: ${NEXTCLOUD_DB_SIZE}Gi"
echo "Redis Size: ${NEXTCLOUD_REDIS_SIZE}Gi"
echo "Backup Retention: ${NEXTCLOUD_BACKUP_RETENTION} days"
echo ""
echo "=== Cluster Configuration ==="
echo "Control Plane Nodes: ${CLUSTER_CONTROL_NODES}"
echo "Worker Nodes: ${CLUSTER_WORKER_NODES}"
echo "Total Nodes: ${CLUSTER_TOTAL_NODES}"
echo ""
echo "=== Resource Allocation ==="
echo "CPU Requests: ${NEXTCLOUD_CPU_REQUESTS}"
echo "CPU Limits: ${NEXTCLOUD_CPU_LIMITS}"
echo "Memory Requests: ${NEXTCLOUD_MEM_REQUESTS}Mi"
echo "Memory Limits: ${NEXTCLOUD_MEM_LIMITS}Mi"
echo ""
echo "=== HA Configuration ==="
echo "HA Enabled: ${NEXTCLOUD_HA_ENABLED}"
echo "Anti-affinity: ${NEXTCLOUD_ANTI_AFFINITY_ENABLED}"
echo "Pod Disruption Budget: ${NEXTCLOUD_PDB_MIN_AVAILABLE}"
echo "==============================="

# Export additional computed variables
export NEXTCLOUD_URL="https://${NEXTCLOUD_DOMAIN}"
export NEXTCLOUD_NAMESPACE="nextcloud"