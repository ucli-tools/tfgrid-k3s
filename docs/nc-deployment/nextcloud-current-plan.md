# Nextcloud App Implementation Plan for TFGrid K3s

## Executive Summary

This document outlines the implementation plan for deploying Nextcloud as a modular application within the TFGrid K3s infrastructure. The implementation follows industry-standard practices with a modular, scalable architecture that supports multiple applications.

## Architecture Overview

### Current Infrastructure
- **Platform**: K3s cluster on ThreeFold Grid with configurable master/worker nodes
- **Management**: Dedicated management node with kubectl, helm, and ansible
- **Deployment**: Make-based automation system with infrastructure → platform → app flow

### Target Architecture
```
tfgrid-k3s/
├── apps/
│   └── nextcloud/
│       ├── deploy.sh          # App-specific deployment script
│       ├── backup.sh          # App-specific backup script
│       ├── namespace.yaml
│       ├── storage/
│       │   ├── storageclass.yaml
│       │   └── pvcs.yaml
│       ├── ingress/
│       │   ├── cert-manager.yaml
│       │   ├── issuer.yaml
│       │   └── ingress.yaml
│       └── values/
│           └── nextcloud-aio.yaml
├── scripts/
│   ├── app.sh                 # Dispatcher script
│   └── nextcloud-config.sh    # Shared configuration
└── Makefile                   # Updated with app targets
```

## Implementation Components

### 1. Directory Structure & File Organization

#### Apps Directory Structure
- `apps/nextcloud/`: Dedicated directory for Nextcloud application
- Self-contained with all necessary manifests and scripts
- Easy to replicate for additional applications

#### File Responsibilities
- `deploy.sh`: Main deployment orchestration
- `backup.sh`: Backup and restore operations
- `*.yaml`: Kubernetes manifests for deployment
- `values/`: Helm chart customizations

### 2. Deployment Scripts

#### Main Deployment Script (`apps/nextcloud/deploy.sh`)
```bash
#!/bin/bash
# Nextcloud-specific deployment logic
# Handles: namespace, storage, ingress, helm deployment
```

#### Backup Script (`apps/nextcloud/backup.sh`)
```bash
#!/bin/bash
# Nextcloud-specific backup/restore operations
# Handles: database dumps, file backups, point-in-time recovery
```

#### Dispatcher Script (`scripts/app.sh`)
```bash
#!/bin/bash
# Lightweight dispatcher for app-specific deployments
# Usage: make app nextcloud -> calls apps/nextcloud/deploy.sh
```

### 3. Kubernetes Manifests

#### Core Components
- **Namespace**: Isolated deployment environment
- **Storage**: Persistent volumes for data, database, and cache
- **Ingress**: SSL/TLS termination and load balancing
- **Helm Values**: Nextcloud AIO configuration

#### HA Configuration for 3Master/3Worker
- **Storage Distribution**: PVCs across worker nodes
- **Resource Allocation**: Scaled for multi-node setup
- **Load Balancing**: NGINX ingress with session affinity
- **Monitoring**: Prometheus metrics collection

### 4. Configuration Management

#### Environment Variables
```bash
NEXTCLOUD_DOMAIN=nextcloud.example.com
NEXTCLOUD_STORAGE_SIZE=100
NEXTCLOUD_ADMIN_EMAIL=admin@example.com
```

#### Infrastructure Integration
- Variables defined in `infrastructure/credentials.auto.tfvars`
- Shared configuration in `scripts/nextcloud-config.sh`
- Environment-specific overrides

### 5. Makefile Integration

#### New Targets
```makefile
# App dispatcher
app:
	cd scripts && bash app.sh $(filter-out $@,$(MAKECMDGOALS))

# Direct app access
nextcloud:
	cd apps/nextcloud && bash deploy.sh

nextcloud-backup:
	cd apps/nextcloud && bash backup.sh backup

nextcloud-restore:
	cd apps/nextcloud && bash backup.sh restore $(BACKUP_NAME)
```

#### Usage Examples
```bash
# Deploy Nextcloud
make app nextcloud
make nextcloud

# Backup operations
make nextcloud-backup
make nextcloud-restore BACKUP_NAME=nextcloud-backup-20231201

# Multiple apps (future)
make app nextcloud wordpress
```

## Implementation Phases

### Phase 1: Directory Structure & Core Scripts
1. Create `apps/nextcloud/` directory structure
2. Implement `apps/nextcloud/deploy.sh`
3. Create `scripts/nextcloud-config.sh`
4. Update `scripts/app.sh` dispatcher

### Phase 2: Kubernetes Manifests
1. Create namespace, storage, and ingress YAMLs
2. Configure Helm values for Nextcloud AIO
3. Set up cert-manager for SSL/TLS
4. Configure HA settings for 3master/3worker

### Phase 3: Integration & Testing
1. Update Makefile with new targets
2. Add configuration variables
3. Test deployment on development environment
4. Validate HA functionality

### Phase 4: Documentation & Production
1. Update deployment documentation
2. Create troubleshooting guides
3. Set up monitoring and alerts
4. Production deployment validation

## High Availability Configuration

### 3Master/3Worker Optimization
- **Control Plane**: 3 master nodes for etcd quorum and API server HA
- **Data Plane**: 3 worker nodes for application pod distribution
- **Storage**: Distributed PVCs with anti-affinity rules
- **Networking**: Load balancer with session persistence
- **Monitoring**: Comprehensive metrics and alerting

### Resource Allocation
```yaml
# Master nodes: API server, etcd, control plane
resources:
  requests:
    cpu: 2
    memory: 4Gi
  limits:
    cpu: 4
    memory: 8Gi

# Worker nodes: Application pods, storage
resources:
  requests:
    cpu: 4
    memory: 8Gi
  limits:
    cpu: 8
    memory: 16Gi
```

### Storage Strategy
- **Data PVC**: 100-500GB distributed across workers
- **Database PVC**: 20GB with backup replication
- **Redis PVC**: 5GB for session caching
- **Backup Storage**: 50% of data size for retention

## Security Configuration

### Network Security
- **TLS 1.3**: End-to-end encryption
- **HSTS**: Strict transport security headers
- **Rate Limiting**: DDoS protection at ingress
- **Firewall Rules**: Minimal required access

### Application Security
- **Strong Passwords**: Enforced policies
- **2FA**: Available for all users
- **Brute Force Protection**: Automatic blocking
- **File Encryption**: At-rest encryption
- **Regular Updates**: Automated security patches

## Backup & Disaster Recovery

### Backup Strategy
- **Daily Automated**: Database and file backups
- **Incremental**: Efficient storage usage
- **Off-site**: ThreeFold Grid storage integration
- **Retention**: Configurable retention periods

### Recovery Procedures
- **Point-in-Time**: Database recovery to specific time
- **File Restore**: Individual or bulk file recovery
- **Full Restore**: Complete environment recovery
- **Testing**: Regular restore validation

## Monitoring & Maintenance

### Monitoring Stack
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Alert Manager**: Critical issue notifications
- **Logging**: Centralized log aggregation

### Maintenance Tasks
- **Weekly**: Security updates check
- **Monthly**: Performance review
- **Quarterly**: Capacity planning
- **Annually**: Disaster recovery drill

## Success Criteria

### Availability
- **99.9% Uptime**: SLA compliance
- **Page Load < 2s**: Performance target
- **A+ SSL Rating**: Security compliance

### Scalability
- **100+ Users**: Concurrent user support
- **Auto-scaling**: Resource adaptation
- **Horizontal Scaling**: Additional worker nodes

### Reliability
- **Daily Backups**: Automated and tested
- **< 1 hour RPO**: Recovery point objective
- **< 4 hour RTO**: Recovery time objective

## Future Extensions

### Additional Applications
The modular architecture supports easy addition of:
- **WordPress**: CMS with database and caching
- **Gitea**: Git repository management
- **Matrix**: Decentralized communication
- **Vault**: Secrets management

### Enhanced Features
- **Multi-cluster**: Cross-cluster deployments
- **GitOps**: Automated deployment pipelines
- **Service Mesh**: Advanced networking capabilities
- **AI/ML**: Integrated AI services

## Conclusion

This implementation plan provides a production-ready, industry-standard approach to deploying Nextcloud on the TFGrid K3s infrastructure. The modular architecture ensures scalability, maintainability, and ease of extending to additional applications while maintaining the existing make-based deployment workflow.

The HA configuration for 3master/3worker provides enterprise-grade reliability and performance, making it suitable for production workloads with high availability requirements.