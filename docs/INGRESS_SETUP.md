<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](docs/INGRESS_SETUP.en.md) | 🇹🇷 [Türkçe](docs/INGRESS_SETUP.md) |
| :-------------------------------: | :---------------------------: |

</div>

---

# Ingress Controller Kurulum Rehberi

## 🎯 Önerilen Yöntem: Özel YAML

Projede `k8s/ingress-nginx-deployment.yaml` dosyası hazır! Bu dosya Kind için optimize edilmiş ve şu ayarları içeriyor:

```yaml
spec:
  template:
    spec:
      hostNetwork: true # localhost:80/443 için
      nodeSelector:
        ingress-ready: "true" # Control-plane'de çalış
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          effect: NoSchedule # Taint'i tolere et
```

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
# 1. Pod control-plane'de mi?
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-control-plane olmalı

# 2. hostNetwork true mu?
kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o yaml | grep hostNetwork
# hostNetwork: true

# 3. nodeSelector doğru mu?
kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o yaml | grep -A 2 nodeSelector
# nodeSelector:
#   ingress-ready: "true"
#   kubernetes.io/os: linux

# 4. Test
curl http://api.local/api/datetime
```

## 🔧 Sorun Giderme

### Sorun: Pod worker node'da

```bash
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-worker veya kind-worker2

# Çözüm 1: YAML'ı kullan (önerilen)
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml

# Çözüm 2: Patch uygula
make fix-ingress
```

### Sorun: YAML dosyası yok

```bash
# Dosyayı oluştur veya artifact'tan kopyala
# k8s/ingress-nginx-deployment.yaml

# Veya patch kullan
make fix-ingress
```

## 📝 Dosya Özellikleri

**k8s/ingress-nginx-deployment.yaml**:

- 🔹 Tam NGINX Ingress Controller deployment
- 🔹 Kind için optimize edilmiş
- 🔹 ~400 satır (tüm gerekli resource'lar)
- 🔹 Namespace, RBAC, Service, Deployment, IngressClass

**İçerik**:

- ✅ Namespace (ingress-nginx)
- ✅ ServiceAccount
- ✅ ConfigMap
- ✅ ClusterRole & ClusterRoleBinding
- ✅ Role & RoleBinding
- ✅ Service (NodePort)
- ✅ Deployment (⭐ kritik ayarlarla)
- ✅ IngressClass

## 🎓 Neden Bu Yöntem?

| Özellik        | Özel YAML    | Patch       | Kind Varsayılan |
| -------------- | ------------ | ----------- | --------------- |
| **Kontrol**    | ✅ Tam       | ⚠️ Kısmi    | ❌ Yok          |
| **Versiyon**   | ✅ Git'te    | ❌ Runtime  | ❌ Remote       |
| **Tutarlılık** | ✅ Her zaman | ⚠️ Manuel   | ❌ Rastgele     |
| **Basitlik**   | ✅ Tek komut | ⚠️ İki adım | ❌ Sorunlu      |

## 🚀 Hızlı Test

```bash
# 1. Cluster oluştur
make clean-all
make deploy

# 2. Kontrol et
kubectl get pods -n ingress-nginx -o wide

# 3. Test et
curl http://api.local/api/datetime

# Beklenen: JSON response ✅
```

## 📚 Detaylı Bilgi

- **[INGRESS_CONTROLLER_FIX](INGRESS_CONTROLLER_FIX.md)**: Tüm çözümler ve detaylı açıklama
- **[INGRESS_ROUTING](INGRESS_ROUTING.md)**: Routing mekanizması
- **[README](../README.md)**: Genel dokümantasyon

---

**Sonuç**: `k8s/ingress-nginx-deployment.yaml` kullanarak Ingress Controller her zaman control-plane'de çalışacak! 🎉
