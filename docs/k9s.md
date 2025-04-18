# k9s: A Terminal UI for Kubernetes

## Introduction

k9s is a powerful terminal-based UI for managing Kubernetes clusters. This guide explains how to use k9s effectively with our K3s cluster deployment.

## Connecting to k9s

To launch k9s, SSH into the management node and run the k9s command:

```bash
ssh root@10.1.3.2 "k9s"
```

This will directly connect you to the k9s interface using the pre-configured kubeconfig.

## Basic Navigation

### Command Mode

k9s uses a command-based navigation system:

- Enter command mode by typing `:` (colon)
- Exit any view by pressing `Esc`
- Access the command palette with `Ctrl+a`
- Get help by pressing `?`

### Essential Commands

| Command | Description |
|---------|-------------|
| `:ns` or `:namespace` | List and switch namespaces |
| `:ns all` | View resources across all namespaces |
| `:ns kube-system` | Switch to kube-system namespace |
| `:pod` or `:pods` | View pods in current namespace |
| `:svc` | View services |
| `:deploy` | View deployments |
| `:node` | View nodes |
| `:ing` | View ingress resources |
| `:ctx` | View and switch contexts |
| `:secret` | View secrets |
| `:cm` | View ConfigMaps |

### Keyboard Shortcuts in Resource Views

| Key | Action |
|-----|--------|
| `Enter` | Select/drill down |
| `d` | Describe selected resource |
| `l` | View logs (for pods) |
| `s` | Open shell (for pods) |
| `y` | View YAML |
| `e` | Edit resource |
| `Ctrl+d` | Delete resource |
| `/` | Filter resources |
| `Esc` | Go back/exit view |

## Exploring Our K3s Cluster

### System Components

1. View K3s system components:
   ```
   :ns kube-system
   :pod
   ```

2. Check node status:
   ```
   :node
   ```

### Networking Components

1. View MetalLB components:
   ```
   :ns metallb-system
   :pod
   ```

2. Check MetalLB address pools:
   ```
   :addresspools
   ```

3. View Nginx Ingress Controller:
   ```
   :ns ingress-nginx
   :pod
   ```

4. Check services across all namespaces:
   ```
   :ns all
   :svc
   ```

## Monitoring Resources

### Pod Management

1. View pod details:
   - Navigate to pods using `:pod`
   - Select a pod using arrow keys
   - Press `d` to see detailed information

2. View logs:
   - Select a pod
   - Press `l` to view logs
   - Press `p` to view previous container logs (if crashed)

3. Access a shell:
   - Select a pod
   - Press `s` to launch a shell

### Resource Usage

1. View node resource usage:
   ```
   :node
   ```
   Press `u` to toggle the CPU/Memory usage view

2. Benchmark pods:
   - Select a pod
   - Press `b` to start benchmarking
   - Navigate to `:benchmarks` to view results

## Working with Resources

### YAML Management

1. View resource YAML:
   - Select any resource
   - Press `y` to view its YAML definition

2. Edit resources:
   - Select any resource
   - Press `e` to edit its YAML
   - Make changes and save

3. Create new resources:
   - Press `Ctrl+a`
   - Select "Create Resource"
   - Paste YAML and save

### Port Forwarding

1. Set up port forwarding:
   - Select a pod or service
   - Press `Shift+f`
   - Enter local and remote port

## Common Tasks

### Checking Deployment Status

1. View deployments:
   ```
   :deploy
   ```

2. Check ReplicaSets:
   ```
   :rs
   ```

3. View events for troubleshooting:
   ```
   :events
   ```

### Managing MetalLB

1. Check address pools:
   ```
   :addresspools
   ```

2. View BGP configurations (if using BGP mode):
   ```
   :bgppeers
   ```

### Inspecting Network Policies

1. View NetworkPolicies:
   ```
   :netpol
   ```

## Advanced Usage

### Custom Resource Definitions

View custom resources specific to our setup:
```
:crd
```

Then select a CRD to see its instances.

### Using Aliases

k9s supports aliases for quick access to resources:
- Press `Ctrl+a` and select "aliases"
- Use these aliases in command mode with a colon

### Context Management

1. View contexts:
   ```
   :ctx
   ```

2. Configure cluster access from the context view

## Troubleshooting

### Common Issues

1. **Display Issues**: If arrow keys or UI elements don't work correctly:
   - Exit k9s
   - Run `export TERM=xterm-256color`
   - Restart k9s

2. **Performance Problems**: If k9s is slow or unresponsive:
   - Reduce the refresh rate: `k9s --refresh 5` (5 seconds)
   - Use readonly mode: `k9s --readonly`

3. **Connection Issues**: If k9s can't connect to the cluster:
   - Verify that you can use `kubectl` commands
   - Check if `~/.kube/config` exists and is valid

### Getting Help

For detailed information on any feature, press `?` while in k9s or refer to the [official k9s documentation](https://k9scli.io/).

## Reference

- [k9s GitHub Repository](https://github.com/derailed/k9s)
- [k9s Documentation](https://k9scli.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
