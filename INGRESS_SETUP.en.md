<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](INGRESS_SETUP.en.md) | 🇹🇷 [Türkçe](INGRESS_SETUP.md) |
| :-------------------------------: | :---------------------------: |

</div>

---

# Ingress Controller Setup Guide

## 🎯 Recommended Method: Custom YAML

The project includes a ready `k8s/ingress-nginx-deployment.yaml` file! This file is optimized for Kind and includes these settings:

```yaml
spec:
  template:
    spec:
      hostNetwork: true # For localhost:80/443
      nodeSelector:
        ingress-ready: "true" # Run on control-plane
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          effect: NoSchedule # Tolerate taint
```

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
# 1. Is pod on control-plane?
kubectl get pods -n ingress-nginx -o wide
# NODE: should be kind-control-plane

# 2. Is hostNetwork true?
kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o yaml | grep hostNetwork
# hostNetwork: true

# 3. Is nodeSelector correct?
kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o yaml | grep -A 2 nodeSelector
# nodeSelector:
#   ingress-ready: "true"
#   kubernetes.io/os: linux

# 4. Test
curl http://api.local/api/datetime
```

## 🔧 Troubleshooting

### Issue: Pod on worker node

```bash
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-worker or kind-worker2

# Solution 1: Use YAML (recommended)
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml

# Solution 2: Apply patch
make fix-ingress
```

### Issue: YAML file missing

```bash
# Create file or copy from artifact
# k8s/ingress-nginx-deployment.yaml

# Or use patch
make fix-ingress
```

## 📝 File Features

**k8s/ingress-nginx-deployment.yaml**:

- 🔹 Complete NGINX Ingress Controller deployment
- 🔹 Optimized for Kind
- 🔹 ~400 lines (all required resources)
- 🔹 Namespace, RBAC, Service, Deployment, IngressClass

**Contents**:

- ✅ Namespace (ingress-nginx)
- ✅ ServiceAccount
- ✅ ConfigMap
- ✅ ClusterRole & ClusterRoleBinding
- ✅ Role & RoleBinding
- ✅ Service (NodePort)
- ✅ Deployment (⭐ with critical settings)
- ✅ IngressClass

## 🎓 Why This Method?

| Feature         | Custom YAML | Patch        | Kind Default   |
| --------------- | ----------- | ------------ | -------------- |
| **Control**     | ✅ Full     | ⚠️ Partial   | ❌ None        |
| **Version**     | ✅ In Git   | ❌ Runtime   | ❌ Remote      |
| **Consistency** | ✅ Always   | ⚠️ Manual    | ❌ Random      |
| **Simplicity**  | ✅ One cmd  | ⚠️ Two steps | ❌ Problematic |

## 🚀 Quick Test

```bash
# 1. Create cluster
make clean-all
make deploy

# 2. Check
kubectl get pods -n ingress-nginx -o wide

# 3. Test
curl http://api.local/api/datetime

# Expected: JSON response ✅
```

## 📚 Detailed Information

- **[INGRESS_CONTROLLER_FIX](INGRESS_CONTROLLER_FIX.en.md)**: All solutions and detailed explanation
- **[INGRESS_ROUTING](INGRESS_ROUTING.en.md)**: Routing mechanism
- **[README](README.en.md)**: General documentation

---

**Result**: Using `k8s/ingress-nginx-deployment.yaml`, Ingress Controller will always run on control-plane! 🎉
