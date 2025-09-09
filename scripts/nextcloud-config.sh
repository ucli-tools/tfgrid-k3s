#!/bin/bash

# Nextcloud Configuration Script
# This script manages environment variables and configuration for Nextcloud deployment

# Default configuration values
export NEXTCLOUD_DOMAIN="${NEXTCLOUD_DOMAIN:-nextcloud.example.com}"
export NEXTCLOUD_ADMIN_EMAIL="${NEXTCLOUD_ADMIN_EMAIL:-admin@example.com}"
export NEXTCLOUD_STORAGE_SIZE="${NEXTCLOUD_STORAGE_SIZE:-100}"
export NEXTCLOUD_DB_SIZE="${NEXTCLOUD_DB_SIZE:-20}"
export NEXTCLOUD_REDIS_SIZE="${NEXTCLOUD_REDIS_SIZE:-5}"
export NEXTCLOUD_BACKUP_RETENTION="${NEXTCLOUD_BACKUP_RETENTION:-7}"

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

# Display configuration
echo "=== Nextcloud Configuration ==="
echo "Domain: ${NEXTCLOUD_DOMAIN}"
echo "Admin Email: ${NEXTCLOUD_ADMIN_EMAIL}"
echo "Storage Size: ${NEXTCLOUD_STORAGE_SIZE}Gi"
echo "Database Size: ${NEXTCLOUD_DB_SIZE}Gi"
echo "Redis Size: ${NEXTCLOUD_REDIS_SIZE}Gi"
echo "Backup Retention: ${NEXTCLOUD_BACKUP_RETENTION} days"
echo "==============================="

# Export additional computed variables
export NEXTCLOUD_URL="https://${NEXTCLOUD_DOMAIN}"
export NEXTCLOUD_NAMESPACE="nextcloud"