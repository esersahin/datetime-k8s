<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](TROUBLESHOOTING.en.md) | 🇹🇷 [Türkçe](TROUBLESHOOTING.md) |
| :---------------------------------: | :-----------------------------: |

</div>

---

# Troubleshooting Guide - DateTime Kubernetes Application

This document explains all encountered issues, their causes, and step-by-step solutions.

## 📋 Table of Contents

1. [Endpoint Issues](#1-endpoint-issues)
2. [Ingress Controller Node Placement](#2-ingress-controller-node-placement)
3. [Admission Webhook Issues](#3-admission-webhook-issues)
4. [Image Pull Issues](#4-image-pull-issues)
5. [Access Issues](#5-access-issues)

---

## 1. Endpoint Issues

### 🔴 Problem

```
Service "default/datetime-api-service" does not have any active Endpoint.
Service "default/datetime-web-service" does not have any active Endpoint.
```

**Symptom**: Endpoint warnings appear in Ingress Controller logs.

### 🔍 Analysis

```bash
# Check endpoints
kubectl get endpoints

# Output:
NAME                   ENDPOINTS   AGE
datetime-api-service   <none>      5m
datetime-web-service   <none>      5m
```

**Cause**: Wrong order of `selector` and `ports` in Services. In YAML, `selector` should come before ports.

### ✅ Solution

Fixed Service definition in **api-deployment.yaml and web-deployment.yaml**:

```yaml
# WRONG ❌
spec:
  type: ClusterIP
  selector:           # selector first
    app: datetime-api
  ports:              # then ports
  - port: 80
    targetPort: 5000

# CORRECT ✅
spec:
  type: ClusterIP
  ports:              # ports first
  - port: 80
    targetPort: 5000
  selector:           # then selector
    app: datetime-api
```

**Application**:

```bash
kubectl apply -f k8s/api-deployment.yaml
kubectl apply -f k8s/web-deployment.yaml

# Verification
kubectl get endpoints
# ENDPOINTS: 10.244.1.4:5000,10.244.2.2:5000 ✅
```

**Result**: ✅ Endpoints created, Services are finding pods.

---

## 2. Ingress Controller Node Placement

### 🔴 Problem

Ingress Controller is running on **worker node** but it should run on **control-plane**.

```bash
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-worker2 ❌
```

**Symptom**: Access via localhost:80/443 is not working.

### 🔍 Analysis

#### Why Should It Run on Control-Plane?

In Kind configuration, `extraPortMappings` are only on control-plane node:

```yaml
# kind-config.yaml
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80 # ← Only on control-plane!
      - containerPort: 443
        hostPort: 443
```

Worker nodes don't have this mapping, so localhost access doesn't work.

#### Why Did It Land on Worker?

In Kind's NGINX Ingress manifest:

- ✅ `hostNetwork: true` exists
- ❌ `nodeSelector: ingress-ready: "true"` MISSING!
- ❌ `tolerations` MISSING!

**Kubernetes Scheduler Behavior**:

```
Predicate (Filtering):
├─ Control-plane: ✓ (os=linux)
├─ Worker1: ✓ (os=linux)
└─ Worker2: ✓ (os=linux)

Priority (Equal):
├─ Control-plane: 100 points
├─ Worker1: 100 points
└─ Worker2: 100 points

Selection: Random! → Worker2 selected 🎲
```

### ✅ Solution

#### Option 1: Custom Deployment YAML (RECOMMENDED ⭐)

Created `k8s/ingress-nginx-deployment.yaml` file:

```yaml
spec:
  template:
    spec:
      hostNetwork: true
      nodeSelector:
        kubernetes.io/os: linux
        ingress-ready: "true" # ← Control-plane has this label!
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
        - key: node-role.kubernetes.io/master
          operator: Exists
          effect: NoSchedule
```

**Usage**:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

#### Option 2: Patch (Alternative)

```bash
# Using Makefile
make fix-ingress

# Or manual
kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '
{
  "spec": {
    "template": {
      "spec": {
        "nodeSelector": {
          "ingress-ready": "true"
        }
      }
    }
  }
}'
```

**Verification**:

```bash
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-control-plane ✅
```

**Result**: ✅ Ingress Controller running on control-plane.

---

## 3. Admission Webhook Issues

### 🔴 Problem

Pod not starting:

```bash
kubectl describe pod -n ingress-nginx ingress-nginx-controller-xxx

Events:
  Warning  FailedMount  secret "ingress-nginx-admission" not found
```

**Symptom**: Pod in `Pending` state, webhook certificate missing.

### 🔍 Analysis

NGINX Ingress Controller uses **ValidatingWebhook** by default:

- Webhook requires TLS certificate
- Certificate is created by a Job
- This Job sometimes doesn't run in Kind

**Webhook Not Needed in Kind**:

- Local development environment
- Ingress validation not required
- Only important in production

### ✅ Solution

#### Option 1: Webhook-less Deployment (RECOMMENDED ⭐)

Updated `k8s/ingress-nginx-deployment.yaml`:

```yaml
# Removed webhook arguments
args:
  - /nginx-ingress-controller
  - --election-id=ingress-nginx-leader
  - --controller-class=k8s.io/ingress-nginx
  # Webhook disabled
  # - --validating-webhook=:8443
  # - --validating-webhook-certificate=/usr/local/certificates/cert
  # - --validating-webhook-key=/usr/local/certificates/key

# Removed volume
# volumes:
#   - name: webhook-cert
#     secret:
#       secretName: ingress-nginx-admission

# Removed port
ports:
  - name: http
    containerPort: 80
  - name: https
    containerPort: 443
  # - name: webhook        # ← Removed
  #   containerPort: 8443
```

**Application**:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

#### Option 2: Manual Secret Creation

```bash
# Create self-signed certificate
kubectl create secret tls ingress-nginx-admission \
  --cert=<(openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj "/CN=ingress-nginx") \
  --key=<(openssl genrsa 2048) \
  -n ingress-nginx

kubectl delete pod -n ingress-nginx -l app.kubernetes.io/component=controller
```

#### Option 3: Delete Webhooks

```bash
kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission
```

**Verification**:

```bash
kubectl get pods -n ingress-nginx
# STATUS: Running ✅
```

**Result**: ✅ Ingress Controller running without webhooks.

---

## 4. Image Pull Issues

### 🔴 Problem

```bash
kubectl get pods -n ingress-nginx
# STATUS: ImagePullBackOff ❌
```

**Symptom**: Container image cannot be pulled.

### 🔍 Analysis

```bash
kubectl describe pod -n ingress-nginx ingress-nginx-controller-xxx

Events:
  Failed to pull image "registry.k8s.io/ingress-nginx/controller:v1.13.3@sha256:c54d7a8..."
  Error: manifest unknown
```

**Cause**:

- SHA256 digest not available on ARM64 platform
- You're using M1/M2/M3 Mac (ARM64)
- Image is multi-platform but digest is for single platform

**Platform Check**:

```bash
uname -m
# arm64 → ARM Mac ✅
# x86_64 → Intel Mac
```

### ✅ Solution

Removed SHA256 digest, let Docker auto-select platform:

```yaml
# WRONG ❌ (with SHA digest)
image: registry.k8s.io/ingress-nginx/controller:v1.13.3@sha256:c54d7a8ac1c8a04e71091d8a5e6b31f9df9b0a35c7cba73bc87c653ad8ba4b13

# CORRECT ✅ (Platform-agnostic)
image: registry.k8s.io/ingress-nginx/controller:v1.13.3
```

Updated **k8s/ingress-nginx-deployment.yaml**:

```yaml
containers:
  - name: controller
    image: registry.k8s.io/ingress-nginx/controller:v1.13.3
    imagePullPolicy: IfNotPresent
```

**Application**:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml

# Watch image pull
kubectl get pods -n ingress-nginx -w
```

**Verification**:

```bash
kubectl get pods -n ingress-nginx
# STATUS: Running ✅

kubectl describe pod -n ingress-nginx ingress-nginx-controller-xxx | grep "Image:"
# Image: registry.k8s.io/ingress-nginx/controller:v1.13.3
# Image ID: sha256:... (correct image for ARM64)
```

**Result**: ✅ ARM64 image successfully pulled and pod running.

---

## 5. Access Issues

### 🔴 Problem

```bash
curl http://api.local/api/datetime
# curl: (7) Failed to connect to api.local port 80: Connection refused
```

**Symptom**: Endpoints exist, Ingress Controller running but no access.

### 🔍 Analysis

**Possible Causes**:

1. `/etc/hosts` not updated
2. Ingress Controller on worker node
3. hostNetwork false

**Check**:

```bash
# 1. /etc/hosts check
cat /etc/hosts | grep api.local
# If not there, that's the problem!

# 2. Ingress Controller node
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-worker2 means that's the problem!

# 3. hostNetwork
kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o yaml | grep hostNetwork
# false or missing means that's the problem!
```

### ✅ Solution

#### 1. Update /etc/hosts

```bash
# Add
echo "127.0.0.1 api.local web.local" | sudo tee -a /etc/hosts

# Check
grep "api.local\|web.local" /etc/hosts

# Or using Makefile
make update-hosts
```

#### 2. Move Ingress Controller to Control-Plane

See [Section 2](#2-ingress-controller-node-placement) above.

#### 3. Fix hostNetwork

```bash
make fix-ingress

# Or manual
kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '
{
  "spec": {
    "template": {
      "spec": {
        "hostNetwork": true
      }
    }
  }
}'
```

**Verification**:

```bash
# Test
curl http://api.local/api/datetime

# Expected:
{
  "date": "05.10.2025",
  "time": "15:30:45",
  "dayOfWeek": "Sunday",
  "timestamp": "2025-10-05T15:30:45+03:00"
}
```

**Result**: ✅ API and Web application access working.

---

## 📊 Troubleshooting Flowchart

```
┌─────────────────────────────────────┐
│  Cannot access application?         │
└─────────────────┬───────────────────┘
                  │
                  ▼
         ┌─────────────────────┐
         │ Are Endpoints there?│
         └────┬──────────┬─────┘
              │          │
           NO          YES
              │          │
              ▼          ▼
    ┌──────────────┐  ┌──────────────────────┐
    │ Fix Service  │  │ Is Ingress Controller│
    │ YAML         │  │ running?             │
    │ (selector)   │  └────┬──────────┬──────┘
    └──────────────┘       │          │
                        NO          YES
                           │          │
                           ▼          ▼
                ┌────────────────┐  ┌──────────────────┐
                │ Pod STATUS?    │  │ On control-plane?│
                │ - Pending      │  └────┬──────┬──────┘
                │ - ImagePull... │      │      │
                └────┬───────┬───┘   NO     YES
                     │       │        │      │
                     ▼       ▼        ▼      ▼
            ┌─────────┐ ┌─────────┐ ┌────┐ ┌────────┐
            │Webhook  │ │Image    │ │Fix │ │/etc/   │
            │Secret   │ │SHA256   │ │    │ │hosts?  │
            │create   │ │remove   │ └────┘ └────────┘
            └─────────┘ └─────────┘   │       │
                                       ▼       ▼
                                   ✅ SOLVED
```

---

## 🎯 Quick Fix Guide

### Fresh Installation (Recommended)

```bash
# 1. Cleanup
make clean-all

# 2. Deploy with custom Ingress YAML
make deploy

# 3. Verify
make verify

# 4. Test
curl http://api.local/api/datetime
```

### Existing Cluster Issues

```bash
# 1. If no endpoints
kubectl apply -f k8s/api-deployment.yaml
kubectl apply -f k8s/web-deployment.yaml

# 2. If Ingress issues
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml

# 3. /etc/hosts
echo "127.0.0.1 api.local web.local" | sudo tee -a /etc/hosts

# 4. Test
curl http://api.local/api/datetime
```

---

## 📋 Checklist: Deployment Verification

After all issues are resolved:

- [ ] **Node Count**: `kubectl get nodes` → 3 nodes (1 control + 2 worker)
- [ ] **Endpoints**: `kubectl get endpoints` → Each service has 2 endpoints
- [ ] **Ingress Controller**: `kubectl get pods -n ingress-nginx -o wide` → kind-control-plane
- [ ] **Pod Status**: `kubectl get pods` → All Running
- [ ] **hostNetwork**: `kubectl get pod -n ingress-nginx -o yaml | grep hostNetwork` → true
- [ ] **/etc/hosts**: `grep api.local /etc/hosts` → 127.0.0.1 api.local web.local
- [ ] **API Test**: `curl http://api.local/api/datetime` → JSON response
- [ ] **Web Test**: `curl http://web.local` → HTML response
- [ ] **Verify**: `make verify` → All tests passing

---

## 🛠️ Useful Debug Commands

```bash
# General Status
make status
make show-nodes
make verify

# Ingress Controller
kubectl get pods -n ingress-nginx -o wide
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
kubectl describe pod -n ingress-nginx <pod-name>

# Service & Endpoint
kubectl get endpoints
kubectl describe service datetime-api-service

# Ingress
kubectl describe ingress datetime-ingress

# Pods
kubectl get pods -o wide
kubectl logs <pod-name> -f

# Network Test (from inside cluster)
kubectl run test --image=curlimages/curl -it --rm -- curl http://datetime-api-service/api/datetime
```

---

## 📚 Related Documentation

- **[README](README.en.md)**: General usage and installation
- **[WORKER_NODES](WORKER_NODES.en.md)**: Multi-node cluster guide
- **[INGRESS_ROUTING](INGRESS_ROUTING.en.md)**: Ingress routing details
- **[INGRESS_CONTROLLER_FIX](INGRESS_CONTROLLER_FIX.en.md)**: Ingress Controller fix methods
- **[INGRESS_SETUP](INGRESS_SETUP.en.md)**: Ingress setup guide
- **[LOAD_BALANCING](LOAD_BALANCING.en.md)**: Load balancing strategies

---

## 🎓 Lessons Learned

### 1. YAML Order Matters

In Service definition, the order of `ports` and `selector` matters in Kubernetes.

### 2. Kind Scheduler Can Make Random Selections

Without `nodeSelector`, pods can land on random nodes.

### 3. Platform-Specific Image Digests Cause Issues

ARM64/AMD64 have different digests, don't use digest for multi-platform.

### 4. Webhooks Not Needed in Local Development

You can disable admission webhooks in Kind.

### 5. hostNetwork + extraPortMappings = localhost Access

Both are required together for localhost access in Kind.

---

## ✅ Final Configuration

### k8s/ingress-nginx-deployment.yaml (Summary)

```yaml
spec:
  template:
    spec:
      # ✅ Host network
      hostNetwork: true

      # ✅ Run on control-plane
      nodeSelector:
        kubernetes.io/os: linux
        ingress-ready: "true"

      # ✅ Tolerate control-plane taint
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          effect: NoSchedule

      containers:
        - name: controller
          # ✅ Platform-agnostic image
          image: registry.k8s.io/ingress-nginx/controller:v1.13.3

          # ✅ Args without webhook
          args:
            - /nginx-ingress-controller
            - --ingress-class=nginx
            # Webhook disabled

          # ✅ Host ports
          ports:
            - containerPort: 80
              hostPort: 80
            - containerPort: 443
              hostPort: 443
```

---

**Result**: All issues resolved, system working! 🎉
