<div align="center">

### 🌐 Diğer Dillerde Oku / Read in Other Languages

| 🇹🇷 [Türkçe](docs/QUICK_START.md) | 🇬🇧 [English](docs/QUICK_START.en.md) |
| :------------------------------: | :----------------------------------: |

</div>

---

# Quick Start Guide

Bu rehber DateTime Kubernetes uygulamasını 5 dakikada çalıştırmanızı sağlar.

## ⚡ Hızlı Kurulum

### Ön Gereksinimler

```bash
# Docker, Kind, kubectl kurulu olmalı
docker --version
kind --version
kubectl version --client
```

### Adım 1: Proje Yapısını Oluştur

```bash
# Dizinleri oluştur
mkdir -p datetime-k8s/{api,web,k8s}
cd datetime-k8s

# Tüm artifact dosyalarını ilgili klasörlere kopyala
```

### Adım 2: Deploy Et

```bash
# Tek komutla tüm sistemi kur
make deploy

# Veya shell script ile
./deploy.sh
```

### Adım 3: Test Et

```bash
# Durum kontrolü
make status

# Doğrulama
make verify

# API test
curl http://api.local/api/datetime

# Web test
curl http://web.local
```

**Hepsi bu kadar!** 🎉

---

## 🔧 Sorun mu Var?

### Hızlı Kontroller

```bash
# 1. Cluster çalışıyor mu?
kubectl get nodes
# Beklenen: 3 node (1 control-plane + 2 workers)

# 2. Pod'lar hazır mı?
kubectl get pods --all-namespaces
# Beklenen: Hepsi Running

# 3. Ingress Controller nerede?
kubectl get pods -n ingress-nginx -o wide
# Beklenen: NODE=kind-control-plane

# 4. Endpoint'ler var mı?
kubectl get endpoints
# Beklenen: Her service 2 endpoint
```

### Yaygın Sorunlar

| Sorun                | Hızlı Çözüm                                                                        |
| -------------------- | ---------------------------------------------------------------------------------- |
| **ImagePullBackOff** | `kubectl delete namespace ingress-nginx` → `make deploy`                           |
| **Endpoint yok**     | `kubectl apply -f k8s/`                                                            |
| **Erişim yok**       | `echo "127.0.0.1 api.local web.local" \| sudo tee -a /etc/hosts`                   |
| **Pod Pending**      | `kubectl describe pod <pod-name>` → [TROUBLESHOOTING](TROUBLESHOOTING.md)'ye bakın |

### Detaylı Sorun Giderme

**[TROUBLESHOOTING](TROUBLESHOOTING.md)** dosyasına bakın! 🆘

---

## 📋 Komut Referansı

### Deployment

```bash
make deploy          # Full deployment
make clean-all       # Her şeyi temizle
make redeploy        # Temizle ve yeniden deploy et
```

### Monitoring

```bash
make status          # Genel durum
make show-nodes      # Node detayları
make verify          # Tüm testler
make logs-api        # API logları
make logs-web        # Web logları
```

### Debug

```bash
make fix-ingress     # Ingress düzelt
make fix-webhooks    # Webhook temizle
make test            # Endpoint testleri
```

### Scaling

```bash
make scale-api REPLICAS=3    # API scale
make scale-web REPLICAS=3    # Web scale
make restart-api             # API restart
make restart-web             # Web restart
```

---

## 🎯 Beklenen Sonuç

### Başarılı Kurulum

```bash
$ make status

📊 Cluster Durumu
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

### Test Sonuçları

```bash
$ curl http://api.local/api/datetime
{
  "date": "05.10.2025",
  "time": "15:45:30",
  "dayOfWeek": "Pazar",
  "timestamp": "2025-10-05T15:45:30+03:00"
}

$ curl http://web.local
<!DOCTYPE html>
<html>
  <head><title>Tarih ve Saat Uygulaması</title></head>
  ...
</html>

$ make verify
🔍 Deployment Doğrulama
========================

1. Kind Cluster
✓ Kind cluster mevcut
✓ Kubectl cluster'a bağlı

2. NGINX Ingress Controller
✓ Ingress namespace mevcut
✓ Ingress controller hazır (1 replicas)
✓ hostNetwork: true (Doğru)
✓ ValidatingWebhook yok (Mac/Kind için ideal)

3. Deployments
✓ API deployment mevcut
✓ API pod'ları hazır (2/2)
✓ Web deployment mevcut
✓ Web pod'ları hazır (2/2)

4. Endpoint Testleri
✓ API health endpoint erişilebilir
✓ API datetime endpoint erişilebilir
✓ API valid JSON dönüyor
✓ Web uygulaması erişilebilir

ÖZET
Toplam: 15 | Başarılı: 15 | Başarısız: 0 | Oran: 100%

🎉 TÜM TESTLER BAŞARILI! 🎉
```

---

## 📚 Önemli Dosyalar

### Zorunlu Dosyalar

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
│   └── ingress-nginx-deployment.yaml   # ⭐ ÖNEMLİ!
├── Makefile                            # ⭐ ÖNEMLİ!
└── deploy.sh
```

### Dokümantasyon Dosyaları

```
├── README.md                   # Genel rehber
├── CHANGES_SUMMARY.md          # Değişikliklerin özeti
├── PROJECT_SUMMARY.en.md       # Bileşenlerin ve önemli noktaların özeti
├── QUICK_START.md              # Bu dosya
├── TROUBLESHOOTING.md          # 🆘 Sorun giderme
├── WORKER_NODES.md             # Multi-node detaylar
├── INGRESS_ROUTING.md          # Routing açıklaması
├── INGRESS_CONTROLLER_FIX.md   # Ingress düzeltme
├── INGRESS_SETUP.md            # Ingress kurulum
└── LOAD_BALANCING.md           # Yük dengeleme stratejileri
```

---

## 🎓 Önemli Notlar

### 1. ARM64 (M1/M2/M3 Mac) Kullanıcıları

`k8s/ingress-nginx-deployment.yaml` dosyası ARM64 için optimize edilmiştir:

```yaml
# SHA256 digest YOK - platform otomatik seçilir
image: registry.k8s.io/ingress-nginx/controller:v1.13.3
```

### 2. Multi-Node Cluster

Varsayılan olarak **3 node** çalışır:

- 1 Control-Plane (Ingress Controller burada)
- 2 Worker (Uygulama pod'ları burada)

### 3. Ingress Controller Yerleşimi

**Kritik**: Ingress Controller **mutlaka control-plane'de** olmalı:

```bash
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-control-plane ✅
```

Worker node'daysa **erişim çalışmaz**!

### 4. /etc/hosts

```bash
# Otomatik eklenir (sudo gerekir)
127.0.0.1 api.local web.local

# Kontrol
cat /etc/hosts | grep local
```

### 5. Webhook'lar Devre Dışı

Kind'da admission webhook'lar gereksiz ve sorun çıkarır. Projemizde devre dışı bırakıldı.

---

## 🚨 Sık Karşılaşılan Hatalar

### Hata 1: "Service does not have any active Endpoint"

**Neden**: Service'ler pod'ları bulamıyor.

**Çözüm**:

```bash
kubectl apply -f k8s/api-deployment.yaml
kubectl apply -f k8s/web-deployment.yaml
kubectl get endpoints  # Kontrol et
```

### Hata 2: "ImagePullBackOff"

**Neden**: SHA256 digest ARM64'te çalışmıyor.

**Çözüm**:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

### Hata 3: "Failed to connect to api.local"

**Neden**: /etc/hosts eksik veya Ingress Controller worker'da.

**Çözüm**:

```bash
# /etc/hosts ekle
echo "127.0.0.1 api.local web.local" | sudo tee -a /etc/hosts

# Ingress düzelt
make fix-ingress
```

### Hata 4: "secret ingress-nginx-admission not found"

**Neden**: Webhook sertifikası eksik.

**Çözüm**: Zaten `k8s/ingress-nginx-deployment.yaml` webhook'suz. Kullanın:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

---

## 🔄 Workflow Örnekleri

### Yeni Özellik Geliştirme

```bash
# 1. Kod değiştir (örn: Program.cs)

# 2. Hızlı güncelleme
make quick-update

# 3. Test
curl http://api.local/api/datetime
```

### Tam Yeniden Başlatma

```bash
# 1. Her şeyi temizle
make clean-all

# 2. Yeniden deploy
make deploy

# 3. Doğrula
make verify
```

### Debugging

```bash
# 1. Durum kontrol
make status

# 2. Logları izle
make logs-api

# 3. Pod'a bağlan
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

## 📊 Makefile Komut Özeti

### Temel Komutlar

| Komut         | Açıklama                  |
| ------------- | ------------------------- |
| `make help`   | Tüm komutları listele     |
| `make deploy` | **Full deployment (ANA)** |
| `make verify` | Doğrulama testleri        |
| `make status` | Genel durum               |
| `make test`   | Endpoint testleri         |

### Debugging

| Komut               | Açıklama                |
| ------------------- | ----------------------- |
| `make show-nodes`   | Node detayları          |
| `make logs-api`     | API logları (real-time) |
| `make logs-web`     | Web logları (real-time) |
| `make fix-ingress`  | Ingress düzelt          |
| `make fix-webhooks` | Webhook'ları temizle    |

### Yönetim

| Komut                       | Açıklama                |
| --------------------------- | ----------------------- |
| `make scale-api REPLICAS=3` | API scale               |
| `make scale-web REPLICAS=3` | Web scale               |
| `make restart-api`          | API restart             |
| `make restart-web`          | Web restart             |
| `make clean`                | K8s kaynakları sil      |
| `make clean-all`            | Cluster + kaynaklar sil |
| `make redeploy`             | Tam yeniden deploy      |

---

## 🎯 Checklist

Başarılı deployment için:

- [ ] Docker, Kind, kubectl kurulu
- [ ] Proje dosyaları doğru klasörlerde
- [ ] `make deploy` çalıştırıldı
- [ ] 3 node var (1 control + 2 worker)
- [ ] Ingress Controller control-plane'de
- [ ] Tüm pod'lar Running
- [ ] Endpoint'ler mevcut
- [ ] /etc/hosts güncel
- [ ] `curl http://api.local/api/datetime` çalışıyor
- [ ] `curl http://web.local` çalışıyor
- [ ] `make verify` başarılı

---

## 🆘 Yardım

### Sorun Giderme

1. **TROUBLESHOOTING.md** → Tüm hatalar ve çözümleri
2. `make verify` → Otomatik sorun tespiti
3. `kubectl describe pod <pod-name>` → Pod detayları
4. `kubectl logs <pod-name>` → Pod logları

### Dokümantasyon

- **[README](../README.md)** → Genel bilgi
- **[WORKER_NODES](WORKER_NODES.md)** → Multi-node detaylar
- **[INGRESS_ROUTING](INGRESS_ROUTING.md)** → Network akışı
- **[LOAD_BALANCING](LOAD_BALANCING.md)** → Load balancing

### Komutlar

```bash
make help          # Tüm komutları görüntüle
kubectl get all    # Tüm kaynakları görüntüle
```

---

## 🎉 Başarı!

Eğer bu adımları tamamladıysanız:

✅ Multi-node Kubernetes cluster çalışıyor  
✅ NGINX Ingress Controller aktif  
✅ .NET API ve Web uygulaması erişilebilir  
✅ Load balancing çalışıyor  
✅ Production-like ortam hazır

**Tebrikler!** 🚀

---

**İlk kez kuruyorsanız**: 5-10 dakika sürer  
**Sorun yaşıyorsanız**: [TROUBLESHOOTING](TROUBLESHOOTING.md)'ye bakın  
**Her şey çalışıyorsa**: Keyifli geliştirmeler! 🎨
