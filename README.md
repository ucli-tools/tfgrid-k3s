# K3s Cluster Deployment on ThreeFold Grid

A complete solution for deploying a K3s Kubernetes cluster on ThreeFold Grid using Terraform/OpenTofu for infrastructure provisioning and Ansible for configuration management, with a dedicated management node equipped with K9s as a terminal user interface.

## Overview

This repository combines infrastructure provisioning via Terraform/OpenTofu with automated K3s cluster configuration using Ansible. The entire deployment process is automated through a single command, creating both the cluster nodes and a dedicated management node.

### Features

- **Dedicated Management Node**: A VM on ThreeFold Grid for managing your cluster
- **Infrastructure as Code**: Provisions all necessary infrastructure using Terraform/OpenTofu
- **Lightweight Kubernetes**: Uses K3s instead of full Kubernetes
- **Fully Automated**: Single command deployment with `make`
- **WireGuard Integration**: Secure network connectivity between nodes
- **Mycelium Integration**: IPv6 overlay network installed on all nodes
- **High Availability**: Support for HA cluster deployment
- **Scalable**: Support for multiple worker nodes
- **Ready for Apps**: Pre-configured for deploying your applications

## Architecture

The deployment consists of:

1. **Control Plane Nodes**: Run the Kubernetes control plane components (`k3s_control` group)
2. **Worker Nodes**: Run application workloads (`k3s_worker` group)
3. **Management Node**: Dedicated node for cluster management with all required tools (`k3s_management` group)

The management node lives within the same private network as your cluster nodes, providing secure management without exposing your cluster to the public internet.

## Prerequisites

- Linux/macOS system with bash
- [OpenTofu](https://opentofu.org/) (or Terraform) installed
- [Ansible](https://www.ansible.com/) installed
- [WireGuard](https://www.wireguard.com/) installed
- [jq](https://stedolan.github.io/jq/) installed
- ThreeFold account with sufficient TFT balance

## Quick Start

1. Clone this repository:
   ```
   git clone https://github.com/mik-tf/tfgrid-k3s
   cd tfgrid-k3s
   ```

2. Configure your deployment:
   ```bash
   # Set up Terraform/OpenTofu configuration for non-sensitive settings
   cp infrastructure/credentials.auto.tfvars.example infrastructure/credentials.auto.tfvars
   nano infrastructure/credentials.auto.tfvars

   # MAXIMUM SECURITY: Set up your ThreeFold mnemonic securely (prevents shell history recording)
   set +o history
   export TF_VAR_mnemonic="your_actual_mnemonic_phrase"
   set -o history

   # Alternative: Read from file (recommended)
   export TF_VAR_mnemonic="$(cat ~/.config/threefold/mnemonic)"

   # Or inline with deployment:
   TF_VAR_mnemonic="$(cat ~/.config/threefold/mnemonic)" make infrastructure
   ```

   See `docs/security.md` for more details on secure credential handling.

   > **SSH Key Auto-Detection**: The system will automatically use your SSH keys for deployment without requiring manual configuration. It first checks for `~/.ssh/id_ed25519.pub`, then falls back to `~/.ssh/id_rsa.pub` if needed. You can also manually specify your SSH key in the `credentials.auto.tfvars` file if desired.

3. Deploy the cluster:

   ```bash
   # Deploy everything in one go (infrastructure, platform, applications)
   make

   # Or deploy step by step:
   make infrastructure   # Deploy ThreeFold Grid VMs
   make platform         # Configure K3s on the infrastructure
   make app nextcloud    # Deploy Nextcloud with HA
   ```

   > **Tip**: Run `make help` to see all available make commands

4. After deployment, for security, unset the sensitive environment variable:
   ```bash
   unset TF_VAR_mnemonic
   ```

## Deployment Process

The deployment happens in three distinct phases, which can be run individually or together:

### 1. Infrastructure Deployment (`make infrastructure`)

Runs `scripts/infrastructure.sh`, which:
- Cleans up any previous infrastructure
- Initializes and applies Terraform/OpenTofu configuration
- Sets up WireGuard connections
- Generates the Ansible inventory based on deployed nodes
- Tests connectivity to all nodes

### 2. Platform Deployment (`make platform`)

Runs `scripts/platform.sh`, which:
- Configures the management node with required tools (Ansible, kubectl, Helm)
- Deploys the K3s control plane on the `k3s_control` nodes
- Joins worker nodes to the cluster
- Sets up kubectl configuration for easy access

### 3. Application Deployment (`make app`)

Runs `scripts/app.sh`, which:
- Verifies the cluster is ready
- Deploys your applications (customizable)

#### Nextcloud HA Deployment (`make app nextcloud`)

For production-grade Nextcloud deployment with **no single point of failure**:

**Features:**
- ✅ **DNS Round-Robin Load Balancing** across multiple public IPs
- ✅ **MetalLB IP Advertisement** for seamless IP management
- ✅ **Automatic SSL Certificates** via cert-manager + Let's Encrypt
- ✅ **Dynamic X Master/Y Worker Support** (adapts to any cluster size)
- ✅ **Enterprise HA Configuration** with PostgreSQL + Redis
- ✅ **Automated Backups** with point-in-time recovery

**Quick Deployment:**
```bash
# Deploy Nextcloud with HA
make app nextcloud

# Alternative direct deployment
make nextcloud
```

**Post-Deployment:**
```bash
# Check status
make nextcloud-status

# Create backup
make nextcloud-backup

# Access Nextcloud
# URL: https://your-domain.com (from nextcloud_domain variable)
# Admin: admin / [password shown during deployment]
```

**DNS Round-Robin Setup (No-SPOF):**
1. Deploy with `worker_public_ipv4 = true`
2. Get worker public IPs from deployment output
3. Create multiple DNS A records:
   ```
   nextcloud.yourdomain.com → PUBLIC_IP_WORKER_1
   nextcloud.yourdomain.com → PUBLIC_IP_WORKER_2
   nextcloud.yourdomain.com → PUBLIC_IP_WORKER_3
   ```
4. MetalLB automatically handles IP advertisement

See `docs/nextcloud/dns-round-robin-setup.md` for detailed instructions.

## Using the Management Node

The management node is your central location for all cluster operations. After deployment completes, you'll receive the management node's IP address.

### Connecting to the Management Node

```bash
# Connect to the management node
make connect

# Or directly:
ssh root@<management-node-ip>

# Connect to the management node and launch K9s TUI directly
make k9s
```

### Managing Your Cluster from the Management Node

Once connected to the management node, you can:

```bash
# Check cluster status
kubectl get nodes

# View running pods
kubectl get pods -A

# Run Helm commands
helm list -A

# Launch K9s Terminal UI for Kubernetes
k9s

# Update cluster configuration
cd ~/tfgrid-k3s/platform
ansible-playbook site.yml
```

The management node has all necessary tools pre-installed:
- kubectl
- K9s
- Ansible
- Helm
- OpenTofu
- WireGuard

## Additional Management Commands

```bash
# Check connectivity to all nodes
make ping

# Verify cluster permissions
make permissions

# Clean up deployment resources
make clean
```

## Project Structure

```
tfgrid_k3s/
├── infrastructure/    # Infrastructure provisioning (via OpenTofu)
│   ├── credentials.auto.tfvars.example  # Example configuration variables (non-sensitive)
│   └── main.tf        # Main infrastructure definition with secure variable handling
├── platform/          # Platform configuration and K3s deployment (via Ansible)
│   ├── roles/         # Configuration components
│   │   ├── common/    # Common configuration for all nodes
│   │   ├── control/   # K3s control plane configuration
│   │   ├── worker/    # K3s worker node configuration
│   │   ├── management/ # Management node configuration
│   │   └── kubeconfig/# kubectl configuration
│   └── site.yml       # Main deployment playbook
├── apps/              # Application deployments
│   └── nextcloud/     # Nextcloud HA deployment
│       ├── deploy.sh  # Nextcloud deployment script
│       ├── backup.sh  # Backup and restore operations
│       ├── namespace.yaml
│       ├── storage/   # Storage configuration
│       ├── ingress/   # SSL and load balancing
│       ├── metallb/   # MetalLB for no-SPOF IP management
│       └── values/    # Helm chart customizations
├── scripts/           # Deployment and utility scripts
│   ├── infrastructure.sh # Script to deploy infrastructure
│   ├── platform.sh    # Script to deploy platform
│   ├── app.sh         # Application dispatcher script
│   ├── nextcloud-config.sh # Nextcloud configuration
│   ├── cleantf.sh     # Script to clean Terraform/OpenTofu state
│   ├── ping.sh        # Connectivity test utility
│   └── wg.sh          # WireGuard setup script
├── Makefile           # Main interface for all deployment commands
└── docs/              # Additional documentation
    ├── security.md    # Security best practices documentation
    ├── troubleshooting.md # Solutions to common issues
    ├── k9s.md         # K9s documentation
    └── nextcloud/     # Nextcloud-specific documentation
        ├── plan.md    # Implementation plan
        └── dns-round-robin-setup.md # No-SPOF setup guide
```

## Network Configuration

### ThreeFold Grid Networks

You can deploy to different ThreeFold Grid networks:

```bash
# Production network (default)
export TF_VAR_network="main"

# Test network
export TF_VAR_network="test"

# Development network
export TF_VAR_network="dev"
```

**Note:** Add this to your `credentials.auto.tfvars` file or export as environment variable before running `make infrastructure`.

## Infrastructure Configuration

In your `credentials.auto.tfvars` file, you can configure:

```
# Management node specifications (defaults if not specified)
# management_cpu = 1      # 1 vCPU
# management_mem = 2048   # 2GB RAM
# management_disk = 25    # 25GB storage

# Optional: Set to false to deploy worker nodes without public IPv4 addresses
# worker_public_ipv4 = true  # Default is true

# Node IDs from ThreeFold Grid
control_nodes = [1000, 1001, 1002]  # Control plane node IDs
worker_nodes = [2000, 2001, 2002]   # Worker node IDs
management_node = 3000              # Management node ID

# Control plane node specifications
control_cpu = 4
control_mem = 8192   # 8GB RAM
control_disk = 100   # 100GB storage

# Worker node specifications
worker_cpu = 8
worker_mem = 16384   # 16GB RAM
worker_disk = 250    # 250GB storage
```

## Maintenance and Updates

### Updating Cluster Configuration

To update your cluster configuration, connect to the management node and run:

```bash
cd ~/tfgrid-k3s/platform
ansible-playbook site.yml
```

### Adding or Removing Nodes

To add or remove nodes:

1. Update your `credentials.auto.tfvars` file
2. Run `make infrastructure` again to update the infrastructure
3. Run `make platform` to reconfigure the cluster

## Troubleshooting

See the [troubleshooting guide](docs/troubleshooting.md) for common issues and solutions.

### Common Issues

#### Management Node Connection Issues

If you can't connect to the management node:

1. Verify the node has been deployed correctly:
   ```bash
   cd infrastructure
   tofu output management_node_wireguard_ip
   ```

2. Check WireGuard connection status:
   ```bash
   sudo wg show
   ```

#### Kubernetes Access Issues

If you can connect to the management node but can't access the cluster:

1. Check if kubectl is configured:
   ```bash
   kubectl cluster-info
   ```

2. Verify the cluster nodes are running:
   ```bash
   kubectl get nodes
   ```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
