<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](QUICK_START.en.md) | 🇹🇷 [Türkçe](QUICK_START.md) |
| :-----------------------------: | :-------------------------: |

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
mkdir -p datetime-k8s/{api-csharp,web-csharp,k8s}
cd datetime-k8s

# Copy all artifact files to respective folders
```

### Step 2: Deploy

```bash
# Install the entire system with one command
make deploy

# Or using shell script
make deploy
```

### Step 3: Test

```bash
# Status check
make status

# Verification
make verify

# API test
curl http://api-csharp.local/api/datetime

# Web test
curl http://web-csharp.local
```

**That's all!** 🎉

---

## 🔧 Having Issues?

### Quick Checks

```bash
# 1. Is cluster running?
kubectl get nodes
# Expected: 6 nodes (3 control-planes + 3 workers - HA setup)

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

| Issue                | Quick Fix                                                                      |
| -------------------- | ------------------------------------------------------------------------------ |
| **ImagePullBackOff** | `kubectl delete namespace ingress-nginx` → `make deploy`                       |
| **No endpoint**      | `kubectl apply -f k8s/`                                                        |
| **No access**        | `echo "127.0.0.1 api-csharp.local web-csharp.local" \| sudo tee -a /etc/hosts` |
| **Pod Pending**      | `kubectl describe pod <pod-name>` for more details                             |

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

📊 Cluster Durumu
==================

Nodes:
NAME                  STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION     CONTAINER-RUNTIME
kind-control-plane    Ready    control-plane   33m   v1.34.0   172.20.0.4    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-control-plane2   Ready    control-plane   33m   v1.34.0   172.20.0.7    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-control-plane3   Ready    control-plane   32m   v1.34.0   172.20.0.8    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker           Ready    <none>          32m   v1.34.0   172.20.0.6    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker2          Ready    <none>          32m   v1.34.0   172.20.0.5    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker3          Ready    <none>          32m   v1.34.0   172.20.0.3    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3

Pods (with Node placement):
NAME                                   READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
datetime-api-csharp-5b755f6575-7cmh9   1/1     Running   0          30m   10.244.5.2   kind-worker3   <none>           <none>
datetime-api-csharp-5b755f6575-bbxvn   1/1     Running   0          30m   10.244.3.2   kind-worker2   <none>           <none>
datetime-api-csharp-5b755f6575-qdb5x   1/1     Running   0          30m   10.244.4.2   kind-worker    <none>           <none>
datetime-api-go-69d7d7c5c-gxfbg        1/1     Running   0          30m   10.244.4.4   kind-worker    <none>           <none>
datetime-api-go-69d7d7c5c-h4p6c        1/1     Running   0          30m   10.244.3.5   kind-worker2   <none>           <none>
datetime-api-go-69d7d7c5c-sdm75        1/1     Running   0          30m   10.244.5.4   kind-worker3   <none>           <none>
datetime-web-csharp-78cb6c4558-4jb4s   1/1     Running   0          30m   10.244.4.3   kind-worker    <none>           <none>
datetime-web-csharp-78cb6c4558-nllpm   1/1     Running   0          30m   10.244.5.3   kind-worker3   <none>           <none>
datetime-web-csharp-78cb6c4558-wxdjf   1/1     Running   0          30m   10.244.3.3   kind-worker2   <none>           <none>
datetime-web-go-5c776fd996-fdlf8       1/1     Running   0          30m   10.244.5.5   kind-worker3   <none>           <none>
datetime-web-go-5c776fd996-knz8p       1/1     Running   0          30m   10.244.3.4   kind-worker2   <none>           <none>
datetime-web-go-5c776fd996-qtdnq       1/1     Running   0          30m   10.244.4.5   kind-worker    <none>           <none>

Services:
NAME                          TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
datetime-api-csharp-service   ClusterIP   10.96.199.65   <none>        80/TCP    30m
datetime-api-go-service       ClusterIP   10.96.130.19   <none>        80/TCP    30m
datetime-web-csharp-service   ClusterIP   10.96.96.23    <none>        80/TCP    30m
datetime-web-go-service       ClusterIP   10.96.172.47   <none>        80/TCP    30m
kubernetes                    ClusterIP   10.96.0.1      <none>        443/TCP   33m

Ingress:
NAME               CLASS   HOSTS                                                        ADDRESS     PORTS   AGE
datetime-ingress   nginx   api-csharp.local,api-go.local,web-csharp.local + 1 more...   localhost   80      30m
```

### Test Results

```bash
$ curl http://api-csharp.local/api/datetime
{
  "date": "05.10.2025",
  "time": "15:45:30",
  "dayOfWeek": "Sunday",
  "timestamp": "2025-10-05T15:45:30+03:00"
}

$ curl http://web-csharp.local
<!DOCTYPE html>
<html>
  <head><title>Date and Time Application</title></head>
  ...
</html>

$ make verify
🔍 Deployment Doğrulama
========================

1. Kind Cluster
✓ Kind cluster mevcut

2. NGINX Ingress Controller
✓ Ingress namespace mevcut
✓ hostNetwork: true (Doğru)
✓ ValidatingWebhook yok (İdeal)

3. Deployments
✓ API deployment mevcut
✓ Web deployment mevcut

4. Endpoint Testleri
✓ API health endpoint erişilebilir
✓ API datetime endpoint erişilebilir
✓ Web uygulaması erişilebilir

ÖZET
Toplam: 9 | Başarılı: 9  | Başarısız: 0  | Oran: 100%

🎉 TÜM TESTLER BAŞARILI! 🎉
```

---

## 📚 Important Files

### Required Files

```
datetime-k8s/
├── api-csharp/
│   ├── Program.cs
│   ├── DateTimeApi.csproj
│   └── Dockerfile.api
├── web-csharp/
│   ├── index.html
│   ├── nginx.conf
│   └── Dockerfile.web
├── k8s/
│   ├── api-csharp-deployment.yaml
│   ├── web-csharp-deployment.yaml
│   ├── kind-config.yaml
│   ├── ingress.yaml
│   └── ingress-nginx-deployment.yaml   # ⭐ IMPORTANT!
├── Makefile                            # ⭐ IMPORTANT!
```

### Documentation Files

```
├── docs/                              # Documents
│   ├── ARCHITECTURE.en.md             # 📘 System architecture overview
│   ├── ARCHITECTURE.md                # 📘 System architecture overview (TR)
│   ├── ARCHITECTURE_C4.en.md          # 📘 C4 model architecture diagrams
│   ├── ARCHITECTURE_C4.md             # 📘 C4 model architecture diagrams (TR)
│   ├── architecture-diagram.md        # 📘 Architecture diagram documentation
│   ├── c4-diagrams.md                 # 📘 C4 diagram generation guide
│   ├── CHANGES_SUMMARY.en.md          # 📄 Summary of changes
│   ├── CHANGES_SUMMARY.md             # 📄 Summary of changes (TR)
│   ├── HAPROXY_LOADBALANCER.en.md     # 📘 HAProxy load balancer setup
│   ├── HAPROXY_LOADBALANCER.md        # 📘 HAProxy load balancer setup (TR)
│   ├── HAPROXY_NGINX_ARCHITECTURE.en.md # 📘 HAProxy vs NGINX architecture
│   ├── HAPROXY_NGINX_ARCHITECTURE.md  # 📘 HAProxy vs NGINX architecture (TR)
│   ├── INGRESS_CONTROLLER_FIX.en.md   # 📘 Ingress fix methods
│   ├── INGRESS_CONTROLLER_FIX.md      # 📘 Ingress fix methods (TR)
│   ├── INGRESS_ROUTING.en.md          # 📘 Ingress routing explanation
│   ├── INGRESS_ROUTING.md             # 📘 Ingress routing explanation (TR)
│   ├── INGRESS_SETUP.en.md            # 📘 Ingress setup guide
│   ├── INGRESS_SETUP.md               # 📘 Ingress setup guide (TR)
│   ├── INGRESS-WORKER-NODE-MIGRATION.en.md # 📘 Ingress worker node migration
│   ├── INGRESS-WORKER-NODE-MIGRATION.md # 📘 Ingress worker node migration (TR)
│   ├── LOAD_BALANCING.en.md           # 📘 Load balancing strategies
│   ├── LOAD_BALANCING.md              # 📘 Load balancing strategies (TR)
│   ├── MACOS_NETWORK_FIX.en.md        # 📘 macOS network troubleshooting
│   ├── MACOS_NETWORK_FIX.md           # 📘 macOS network troubleshooting (TR)
│   ├── PROJECT_SUMMARY.en.md          # 📘 Summary of components and key points
│   ├── PROJECT_SUMMARY.md             # 📘 Summary of components (TR)
│   ├── QUICK_START.en.md              # 📘 Quick start guide
│   ├── QUICK_START.md                 # 📘 Quick start guide (TR)
│   ├── SERVICE_TO_SERVICE_COMMUNICATION.en.md # 📘 Service-to-service calls
│   ├── SERVICE_TO_SERVICE_COMMUNICATION.md # 📘 Service-to-service calls (TR)
│   ├── WORKER_NODES.en.md             # 📘 Multi-node cluster guide
│   └── WORKER_NODES.md                # 📘 Multi-node cluster guide (TR)
├── Makefile                           # 🎯 Main automation (RECOMMENDED!)
├── CONTRIBUTING.md                    # 📖 How to contribute?
└── README.md                          # 📖 Main documentation
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

By default **6 nodes** run:

- 3 Control-Plane
- 3 Workers

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
127.0.0.1 api-csharp.local web-csharp.local api-go.local web-go.local
::1 api-csharp.local web-csharp.local api-go.local web-go.local

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
kubectl apply -f k8s/api-csharp-deployment.yaml
kubectl apply -f k8s/web-csharp-deployment.yaml
kubectl get endpoints  # Check
```

### Error 2: "ImagePullBackOff"

**Reason**: SHA256 digest doesn't work on ARM64.

**Solution**:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

### Error 3: "Failed to connect to api-csharp.local"

**Reason**: /etc/hosts missing or Ingress Controller on worker.

**Solution**:

```bash
# Add to /etc/hosts
echo "127.0.0.1 api-csharp.local web-csharp.local" | sudo tee -a /etc/hosts

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
curl http://api-csharp.local/api/datetime
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
for i in {1..100}; do curl -s http://api-csharp.local/api/datetime; done

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
- [ ] 6 nodes present (3 control-planes + 3 workers - HA setup)
- [ ] Ingress Controller on control-plane
- [ ] All pods Running
- [ ] Endpoints exist
- [ ] /etc/hosts updated
- [ ] `curl http://api-csharp.local/api/datetime` working
- [ ] `curl http://web-csharp.local` working
- [ ] `make verify` successful

---

## 🆘 Help

### Troubleshooting

1. `make verify` → Automatic issue detection
2. `kubectl describe pod <pod-name>` → Pod details
3. `kubectl logs <pod-name>` → Pod logs

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
**Having issues**: Run `make verify` to diagnose issues
**Everything working**: Enjoy development! 🎨

**Prepared by:** Claude (Anthropic)
**Date:** 2025-10-28
**Version:** 1.1
**Project:** DateTime Kubernetes Polyglot Microservices
