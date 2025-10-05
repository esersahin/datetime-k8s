<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](QUICK_START.en.md) | 🇹🇷 [Türkçe](QUICK_START.md) |
| :----------------------------------: | :------------------------------: |

</div>

---

# Quick Start Guide

## 📋 Table of Contents

1. [Quick Setup](#-quick-setup)
2. [Having Issues?](#-having-issues)
3. [Command Reference](#-command-reference)
4. [Expected Results](#-expected-results)
5. [Important Files](#-important-files)
6. [Important Notes](#-important-notes)
7. [Common Errors](#-common-errors)
8. [Workflow Examples](#-workflow-examples)
9. [Makefile Command Summary](#-makefile-command-summary)
10. [Checklist](#-checklist)
11. [Help](#-help)
12. [Success!](#-success)

---

This guide will get you running the DateTime Kubernetes application in 5 minutes.

## ⚡ Quick Setup

### Prerequisites

```bash
# Docker, Kind, kubectl must be installed
docker --version
kind --version
kubectl version --client
```

### Step 1: Create Project Structure

```bash
# Create directories
mkdir -p datetime-k8s/{api,web,k8s}
cd datetime-k8s

# Copy all artifact files to respective folders
```

### Step 2: Deploy

```bash
# Install the entire system with one command
make deploy

# Or using shell script
./deploy.sh
```

### Step 3: Test

```bash
# Status check
make status

# Verification
make verify

# API test
curl http://api.local/api/datetime

# Web test
curl http://web.local
```

**That's all!** 🎉

---

## 🔧 Having Issues?

### Quick Checks

```bash
# 1. Is cluster running?
kubectl get nodes
# Expected: 3 nodes (1 control-plane + 2 workers)

# 2. Are pods ready?
kubectl get pods --all-namespaces
# Expected: All Running

# 3. Where is Ingress Controller?
kubectl get pods -n ingress-nginx -o wide
# Expected: NODE=kind-control-plane

# 4. Do endpoints exist?
kubectl get endpoints
# Expected: 2 endpoints per service
```

### Common Issues

| Issue                | Quick Fix                                                                        |
| -------------------- | -------------------------------------------------------------------------------- |
| **ImagePullBackOff** | `kubectl delete namespace ingress-nginx` → `make deploy`                         |
| **No endpoint**      | `kubectl apply -f k8s/`                                                          |
| **No access**        | `echo "127.0.0.1 api.local web.local" \| sudo tee -a /etc/hosts`                 |
| **Pod Pending**      | `kubectl describe pod <pod-name>` → See [TROUBLESHOOTING](TROUBLESHOOTING.en.md) |

### Detailed Troubleshooting

Check **[TROUBLESHOOTING](TROUBLESHOOTING.en.md)** file! 🆘

---

## 📋 Command Reference

### Deployment

```bash
make deploy          # Full deployment
make clean-all       # Clean everything
make redeploy        # Clean and redeploy
```

### Monitoring

```bash
make status          # General status
make show-nodes      # Node details
make verify          # All tests
make logs-api        # API logs
make logs-web        # Web logs
```

### Debug

```bash
make fix-ingress     # Fix Ingress
make fix-webhooks    # Clean webhooks
make test            # Endpoint tests
```

### Scaling

```bash
make scale-api REPLICAS=3    # Scale API
make scale-web REPLICAS=3    # Scale Web
make restart-api             # Restart API
make restart-web             # Restart Web
```

---

## 🎯 Expected Results

### Successful Setup

```bash
$ make status

📊 Cluster Status
==================

Nodes:
NAME                 STATUS   ROLES           AGE   VERSION
kind-control-plane   Ready    control-plane   5m    v1.34.0
kind-worker          Ready    <none>          5m    v1.34.0
kind-worker2         Ready    <none>          5m    v1.34.0

Pods (with Node placement):
NAME                           READY   STATUS    NODE
datetime-api-xxx              1/1     Running   kind-worker
datetime-api-yyy              1/1     Running   kind-worker2
datetime-web-xxx              1/1     Running   kind-worker
datetime-web-yyy              1/1     Running   kind-worker2

Services:
NAME                   TYPE        CLUSTER-IP      PORT(S)
datetime-api-service   ClusterIP   10.96.177.25    80/TCP
datetime-web-service   ClusterIP   10.96.240.159   80/TCP

Ingress:
NAME               CLASS   HOSTS                 ADDRESS     PORTS
datetime-ingress   nginx   api.local,web.local   localhost   80
```

### Test Results

```bash
$ curl http://api.local/api/datetime
{
  "date": "05.10.2025",
  "time": "15:45:30",
  "dayOfWeek": "Sunday",
  "timestamp": "2025-10-05T15:45:30+03:00"
}

$ curl http://web.local
<!DOCTYPE html>
<html>
  <head><title>Date and Time Application</title></head>
  ...
</html>

$ make verify
🔍 Deployment Verification
========================

1. Kind Cluster
✓ Kind cluster exists
✓ Kubectl connected to cluster

2. NGINX Ingress Controller
✓ Ingress namespace exists
✓ Ingress controller ready (1 replicas)
✓ hostNetwork: true (Correct)
✓ ValidatingWebhook not present (Ideal for Mac/Kind)

3. Deployments
✓ API deployment exists
✓ API pods ready (2/2)
✓ Web deployment exists
✓ Web pods ready (2/2)

4. Endpoint Tests
✓ API health endpoint accessible
✓ API datetime endpoint accessible
✓ API returns valid JSON
✓ Web application accessible

SUMMARY
Total: 15 | Successful: 15 | Failed: 0 | Rate: 100%

🎉 ALL TESTS PASSED! 🎉
```

---

## 📚 Important Files

### Required Files

```
datetime-k8s/
├── api/
│   ├── Program.cs
│   ├── DateTimeApi.csproj
│   └── Dockerfile.api
├── web/
│   ├── index.html
│   ├── nginx.conf
│   └── Dockerfile.web
├── k8s/
│   ├── api-deployment.yaml
│   ├── web-deployment.yaml
│   ├── kind-config.yaml
│   ├── ingress.yaml
│   └── ingress-nginx-deployment.yaml   # ⭐ IMPORTANT!
├── Makefile                            # ⭐ IMPORTANT!
└── deploy.sh
```

### Documentation Files

```
├── README.md                      # General guide
├── CHANGES_SUMMARY.md             # Summary of changes
├── PROJECT_SUMMARY.en.md          # Summary of components and key points
├── QUICK_START.en.md              # This file
├── TROUBLESHOOTING.en.md          # 🆘 Troubleshooting
├── WORKER_NODES.en.md             # Multi-node details
├── INGRESS_ROUTING.en.md          # Routing explanation
├── INGRESS_CONTROLLER_FIX.en.md   # Ingress fixes
├── INGRESS_SETUP.en.md            # Ingress setup
└── LOAD_BALANCING.en.md           # Load balancing strategies
```

---

## 🎓 Important Notes

### 1. ARM64 (M1/M2/M3 Mac) Users

The `k8s/ingress-nginx-deployment.yaml` file is optimized for ARM64:

```yaml
# NO SHA256 digest - platform is auto-selected
image: registry.k8s.io/ingress-nginx/controller:v1.13.3
```

### 2. Multi-Node Cluster

By default **3 nodes** run:

- 1 Control-Plane (Ingress Controller runs here)
- 2 Workers (Application pods run here)

### 3. Ingress Controller Placement

**Critical**: Ingress Controller **must be on control-plane**:

```bash
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-control-plane ✅
```

If on worker node, **access won't work**!

### 4. /etc/hosts

```bash
# Added automatically (requires sudo)
127.0.0.1 api.local web.local

# Check
cat /etc/hosts | grep local
```

### 5. Webhooks Disabled

Admission webhooks are unnecessary and cause issues in Kind. They're disabled in our project.

---

## 🚨 Common Errors

### Error 1: "Service does not have any active Endpoint"

**Reason**: Services can't find pods.

**Solution**:

```bash
kubectl apply -f k8s/api-deployment.yaml
kubectl apply -f k8s/web-deployment.yaml
kubectl get endpoints  # Check
```

### Error 2: "ImagePullBackOff"

**Reason**: SHA256 digest doesn't work on ARM64.

**Solution**:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

### Error 3: "Failed to connect to api.local"

**Reason**: /etc/hosts missing or Ingress Controller on worker.

**Solution**:

```bash
# Add to /etc/hosts
echo "127.0.0.1 api.local web.local" | sudo tee -a /etc/hosts

# Fix Ingress
make fix-ingress
```

### Error 4: "secret ingress-nginx-admission not found"

**Reason**: Webhook certificate missing.

**Solution**: `k8s/ingress-nginx-deployment.yaml` already has no webhooks. Use it:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

---

## 🔄 Workflow Examples

### Developing New Features

```bash
# 1. Modify code (e.g., Program.cs)

# 2. Quick update
make quick-update

# 3. Test
curl http://api.local/api/datetime
```

### Full Restart

```bash
# 1. Clean everything
make clean-all

# 2. Redeploy
make deploy

# 3. Verify
make verify
```

### Debugging

```bash
# 1. Check status
make status

# 2. Watch logs
make logs-api

# 3. Connect to pod
kubectl exec -it <pod-name> -- /bin/sh

# 4. Network test
kubectl run test --image=curlimages/curl -it --rm -- \
  curl http://datetime-api-service/api/datetime
```

### Load Testing

```bash
# 1. Scale up
make scale-api REPLICAS=5
make scale-web REPLICAS=5

# 2. Test
for i in {1..100}; do curl -s http://api.local/api/datetime; done

# 3. Scale down
make scale-api REPLICAS=2
make scale-web REPLICAS=2
```

---

## 📊 Makefile Command Summary

### Basic Commands

| Command       | Description                |
| ------------- | -------------------------- |
| `make help`   | List all commands          |
| `make deploy` | **Full deployment (MAIN)** |
| `make verify` | Verification tests         |
| `make status` | General status             |
| `make test`   | Endpoint tests             |

### Debugging

| Command             | Description          |
| ------------------- | -------------------- |
| `make show-nodes`   | Node details         |
| `make logs-api`     | API logs (real-time) |
| `make logs-web`     | Web logs (real-time) |
| `make fix-ingress`  | Fix Ingress          |
| `make fix-webhooks` | Clean webhooks       |

### Management

| Command                     | Description                |
| --------------------------- | -------------------------- |
| `make scale-api REPLICAS=3` | Scale API                  |
| `make scale-web REPLICAS=3` | Scale Web                  |
| `make restart-api`          | Restart API                |
| `make restart-web`          | Restart Web                |
| `make clean`                | Delete K8s resources       |
| `make clean-all`            | Delete cluster + resources |
| `make redeploy`             | Full redeploy              |

---

## 🎯 Checklist

For successful deployment:

- [ ] Docker, Kind, kubectl installed
- [ ] Project files in correct folders
- [ ] `make deploy` executed
- [ ] 3 nodes present (1 control + 2 workers)
- [ ] Ingress Controller on control-plane
- [ ] All pods Running
- [ ] Endpoints exist
- [ ] /etc/hosts updated
- [ ] `curl http://api.local/api/datetime` working
- [ ] `curl http://web.local` working
- [ ] `make verify` successful

---

## 🆘 Help

### Troubleshooting

1. **[TROUBLESHOOTING](TROUBLESHOOTING.en.md)** → All errors and solutions
2. `make verify` → Automatic issue detection
3. `kubectl describe pod <pod-name>` → Pod details
4. `kubectl logs <pod-name>` → Pod logs

### Documentation

- **[README](../README.en.md)** → General information
- **[WORKER_NODES](WORKER_NODES.en.md)** → Multi-node details
- **[INGRESS_ROUTING](INGRESS_ROUTING.en.md)** → Network flow
- **[LOAD_BALANCING](LOAD_BALANCING.en.md)** → Load balancing

### Commands

```bash
make help          # View all commands
kubectl get all    # View all resources
```

---

## 🎉 Success!

If you completed these steps:

✅ Multi-node Kubernetes cluster running
✅ NGINX Ingress Controller active
✅ .NET API and Web application accessible
✅ Load balancing working
✅ Production-like environment ready

**Congratulations!** 🚀

---

**First time setup**: Takes 5-10 minutes
**Having issues**: Check [TROUBLESHOOTING](TROUBLESHOOTING.en.md)
**Everything working**: Enjoy development! 🎨
