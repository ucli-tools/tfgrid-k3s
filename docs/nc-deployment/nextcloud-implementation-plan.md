# Nextcloud AIO Implementation Guide

This guide provides detailed implementation instructions for deploying Nextcloud All-in-One on the K3s cluster. These instructions should be followed by the implementation team or AI Coder to create the actual deployment scripts and configurations.

## Implementation Files to Create

### 1. Main Deployment Script: `scripts/nextcloud.sh`

This script orchestrates the entire Nextcloud deployment process.

```bash
#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLATFORM_DIR="${REPO_ROOT}/platform"
NEXTCLOUD_DIR="${REPO_ROOT}/nextcloud"

# Load configuration
source "${SCRIPT_DIR}/nextcloud-config.sh"

# Check if platform exists by checking inventory
if [ ! -f "${PLATFORM_DIR}/inventory.ini" ]; then
  echo "⚠️ Ansible inventory not found!"
  echo "Platform must be deployed first. Run:"
  echo "  make platform"
  exit 1
fi

# Get management node IP
MGMT_HOST=$(grep "mgmt_host ansible_host" "${PLATFORM_DIR}/inventory.ini" | awk '{print $2}' | cut -d= -f2)
if [ -z "$MGMT_HOST" ]; then
  echo "Error: Could not retrieve management node IP from inventory."
  exit 1
fi

# Function to deploy using kubectl on management node
deploy_on_management() {
  local yaml_file=$1
  local description=$2
  echo "Deploying ${description}..."
  scp -o StrictHostKeyChecking=no "${yaml_file}" root@${MGMT_HOST}:/tmp/
  ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "kubectl apply -f /tmp/$(basename ${yaml_file})"
}

# Main deployment function
main() {
  case "${1:-deploy}" in
    deploy)
      echo "=== Deploying Nextcloud AIO to K3s Cluster ==="
      
      # Step 1: Create namespace
      deploy_on_management "${NEXTCLOUD_DIR}/namespace.yaml" "Nextcloud namespace"
      
      # Step 2: Deploy cert-manager if not already present
      ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        if ! kubectl get deployment -n cert-manager cert-manager &>/dev/null; then
          echo 'Installing cert-manager...'
          kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
          sleep 30
        fi
      "
      
      # Step 3: Deploy storage configuration
      deploy_on_management "${NEXTCLOUD_DIR}/storage/storageclass.yaml" "StorageClass"
      deploy_on_management "${NEXTCLOUD_DIR}/storage/pvcs.yaml" "Persistent Volume Claims"
      
      # Step 4: Configure SSL issuer
      envsubst < "${NEXTCLOUD_DIR}/ingress/issuer.yaml" | ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "kubectl apply -f -"
      
      # Step 5: Deploy Nextcloud AIO
      echo "Deploying Nextcloud AIO..."
      ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        # Add Nextcloud AIO Helm repository
        helm repo add nextcloud https://nextcloud.github.io/helm/
        helm repo update
        
        # Install Nextcloud AIO
        helm upgrade --install nextcloud-aio nextcloud/nextcloud \
          --namespace nextcloud \
          --values /tmp/nextcloud-values.yaml \
          --wait --timeout 10m
      "
      
      # Step 6: Configure ingress
      envsubst < "${NEXTCLOUD_DIR}/ingress/ingress.yaml" | ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "kubectl apply -f -"
      
      # Step 7: Wait for deployment to be ready
      echo "Waiting for Nextcloud to be ready..."
      ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        kubectl wait --for=condition=available --timeout=600s \
          deployment/nextcloud-aio -n nextcloud
      "
      
      # Step 8: Get admin password
      echo "=== Nextcloud Deployment Complete ==="
      echo "Getting admin credentials..."
      ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        echo 'Admin password:'
        kubectl get secret -n nextcloud nextcloud-aio -o jsonpath='{.data.admin-password}' | base64 -d
        echo ''
        echo 'Access URL: https://${NEXTCLOUD_DOMAIN}'
      "
      ;;
      
    clean)
      echo "=== Cleaning Nextcloud Deployment ==="
      ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        helm uninstall nextcloud-aio -n nextcloud || true
        kubectl delete namespace nextcloud || true
      "
      ;;
      
    status)
      echo "=== Nextcloud Status ==="
      ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
        kubectl get all -n nextcloud
        echo '---'
        kubectl get ingress -n nextcloud
        echo '---'
        kubectl get pvc -n nextcloud
      "
      ;;
      
    *)
      echo "Usage: $0 {deploy|clean|status}"
      exit 1
      ;;
  esac
}

main "$@"
```

### 2. Configuration Script: `scripts/nextcloud-config.sh`

Environment configuration for Nextcloud deployment.

```bash
#!/bin/bash

# Default configuration values
export NEXTCLOUD_DOMAIN="${NEXTCLOUD_DOMAIN:-nextcloud.example.com}"
export NEXTCLOUD_ADMIN_EMAIL="${NEXTCLOUD_ADMIN_EMAIL:-admin@example.com}"
export NEXTCLOUD_STORAGE_SIZE="${NEXTCLOUD_STORAGE_SIZE:-100}"
export NEXTCLOUD_DB_SIZE="${NEXTCLOUD_DB_SIZE:-20}"
export NEXTCLOUD_REDIS_SIZE="${NEXTCLOUD_REDIS_SIZE:-5}"
export NEXTCLOUD_BACKUP_SIZE="${NEXTCLOUD_BACKUP_SIZE:-50}"

# Check for required environment variables
if [ -z "$NEXTCLOUD_DOMAIN" ]; then
  echo "Error: NEXTCLOUD_DOMAIN environment variable is not set"
  echo "Please set it in infrastructure/credentials.auto.tfvars or export it"
  exit 1
fi

# Display configuration
echo "Nextcloud Configuration:"
echo "  Domain: ${NEXTCLOUD_DOMAIN}"
echo "  Admin Email: ${NEXTCLOUD_ADMIN_EMAIL}"
echo "  Storage Size: ${NEXTCLOUD_STORAGE_SIZE}Gi"
echo "  Database Size: ${NEXTCLOUD_DB_SIZE}Gi"
echo "  Redis Size: ${NEXTCLOUD_REDIS_SIZE}Gi"
echo ""
```

### 3. Namespace Definition: `nextcloud/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nextcloud
  labels:
    name: nextcloud
    app.kubernetes.io/name: nextcloud
```

### 4. StorageClass Configuration: `nextcloud/storage/storageclass.yaml`

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nextcloud-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: rancher.io/local-path
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
```

### 5. Persistent Volume Claims: `nextcloud/storage/pvcs.yaml`

```yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nextcloud-data
  namespace: nextcloud
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nextcloud-storage
  resources:
    requests:
      storage: ${NEXTCLOUD_STORAGE_SIZE}Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nextcloud-db
  namespace: nextcloud
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nextcloud-storage
  resources:
    requests:
      storage: ${NEXTCLOUD_DB_SIZE}Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nextcloud-redis
  namespace: nextcloud
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nextcloud-storage
  resources:
    requests:
      storage: ${NEXTCLOUD_REDIS_SIZE}Gi
```

### 6. SSL Certificate Issuer: `nextcloud/ingress/issuer.yaml`

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${NEXTCLOUD_ADMIN_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

### 7. Ingress Configuration: `nextcloud/ingress/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nextcloud-ingress
  namespace: nextcloud
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-body-size: "10G"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-headers: "X-Forwarded-For"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - ${NEXTCLOUD_DOMAIN}
    secretName: nextcloud-tls
  rules:
  - host: ${NEXTCLOUD_DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nextcloud-aio
            port:
              number: 80
```

### 8. Helm Values: `nextcloud/values/nextcloud-aio.yaml`

```yaml
# Nextcloud All-in-One Helm Values
image:
  repository: nextcloud/all-in-one
  tag: latest
  pullPolicy: IfNotPresent

nextcloud:
  host: ${NEXTCLOUD_DOMAIN}
  username: admin
  password: "" # Will be auto-generated
  
  configs:
    overwrite.cli.url: "https://${NEXTCLOUD_DOMAIN}"
    trusted_domains: "${NEXTCLOUD_DOMAIN}"
    trusted_proxies: "10.0.0.0/8"
    
  mail:
    enabled: true
    fromAddress: noreply
    domain: ${NEXTCLOUD_DOMAIN#*.}
    smtp:
      secure: ssl
      port: 465
      authtype: LOGIN

persistence:
  enabled: true
  existingClaim: nextcloud-data
  
postgresql:
  enabled: true
  auth:
    database: nextcloud
    username: nextcloud
  primary:
    persistence:
      enabled: true
      existingClaim: nextcloud-db
      
redis:
  enabled: true
  auth:
    enabled: true
  master:
    persistence:
      enabled: true
      existingClaim: nextcloud-redis

cronjob:
  enabled: true

metrics:
  enabled: true
  serviceMonitor:
    enabled: false

# Resource allocation
resources:
  limits:
    cpu: 4
    memory: 8Gi
  requests:
    cpu: 2
    memory: 4Gi

# Nextcloud apps to enable
apps:
  enabled:
    - admin_audit
    - bruteforcesettings
    - calendar
    - contacts
    - deck
    - files_external
    - files_pdfviewer
    - files_rightclick
    - files_versions
    - files_trashbin
    - mail
    - notes
    - notifications
    - password_policy
    - photos
    - richdocuments
    - spreed
    - tasks
    - text
    - twofactor_totp
    - user_ldap
    - viewer

# High Availability settings
replicaCount: 1

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
```

### 9. Backup Script: `scripts/nextcloud-backup.sh`

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLATFORM_DIR="${REPO_ROOT}/platform"

# Get management node IP
MGMT_HOST=$(grep "mgmt_host ansible_host" "${PLATFORM_DIR}/inventory.ini" | awk '{print $2}' | cut -d= -f2)

case "${1:-backup}" in
  backup)
    echo "=== Starting Nextcloud Backup ==="
    ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
      # Put Nextcloud in maintenance mode
      kubectl exec -n nextcloud deployment/nextcloud-aio -- \
        php occ maintenance:mode --on
      
      # Create backup
      BACKUP_NAME=nextcloud-backup-\$(date +%Y%m%d-%H%M%S)
      
      # Backup database
      kubectl exec -n nextcloud deployment/postgresql -- \
        pg_dump -U nextcloud nextcloud > /tmp/\${BACKUP_NAME}-db.sql
      
      # Create backup job
      kubectl create job -n nextcloud \${BACKUP_NAME} \
        --from=cronjob/nextcloud-backup
      
      # Wait for backup to complete
      kubectl wait --for=condition=complete --timeout=3600s \
        job/\${BACKUP_NAME} -n nextcloud
      
      # Take Nextcloud out of maintenance mode
      kubectl exec -n nextcloud deployment/nextcloud-aio -- \
        php occ maintenance:mode --off
      
      echo 'Backup completed: '\${BACKUP_NAME}
    "
    ;;
    
  restore)
    if [ -z "$2" ]; then
      echo "Usage: $0 restore <backup-name>"
      exit 1
    fi
    
    echo "=== Starting Nextcloud Restore ==="
    BACKUP_NAME=$2
    ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
      # Put Nextcloud in maintenance mode
      kubectl exec -n nextcloud deployment/nextcloud-aio -- \
        php occ maintenance:mode --on
      
      # Restore database
      kubectl exec -i -n nextcloud deployment/postgresql -- \
        psql -U nextcloud nextcloud < /backups/\${BACKUP_NAME}-db.sql
      
      # Restore files
      kubectl exec -n nextcloud deployment/nextcloud-aio -- \
        tar -xzf /backups/\${BACKUP_NAME}-files.tar.gz -C /var/www/html/data
      
      # Update file cache
      kubectl exec -n nextcloud deployment/nextcloud-aio -- \
        php occ files:scan --all
      
      # Take Nextcloud out of maintenance mode
      kubectl exec -n nextcloud deployment/nextcloud-aio -- \
        php occ maintenance:mode --off
      
      echo 'Restore completed from: '\${BACKUP_NAME}
    "
    ;;
    
  list)
    echo "=== Available Backups ==="
    ssh -o StrictHostKeyChecking=no root@${MGMT_HOST} "
      kubectl exec -n nextcloud deployment/nextcloud-aio -- \
        ls -la /backups/ | grep nextcloud-backup
    "
    ;;
    
  *)
    echo "Usage: $0 {backup|restore <backup-name>|list}"
    exit 1
    ;;
esac
```

### 10. Makefile Additions

Add these targets to the existing Makefile:

```makefile
# Nextcloud deployment targets
.PHONY: nextcloud nextcloud-backup nextcloud-restore nextcloud-status clean-nextcloud

# Deploy Nextcloud AIO
nextcloud:
	@echo "Deploying Nextcloud All-in-One..."
	cd scripts && bash nextcloud.sh deploy

# Check Nextcloud status
nextcloud-status:
	cd scripts && bash nextcloud.sh status

# Backup Nextcloud data
nextcloud-backup:
	cd scripts && bash nextcloud-backup.sh backup

# Restore Nextcloud from backup
nextcloud-restore:
	@read -p "Enter backup name to restore: " BACKUP_NAME; \
	cd scripts && bash nextcloud-backup.sh restore $$BACKUP_NAME

# List available backups
nextcloud-backup-list:
	cd scripts && bash nextcloud-backup.sh list

# Clean Nextcloud deployment
clean-nextcloud:
	cd scripts && bash nextcloud.sh clean

# Full deployment including Nextcloud
all-with-nextcloud: infrastructure platform app nextcloud

# Add to help target
help:
	@echo "  make nextcloud       - Deploy Nextcloud All-in-One"
	@echo "  make nextcloud-status - Check Nextcloud deployment status"
	@echo "  make nextcloud-backup - Backup Nextcloud data"
	@echo "  make nextcloud-restore - Restore Nextcloud from backup"
	@echo "  make clean-nextcloud - Remove Nextcloud deployment"
```

### 11. Configuration Template Addition

Add to `infrastructure/credentials.auto.tfvars.example`:

```hcl
#------------------------------------------------------------
# Nextcloud Configuration
#------------------------------------------------------------
# nextcloud_domain = "nextcloud.example.com"  # Your domain for Nextcloud
# nextcloud_admin_email = "admin@example.com" # Admin email for Let's Encrypt
# nextcloud_storage_size = 100                # GB for Nextcloud data
# nextcloud_db_size = 20                      # GB for PostgreSQL database
# nextcloud_redis_size = 5                    # GB for Redis cache
# nextcloud_backup_retention = 7              # Days to keep backups
```

### 12. Ansible Role: `platform/roles/nextcloud/tasks/main.yml`

```yaml
---
- name: Ensure Nextcloud directories exist on management node
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: '0755'
  with_items:
    - /root/nextcloud
    - /root/nextcloud/manifests
    - /root/nextcloud/backups
  become: true

- name: Copy Nextcloud manifests to management node
  ansible.builtin.copy:
    src: "{{ item }}"
    dest: "/root/nextcloud/manifests/"
    mode: '0644'
  with_fileglob:
    - "{{ playbook_dir }}/../nextcloud/**/*.yaml"
  become: true

- name: Template Nextcloud values file
  ansible.builtin.template:
    src: nextcloud-values.yaml.j2
    dest: /root/nextcloud/nextcloud-values.yaml
    mode: '0644'
  become: true

- name: Create backup cronjob
  ansible.builtin.cron:
    name: "Nextcloud daily backup"
    hour: "2"
    minute: "0"
    job: "/root/tfgrid-k3s/scripts/nextcloud-backup.sh backup"
    state: present
  become: true
```

## Testing Procedures

### Initial Deployment Test
1. Run `make nextcloud`
2. Verify all pods are running: `kubectl get pods -n nextcloud`
3. Check certificate status: `kubectl get certificate -n nextcloud`
4. Access Nextcloud via browser at configured domain
5. Log in with admin credentials

### Functionality Tests
1. Create test users
2. Upload test files
3. Share files between users
4. Test Collabora Online document editing
5. Test Talk video calls
6. Test calendar and contacts sync

### Backup/Restore Test
1. Create test data in Nextcloud
2. Run `make nextcloud-backup`
3. Delete some test data
4. Run `make nextcloud-restore`
5. Verify data is restored

### Performance Test
1. Use Apache Bench or similar tool for load testing
2. Monitor resource usage during load
3. Check response times
4. Verify autoscaling if enabled

## Monitoring Setup

Add Prometheus ServiceMonitor for Nextcloud metrics:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nextcloud
  namespace: nextcloud
spec:
  selector:
    matchLabels:
      app: nextcloud
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

## Security Hardening

1. Enable fail2ban for brute force protection
2. Configure CSP headers in ingress
3. Enable 2FA for all admin accounts
4. Regular security updates via automated jobs
5. Network policies to restrict pod communication

## Troubleshooting Commands

```bash
# Check pod status
kubectl get pods -n nextcloud -o wide

# View pod logs
kubectl logs -n nextcloud deployment/nextcloud-aio

# Check ingress
kubectl describe ingress -n nextcloud nextcloud-ingress

# Check certificate
kubectl describe certificate -n nextcloud nextcloud-tls

# Check PVC status
kubectl get pvc -n nextcloud

# Execute commands in Nextcloud pod
kubectl exec -it -n nextcloud deployment/nextcloud-aio -- bash

# Check Nextcloud status
kubectl exec -n nextcloud deployment/nextcloud-aio -- php occ status

# List Nextcloud apps
kubectl exec -n nextcloud deployment/nextcloud-aio -- php occ app:list
```

## Post-Deployment Configuration

1. Configure SMTP settings for email notifications
2. Set up external storage (S3, etc.) if needed
3. Configure LDAP/AD integration if required
4. Set up backup to external location
5. Configure monitoring and alerting
6. Document admin procedures

This completes the implementation guide for Nextcloud AIO on K3s.