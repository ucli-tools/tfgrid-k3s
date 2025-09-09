# Nextcloud Application for TFGrid K3s

This directory contains the complete Nextcloud All-in-One deployment for the TFGrid K3s cluster with High Availability support for 3master/3worker configurations.

## Overview

Nextcloud is deployed using the official Nextcloud AIO Helm chart with the following components:
- **Nextcloud Server**: Main application with web interface
- **PostgreSQL**: Primary database for data storage
- **Redis**: Session and file locking cache
- **Collabora Online**: Office document editing (optional)
- **Imaginary**: High-performance image preview generation
- **ClamAV**: Antivirus scanning
- **Fulltextsearch**: Elasticsearch-based full-text search

## Quick Start

### Prerequisites
1. Deploy infrastructure: `make infrastructure`
2. Deploy platform: `make platform`
3. Configure domain and SSL certificates in `infrastructure/credentials.auto.tfvars`

### Deployment
```bash
# Deploy Nextcloud
make app nextcloud

# Or deploy directly
make nextcloud
```

### Access
After deployment, Nextcloud will be available at:
- **URL**: `https://your-domain.com` (configured in credentials.auto.tfvars)
- **Admin User**: `admin`
- **Admin Password**: Displayed during deployment

## Configuration

### Environment Variables
Configure these in `infrastructure/credentials.auto.tfvars`:

```hcl
# Nextcloud domain and admin settings
nextcloud_domain = "nextcloud.yourdomain.com"
nextcloud_admin_email = "admin@yourdomain.com"

# Storage configuration (in GB)
nextcloud_storage_size = 100   # Nextcloud data storage
nextcloud_db_size = 20         # PostgreSQL database storage
nextcloud_redis_size = 5       # Redis cache storage

# Backup configuration
nextcloud_backup_retention = 7  # Days to keep backups
```

### Customization
Modify `values/nextcloud-aio.yaml` to customize:
- Resource limits and requests
- Enabled applications
- Security settings
- HA configuration

## High Availability Features

### 3Master/3Worker Support
- **Anti-affinity rules**: Ensures pods distribute across nodes
- **Pod disruption budget**: Maintains availability during updates
- **Resource optimization**: Scaled for multi-node deployment
- **Load balancing**: NGINX ingress with session persistence

### Storage
- **Distributed PVCs**: Data spread across worker nodes
- **Local storage**: K3s local-path provisioner
- **Backup integration**: Automated backup to management node

## Management Commands

### Status Check
```bash
make nextcloud-status
```

### Backup
```bash
# Create backup
make nextcloud-backup

# List available backups
cd apps/nextcloud && ./backup.sh list

# Restore from backup
make nextcloud-restore BACKUP_NAME=nextcloud-backup-20231201
```

### Cleanup
```bash
make clean-nextcloud
```

## File Structure

```
apps/nextcloud/
├── deploy.sh              # Main deployment script
├── backup.sh              # Backup and restore script
├── README.md              # This file
├── namespace.yaml         # Kubernetes namespace
├── storage/
│   ├── storageclass.yaml  # Storage class definition
│   └── pvcs.yaml          # Persistent volume claims
├── ingress/
│   ├── cert-manager.yaml  # SSL certificate management
│   └── ingress.yaml       # Ingress configuration
└── values/
    └── nextcloud-aio.yaml # Helm chart values
```

## Security

### Network Security
- **TLS 1.3**: End-to-end encryption
- **HSTS**: Strict transport security headers
- **Rate limiting**: DDoS protection at ingress
- **Firewall rules**: Minimal required access

### Application Security
- **Strong passwords**: Enforced policies
- **2FA support**: Available for all users
- **Brute force protection**: Automatic blocking
- **File encryption**: At-rest encryption
- **Regular updates**: Automated security patches

## Monitoring

### Metrics
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Alert Manager**: Critical issue notifications

### Health Checks
- **Pod health**: Kubernetes liveness/readiness probes
- **Service health**: Application-level health endpoints
- **Storage health**: PVC and PV monitoring

## Troubleshooting

### Common Issues

#### Certificate Issues
```bash
# Check certificate status
kubectl get certificate -n nextcloud

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

#### Storage Issues
```bash
# Check PVC status
kubectl get pvc -n nextcloud

# Check storage class
kubectl get storageclass
```

#### Deployment Issues
```bash
# Check pod status
kubectl get pods -n nextcloud

# Check pod logs
kubectl logs -n nextcloud deployment/nextcloud-aio
```

### Debug Commands
```bash
# Connect to management node
make connect

# Use k9s for cluster inspection
make k9s

# Check cluster events
kubectl get events -n nextcloud --sort-by=.metadata.creationTimestamp
```

## Backup and Recovery

### Automated Backups
- **Daily backups**: Scheduled at 2 AM
- **Retention policy**: Configurable retention period
- **Storage location**: `/opt/nextcloud-backups` on management node

### Manual Backup
```bash
cd apps/nextcloud
./backup.sh backup
```

### Recovery Process
1. Put Nextcloud in maintenance mode
2. Restore database from backup
3. Restore files from backup
4. Update file cache
5. Take Nextcloud out of maintenance mode

## Scaling

### Horizontal Scaling
- **Worker nodes**: Add more worker nodes to cluster
- **Pod replicas**: Increase replica count in values file
- **Load balancing**: NGINX ingress handles distribution

### Vertical Scaling
- **Resource limits**: Increase CPU/memory in values file
- **Storage**: Expand PVCs as needed
- **Database**: Scale PostgreSQL resources

## Support

### Documentation
- **Deployment plan**: `docs/nextcloud/plan.md`
- **Troubleshooting**: `docs/troubleshooting.md`
- **Infrastructure docs**: `docs/` directory

### Logs and Monitoring
- **Application logs**: `kubectl logs -n nextcloud deployment/nextcloud-aio`
- **System logs**: `kubectl logs -n kube-system`
- **Audit logs**: Nextcloud admin interface

## Contributing

### Adding New Features
1. Modify `values/nextcloud-aio.yaml` for configuration changes
2. Update `deploy.sh` for deployment logic changes
3. Test changes in development environment
4. Update documentation

### Code Standards
- **Shell scripts**: Bash with error handling
- **YAML**: Kubernetes standard formatting
- **Documentation**: Markdown with examples
- **Security**: Least privilege principles