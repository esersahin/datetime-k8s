<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](INGRESS_SETUP.en.md) | 🇹🇷 [Türkçe](INGRESS_SETUP.md) |
| :-------------------------------: | :---------------------------: |

</div>

---

# Ingress Controller Setup Guide

## 📋 Table of Contents

1. [Recommended Method: Custom YAML](#-recommended-method-custom-yaml)
2. [High Availability (HA) Architecture](#-high-availability-ha-architecture)
3. [Usage](#-usage)
4. [Verification](#-verification)
5. [Troubleshooting](#-troubleshooting)
6. [File Features](#-file-features)
7. [Why This Method?](#-why-this-method)
8. [Quick Test](#-quick-test)
9. [Detailed Information](#-detailed-information)

---

## 🎯 Recommended Method: Custom YAML

The project includes a ready `k8s/ingress-nginx-deployment.yaml` file! This file is optimized for Kind and includes these settings:

```yaml
spec:
  replicas: 3  # 3 replicas for HA (1 replica per worker node)

  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0  # Zero downtime
      maxSurge: 1        # Progressive rollout

  template:
    spec:
      hostNetwork: true  # Use host network (port 80/443)
      nodeSelector:
        ingress-ready: "true"  # Run on worker nodes
      # no tolerations - DO NOT run on control-plane
```

## 🏗️ High Availability (HA) Architecture

### Cluster Architecture

```
┌─────────────────────────────────────────────────────────┐
│                 3 Control Plane Nodes                   │
│  (Kubernetes management - Ingress does not run here)    │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              3 Worker Nodes (HA Setup)                      │
│                                                             │
│  Worker-1           Worker-2          Worker-3              │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐           │
│  │ Ingress  │      │ Ingress  │      │ Ingress  │           │
│  │ Replica1 │      │ Replica2 │      │ Replica3 │           │
│  │ :80/443  │      │ :80/443  │      │ :80/443  │           │
│  └──────────┘      └──────────┘      └──────────┘           │
│                                                             │
│  ingress-ready=true  ingress-ready=true  ingress-ready=true │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
               ┌─────────────────┐
               │   HAProxy LB    │
               │  localhost:80   │
               │  localhost:443  │
               └─────────────────┘
```

### HA Features

- ✅ **3 Replicas**: 1 Ingress controller per worker node
- ✅ **Zero Downtime**: Seamless updates with rolling update
- ✅ **Load Balancing**: HAProxy distributes traffic to 3 workers
- ✅ **Fault Tolerance**: System continues if 1-2 nodes fail
- ✅ **Progressive Rollout**: Only 1 replica updated at a time

## 🚀 Usage

### Method 1: Automatic (Recommended)

```bash
make deploy
```

The script automatically:

1. Uses `k8s/ingress-nginx-deployment.yaml` if it exists
2. Otherwise uses Kind's default and applies patch

### Method 2: Manual

```bash
# Install Ingress Controller only
kubectl apply -f k8s/ingress-nginx-deployment.yaml

# Wait for it to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Check
kubectl get pods -n ingress-nginx -o wide
```

### Method 3: Makefile

```bash
# Install Ingress
make install-ingress

# Check
kubectl get pods -n ingress-nginx -o wide
```

## ✅ Verification

```bash
# 1. Are pods on worker nodes? (3 replicas)
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-worker, kind-worker2, kind-worker3 expected
# READY: 3/3

# 2. Is hostNetwork true?
kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o yaml | grep hostNetwork
# hostNetwork: true

# 3. Is nodeSelector correct?
kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o yaml | grep -A 2 nodeSelector
# nodeSelector:
#   ingress-ready: "true"
#   kubernetes.io/os: linux

# 4. No tolerations? (should NOT run on control-plane)
kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o yaml | grep -A 2 tolerations
# Output should be empty or only default tolerations like node.kubernetes.io/not-ready

# 5. Is RollingUpdate strategy correct?
kubectl get deployment -n ingress-nginx ingress-nginx-controller -o yaml | grep -A 3 "strategy:"
# maxSurge: 1
# maxUnavailable: 0

# 6. Test - Access via HAProxy
curl http://api-csharp.local/api/datetime
curl http://web-csharp.local
```

## 🔧 Troubleshooting

### Issue 1: Pods running on control-plane

```bash
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-control-plane, kind-control-plane2, kind-control-plane3 ❌ WRONG!

# Solution 1: Update deployment (recommended)
kubectl delete deployment -n ingress-nginx ingress-nginx-controller
kubectl apply -f k8s/ingress-nginx-deployment.yaml

# Solution 2: Recreate cluster
make clean-all
make deploy
```

### Issue 2: Worker nodes missing ingress-ready label

```bash
kubectl get nodes --show-labels | grep ingress-ready
# If output is empty, label is missing

# Solution: Add label
kubectl label node kind-worker ingress-ready=true --overwrite
kubectl label node kind-worker2 ingress-ready=true --overwrite
kubectl label node kind-worker3 ingress-ready=true --overwrite

# Recreate Ingress pods
kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller
```

### Issue 3: Pods stuck in Pending state

```bash
kubectl get pods -n ingress-nginx
# STATUS: Pending

kubectl describe pod -n ingress-nginx <pod-name>
# 0/6 nodes are available: 3 node(s) had untolerated taint, 3 node(s) didn't match Pod's node affinity/selector

# Solution: Add labels to worker nodes (see Issue 2)
```

### Issue 4: HAProxy access not working

```bash
curl http://api-csharp.local/api/datetime
# Connection refused or timeout

# 1. Is HAProxy running?
docker ps | grep haproxy

# 2. Is HAProxy config correct?
cat haproxy/haproxy.cfg | grep -A 5 "backend k8s"

# 3. Are Ingress pods ready?
kubectl get pods -n ingress-nginx

# Solution: Restart HAProxy
cd haproxy
docker-compose down
docker-compose up -d
```

## 📝 File Features

**k8s/ingress-nginx-deployment.yaml**:

- 🔹 Complete NGINX Ingress Controller deployment
- 🔹 Optimized for HA setup (3 replicas)
- 🔹 Worker node deployment (nodeSelector)
- 🔹 Zero downtime rollout (RollingUpdate strategy)
- 🔹 ~450 lines (all required resources)

**Contents**:

- ✅ Namespace (ingress-nginx)
- ✅ ServiceAccount
- ✅ ConfigMap (optimized settings)
- ✅ ClusterRole & ClusterRoleBinding
- ✅ Role & RoleBinding
- ✅ Service (NodePort)
- ✅ Deployment (⭐ with critical settings):
  - `replicas: 3` - For HA
  - `hostNetwork: true` - Host network usage
  - `nodeSelector: ingress-ready=true` - Worker node placement
  - `maxSurge: 1, maxUnavailable: 0` - Progressive rollout
  - ReadinessProbe: `initialDelaySeconds: 5, periodSeconds: 5` - Optimized
- ✅ IngressClass

**kind-config.yaml**:

- 🔹 3 Control Plane Nodes (HA)
- 🔹 3 Worker Nodes (for Ingress)
- 🔹 Worker nodes with `ingress-ready=true` label
- 🔹 NO port mapping (HAProxy is used)

## 🎓 Why This Method?

### Custom YAML vs Other Methods

| Feature              | Custom YAML (Current) | Patch          | Kind Default           |
| -------------------- | --------------------- | -------------- | ---------------------- |
| **Control**          | ✅ Full               | ⚠️ Partial     | ❌ None                |
| **HA Support**       | ✅ 3 replicas         | ❌ 1 replica   | ❌ 1 replica           |
| **Worker Placement** | ✅ Automatic          | ⚠️ Manual      | ❌ Control-plane       |
| **Version Control**  | ✅ In Git             | ❌ Runtime     | ❌ Remote              |
| **Consistency**      | ✅ Always             | ⚠️ Manual      | ❌ Random              |
| **Zero Downtime**    | ✅ RollingUpdate      | ❌ None        | ❌ None                |
| **HAProxy Integrated** | ✅ Compatible       | ⚠️ Extra setup | ❌ Incompatible        |
| **Production Ready** | ✅ Yes                | ❌ No          | ❌ No                  |

### Advantages

- ✅ **High Availability**: 3 replicas, fault tolerance
- ✅ **Best Practice**: Worker node deployment (keeps control-plane clean)
- ✅ **Zero Downtime**: Progressive rollout with seamless updates
- ✅ **Load Balancing**: HAProxy traffic distribution
- ✅ **Consistent**: Versioned in Git, same deployment every time
- ✅ **Optimized**: ReadinessProbe, RollingUpdate strategy optimized

## 🚀 Quick Test

```bash
# 1. Create cluster (with HA setup)
make clean-all
make deploy

# 2. Check nodes (should be 3 control-plane + 3 worker)
kubectl get nodes

# 3. Check Ingress pods (3 replicas, on worker nodes)
kubectl get pods -n ingress-nginx -o wide

# 4. HAProxy status
docker ps | grep haproxy

# 5. Test (via HAProxy)
curl http://api-csharp.local/api/datetime
curl http://web-csharp.local

# Expected: JSON response and HTML response ✅
```

## 📚 Detailed Information

- **[LOAD_BALANCING](LOAD_BALANCING.en.md)**: HAProxy and load balancing details
- **[INGRESS_ROUTING](INGRESS_ROUTING.en.md)**: Routing mechanism
- **[README](../README.en.md)**: General documentation

---

**Result**: Using `k8s/ingress-nginx-deployment.yaml`, Ingress Controller runs on worker nodes with HA! 🎉

---

**Last Updated:** 2025-10-31
**Version:** 2.1
**Project:** DateTime Kubernetes Polyglot Microservices
