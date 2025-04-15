# DNS Configuration for Applications

This guide explains how to configure DNS for applications running on your K3s cluster. Unlike the infrastructure deployment, DNS configuration is application-specific and should be done after your cluster is running.

## Special Considerations for Private Workers

If you've configured your cluster with `worker_public_ipv4 = false`, your worker nodes won't have public IPv4 addresses. For application ingress in this case:

1. Use a node with a public IP (such as the management node) as your edge node
2. Configure appropriate internal routing to your applications
3. Consider using a cloud load balancer or similar service

## Getting Your Cluster's IP Address

Before configuring DNS, you need to determine the appropriate IP address:

```bash
# Connect to your management node
ssh root@<management-node-ip>

# Check the worker nodes with public IPs
kubectl get nodes -o wide
```

For ingress-based applications, use the IP address of a worker node or a load balancer if configured.

## DNS Configuration Options

### Option 1: Public DNS (Recommended for Production)

For a domain you own (e.g., yourdomain.com), add these records in your DNS provider:

```
yourdomain.com          IN A     <worker-node-ip>
*.yourdomain.com        IN A     <worker-node-ip>
```

These records typically take minutes to hours to propagate throughout the internet.

### Option 2: Local /etc/hosts File (Development/Testing)

For testing without public DNS, modify your local machine's hosts file:

#### Linux/macOS:
```bash
sudo nano /etc/hosts
```

#### Windows:
Edit `C:\Windows\System32\drivers\etc\hosts` as Administrator

Add these lines:
```
<worker-node-ip>  yourdomain.com
<worker-node-ip>  app1.yourdomain.com
<worker-node-ip>  app2.yourdomain.com
```

## Configuring Applications with Ingress

Once DNS is configured, create Kubernetes Ingress resources for your applications:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-application
  namespace: default
spec:
  rules:
  - host: app.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```

## Testing Your DNS Configuration

After configuration, verify it works:

```bash
# Simple connectivity test
ping yourdomain.com

# HTTP request test
curl -I http://yourdomain.com
```

## TLS/SSL Configuration

For HTTPS, you can use cert-manager to automatically provision certificates:

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager
```

Then add TLS configuration to your Ingress resources.

## Troubleshooting DNS Issues

If you're experiencing DNS issues:

1. **Verify DNS Resolution**:
   ```bash
   nslookup yourdomain.com
   ```

2. **Check Ingress Controller**:
   ```bash
   kubectl get pods -n ingress-nginx
   kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
   ```

3. **Verify Ingress Resources**:
   ```bash
   kubectl get ingress -A
   kubectl describe ingress my-application
   ```

4. **Test Network Path**:
   ```bash
   traceroute yourdomain.com
   ```

## Best Practices

1. **Use Wildcard DNS Records** for flexibility with multiple applications
2. **Implement TLS** for all production applications
3. **Use Separate Subdomains** for different applications rather than path-based routing
4. **Consider External DNS** for automated DNS management from Kubernetes
5. **Set Appropriate TTLs** - lower for testing, higher for production

Remember that DNS changes can take time to propagate, so be patient when making changes to production DNS records.
