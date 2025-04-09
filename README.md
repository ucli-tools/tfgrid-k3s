# K3s Cluster Deployment on ThreeFold Grid

A complete solution for deploying a K3s Kubernetes cluster on ThreeFold Grid using Terraform/OpenTofu for infrastructure provisioning and Ansible for configuration management.

## Overview

This repository combines infrastructure provisioning via Terraform/OpenTofu with automated K3s cluster configuration using Ansible. The entire deployment process is automated through a single command.

### Features

- **Infrastructure as Code**: Provisions all necessary infrastructure using Terraform/OpenTofu
- **Lightweight Kubernetes**: Uses K3s instead of full Kubernetes
- **Fully Automated**: Single command deployment with `deploy.sh`
- **WireGuard Integration**: Secure network connectivity between nodes
- **High Availability**: Support for HA cluster deployment
- **Scalable**: Support for multiple worker nodes
- **Ready for Apps**: Pre-configured for deploying your applications

## Prerequisites

- Linux/macOS system with bash
- [OpenTofu](https://opentofu.org/) (or Terraform) installed
- [Ansible](https://www.ansible.com/) installed
- [WireGuard](https://www.wireguard.com/) installed
- [jq](https://stedolan.github.io/jq/) installed

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
   - Provision the infrastructure with OpenTofu
   - Set up WireGuard for secure communications
   - Deploy the K3s cluster
   - Set up your local kubeconfig

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
│   │   └── kubeconfig/# Local kubectl configuration
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

### Advanced Configuration

The configuration files contain comments explaining each setting. You can customize:

- **Infrastructure**: Number of nodes, instance types, region, etc.
- **Kubernetes**: Number of control and worker nodes

Refer to the example files for all available configuration options.

### Using Your Cluster

After deployment completes, you'll have a fully functional K3s cluster ready for your applications.

#### Accessing the Cluster

The deployment automatically configures kubectl on your local machine:

```bash
# Use the generated kubeconfig
export KUBECONFIG=$(pwd)/k3s.yaml

# Verify the cluster is working
kubectl get nodes
```

You can also verify your access to the cluster and check permissions using:

```bash
# Verifies your local machine can access the cluster and shows permissions details
make permissions
```

This command automatically sets the KUBECONFIG environment variable to the generated k3s.yaml file.

#### Deploying Applications

You can now deploy applications to your K3s cluster using standard Kubernetes methods:

```bash
# Example: Deploy an application
kubectl apply -f your-application.yaml
```

## Troubleshooting

See the [troubleshooting guide](docs/troubleshooting.md) for common issues and solutions.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
