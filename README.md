# K3s Cluster Deployment on ThreeFold Grid

A complete solution for deploying a K3s Kubernetes cluster on ThreeFold Grid using Terraform/OpenTofu for infrastructure provisioning and Ansible for configuration management, with a dedicated management node.

## Overview

This repository combines infrastructure provisioning via Terraform/OpenTofu with automated K3s cluster configuration using Ansible. The entire deployment process is automated through a single command, creating both the cluster nodes and a dedicated management node.

### Features

- **Dedicated Management Node**: A VM on ThreeFold Grid for managing your cluster
- **Infrastructure as Code**: Provisions all necessary infrastructure using Terraform/OpenTofu
- **Lightweight Kubernetes**: Uses K3s instead of full Kubernetes
- **Fully Automated**: Single command deployment with `deploy.sh`
- **WireGuard Integration**: Secure network connectivity between nodes
- **High Availability**: Support for HA cluster deployment
- **Scalable**: Support for multiple worker nodes
- **Ready for Apps**: Pre-configured for deploying your applications

## Architecture

The deployment consists of:

1. **Control Plane Nodes**: Run the Kubernetes control plane components
2. **Worker Nodes**: Run application workloads
3. **Management Node**: Dedicated node for cluster management with all required tools

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
   ```

   See `docs/security.md` for more details on secure credential handling.

   > **SSH Key Auto-Detection**: The system will automatically use your SSH keys for deployment without requiring manual configuration. It first checks for `~/.ssh/id_ed25519.pub`, then falls back to `~/.ssh/id_rsa.pub` if needed. You can also manually specify your SSH key in the `credentials.auto.tfvars` file if desired.

3. Deploy the cluster:

   **Option A**: Using Make (recommended)
   ```bash
   # Simply run make from the repository root
   make
   ```

   **Option B**: Directly using the script
   ```bash
   # Important: The script must be run from within the scripts directory
   cd scripts
   bash deploy.sh

   # Do NOT run it this way (will fail due to relative paths in the script):
   # bash scripts/deploy.sh
   ```

   > **Tip**: Run `make help` to see all available make commands

4. After deployment, for security, unset the sensitive environment variable:
   ```bash
   unset TF_VAR_mnemonic
   ```

   This will:
   - Provision the infrastructure with OpenTofu including the management node
   - Set up WireGuard for secure communications
   - Configure the management node with necessary tools
   - Deploy the K3s cluster using the management node
   - Set up kubectl on the management node

## Using the Management Node

The management node is your central location for all cluster operations. After deployment completes, you'll receive the management node's IP address.

### Connecting to the Management Node

```bash
# Connect to the management node
ssh root@<management-node-ip>

# Example: ssh root@185.206.122.33
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

# Update cluster configuration
cd ~/tfgrid-k3s/platform
ansible-playbook site.yml
```

The management node has all necessary tools pre-installed:
- kubectl
- Ansible
- Helm
- OpenTofu
- WireGuard

### Deployment Files Location

All deployment files are copied to the management node at `~/tfgrid-k3s/`:

```
tfgrid-k3s/
├── infrastructure/    # Infrastructure configuration
├── platform/          # Ansible playbooks and roles
└── scripts/           # Utility scripts
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
├── scripts/           # Deployment and utility scripts
│   ├── cleantf.sh     # Script to clean Terraform/OpenTofu state and files
│   ├── configure-dns.sh # DNS configuration utility
│   ├── deploy.sh      # Main deployment script with security checks
│   ├── generate-inventory.sh # Generate Ansible inventory from deployment
│   ├── ping.sh        # Connectivity test utility
│   └── wg.sh          # WireGuard setup script
└── docs/              # Additional documentation
    ├── security.md    # Security best practices documentation
    └── troubleshooting.md # Solutions to common issues
```

## Configuration

### Infrastructure Configuration

In your `credentials.auto.tfvars` file, you can configure:

```
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

# Management node specifications (defaults if not specified)
# management_cpu = 1      # 1 vCPU
# management_mem = 2048   # 2GB RAM
# management_disk = 25    # 25GB storage
```

### Advanced Configuration

The configuration files contain comments explaining each setting. You can customize:

- **Infrastructure**: Number of nodes, instance types, region, etc.
- **Kubernetes**: Number of control and worker nodes
- **Management Node**: CPU, memory, and storage allocation

Refer to the example files for all available configuration options.

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
2. Run the `deploy.sh` script again
3. The script will update your infrastructure and reconfigure the cluster

## Troubleshooting

See the [troubleshooting guide](docs/troubleshooting.md) for common issues and solutions.

### Management Node Issues

If you can't connect to the management node:

1. Verify the node has been deployed correctly:
   ```bash
   cd infrastructure
   tofu output management_node_ip
   ```

2. Check if you can ping the management node:
   ```bash
   ping <management-node-ip>
   ```

3. Verify SSH access:
   ```bash
   ssh -v root@<management-node-ip>
   ```

### Cluster Access Issues

If you can connect to the management node but can't access the cluster:

1. Check if kubectl is configured:
   ```bash
   kubectl cluster-info
   ```

2. Verify the kubeconfig:
   ```bash
   cat ~/.kube/config
   ```

3. Check if all nodes are running:
   ```bash
   kubectl get nodes
   ```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
