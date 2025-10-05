<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](INGRESS_CONTROLLER_FIX.en.md) | 🇹🇷 [Türkçe](INGRESS_CONTROLLER_FIX.md) |
|:---:|:---:|

</div>

---

# Ingress Controller Move to Control-Plane Guide

## 📋 Table of Contents

1. [Problem](#-problem)
2. [Solutions](#-solutions)
3. [Verification](#-verification)
4. [Changes](#-changes)
5. [Why Is This Necessary?](#-why-is-this-necessary)
6. [Recommended Approach](#-recommended-approach)
7. [Summary](#-summary)

---

This document explains why Ingress Controller sometimes lands on worker nodes and how to move it to control-plane.

## 🎯 Problem

In Kind, NGINX Ingress Controller sometimes runs on worker nodes. In this case, access via localhost:80/443 doesn't work because `extraPortMappings` are only defined on control-plane node.

## ✅ Solutions

### Solution 1: Custom Deployment YAML (RECOMMENDED! ⭐)

The project now includes `k8s/ingress-nginx-deployment.yaml` file. This file has:
- ✅ hostNetwork: true
- ✅ nodeSelector: ingress-ready: "true"
- ✅ Control-plane tolerations
- ✅ All required RBAC and Services

**Usage**:

```bash
# Automatic (deploy.sh or Makefile)
make deploy
# or
./deploy.sh

# Manual
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

**Advantages**:
- ✅ Full control - all settings in YAML
- ✅ Version control - can be tracked in Git
- ✅ Always same configuration
- ✅ No need for patch

### Solution 2: Automatic (deploy.sh)

The `deploy.sh` script first checks for custom YAML, otherwise uses Kind's default and applies patch:

```bash
./deploy.sh
# Or
make deploy
```

### Solution 3: Manual Patch Script

To fix Ingress only:

```bash
chmod +x patch-ingress-controller.sh
./patch-ingress-controller.sh
```

### Solution 4: Makefile

```bash
make fix-ingress
```

This command:
- Checks and fixes hostNetwork
- Checks node placement
- Moves to control-plane if needed

### Solution 5: Manual kubectl patch

```bash
kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type=strategic -p '
{
  "spec": {
    "template": {
      "spec": {
        "hostNetwork": true,
        "nodeSelector": {
          "kubernetes.io/os": "linux",
          "ingress-ready": "true"
        },
        "tolerations": [
          {
            "key": "node-role.kubernetes.io/control-plane",
            "operator": "Exists",
            "effect": "NoSchedule"
          }
        ]
      }
    }
  }
}'

# Wait for rollout
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx
```

### Solution 6: YAML File (Kustomize)

```bash
# k8s/ingress-controller-patch.yaml file created
kubectl apply -f k8s/ingress-controller-patch.yaml

# Or with kustomize
kubectl apply -k k8s/
```

## 🔍 Verification

```bash
# 1. Which node is pod on?
kubectl get pods -n ingress-nginx -o wide

# Expected:
# NAME                                       NODE
# ingress-nginx-controller-xxx              kind-control-plane

# 2. Is nodeSelector correct?
kubectl get deployment -n ingress-nginx ingress-nginx-controller -o yaml | grep -A 3 nodeSelector

# Expected:
# nodeSelector:
#   ingress-ready: "true"
#   kubernetes.io/os: linux

# 3. Is hostNetwork true?
kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.template.spec.hostNetwork}'

# Expected: true

# 4. Test
curl http://api.local/api/datetime
```

## 📋 Changes

### Added Settings

```yaml
spec:
  template:
    spec:
      hostNetwork: true
      nodeSelector:
        kubernetes.io/os: linux
        ingress-ready: "true"      # ← This is critical!
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master  # For older K8s versions
        operator: Exists
        effect: NoSchedule
```

## 🎓 Why Is This Necessary?

### Kind Configuration

```yaml
# kind-config.yaml
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"  # ← Only on control-plane!
  extraPortMappings:
  - containerPort: 80
    hostPort: 80        # ← Host connection only on control-plane!
```

### Default Ingress Manifest

In Kind's provided manifest:
- ✅ `hostNetwork: true` exists
- ❌ `nodeSelector: ingress-ready: "true"` MISSING!
- ❌ Toleration MISSING!

That's why the pod can land on any random node.

## 🚀 Recommended Approach

**For new projects**: Use `deploy.sh` or `make deploy` (automatic fix)

**For existing projects**:
1. Run `./patch-ingress-controller.sh`
2. Or use `make fix-ingress`

## 📝 Summary

| Method | Usage | Automatic | Persistent |
|--------|----------|----------|--------|
| **deploy.sh** | `./deploy.sh` | ✅ | ✅ |
| **Makefile** | `make fix-ingress` | ✅ | ✅ |
| **patch-ingress-controller.sh** | `./patch-ingress-controller.sh` | ✅ | ✅ |
| **kubectl patch** | Manual command | ❌ | ✅ |
| **ingress-controller-patch.yaml** | `kubectl apply` | ❌ | ✅ |

**All methods are persistent** - deployment spec is updated, settings are preserved even if pod restarts.

---

**Result**: Now Ingress Controller will always run on control-plane and access via localhost:80/443 will work smoothly! 🎉
