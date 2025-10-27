<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](INGRESS_CONTROLLER_FIX.en.md) | 🇹🇷 [Türkçe](INGRESS_CONTROLLER_FIX.md) |
|:---:|:---:|

</div>

---

﻿# Ingress Controller Control-Plane'e Taşıma Rehberi

## 📋 İçindekiler

1. [Sorun](#-sorun)
2. [Çözümler](#-çözümler)
3. [Doğrulama](#-doğrulama)
4. [Değişiklikler](#-değişiklikler)
5. [Neden Bu Gerekli?](#-neden-bu-gerekli)
6. [Önerilen Yaklaşım](#-önerilen-yaklaşım)
7. [Özet](#-özet)

---

Bu dokümanda Ingress Controller'ın neden worker node'a düştüğü ve nasıl control-plane'e taşınacağı açıklanmaktadır.

## 🎯 Sorun

Kind'da NGINX Ingress Controller bazen worker node'larda çalışıyor. Bu durumda localhost:80/443 üzerinden erişim çalışmıyor çünkü `extraPortMappings` sadece control-plane node'unda tanımlı.

## ✅ Çözümler

### Çözüm 1: Özel Deployment YAML (ÖNERİLEN! ⭐)

Projede artık `k8s/ingress-nginx-deployment.yaml` dosyası var. Bu dosya:
- ✅ hostNetwork: true
- ✅ nodeSelector: ingress-ready: "true"
- ✅ Control-plane tolerations
- ✅ Tüm gerekli RBAC ve Service'ler

**Kullanım**:

```bash
# Otomatik (Makefile)
make deploy

# Manuel
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

**Avantajlar**:
- ✅ Tam kontrol - tüm ayarlar YAML'da
- ✅ Versiyon kontrolü - Git'te takip edilebilir
- ✅ Her zaman aynı yapılandırma
- ✅ Patch'e gerek yok

### Çözüm 2: Makefile

```bash
make fix-ingress
```

Bu komut:
- hostNetwork'u kontrol edip düzeltir
- Node yerleşimini kontrol eder
- Gerekirse control-plane'e taşır

### Çözüm 3: Manuel kubectl patch

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

# Rollout bekle
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx
```

### Çözüm 4: YAML Dosyası ile (Kustomize)

```bash
# k8s/ingress-controller-patch.yaml dosyası oluşturuldu
kubectl apply -f k8s/ingress-controller-patch.yaml

# Veya kustomize ile
kubectl apply -k k8s/
```

## 🔍 Doğrulama

```bash
# 1. Pod hangi node'da?
kubectl get pods -n ingress-nginx -o wide

# Beklenen:
# NAME                                       NODE
# ingress-nginx-controller-xxx              kind-control-plane

# 2. nodeSelector doğru mu?
kubectl get deployment -n ingress-nginx ingress-nginx-controller -o yaml | grep -A 3 nodeSelector

# Beklenen:
# nodeSelector:
#   ingress-ready: "true"
#   kubernetes.io/os: linux

# 3. hostNetwork true mu?
kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.template.spec.hostNetwork}'

# Beklenen: true

# 4. Test
curl http://api-csharp.local/api/datetime
```

## 📋 Değişiklikler

### Eklenen Ayarlar

```yaml
spec:
  template:
    spec:
      hostNetwork: true
      nodeSelector:
        kubernetes.io/os: linux
        ingress-ready: "true"      # ← Bu kritik!
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master  # Eski K8s versiyonları için
        operator: Exists
        effect: NoSchedule
```

## 🎓 Neden Bu Gerekli?

### Kind Yapılandırması

```yaml
# kind-config.yaml
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"  # ← Sadece control-plane'de!
  extraPortMappings:
  - containerPort: 80
    hostPort: 80        # ← Host'a bağlantı sadece control-plane'de!
```

### Varsayılan Ingress Manifest

Kind'ın sağladığı manifest'te:
- ✅ `hostNetwork: true` var
- ❌ `nodeSelector: ingress-ready: "true"` YOK!
- ❌ Toleration YOK!

Bu yüzden pod rastgele bir node'a düşebiliyor.

## 🚀 Önerilen Yaklaşım

**Yeni projeler için**: `make deploy` kullanın (otomatik düzeltme)

**Mevcut projeler için**: `make fix-ingress` kullanın

## 📝 Özet

| Yöntem | Kullanım | Otomatik | Kalıcı |
|--------|----------|----------|--------|
| **Makefile** | `make deploy` / `make fix-ingress` | ✅ | ✅ |
| **kubectl patch** | Manuel komut | ❌ | ✅ |
| **ingress-controller-patch.yaml** | `kubectl apply` | ❌ | ✅ |

**Tüm yöntemler kalıcıdır** - deployment spec'i güncellenir, pod restart olsa bile ayarlar korunur.

---

**Sonuç**: Artık Ingress Controller her zaman control-plane'de çalışacak ve localhost:80/443 üzerinden erişim sorunsuz çalışacak! 🎉