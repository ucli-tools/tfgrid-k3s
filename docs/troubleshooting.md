# Troubleshooting Guide

This guide addresses common issues that might occur during the deployment of K3s clusters on ThreeFold Grid using this repository.

## Infrastructure Provisioning Issues

### OpenTofu/Terraform Errors

#### Error: Failed to connect to ThreeFold Grid

**Symptoms:**
- Error messages about failed authentication or connection to the ThreeFold Grid

**Solutions:**
1. Verify your mnemonics are correct
2. Check if you have enough TFT balance for the deployment
3. Ensure you're using the correct network (main, test, dev)

```bash
# Verify you can connect using the same credentials
tofu -chdir=deployment init
```

#### Error: No capacity found on nodes

**Symptoms:**
- Error about insufficient capacity on requested nodes

**Solutions:**
1. Choose different nodes with more capacity
2. Reduce the resource requirements in `variables.tf`
3. Check node status on ThreeFold Grid Explorer

### WireGuard Configuration Issues

**Symptoms:**
- WireGuard fails to connect
- `wg.sh` script errors

**Solutions:**
1. Check if WireGuard is installed correctly
   ```bash
   sudo apt install wireguard
   ```
2. Verify the generated WireGuard configuration
   ```bash
   cat /etc/wireguard/k3s.conf
   ```
3. Ensure your firewall allows WireGuard traffic (port 51820/UDP)
   ```bash
   sudo ufw allow 51820/udp
   ```

## K3s Deployment Issues

### Ansible Connection Failures

**Symptoms:**
- Ansible fails to connect to hosts
- SSH timeouts or authentication failures

**Solutions:**
1. Verify WireGuard is properly configured and active
   ```bash
   sudo wg show
   ```
2. Check SSH connectivity
   ```bash
   ./scripts/ping.sh
   ```
3. Verify inventory file generation
   ```bash
   cat kubernetes/inventory.ini
   ```

### K3s Installation Failures

**Symptoms:**
- K3s installation fails on nodes
- Nodes cannot join the cluster

**Solutions:**
1. Check connectivity between nodes
   ```bash
   ansible all -m ping
   ```
2. Verify node resources (CPU/memory)
   ```bash
   ansible all -m shell -a "free -m && nproc"
   ```
3. Check logs on failed nodes
   ```bash
   ansible [problematic_node] -m shell -a "journalctl -u k3s*"
   ```
4. Clean up and retry
   ```bash
   ansible all -m shell -a "rm -rf /var/lib/rancher/k3s"
   ```

## Kubernetes Access Issues

### Kubectl Configuration

**Symptoms:**
- Cannot connect to the K3s cluster with kubectl
- Getting connection refused or unauthorized errors

**Solutions:**
1. Verify your kubeconfig is correctly set up
   ```bash
   export KUBECONFIG=$(pwd)/k3s.yaml
   kubectl get nodes
   ```
2. Check that the server address in the kubeconfig points to the correct IP
   ```bash
   grep server k3s.yaml
   ```
3. Re-run the kubeconfig role if needed
   ```bash
   ansible-playbook platform/site.yml -t kubeconfig
   ```

### Service Deployment Issues

**Symptoms:**
- Services not accessible
- Pods stuck in pending state

**Solutions:**
1. Check pod status
   ```bash
   kubectl get pods -A
   ```
2. Examine pod logs
   ```bash
   kubectl logs -n [namespace] [pod_name]
   ```
3. Verify networking between nodes
   ```bash
   kubectl get nodes -o wide
   ```
4. Check service status
   ```bash
   kubectl get svc -A
   ```

## Cleaning Up and Redeploying

If you need to start from scratch:

1. Clean up the infrastructure
   ```bash
   ./scripts/cleantf.sh
   ```
2. Down the WireGuard interface
   ```bash
   sudo wg-quick down k3s
   ```
3. Start a fresh deployment
   ```bash
   ./scripts/deploy.sh yourdomain.com
   ```

## Getting Additional Help

If you continue to experience issues:

1. Check the logs in detail
   ```bash
   journalctl -u k3s -f  # On control plane nodes
   journalctl -u k3s-agent -f  # On worker nodes
   ```
2. Consider increasing verbosity for Ansible
   ```bash
   ansible-playbook kubernetes/k3s-cluster.yml -vvv
   ```
3. File an issue on the GitHub repository with:
   - Detailed description of the problem
   - Relevant logs and error messages
   - Your environment details
