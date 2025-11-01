<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](INGRESS_SETUP.en.md) | 🇹🇷 [Türkçe](INGRESS_SETUP.md) |
| :-------------------------------: | :---------------------------: |

</div>

---

# Ingress Controller Kurulum Rehberi

## 📋 İçindekiler

1. [Önerilen Yöntem: Özel YAML](#-önerilen-yöntem-özel-yaml)
2. [Yüksek Erişilebilirlik (HA) Yapısı](#-yüksek-erişilebilirlik-ha-yapısı)
3. [Kullanım](#-kullanım)
4. [Doğrulama](#-doğrulama)
5. [Sorun Giderme](#-sorun-giderme)
6. [Dosya Özellikleri](#-dosya-özellikleri)
7. [Neden Bu Yöntem?](#-neden-bu-yöntem)
8. [Hızlı Test](#-hızlı-test)
9. [Detaylı Bilgi](#-detaylı-bilgi)

---

## 🎯 Önerilen Yöntem: Özel YAML

Projede `k8s/ingress-nginx-deployment.yaml` dosyası hazır! Bu dosya Kind için optimize edilmiş ve şu ayarları içeriyor:

```yaml
spec:
  replicas: 3  # HA için 3 replica (her worker node'da 1 replica)

  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0  # Zero downtime
      maxSurge: 1        # Progressive rollout

  template:
    spec:
      hostNetwork: true  # Host ağını kullan (port 80/443)
      nodeSelector:
        ingress-ready: "true"  # Worker node'larda çalış
      # tolerations yok - control-plane'de ÇALIŞMASIN
```

## 🏗️ Yüksek Erişilebilirlik (HA) Yapısı

### Cluster Mimarisi

```
┌─────────────────────────────────────────────────────────┐
│                 3 Control Plane Nodes                   │
│  (Kubernetes yönetimi - Ingress çalışmaz)               │
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

### HA Özellikleri

- ✅ **3 Replica**: Her worker node'da 1 Ingress controller
- ✅ **Zero Downtime**: Rolling update ile kesintisiz güncelleme
- ✅ **Load Balancing**: HAProxy trafiği 3 worker'a dağıtır
- ✅ **Fault Tolerance**: 1-2 node çökerse sistem çalışmaya devam eder
- ✅ **Progressive Rollout**: Aynı anda sadece 1 replica güncellenir

## 🚀 Kullanım

### Yöntem 1: Otomatik (Önerilen)

```bash
make deploy
```

Script otomatik olarak:

1. `k8s/ingress-nginx-deployment.yaml` varsa onu kullanır
2. Yoksa Kind'ın varsayılanını kullanır ve patch uygular

### Yöntem 2: Manuel

```bash
# Sadece Ingress Controller kur
kubectl apply -f k8s/ingress-nginx-deployment.yaml

# Hazır olmasını bekle
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Kontrol et
kubectl get pods -n ingress-nginx -o wide
```

### Yöntem 3: Makefile

```bash
# Ingress kur
make install-ingress

# Kontrol et
kubectl get pods -n ingress-nginx -o wide
```

## ✅ Doğrulama

```bash
# 1. Pod'lar worker node'larda mı? (3 replica)
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-worker, kind-worker2, kind-worker3 olmalı
# READY: 3/3

# 2. hostNetwork true mu?
kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o yaml | grep hostNetwork
# hostNetwork: true

# 3. nodeSelector doğru mu?
kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o yaml | grep -A 2 nodeSelector
# nodeSelector:
#   ingress-ready: "true"
#   kubernetes.io/os: linux

# 4. Tolerations yok mu? (control-plane'de çalışmamalı)
kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o yaml | grep -A 2 tolerations
# Çıktı boş olmalı veya sadece node.kubernetes.io/not-ready gibi varsayılan tolerations

# 5. RollingUpdate strategy doğru mu?
kubectl get deployment -n ingress-nginx ingress-nginx-controller -o yaml | grep -A 3 "strategy:"
# maxSurge: 1
# maxUnavailable: 0

# 6. Test - HAProxy üzerinden erişim
curl http://api-csharp.local/api/datetime
curl http://web-csharp.local
```

## 🔧 Sorun Giderme

### Sorun 1: Pod'lar control-plane'de çalışıyor

```bash
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-control-plane, kind-control-plane2, kind-control-plane3 ❌ YANLIŞ!

# Çözüm 1: Deployment'ı güncelle (önerilen)
kubectl delete deployment -n ingress-nginx ingress-nginx-controller
kubectl apply -f k8s/ingress-nginx-deployment.yaml

# Çözüm 2: Cluster'ı yeniden oluştur
make clean-all
make deploy
```

### Sorun 2: Worker node'larda ingress-ready label yok

```bash
kubectl get nodes --show-labels | grep ingress-ready
# Çıktı boş ise label yok

# Çözüm: Label ekle
kubectl label node kind-worker ingress-ready=true --overwrite
kubectl label node kind-worker2 ingress-ready=true --overwrite
kubectl label node kind-worker3 ingress-ready=true --overwrite

# Ingress pod'larını yeniden oluştur
kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller
```

### Sorun 3: Pod'lar Pending durumunda

```bash
kubectl get pods -n ingress-nginx
# STATUS: Pending

kubectl describe pod -n ingress-nginx <pod-name>
# 0/6 nodes are available: 3 node(s) had untolerated taint, 3 node(s) didn't match Pod's node affinity/selector

# Çözüm: Worker node'lara label ekle (Sorun 2'ye bak)
```

### Sorun 4: HAProxy üzerinden erişim çalışmıyor

```bash
curl http://api-csharp.local/api/datetime
# Connection refused veya timeout

# 1. HAProxy çalışıyor mu?
docker ps | grep haproxy

# 2. HAProxy config doğru mu?
cat haproxy/haproxy.cfg | grep -A 5 "backend k8s"

# 3. Ingress pod'ları hazır mı?
kubectl get pods -n ingress-nginx

# Çözüm: HAProxy'yi yeniden başlat
cd haproxy
docker-compose down
docker-compose up -d
```

## 📝 Dosya Özellikleri

**k8s/ingress-nginx-deployment.yaml**:

- 🔹 Tam NGINX Ingress Controller deployment
- 🔹 HA setup için optimize edilmiş (3 replica)
- 🔹 Worker node'lara deployment (nodeSelector)
- 🔹 Zero downtime rollout (RollingUpdate strategy)
- 🔹 ~450 satır (tüm gerekli resource'lar)

**İçerik**:

- ✅ Namespace (ingress-nginx)
- ✅ ServiceAccount
- ✅ ConfigMap (optimize edilmiş ayarlarla)
- ✅ ClusterRole & ClusterRoleBinding
- ✅ Role & RoleBinding
- ✅ Service (NodePort)
- ✅ Deployment (⭐ kritik ayarlarla):
  - `replicas: 3` - HA için
  - `hostNetwork: true` - Host network kullanımı
  - `nodeSelector: ingress-ready=true` - Worker node placement
  - `maxSurge: 1, maxUnavailable: 0` - Progressive rollout
  - ReadinessProbe: `initialDelaySeconds: 5, periodSeconds: 5` - Optimize edilmiş
- ✅ IngressClass

**kind-config.yaml**:

- 🔹 3 Control Plane Nodes (HA)
- 🔹 3 Worker Nodes (Ingress için)
- 🔹 Worker node'larda `ingress-ready=true` label
- 🔹 Port mapping YOK (HAProxy kullanılıyor)

## 🎓 Neden Bu Yöntem?

### Özel YAML vs Diğer Yöntemler

| Özellik              | Özel YAML (Mevcut) | Patch          | Kind Varsayılan        |
| -------------------- | ------------------ | -------------- | ---------------------- |
| **Kontrol**          | ✅ Tam             | ⚠️ Kısmi       | ❌ Yok                 |
| **HA Support**       | ✅ 3 replica       | ❌ 1 replica   | ❌ 1 replica           |
| **Worker Placement** | ✅ Otomatik        | ⚠️ Manuel      | ❌ Control-plane       |
| **Versiyon Kontrol** | ✅ Git'te          | ❌ Runtime     | ❌ Remote              |
| **Tutarlılık**       | ✅ Her zaman       | ⚠️ Manuel      | ❌ Rastgele            |
| **Zero Downtime**    | ✅ RollingUpdate   | ❌ Yok         | ❌ Yok                 |
| **HAProxy Entegre**  | ✅ Uyumlu          | ⚠️ Ekstra ayar | ❌ Uyumsuz             |
| **Production Ready** | ✅ Evet            | ❌ Hayır       | ❌ Hayır               |

### Avantajlar

- ✅ **High Availability**: 3 replica, fault tolerance
- ✅ **Best Practice**: Worker node'larda çalışma (control-plane temiz kalır)
- ✅ **Zero Downtime**: Progressive rollout ile kesintisiz güncelleme
- ✅ **Load Balancing**: HAProxy ile trafik dağıtımı
- ✅ **Consistent**: Git'te versiyonlanmış, her deployment aynı
- ✅ **Optimized**: ReadinessProbe, RollingUpdate strategy optimize edilmiş

## 🚀 Hızlı Test

```bash
# 1. Cluster oluştur (HA setup ile)
make clean-all
make deploy

# 2. Node'ları kontrol et (3 control-plane + 3 worker olmalı)
kubectl get nodes

# 3. Ingress pod'larını kontrol et (3 replica, worker node'larda)
kubectl get pods -n ingress-nginx -o wide

# 4. HAProxy durumu
docker ps | grep haproxy

# 5. Test et (HAProxy üzerinden)
curl http://api-csharp.local/api/datetime
curl http://web-csharp.local

# Beklenen: JSON response ve HTML response ✅
```

## 📚 Detaylı Bilgi

- **[LOAD_BALANCING](LOAD_BALANCING.md)**: HAProxy ve load balancing detayları
- **[INGRESS_ROUTING](INGRESS_ROUTING.md)**: Routing mekanizması
- **[README](../README.md)**: Genel dokümantasyon

---

**Sonuç**: `k8s/ingress-nginx-deployment.yaml` kullanarak Ingress Controller HA yapısıyla worker node'larda çalışacak! 🎉

---

**Son Güncelleme:** 2025-10-31
**Versiyon:** 2.1
**Proje:** DateTime Kubernetes Polyglot Microservices
