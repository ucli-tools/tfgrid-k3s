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

3. Deploy with a single command:
   ```
   bash ./scripts/deploy.sh
   ```

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
│   ├── .env.example   # Template for environment variables (for sensitive data)
│   ├── credentials.auto.tfvars.example  # Example configuration variables
│   └── main.tf        # Main infrastructure definition
├── platform/          # Platform configuration and K3s deployment (via Ansible)
│   ├── roles/         # Configuration components
│   │   ├── common/    # Common configuration for all nodes
│   │   ├── control/   # K3s control plane configuration
│   │   ├── worker/    # K3s worker node configuration
│   │   └── kubeconfig/# Local kubectl configuration
│   └── site.yml       # Main deployment playbook
├── scripts/           # Deployment and utility scripts
│   ├── deploy.sh      # Main deployment script
│   └── wg.sh          # WireGuard setup script
└── docs/              # Additional documentation
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
