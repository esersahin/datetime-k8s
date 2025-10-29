<div align="center">

### 🌐 Diğer Dillerde Oku / Read in Other Languages

| 🇹🇷 [Türkçe](QUICK_START.md) | 🇬🇧 [English](QUICK_START.en.md) |
| :-------------------------: | :-----------------------------: |

</div>

---

# Quick Start Guide

## 📋 İçindekiler

1. [Hızlı Kurulum](#-hızlı-kurulum)
2. [Sorun mu Var?](#-sorun-mu-var)
3. [Komut Referansı](#-komut-referansı)
4. [Beklenen Sonuç](#-beklenen-sonuç)
5. [Önemli Dosyalar](#-önemli-dosyalar)
6. [Önemli Notlar](#-önemli-notlar)
7. [Sık Karşılaşılan Hatalar](#-sık-karşılaşılan-hatalar)
8. [Workflow Örnekleri](#-workflow-örnekleri)
9. [Makefile Komut Özeti](#-makefile-komut-özeti)
10. [Checklist](#-checklist)
11. [Yardım](#-yardım)
12. [Başarı!](#-başarı)

---

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
mkdir -p datetime-k8s/{api-csharp,web-csharp,k8s}
cd datetime-k8s

# Tüm artifact dosyalarını ilgili klasörlere kopyala
```

### Adım 2: Deploy Et

```bash
# Tek komutla tüm sistemi kur
make deploy

# Veya shell script ile
make deploy
```

### Adım 3: Test Et

```bash
# Durum kontrolü
make status

# Doğrulama
make verify

# API test
curl http://api-csharp.local/api/datetime

# Web test
curl http://web-csharp.local
```

**Hepsi bu kadar!** 🎉

---

## 🔧 Sorun mu Var?

### Hızlı Kontroller

```bash
# 1. Cluster çalışıyor mu?
kubectl get nodes
# Beklenen: 6 nodes (3 control-planes + 3 workers - HA setup)

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

| Sorun                | Hızlı Çözüm                                                                      |
| -------------------- | -------------------------------------------------------------------------------- |
| **ImagePullBackOff** | `kubectl delete namespace ingress-nginx` → `make deploy`                         |
| **Endpoint yok**     | `kubectl apply -f k8s/`                                                          |
| **Erişim yok**       | `echo "127.0.0.1 api-csharp.local web-csharp.local" \| sudo tee -a /etc/hosts`   |
| **Pod Pending**      | `kubectl describe pod <pod-name>` ile detaylara bakın                            |

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

### Test Sonuçları

```bash
$ curl http://api-csharp.local/api/datetime
{
  "date": "05.10.2025",
  "time": "15:45:30",
  "dayOfWeek": "Pazar",
  "timestamp": "2025-10-05T15:45:30+03:00"
}

$ curl http://web-csharp.local
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

## 📚 Önemli Dosyalar

### Zorunlu Dosyalar

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
│   └── ingress-nginx-deployment.yaml   # ⭐ ÖNEMLİ!
├── Makefile                            # ⭐ ÖNEMLİ!
```

### Dokümantasyon Dosyaları

```
├── docs/                              # Documents
│   ├── ARCHITECTURE.en.md             # 📘 System architecture overview
│   ├── ARCHITECTURE.md                # 📘 Sistem mimarisi genel bakış
│   ├── ARCHITECTURE_C4.en.md          # 📘 C4 model architecture diagrams
│   ├── ARCHITECTURE_C4.md             # 📘 C4 model mimari diyagramları
│   ├── architecture-diagram.md        # 📘 Architecture diagram documentation
│   ├── c4-diagrams.md                 # 📘 C4 diagram generation guide
│   ├── CHANGES_SUMMARY.en.md          # 📄 Summary of changes
│   ├── CHANGES_SUMMARY.md             # 📄 Değişikliklerin özeti
│   ├── HAPROXY_LOADBALANCER.en.md     # 📘 HAProxy load balancer setup
│   ├── HAPROXY_LOADBALANCER.md        # 📘 HAProxy load balancer kurulumu
│   ├── HAPROXY_NGINX_ARCHITECTURE.en.md # 📘 HAProxy vs NGINX architecture
│   ├── HAPROXY_NGINX_ARCHITECTURE.md  # 📘 HAProxy vs NGINX mimarisi
│   ├── INGRESS_CONTROLLER_FIX.en.md   # 📘 Ingress fix methods
│   ├── INGRESS_CONTROLLER_FIX.md      # 📘 Ingress düzeltme yöntemleri
│   ├── INGRESS_ROUTING.en.md          # 📘 Ingress routing explanation
│   ├── INGRESS_ROUTING.md             # 📘 Ingress routing açıklaması
│   ├── INGRESS_SETUP.en.md            # 📘 Ingress setup guide
│   ├── INGRESS_SETUP.md               # 📘 Ingress kurulum rehberi
│   ├── INGRESS-WORKER-NODE-MIGRATION.en.md # 📘 Ingress worker node migration
│   ├── INGRESS-WORKER-NODE-MIGRATION.md # 📘 Ingress worker node taşıma
│   ├── LOAD_BALANCING.en.md           # 📘 Load balancing strategies
│   ├── LOAD_BALANCING.md              # 📘 Yük dengeleme stratejileri
│   ├── MACOS_NETWORK_FIX.en.md        # 📘 macOS network troubleshooting
│   ├── MACOS_NETWORK_FIX.md           # 📘 macOS network sorun giderme
│   ├── PROJECT_SUMMARY.en.md          # 📘 Summary of components and key points
│   ├── PROJECT_SUMMARY.md             # 📘 Bileşenlerin özeti
│   ├── QUICK_START.en.md              # 📘 Quick start guide
│   ├── QUICK_START.md                 # 📘 Hızlı başlangıç rehberi
│   ├── SERVICE_TO_SERVICE_COMMUNICATION.en.md # 📘 Service-to-service calls
│   ├── SERVICE_TO_SERVICE_COMMUNICATION.md # 📘 Servisler arası iletişim
│   ├── WORKER_NODES.en.md             # 📘 Multi-node cluster guide
│   └── WORKER_NODES.md                # 📘 Çok node cluster rehberi
├── Makefile                           # 🎯 Ana otomasyon (ÖNERİLEN!)
├── CONTRIBUTING.md                    # 📖 Nasıl katkıda bulunurum?
└── README.md                          # 📖 Ana dokümantasyon
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

Varsayılan olarak **6 node** çalışır:

- 3 Control-Plane
- 3 Worker

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
127.0.0.1 api-csharp.local web-csharp.local api-go.local web-go.local
::1 api-csharp.local web-csharp.local api-go.local web-go.local

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
kubectl apply -f k8s/api-csharp-deployment.yaml
kubectl apply -f k8s/web-csharp-deployment.yaml
kubectl get endpoints  # Kontrol et
```

### Hata 2: "ImagePullBackOff"

**Neden**: SHA256 digest ARM64'te çalışmıyor.

**Çözüm**:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

### Hata 3: "Failed to connect to api-csharp.local"

**Neden**: /etc/hosts eksik veya Ingress Controller worker'da.

**Çözüm**:

```bash
# /etc/hosts ekle
echo "127.0.0.1 api-csharp.local web-csharp.local" | sudo tee -a /etc/hosts

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
curl http://api-csharp.local/api/datetime
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
for i in {1..100}; do curl -s http://api-csharp.local/api/datetime; done

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
- [ ] 6 nodes var (3 control-planes + 3 workers - HA setup)
- [ ] Ingress Controller control-plane'de
- [ ] Tüm pod'lar Running
- [ ] Endpoint'ler mevcut
- [ ] /etc/hosts güncel
- [ ] `curl http://api-csharp.local/api/datetime` çalışıyor
- [ ] `curl http://web-csharp.local` çalışıyor
- [ ] `make verify` başarılı

---

## 🆘 Yardım

### Sorun Giderme

1. `make verify` → Otomatik sorun tespiti
2. `kubectl describe pod <pod-name>` → Pod detayları
3. `kubectl logs <pod-name>` → Pod logları

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
**Sorun yaşıyorsanız**: `make verify` komutuyla sorunları tespit edin
**Her şey çalışıyorsa**: Keyifli geliştirmeler! 🎨

**Prepared by:** Claude (Anthropic)
**Date:** 2025-10-28
**Version:** 1.1
**Project:** DateTime Kubernetes Polyglot Microservices
