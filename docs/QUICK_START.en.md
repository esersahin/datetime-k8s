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

This guide will get you running the DateTime Kubernetes Polyglot Microservices application in 5 minutes.

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
mkdir -p datetime-k8s/{api-csharp,web-csharp,api-go,web-go,k8s}
cd datetime-k8s

# Copy all artifact files to respective folders
```

### Step 2: Deploy

```bash
# Install the entire system with one command
make deploy

# This command will:
# ✓ Create 3+3 HA cluster (3 control-plane + 3 worker nodes)
# ✓ Deploy NGINX Ingress Controller (on worker nodes, 3 replicas)
# ✓ Deploy HAProxy load balancer (round-robin to 3 workers)
# ✓ Deploy 4 applications (C# API, Go API, C# Web, Go Web)
# ✓ Configure Service-to-Service Communication (Circuit Breaker, Retry, Rate Limiting)
# ✓ Run 20 tests (100% success rate expected)
```

### Step 3: Test

```bash
# Status check
make status

# Verification (9 tests)
make verify

# C# API test
curl http://api-csharp.local/api/datetime

# Go API test
curl http://api-go.local/api/datetime

# C# Web test (Turkish)
curl http://web-csharp.local

# Go Web test (English)
curl http://web-go.local
```

**That's all!** 🎉

---

## 🔧 Having Issues?

### Quick Checks

```bash
# 1. Is cluster running?
kubectl get nodes
# Expected: 6 nodes (3 control-plane + 3 workers - HA setup)
# kind-control-plane, kind-control-plane2, kind-control-plane3 (Ready, control-plane)
# kind-worker, kind-worker2, kind-worker3 (Ready, <none>)

# 2. Are pods ready?
kubectl get pods --all-namespaces
# Expected: All Running (12 application pods + 3 ingress pods)

# 3. Where is Ingress Controller?
kubectl get pods -n ingress-nginx -o wide
# Expected: 3 pods, all on worker nodes (kind-worker, kind-worker2, kind-worker3)
# ✅ CORRECT: On worker nodes
# ❌ WRONG: If on control-plane

# 4. HAProxy Load Balancer working?
docker ps | grep haproxy
# Expected: HAProxy container running, ports 80:80, 443:443, 8404:8404

# 5. Do endpoints exist?
kubectl get endpoints
# Expected: 4 services with endpoints
# - datetime-api-csharp-service (3 endpoints)
# - datetime-api-go-service (3 endpoints)
# - datetime-web-csharp-service (3 endpoints)
# - datetime-web-go-service (3 endpoints)
```

### Common Issues

| Issue                          | Quick Fix                                                                                                |
| ------------------------------ | -------------------------------------------------------------------------------------------------------- |
| **ImagePullBackOff**           | `kubectl delete namespace ingress-nginx` → `make deploy`                                                 |
| **No endpoint**                | `kubectl apply -f k8s/`                                                                                  |
| **No access**                  | `echo "127.0.0.1 api-csharp.local web-csharp.local api-go.local web-go.local" \| sudo tee -a /etc/hosts` |
| **Pod Pending**                | `kubectl describe pod <pod-name>` for more details                                                       |
| **Circuit Breaker test fails** | Check logs: `make logs-api-csharp` to see C# API → Go API communication                                  |

---

## 📋 Command Reference

### Deployment

```bash
make deploy          # Full deployment (creates cluster + deploys apps)
make clean-all       # Clean everything (deletes cluster)
make redeploy        # Clean and redeploy (fresh start)
```

### Monitoring

```bash
make status          # General status (nodes, pods, services)
make show-nodes      # Node details (with IPs)
make verify          # All tests (9 tests)
make logs-api-csharp        # C# API logs
make logs-web        # C# Web logs
make logs-api-go     # Go API logs
make logs-web-go     # Go Web logs
```

### Debug

```bash
make fix-ingress     # Fix Ingress (redeploy)
make fix-webhooks    # Clean webhooks (if needed)
make test            # Endpoint tests (quick)
```

### Scaling

```bash
make scale-api REPLICAS=5       # Scale C# API
make scale-web REPLICAS=5       # Scale C# Web
make scale-api-go REPLICAS=5    # Scale Go API
make scale-web-go REPLICAS=5    # Scale Go Web
make restart-api                # Restart C# API
make restart-web                # Restart C# Web
```

---

## 🎯 Expected Results

### Successful Setup

```bash
$ make status

📊 Cluster Durumu
==================

Nodes:
NAME                  STATUS   ROLES           AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION     CONTAINER-RUNTIME
kind-control-plane    Ready    control-plane   5h11m   v1.34.0   172.20.0.7    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-control-plane2   Ready    control-plane   5h10m   v1.34.0   172.20.0.6    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-control-plane3   Ready    control-plane   5h10m   v1.34.0   172.20.0.8    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker           Ready    <none>          5h10m   v1.34.0   172.20.0.5    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker2          Ready    <none>          5h10m   v1.34.0   172.20.0.4    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker3          Ready    <none>          5h10m   v1.34.0   172.20.0.3    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3

Pods (with Node placement):
NAME                                   READY   STATUS    RESTARTS   AGE    IP           NODE           NOMINATED NODE   READINESS GATES
datetime-api-csharp-555f77dd8d-98v9f   1/1     Running   0          5h8m   10.244.3.2   kind-worker    <none>           <none>
datetime-api-csharp-555f77dd8d-ktvjc   1/1     Running   0          5h8m   10.244.4.2   kind-worker2   <none>           <none>
datetime-api-csharp-555f77dd8d-tvd9c   1/1     Running   0          5h8m   10.244.5.2   kind-worker3   <none>           <none>
datetime-api-go-69d7d7c5c-cmj8k        1/1     Running   0          5h8m   10.244.3.4   kind-worker    <none>           <none>
datetime-api-go-69d7d7c5c-m8x9b        1/1     Running   0          5h8m   10.244.4.4   kind-worker2   <none>           <none>
datetime-api-go-69d7d7c5c-s4w4b        1/1     Running   0          5h8m   10.244.5.4   kind-worker3   <none>           <none>
datetime-web-csharp-78cb6c4558-lt7mk   1/1     Running   0          5h8m   10.244.3.3   kind-worker    <none>           <none>
datetime-web-csharp-78cb6c4558-w5gvn   1/1     Running   0          5h8m   10.244.4.3   kind-worker2   <none>           <none>
datetime-web-csharp-78cb6c4558-xzzkj   1/1     Running   0          5h8m   10.244.5.3   kind-worker3   <none>           <none>
datetime-web-go-5c776fd996-gzhw5       1/1     Running   0          5h8m   10.244.4.5   kind-worker2   <none>           <none>
datetime-web-go-5c776fd996-j7s4x       1/1     Running   0          5h8m   10.244.3.5   kind-worker    <none>           <none>
datetime-web-go-5c776fd996-k854j       1/1     Running   0          5h8m   10.244.5.5   kind-worker3   <none>           <none>

Services:
NAME                          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
datetime-api-csharp-service   ClusterIP   10.96.123.175   <none>        80/TCP    5h8m
datetime-api-go-service       ClusterIP   10.96.244.74    <none>        80/TCP    5h8m
datetime-web-csharp-service   ClusterIP   10.96.230.141   <none>        80/TCP    5h8m
datetime-web-go-service       ClusterIP   10.96.105.81    <none>        80/TCP    5h8m
kubernetes                    ClusterIP   10.96.0.1       <none>        443/TCP   5h11m

Ingress:
NAME               CLASS   HOSTS                                                        ADDRESS     PORTS   AGE
datetime-ingress   nginx   api-csharp.local,api-go.local,web-csharp.local + 1 more...   localhost   80      5h8m
```

### Test Results

```bash
$ curl http://api-csharp.local/api/datetime
{
  "date": "01.11.2025",
  "time": "17:03:10",
  "dayOfWeek": "Cumartesi",
  "timestamp": "2025-11-01T17:03:10.8991797+00:00",
}

$ curl http://api-go.local/health
{
  "status":"healthy",
  "timestamp":"2025-11-01T20:05:21.108016553+03:00",
  "service":"datetime-api-go",
  "pod":"datetime-api-go-69d7d7c5c-s4w4b",
  "node":"kind-worker3"
}

$ curl http://web-csharp.local
<!DOCTYPE html>
<html lang="tr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Tarih ve Saat Uygulaması</title>
    ...
</html>


$ curl http://web-go.local
<!DOCTYPE html>
<html lang="tr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>DateTime API - Go Client</title>
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
│   ├── Program.cs                      # C# API main code (Circuit Breaker, Retry, Rate Limiting)
│   ├── DateTimeApi.csproj              # .NET 9 project file
│   └── Dockerfile.api                  # Docker image: 32.6 MB (Alpine + Invariant Mode)
├── api-go/
│   ├── main.go                         # Go API main code (timezone, calculator)
│   ├── go.mod                          # Go dependencies
│   └── Dockerfile.api-go               # Docker image: ~15 MB (Alpine multi-stage)
├── web-csharp/
│   ├── index.html                      # Turkish UI
│   ├── nginx.conf                      # NGINX config
│   └── Dockerfile.web                  # Lightweight web image
├── web-go/
│   ├── index.html                      # English UI
│   ├── nginx.conf                      # NGINX config
│   └── Dockerfile.web-go               # Lightweight web image
├── k8s/
│   ├── api-csharp-deployment.yaml      # C# API deployment (3 replicas)
│   ├── api-go-deployment.yaml          # Go API deployment (3 replicas)
│   ├── web-csharp-deployment.yaml      # C# Web deployment (3 replicas)
│   ├── web-go-deployment.yaml          # Go Web deployment (3 replicas)
│   ├── kind-config.yaml                # 3+3 HA cluster config
│   ├── ingress.yaml                    # Ingress rules (4 hosts)
│   └── ingress-nginx-deployment.yaml   # ⭐ CRITICAL! (Worker nodes, 3 replicas)
├── Makefile                            # ⭐ CRITICAL! (30+ commands)
└── haproxy.cfg                         # HAProxy load balancer config
```

### Documentation Files

```
├── docs/                              # Documentation
│   ├── ARCHITECTURE.en.md             # 📘 System architecture overview
│   ├── ARCHITECTURE.md                # 📘 System architecture overview (TR)
│   ├── ARCHITECTURE_C4.en.md          # 📘 C4 model architecture diagrams
│   ├── ARCHITECTURE_C4.md             # 📘 C4 model architecture diagrams (TR)
│   ├── architecture-diagram.md        # 📘 Architecture diagram documentation
│   ├── c4-diagrams.md                 # 📘 C4 diagram generation guide
│   ├── CHANGES_SUMMARY.en.md          # 📄 Summary of changes
│   ├── CHANGES_SUMMARY.md             # 📄 Summary of changes (TR)
│   ├── DOCKER_OPTIMIZATION.en.md      # 📘 Docker optimization (277 MB → 32.6 MB)
│   ├── DOCKER_OPTIMIZATION.md         # 📘 Docker optimization (TR)
│   ├── HAPROXY_LOADBALANCER.en.md     # 📘 HAProxy load balancer setup
│   ├── HAPROXY_LOADBALANCER.md        # 📘 HAProxy load balancer setup (TR)
│   ├── HAPROXY_NGINX_ARCHITECTURE.en.md # 📘 HAProxy vs NGINX architecture
│   ├── HAPROXY_NGINX_ARCHITECTURE.md  # 📘 HAProxy vs NGINX architecture (TR)
│   ├── INGRESS_ROUTING.en.md          # 📘 Ingress routing explanation
│   ├── INGRESS_ROUTING.md             # 📘 Ingress routing explanation (TR)
│   ├── INGRESS_SETUP.en.md            # 📘 Ingress setup guide
│   ├── INGRESS_SETUP.md               # 📘 Ingress setup guide (TR)
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

### 2. Multi-Node HA Cluster

By default **6 nodes** run (High Availability):

- **3 Control-Plane nodes**: Kubernetes API, etcd quorum (fault tolerance)
- **3 Worker nodes**: Application pods, Ingress Controller

### 3. Ingress Controller Placement ⭐

**CRITICAL**: Ingress Controller runs on **WORKER NODES** (3 replicas):

```bash
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-worker, kind-worker2, kind-worker3 ✅
```

**WHY?**

- ✅ HA (High Availability) - 3 replicas
- ✅ Load balancing - HAProxy distributes traffic
- ✅ Optimal performance - Separation of concerns
- ✅ Production-like - Control plane for management only

**Old Error**: Tried to run on control-plane ❌

### 4. HAProxy Load Balancer

HAProxy container distributes traffic to worker nodes' ingress controllers:

```bash
# HAProxy stats dashboard
curl http://localhost:8404

# Backends (round-robin)
- kind-worker:80    (UP)
- kind-worker2:80   (UP)
- kind-worker3:80   (UP)
```

**Traffic Flow**:

```
localhost:80/443 → HAProxy → Worker Nodes (Ingress) → Services → Pods
```

### 5. /etc/hosts Configuration

```bash
# Added automatically (requires sudo)
127.0.0.1 api-csharp.local web-csharp.local api-go.local web-go.local
::1 api-csharp.local web-csharp.local api-go.local web-go.local

# Check
cat /etc/hosts | grep local
```

### 6. Webhooks Disabled

Admission webhooks are unnecessary and cause issues in Kind. They're disabled in our project.

### 7. Polyglot Microservices

**4 Applications**:

1. **C# API** (.NET 9) - 32.6 MB, datetime service, calls Go API
2. **Go API** (~15 MB) - High-performance, timezone/calculator
3. **C# Web** - Turkish UI, consumes C# API
4. **Go Web** - English UI, consumes Go API

**Service-to-Service Communication**:

- C# API → Go API (Circuit Breaker, Retry Policy, Rate Limiting)
- **Circuit Breaker**: Opens after 50% failure ratio, 30s break duration
- **Retry Policy**: Exponential backoff (2s, 4s, 8s), max 3 retries
- **Rate Limiting**: Token bucket, 10 req/sec

### 8. Docker Image Optimization

**Evolution**:

- **Before**: 277 MB (Ubuntu base)
- **After Alpine**: 68.5 MB (75% reduction)
- **After Invariant Mode**: 32.6 MB (88.2% reduction)

**Key Techniques**:

- Alpine Linux base image
- .NET Invariant Globalization Mode
- Multi-stage build
- Minimal runtime dependencies

---

## 🚨 Common Errors

### Error 1: "Service does not have any active Endpoint"

**Reason**: Services can't find pods.

**Solution**:

```bash
kubectl apply -f k8s/api-csharp-deployment.yaml
kubectl apply -f k8s/api-go-deployment.yaml
kubectl apply -f k8s/web-csharp-deployment.yaml
kubectl apply -f k8s/web-go-deployment.yaml
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

**Reason**: /etc/hosts missing or Ingress Controller not on worker nodes.

**Solution**:

```bash
# Add to /etc/hosts
echo "127.0.0.1 api-csharp.local web-csharp.local api-go.local web-go.local" | sudo tee -a /etc/hosts

# Fix Ingress
make fix-ingress

# Verify
kubectl get pods -n ingress-nginx -o wide
# Should show all pods on worker nodes
```

### Error 4: "secret ingress-nginx-admission not found"

**Reason**: Webhook certificate missing.

**Solution**: `k8s/ingress-nginx-deployment.yaml` already has no webhooks. Use it:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

### Error 5: "Circuit Breaker not working"

**Reason**: Go API not accessible from C# API.

**Solution**:

```bash
# Check Go API service
kubectl get svc datetime-api-go-service

# Check Go API pods
kubectl get pods -l app=datetime-api-go

# Check logs
make logs-api-csharp
# Should see: "Go API health check successful"
```

---

## 🔄 Workflow Examples

### Developing New Features

```bash
# 1. Modify code (e.g., Program.cs or main.go)

# 2. Quick update
make quick-update

# 3. Test
curl http://api-csharp.local/api/datetime
curl http://api-go.local/api/datetime
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
make logs-api-csharp        # C# API
make logs-api-go     # Go API

# 3. Connect to pod
kubectl exec -it <pod-name> -- /bin/sh

# 4. Network test (internal)
kubectl run test --image=curlimages/curl -it --rm -- \
  curl http://datetime-api-csharp-service/api/datetime
```

### Load Testing

```bash
# 1. Scale up
make scale-api REPLICAS=5
make scale-web REPLICAS=5
make scale-api-go REPLICAS=5
make scale-web-go REPLICAS=5

# 2. Test C# API
for i in {1..100}; do curl -s http://api-csharp.local/api/datetime; done

# 3. Test Go API
for i in {1..100}; do curl -s http://api-go.local/api/datetime; done

# 4. Scale down
make scale-api REPLICAS=3
make scale-web REPLICAS=3
make scale-api-go REPLICAS=3
make scale-web-go REPLICAS=3
```

### Circuit Breaker Testing

```bash
# 1. Simulate Go API failure
kubectl scale deployment datetime-api-go --replicas=0

# 2. Test C# API (should handle gracefully)
curl http://api-csharp.local/api/datetime
# Expected: {"goApiStatus": "circuit_open", ...}

# 3. Watch logs
make logs-api-csharp
# Should see: "Circuit breaker opened after 50% failure ratio"

# 4. Restore Go API
kubectl scale deployment datetime-api-go --replicas=3

# 5. Wait 30 seconds (circuit breaker recovery)

# 6. Test again (should work)
curl http://api-csharp.local/api/datetime
# Expected: {"goApiStatus": "healthy", ...}
```

---

## 📊 Makefile Command Summary

### Basic Commands

| Command       | Description                  |
| ------------- | ---------------------------- |
| `make help`   | List all commands            |
| `make deploy` | **Full deployment (MAIN)**   |
| `make verify` | Verification tests (9 tests) |
| `make status` | General status               |
| `make test`   | Endpoint tests               |

### Debugging

| Command                | Description             |
| ---------------------- | ----------------------- |
| `make show-nodes`      | Node details            |
| `make logs`            | All logs (C# + Go)      |
| `make logs-api-csharp` | C# API logs (real-time) |
| `make logs-web-csharp` | C# Web logs (real-time) |
| `make logs-api-go`     | Go API logs (real-time) |
| `make logs-web-go`     | Go Web logs (real-time) |
| `make fix-ingress`     | Fix Ingress             |
| `make fix-webhooks`    | Clean webhooks          |

### Build & Update

| Command                 | Description                    |
| ----------------------- | ------------------------------ |
| `make build-all`        | All images (C# + Go API + Web) |
| `make build-api`        | All API images (C# + Go)       |
| `make build-web`        | All Web images (C# + Go)       |
| `make build-api-csharp` | C# API build                   |
| `make build-api-go`     | Go API build                   |
| `make build-web-csharp` | C# Web build                   |
| `make build-web-go`     | Go Web build                   |
| `make load-images`      | Images → Kind cluster          |
| `make quick-update`     | Quick code update              |

### Management

| Command                        | Description                |
| ------------------------------ | -------------------------- |
| `make scale-api REPLICAS=3`    | Scale C# API               |
| `make scale-web REPLICAS=3`    | Scale C# Web               |
| `make scale-api-go REPLICAS=3` | Scale Go API               |
| `make scale-web-go REPLICAS=3` | Scale Go Web               |
| `make restart-api`             | Restart C# API             |
| `make restart-web`             | Restart C# Web             |
| `make clean`                   | Delete K8s resources       |
| `make clean-all`               | Delete cluster + resources |
| `make redeploy`                | Full redeploy              |

---

## 🎯 Checklist

For successful deployment:

- [ ] Docker, Kind, kubectl installed
- [ ] Project files in correct folders (4 apps: C# API, Go API, C# Web, Go Web)
- [ ] `make deploy` executed successfully
- [ ] 6 nodes present (3 control-plane + 3 workers - HA setup)
- [ ] Ingress Controller on **worker nodes** (NOT control-plane) ⭐
- [ ] 3 Ingress pods running (kind-worker, kind-worker2, kind-worker3)
- [ ] HAProxy container running (localhost:8404 accessible)
- [ ] 15 application pods Running (distributed across workers)
- [ ] 4 services have endpoints (C# API, Go API, C# Web, Go Web)
- [ ] /etc/hosts updated (4 domains)
- [ ] `curl http://api-csharp.local/api/datetime` working
- [ ] `curl http://api-go.local/api/datetime` working
- [ ] `curl http://web-csharp.local` working
- [ ] `curl http://web-go.local` working
- [ ] Service-to-Service communication working (C# API → Go API)
- [ ] Circuit Breaker configured and tested
- [ ] `make verify` successful (9/9 tests passed)

---

## 🆘 Help

### Troubleshooting

1. `make verify` → Automatic issue detection (20 tests)
2. `kubectl describe pod <pod-name>` → Pod details
3. `kubectl logs <pod-name>` → Pod logs
4. `make status` → Overall cluster status

### Documentation

- **[README](../README.en.md)** → General information
- **[WORKER_NODES](WORKER_NODES.en.md)** → Multi-node HA cluster details
- **[INGRESS_ROUTING](INGRESS_ROUTING.en.md)** → Network flow
- **[LOAD_BALANCING](LOAD_BALANCING.en.md)** → Load balancing strategies
- **[HAPROXY_LOADBALANCER](HAPROXY_LOADBALANCER.en.md)** → HAProxy setup
- **[SERVICE_TO_SERVICE_COMMUNICATION](SERVICE_TO_SERVICE_COMMUNICATION.en.md)** → Circuit Breaker, Retry, Rate Limiting
- **[DOCKER_OPTIMIZATION](DOCKER_OPTIMIZATION.en.md)** → Docker image optimization (277 MB → 32.6 MB)

### Commands

```bash
make help          # View all commands (30+)
kubectl get all    # View all resources
kubectl get nodes  # View all nodes
```

---

## 🎉 Success!

If you completed these steps:

✅ Multi-node HA Kubernetes cluster running (3+3 nodes)
✅ NGINX Ingress Controller active (on worker nodes, 3 replicas)
✅ HAProxy load balancer distributing traffic
✅ Polyglot microservices running (.NET 9 + Go)
✅ 4 applications accessible (C# API, Go API, C# Web, Go Web)
✅ Service-to-Service communication working (Circuit Breaker, Retry, Rate Limiting)
✅ Load balancing working (across 3 workers)
✅ Production-like environment ready
✅ Docker images optimized (32.6 MB C# API, ~15 MB Go API)

**Congratulations!** 🚀

---

**First time setup**: Takes 5-10 minutes
**Having issues**: Run `make verify` to diagnose issues (9 automated tests)
**Everything working**: Enjoy development! 🎨

---

## 📊 Project Statistics

- **Nodes**: 6 (3 control-plane + 3 workers)
- **Application Pods**: 15 (3 per app × 4 apps + 3 spare)
- **Services**: 4 ClusterIP services
- **Ingress Rules**: 4 hosts
- **Ingress Replicas**: 3 (HA)
- **Tests**: 9 (100% success rate)
- **Docker Images**: 2 optimized (32.6 MB C# + ~15 MB Go)
- **Resiliency Patterns**: 3 (Circuit Breaker, Retry, Rate Limiting)
- **Languages**: 2 (C# .NET 9 + Go)
- **Makefile Commands**: 30+

---

**Date:** 2025-10-29
**Version:** 2.0
**Project:** DateTime Kubernetes Polyglot Microservices with Resiliency Patterns
