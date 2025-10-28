# Ingress-Nginx Setup for Kind Cluster

## Overview

This document explains how ingress-nginx is configured for the DailyFeed local Kind cluster.

## Problem with Default Configuration

The default ingress-nginx deployment for Kind uses a **LoadBalancer** service type. However:

- Kind clusters don't natively support LoadBalancer services
- The EXTERNAL-IP remains `<pending>` indefinitely
- Port 80 defined in `cluster.yml` doesn't bind to ingress-nginx
- Applications become inaccessible from the host machine

## Solution: HostPort Configuration

We use a custom deployment that binds ingress-nginx directly to the host's port 80 using **hostPort**.

### Key Configuration Files

1. **ingress-nginx-hostport.yaml**
   - Custom deployment with hostPort enabled
   - Binds container port 80 → host port 80
   - Binds container port 443 → host port 443
   - Scheduled on control-plane node (nodeSelector: ingress-ready=true)

2. **create-cluster.sh**
   - Downloads default ingress-nginx manifests
   - Deletes the default LoadBalancer-based deployment
   - Applies the hostPort-enabled deployment
   - Waits for readiness before proceeding

### How It Works

```bash
# 1. Install default ingress-nginx (creates namespace, RBAC, services, etc.)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# 2. Delete the default deployment (LoadBalancer type)
kubectl delete deployment ingress-nginx-controller -n ingress-nginx

# 3. Apply custom hostPort deployment
kubectl apply -f ingress-nginx-hostport.yaml

# 4. Wait for pod to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### Benefits

- Direct access via localhost:80 on the host machine
- Works with Kind's port mapping in cluster.yml
- No need for external load balancer
- Consistent with Kind best practices for local development

## Port Mapping Flow

```
Browser (http://dailyfeed.local)
         ↓
Host Machine (/etc/hosts: 127.0.0.1 dailyfeed.local)
         ↓
localhost:80
         ↓
Kind Control Plane Container (cluster.yml: hostPort: 80)
         ↓
ingress-nginx-controller Pod (hostPort: 80)
         ↓
NGINX Ingress Controller
         ↓
dailyfeed-frontend Service (ClusterIP:3000)
         ↓
dailyfeed-frontend Pod (Next.js App)
```

## Verification

After installation, verify the setup:

```bash
# Check pod is running with hostPort
kubectl get pods -n ingress-nginx -o wide

# Check ingress configuration
kubectl get ingress -n dailyfeed

# Test connectivity
curl -H "Host: dailyfeed.local" http://localhost:80

# Test from browser
open http://dailyfeed.local
```

## Troubleshooting

### Connection Refused

If you get "connection refused":

```bash
# Check if pod is running
kubectl get pods -n ingress-nginx

# Check pod logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Verify hostPort binding
kubectl describe pod -n ingress-nginx -l app.kubernetes.io/component=controller | grep "Host Ports"
```

### Port Already in Use

If port 80 is already in use on your host:

```bash
# Check what's using port 80
sudo lsof -i :80

# Option 1: Stop the conflicting service
# Option 2: Modify cluster.yml to use different host port
```

### Ingress Not Found

If ingress resources aren't working:

```bash
# Check ingress class
kubectl get ingressclass

# Verify ingress resource
kubectl describe ingress dailyfeed-frontend -n dailyfeed

# Check service endpoints
kubectl get endpoints -n dailyfeed
```

## Migration from Previous Setup

If you're upgrading from the LoadBalancer setup:

```bash
# 1. Delete old cluster (optional, recommended)
kind delete cluster --name istio-cluster

# 2. Run fresh installation
cd /Users/alpha300uk/workspace/alpha300uk/0.toy-project/dailyfeed/project/dailyfeed-installer
source local-install-infra-and-app.sh <version>

# 3. Verify ingress is using hostPort
kubectl get pods -n ingress-nginx -o yaml | grep hostPort
```

## Related Files

- `cluster.yml` - Defines Kind cluster with port mappings
- `ingress-nginx-hostport.yaml` - HostPort deployment configuration
- `create-cluster.sh` - Installation script
- `ingress.yaml` - Ingress resource for dailyfeed-frontend

## References

- [Kind Ingress Documentation](https://kind.sigs.k8s.io/docs/user/ingress/)
- [Ingress-Nginx Documentation](https://kubernetes.github.io/ingress-nginx/)
- [Kubernetes HostPort](https://kubernetes.io/docs/concepts/services-networking/network-policies/#targeting-a-range-of-ports)