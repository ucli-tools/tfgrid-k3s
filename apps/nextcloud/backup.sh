#!/bin/bash
set -e

# Nextcloud Backup and Restore Script
# This script handles backup and restore operations for Nextcloud AIO

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PLATFORM_DIR="${REPO_ROOT}/platform"

# Load configuration
source "${REPO_ROOT}/scripts/nextcloud-config.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get management node IP
get_mgmt_host() {
    MGMT_HOST=$(grep "mgmt_host ansible_host" "${PLATFORM_DIR}/inventory.ini" | awk '{print $2}' | cut -d= -f2)
    if [ -z "$MGMT_HOST" ]; then
        log_error "Could not retrieve management node IP from inventory."
        exit 1
    fi
}

# Check if Nextcloud is deployed
check_nextcloud() {
    if ! ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "kubectl get namespace nextcloud >/dev/null 2>&1"; then
        log_error "Nextcloud namespace not found. Please deploy Nextcloud first."
        exit 1
    fi
}

# Backup function
backup_nextcloud() {
    log_info "=== Starting Nextcloud Backup ==="

    # Generate backup name
    BACKUP_NAME="nextcloud-backup-$(date +%Y%m%d-%H%M%S)"
    BACKUP_DIR="/opt/nextcloud-backups"

    ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        # Create backup directory if it doesn't exist
        mkdir -p ${BACKUP_DIR}

        # Put Nextcloud in maintenance mode
        echo 'Enabling maintenance mode...'
        kubectl exec -n nextcloud deployment/nextcloud-aio -- \
            php occ maintenance:mode --on >/dev/null 2>&1

        # Create backup directory
        BACKUP_PATH='${BACKUP_DIR}/${BACKUP_NAME}'
        mkdir -p \$BACKUP_PATH

        echo 'Backing up database...'
        # Backup PostgreSQL database
        kubectl exec -n nextcloud deployment/postgresql -- \
            pg_dump -U nextcloud nextcloud > \$BACKUP_PATH/database.sql

        echo 'Backing up files...'
        # Backup Nextcloud data
        kubectl exec -n nextcloud deployment/nextcloud-aio -- \
            tar -czf - -C /var/www/html/data . > \$BACKUP_PATH/files.tar.gz

        echo 'Backing up configuration...'
        # Backup configuration
        kubectl exec -n nextcloud deployment/nextcloud-aio -- \
            tar -czf - -C /var/www/html/config . > \$BACKUP_PATH/config.tar.gz

        # Take Nextcloud out of maintenance mode
        echo 'Disabling maintenance mode...'
        kubectl exec -n nextcloud deployment/nextcloud-aio -- \
            php occ maintenance:mode --off >/dev/null 2>&1

        # Create backup info file
        cat > \$BACKUP_PATH/backup-info.txt << EOF
Backup created: $(date)
Nextcloud version: \$(kubectl exec -n nextcloud deployment/nextcloud-aio -- php occ status | grep 'version:' | awk '{print \$2}')
Domain: ${NEXTCLOUD_DOMAIN}
Backup size: \$(du -sh \$BACKUP_PATH | awk '{print \$1}')
EOF

        echo 'Backup completed successfully'
        echo 'Backup location: \$BACKUP_PATH'
        echo 'Backup size: '\$(du -sh \$BACKUP_PATH | awk '{print \$1}')
    "

    log_success "Backup completed: ${BACKUP_NAME}"
}

# Restore function
restore_nextcloud() {
    if [ -z "$1" ]; then
        log_error "Usage: $0 restore <backup-name>"
        log_error "Available backups:"
        list_backups
        exit 1
    fi

    BACKUP_NAME=$1
    BACKUP_DIR="/opt/nextcloud-backups"
    BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

    log_warning "=== Starting Nextcloud Restore ==="
    log_warning "This will overwrite existing Nextcloud data!"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restore cancelled"
        exit 0
    fi

    # Check if backup exists
    if ! ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "[ -d '${BACKUP_PATH}' ]"; then
        log_error "Backup '${BACKUP_NAME}' not found"
        log_error "Available backups:"
        list_backups
        exit 1
    fi

    ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        # Put Nextcloud in maintenance mode
        echo 'Enabling maintenance mode...'
        kubectl exec -n nextcloud deployment/nextcloud-aio -- \
            php occ maintenance:mode --on >/dev/null 2>&1

        # Restore database
        echo 'Restoring database...'
        kubectl exec -i -n nextcloud deployment/postgresql -- \
            psql -U nextcloud nextcloud < ${BACKUP_PATH}/database.sql

        # Restore files
        echo 'Restoring files...'
        kubectl exec -i -n nextcloud deployment/nextcloud-aio -- \
            tar -xzf - -C /var/www/html/data < ${BACKUP_PATH}/files.tar.gz

        # Restore configuration
        echo 'Restoring configuration...'
        kubectl exec -i -n nextcloud deployment/nextcloud-aio -- \
            tar -xzf - -C /var/www/html/config < ${BACKUP_PATH}/config.tar.gz

        # Update file cache
        echo 'Updating file cache...'
        kubectl exec -n nextcloud deployment/nextcloud-aio -- \
            php occ files:scan --all >/dev/null 2>&1

        # Take Nextcloud out of maintenance mode
        echo 'Disabling maintenance mode...'
        kubectl exec -n nextcloud deployment/nextcloud-aio -- \
            php occ maintenance:mode --off >/dev/null 2>&1

        echo 'Restore completed successfully'
    "

    log_success "Restore completed from: ${BACKUP_NAME}"
}

# List backups function
list_backups() {
    log_info "=== Available Backups ==="

    ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        BACKUP_DIR='/opt/nextcloud-backups'
        if [ -d \$BACKUP_DIR ]; then
            echo 'Backup Directory: \$BACKUP_DIR'
            echo ''
            for backup in \$(ls -t \$BACKUP_DIR 2>/dev/null); do
                if [ -d \$BACKUP_DIR/\$backup ]; then
                    SIZE=\$(du -sh \$BACKUP_DIR/\$backup 2>/dev/null | awk '{print \$1}')
                    DATE=\$(stat -c '%y' \$BACKUP_DIR/\$backup 2>/dev/null | cut -d'.' -f1)
                    echo \"  \$backup (Size: \$SIZE, Date: \$DATE)\"
                fi
            done
        else
            echo 'No backups found'
        fi
    "
}

# Cleanup old backups function
cleanup_backups() {
    RETENTION_DAYS=${NEXTCLOUD_BACKUP_RETENTION:-7}

    log_info "=== Cleaning up old backups (retention: ${RETENTION_DAYS} days) ==="

    ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        BACKUP_DIR='/opt/nextcloud-backups'
        if [ -d \$BACKUP_DIR ]; then
            find \$BACKUP_DIR -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} + 2>/dev/null || true
            echo 'Cleanup completed'
        else
            echo 'No backup directory found'
        fi
    "

    log_success "Backup cleanup completed"
}

# Main script logic
get_mgmt_host

case "${1:-backup}" in
    backup)
        check_nextcloud
        backup_nextcloud
        ;;
    restore)
        check_nextcloud
        restore_nextcloud "$2"
        ;;
    list)
        list_backups
        ;;
    cleanup)
        cleanup_backups
        ;;
    *)
        echo "Usage: $0 {backup|restore <backup-name>|list|cleanup}"
        echo "  backup  - Create a new backup"
        echo "  restore - Restore from a specific backup"
        echo "  list    - List available backups"
        echo "  cleanup - Remove old backups based on retention policy"
        exit 1
        ;;
esac