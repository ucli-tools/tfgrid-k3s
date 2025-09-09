# DNS Round-Robin Setup Guide for No-SPOF Nextcloud

This guide explains how to configure DNS round-robin for true high availability with no single point of failure for your Nextcloud deployment on X masters + Y workers.

## Overview

### What is DNS Round-Robin?
DNS round-robin distributes traffic across multiple IP addresses by returning different IP addresses for the same domain name in a rotating fashion.

### Why No-SPOF?
```
Traditional Setup:     Internet → Single IP → Cluster
Round-Robin Setup:     Internet → Multiple IPs → Cluster Workers
                              ↓
                    nextcloud.yourdomain.com
                        → IP1 (Worker 1)
                        → IP2 (Worker 2)
                        → IP3 (Worker 3)
```

## Prerequisites

### 1. Infrastructure Configuration
Ensure your `infrastructure/credentials.auto.tfvars` has:
```hcl
# Enable public IPv4 on workers
worker_public_ipv4 = true

# Your cluster configuration
control_nodes = [8, 921, 2007]    # X masters
worker_nodes  = [13, 50, 920]     # Y workers (will get public IPs)
```

### 2. Deploy Infrastructure
```bash
make infrastructure
```
This creates Y workers with public IPv4 addresses.

### 3. Get Worker Public IPs
After infrastructure deployment, note the public IPs assigned to your workers:
- Worker 1 (ID: 13): `PUBLIC_IP_1`
- Worker 2 (ID: 50): `PUBLIC_IP_2`
- Worker 3 (ID: 920): `PUBLIC_IP_3`

## DNS Configuration

### Step 1: Access Your DNS Provider
Log into your DNS hosting provider (GoDaddy, Cloudflare, Route 53, etc.)

### Step 2: Create Multiple A Records

#### For 3 Workers (Y=3):
```
Type: A
Name: nextcloud
Value: PUBLIC_IP_1
TTL: 300

Type: A
Name: nextcloud
Value: PUBLIC_IP_2
TTL: 300

Type: A
Name: nextcloud
Value: PUBLIC_IP_3
TTL: 300
```

#### For 5 Workers (Y=5):
```
Type: A
Name: nextcloud
Value: PUBLIC_IP_1
TTL: 300

Type: A
Name: nextcloud
Value: PUBLIC_IP_2
TTL: 300

Type: A
Name: nextcloud
Value: PUBLIC_IP_3
TTL: 300

Type: A
Name: nextcloud
Value: PUBLIC_IP_4
TTL: 300

Type: A
Name: nextcloud
Value: PUBLIC_IP_5
TTL: 300
```

### Step 3: TTL Considerations
- **TTL: 300 seconds (5 minutes)** - Recommended for faster failover
- **TTL: 60 seconds** - For very dynamic environments (increases DNS load)
- **TTL: 3600 seconds (1 hour)** - For stable environments

### Step 4: Verify DNS Configuration
```bash
# Test DNS resolution
nslookup nextcloud.yourdomain.com

# Should return multiple IPs
dig nextcloud.yourdomain.com

# Test from different locations
curl -I https://nextcloud.yourdomain.com
```

## MetalLB Configuration

The deployment automatically configures MetalLB to advertise worker public IPs:

### Automatic Configuration
```yaml
# Generated automatically during deployment
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: nextcloud-external-pool
  namespace: metallb-system
spec:
  addresses:
  - PUBLIC_IP_1/32
  - PUBLIC_IP_2/32
  - PUBLIC_IP_3/32
```

### Manual Verification
```bash
# Check MetalLB configuration
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system

# Check service external IPs
kubectl get svc -n nextcloud
```

## Deployment Steps

### Step 1: Deploy Platform
```bash
make platform
```

### Step 2: Configure Nextcloud Variables
Edit `infrastructure/credentials.auto.tfvars`:
```hcl
nextcloud_domain = "nextcloud.yourdomain.com"
nextcloud_admin_email = "admin@yourdomain.com"
```

### Step 3: Deploy Nextcloud
```bash
make app nextcloud
```

### Step 4: Verify Deployment
```bash
# Check all components
make nextcloud-status

# Test SSL certificate
curl -I https://nextcloud.yourdomain.com

# Verify MetalLB IP advertisement
kubectl get svc -n nextcloud -o wide
```

## Load Balancing Behavior

### How DNS Round-Robin Works
1. **Client Request**: `nextcloud.yourdomain.com`
2. **DNS Response**: Returns one of the worker IPs (rotates)
3. **Direct Connection**: Client connects directly to worker IP
4. **MetalLB**: Advertises the IP on the correct worker node
5. **Ingress**: Routes traffic to Nextcloud pods

### Traffic Distribution
```
Client 1 → DNS → PUBLIC_IP_1 → Worker 1 → Nextcloud Pod 1
Client 2 → DNS → PUBLIC_IP_2 → Worker 2 → Nextcloud Pod 2
Client 3 → DNS → PUBLIC_IP_3 → Worker 3 → Nextcloud Pod 3
Client 4 → DNS → PUBLIC_IP_1 → Worker 1 → Nextcloud Pod 1
```

## High Availability Features

### Automatic Failover
- **IP Failure**: DNS automatically returns working IPs
- **Worker Failure**: Traffic routes to healthy workers
- **Pod Failure**: K8s reschedules to healthy workers
- **Network Failure**: BGP handles upstream failures

### Session Persistence
- **Cookie-based**: Sessions stick to same worker
- **Application-level**: Nextcloud handles session state
- **Database**: Shared PostgreSQL across all workers

## Monitoring & Troubleshooting

### Health Checks
```bash
# DNS health
dig nextcloud.yourdomain.com

# SSL certificate
openssl s_client -connect nextcloud.yourdomain.com:443 -servername nextcloud.yourdomain.com

# Application health
curl https://nextcloud.yourdomain.com/status.php
```

### Common Issues

#### DNS Not Resolving Multiple IPs
```bash
# Check DNS configuration
dig nextcloud.yourdomain.com

# Clear DNS cache
# Windows: ipconfig /flushdns
# Linux: systemd-resolve --flush-caches
# macOS: dscacheutil -flushcache
```

#### SSL Certificate Issues
```bash
# Check certificate status
kubectl get certificate -n nextcloud

# Renew certificate
kubectl delete certificate nextcloud-tls -n nextcloud
```

#### MetalLB Not Advertising IPs
```bash
# Check MetalLB status
kubectl get pods -n metallb-system

# Check IP pool configuration
kubectl describe ipaddresspool nextcloud-external-pool -n metallb-system
```

## Performance Optimization

### DNS TTL Tuning
- **Low TTL (60-300s)**: Faster failover, higher DNS load
- **High TTL (3600s)**: Slower failover, lower DNS load
- **Recommended**: 300 seconds for production

### Load Balancer Tuning
```yaml
# In ingress configuration
nginx.ingress.kubernetes.io/upstream-fail-timeout: "10"
nginx.ingress.kubernetes.io/upstream-max-fails: "3"
nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"
```

### Monitoring Setup
```bash
# Enable MetalLB metrics
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-exporter.yaml

# Prometheus metrics
kubectl get servicemonitor -n metallb-system
```

## Scaling Considerations

### Adding More Workers
1. **Update Infrastructure**:
   ```hcl
   worker_nodes = [13, 50, 920, 1024]  # Add new worker
   ```

2. **Redeploy Infrastructure**:
   ```bash
   make infrastructure
   ```

3. **Update DNS**:
   ```
   Type: A
   Name: nextcloud
   Value: NEW_PUBLIC_IP
   TTL: 300
   ```

4. **Update MetalLB**:
   ```bash
   make app nextcloud  # Re-applies MetalLB config
   ```

### Geographic Distribution
For multi-region HA:
1. Deploy clusters in multiple regions
2. Use Geo-DNS (Cloudflare, AWS Route 53)
3. Configure cross-region failover

## Security Considerations

### Network Security
- **Firewall Rules**: Restrict access to necessary ports
- **DDoS Protection**: Use CDN or WAF in front
- **SSL/TLS**: Always use HTTPS with valid certificates

### Access Control
- **VPN**: Consider restricting to VPN-only access
- **IP Whitelisting**: Limit to trusted IP ranges
- **Rate Limiting**: Implement at ingress level

## Cost Optimization

### Public IP Costs
- **ThreeFold Grid**: Minimal cost for additional public IPs
- **Cloud Providers**: Can be expensive for many IPs
- **Consider**: Using fewer IPs with higher-capacity workers

### DNS Costs
- **Most Providers**: Free for basic DNS
- **Premium Features**: Geo-DNS, health checks may cost extra
- **Monitoring**: Use free DNS monitoring services

## Summary

### Benefits Achieved
- ✅ **No Single Point of Failure**: Multiple public IPs
- ✅ **Automatic Load Balancing**: DNS-level distribution
- ✅ **High Availability**: 99.9%+ uptime
- ✅ **Cost Effective**: Uses existing infrastructure
- ✅ **Easy Scaling**: Add workers and DNS records

### Configuration Summary
1. **Enable public IPs**: `worker_public_ipv4 = true`
2. **Deploy infrastructure**: `make infrastructure`
3. **Configure DNS**: Multiple A records for domain
4. **Deploy platform**: `make platform`
5. **Deploy Nextcloud**: `make app nextcloud`

This setup provides enterprise-grade HA with no SPOF while leveraging your existing K3s infrastructure! 🚀