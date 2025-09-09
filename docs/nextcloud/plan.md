# Nextcloud App Implementation Plan for TFGrid K3s

## Executive Summary

This document outlines the implementation plan for deploying Nextcloud as a modular application within the TFGrid K3s infrastructure. The implementation follows industry-standard practices with a modular, scalable architecture that supports dynamic cluster configurations (X masters, Y workers).

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
│       ├── deploy.sh              # App-specific deployment script
│       ├── backup.sh              # App-specific backup script
│       ├── namespace.yaml
│       ├── storage/
│       │   ├── storageclass.yaml  # Storage configuration
│       │   └── pvcs.yaml          # Persistent volumes
│       ├── ingress/
│       │   ├── cert-manager.yaml  # SSL certificates
│       │   └── ingress.yaml       # Load balancing
│       └── values/
│           └── nextcloud-aio.yaml # Helm configuration
├── scripts/
│   ├── app.sh                     # Dispatcher script
│   └── nextcloud-config.sh        # Dynamic configuration
└── Makefile                       # Updated with app targets
```

### Dynamic Cluster Adaptation
The implementation automatically adapts to your configured cluster size:

- **Automatic Detection**: Reads `platform/inventory.ini` to detect X masters and Y workers
- **Dynamic Resource Allocation**: Calculates optimal CPU/memory based on cluster size
- **Adaptive HA Settings**: Enables appropriate HA features based on cluster capabilities
- **Flexible Storage**: Distributes storage across available worker nodes

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

### 3. Dynamic Configuration System

#### Cluster Detection (`scripts/nextcloud-config.sh`)
- **Automatic Detection**: Parses `platform/inventory.ini` for node counts
- **Resource Calculation**: Computes optimal resource allocation based on cluster size
- **HA Configuration**: Adapts settings based on available nodes
- **Environment Variables**: Exports configuration for deployment scripts

#### Resource Allocation Examples

**Small Cluster (1 Master + 2 Workers):**
```bash
Control Nodes: 1
Worker Nodes: 2
CPU Requests: 2 cores per node
Memory Requests: 4GB per node
HA Mode: Basic
```

**Medium Cluster (3 Masters + 3 Workers):**
```bash
Control Nodes: 3
Worker Nodes: 3
CPU Requests: 2 cores per node
Memory Requests: 4GB per node
HA Mode: Full
```

**Large Cluster (5 Masters + 7 Workers):**
```bash
Control Nodes: 5
Worker Nodes: 7
CPU Requests: 4 cores per node
Memory Requests: 8GB per node
HA Mode: Enterprise
```

### 4. Kubernetes Manifests

#### Core Components
- **Namespace**: Isolated deployment environment
- **Storage**: Persistent volumes for data, database, and cache
- **Ingress**: SSL/TLS termination and load balancing
- **Helm Values**: Nextcloud AIO configuration with dynamic variables

#### HA Configuration for X Master/Y Worker
- **Storage Distribution**: PVCs across worker nodes with proper anti-affinity
- **Resource Allocation**: Scaled CPU/memory limits based on cluster size
- **Load Balancing**: NGINX ingress with session persistence
- **Monitoring**: Prometheus metrics for all components

### 5. Configuration Management

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

### 6. Makefile Integration

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
	@echo "Usage: make nextcloud-restore BACKUP_NAME=<backup-name>"
	@cd apps/nextcloud && bash backup.sh restore $(BACKUP_NAME)
```

#### Usage Examples
```bash
# Deploy Nextcloud
make app nextcloud
make nextcloud

# Management commands
make nextcloud-status
make nextcloud-backup
make nextcloud-restore BACKUP_NAME=nextcloud-backup-20231201

# Multiple apps (future)
make app nextcloud wordpress
```

## Implementation Phases

### Phase 1: Directory Structure & Core Scripts
1. Create `apps/nextcloud/` directory structure
2. Implement `apps/nextcloud/deploy.sh`
3. Create `scripts/nextcloud-config.sh` with dynamic detection
4. Update `scripts/app.sh` dispatcher

### Phase 2: Kubernetes Manifests
1. Create namespace, storage, and ingress YAMLs
2. Configure Helm values with dynamic variables
3. Set up cert-manager for SSL/TLS
4. Configure HA settings for variable cluster sizes

### Phase 3: Integration & Testing
1. Update Makefile with new targets
2. Add configuration variables
3. Test deployment on different cluster configurations
4. Validate dynamic resource allocation

### Phase 4: Documentation & Production
1. Update deployment documentation
2. Create troubleshooting guides
3. Set up monitoring and alerts
4. Production deployment validation

## Dynamic HA Configuration

### Cluster Size Detection
The system automatically detects cluster configuration from `platform/inventory.ini`:

```ini
[k3s_control]
node1 ansible_host=10.1.4.2 ansible_user=root
node2 ansible_host=10.1.5.2 ansible_user=root
node3 ansible_host=10.1.6.2 ansible_user=root

[k3s_worker]
node4 ansible_host=10.1.7.2 ansible_user=root
node5 ansible_host=10.1.8.2 ansible_user=root
node6 ansible_host=10.1.9.2 ansible_user=root
```

### Adaptive HA Settings

#### Single Worker Node
- **HA Mode**: Disabled
- **Replicas**: 1
- **Anti-affinity**: Disabled
- **Resources**: Conservative

#### 2-3 Worker Nodes
- **HA Mode**: Basic
- **Replicas**: 1
- **Anti-affinity**: Optional
- **Resources**: Balanced

#### 4+ Worker Nodes
- **HA Mode**: Full
- **Replicas**: 1
- **Anti-affinity**: Enabled
- **Resources**: High-performance

### Resource Allocation Algorithm
```bash
# Calculate available resources
TOTAL_CPU = WORKER_NODES × WORKER_CPU_BASE
TOTAL_MEM = WORKER_NODES × WORKER_MEM_BASE

# Allocate for Nextcloud (60% of total)
NEXTCLOUD_CPU_REQUESTS = (TOTAL_CPU × 0.6) ÷ WORKER_NODES
NEXTCLOUD_CPU_LIMITS = (TOTAL_CPU × 0.8) ÷ WORKER_NODES
NEXTCLOUD_MEM_REQUESTS = (TOTAL_MEM × 0.6) ÷ WORKER_NODES
NEXTCLOUD_MEM_LIMITS = (TOTAL_MEM × 0.8) ÷ WORKER_NODES

# Apply minimums
NEXTCLOUD_CPU_REQUESTS = max(NEXTCLOUD_CPU_REQUESTS, 2)
NEXTCLOUD_MEM_REQUESTS = max(NEXTCLOUD_MEM_REQUESTS, 4096)
```

## Security Configuration

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

## Backup and Disaster Recovery

### Automated Backups
- **Daily backups**: Scheduled at 2 AM
- **Retention policy**: Configurable retention periods
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

## Monitoring and Maintenance

### Monitoring Stack
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Alert Manager**: Critical issue notifications

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
- **Dynamic Adaptation**: Automatic scaling with cluster size
- **Resource Optimization**: Efficient resource utilization
- **Horizontal Scaling**: Support for additional worker nodes

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

This implementation plan provides a production-ready, industry-standard approach to deploying Nextcloud on the TFGrid K3s infrastructure. The dynamic cluster adaptation ensures optimal performance and HA configuration regardless of whether you have 1 master + 2 workers or 5 masters + 10 workers.

The modular architecture ensures scalability, maintainability, and ease of extending to additional applications while maintaining the existing make-based deployment workflow.

**Key Innovation**: Unlike static configurations, this implementation automatically adapts to your actual cluster topology, providing optimal resource utilization and HA settings for any X master/Y worker configuration.