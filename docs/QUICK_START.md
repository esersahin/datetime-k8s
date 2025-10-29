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
mkdir -p datetime-k8s/{api-csharp,web-csharp,api-go,web-go,k8s}
cd datetime-k8s

# Tüm artifact dosyalarını ilgili klasörlere kopyala
```

### Adım 2: Deploy Et

```bash
# Tek komutla tüm sistemi kur (3+3 HA Cluster + Polyglot APIs)
make deploy

# İçeride otomatik olarak:
# - 3 control-plane + 3 worker nodes (HA)
# - NGINX Ingress Controller (worker nodes, 3 replicas)
# - HAProxy Load Balancer
# - C# API + Go API (3 replicas each)
# - C# Web + Go Web (2 replicas each)
# - /etc/hosts update
```

### Adım 3: Test Et

```bash
# Durum kontrolü
make status

# Doğrulama (20 test)
make verify

# API testleri
curl http://api-csharp.local/api/datetime  # C# API
curl http://api-go.local/health            # Go API

# Web testleri
curl http://web-csharp.local  # Türkçe UI
curl http://web-go.local      # English UI
```

**Hepsi bu kadar!** 🎉

---

## 🔧 Sorun mu Var?

### Hızlı Kontroller

```bash
# 1. Cluster çalışıyor mu?
kubectl get nodes
# Beklenen: 6 nodes (3 control-plane + 3 worker - HA setup)

# 2. Pod'lar hazır mı?
kubectl get pods --all-namespaces
# Beklenen: Hepsi Running (13 application pods)

# 3. Ingress Controller nerede?
kubectl get pods -n ingress-nginx -o wide
# Beklenen: 3 pods, all on worker nodes (kind-worker, kind-worker2, kind-worker3)

# 4. HAProxy çalışıyor mu?
docker ps | grep haproxy
# Beklenen: haproxy-lb container running

# 5. Endpoint'ler var mı?
kubectl get endpoints
# Beklenen: 4 services with endpoints (C# API, Go API, C# Web, Go Web)
```

### Yaygın Sorunlar

| Sorun                | Hızlı Çözüm                                                                      |
| -------------------- | -------------------------------------------------------------------------------- |
| **ImagePullBackOff** | `kubectl delete namespace ingress-nginx` → `make install-ingress`                |
| **Endpoint yok**     | `kubectl apply -f k8s/`                                                          |
| **Erişim yok**       | `make update-hosts` veya manuel: `echo "127.0.0.1 api-csharp.local web-csharp.local api-go.local web-go.local" \| sudo tee -a /etc/hosts` |
| **Pod Pending**      | `kubectl describe pod <pod-name>` ile detaylara bakın                            |
| **Worker node yok**  | `kind delete cluster` → `make deploy` (kind-config.yaml otomatik oluşturulur)   |

---

## 📋 Komut Referansı

### Deployment

```bash
make deploy          # Full deployment (3+3 HA cluster)
make clean-all       # Her şeyi temizle
make redeploy        # Temizle ve yeniden deploy et
make setup-haproxy   # HAProxy load balancer kur
```

### Monitoring

```bash
make status          # Genel durum
make show-nodes      # Node detayları
make verify          # 20 otomatik test
make logs-api        # C# API logları
make logs-api-go     # Go API logları
make logs-web        # Web logları
```

### Debug

```bash
make fix-ingress     # Ingress düzelt (hostNetwork + nodeSelector)
make fix-webhooks    # Webhook temizle
make test            # Endpoint testleri
```

### Scaling

```bash
make scale-api REPLICAS=5       # C# API scale
make scale-api-go REPLICAS=5    # Go API scale
make scale-web REPLICAS=3       # Web scale
make restart-api                # C# API restart
make restart-api-go             # Go API restart
make restart-web                # Web restart
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

Ingress Pods (should be on worker nodes):
NAME                                        READY   STATUS    NODE
ingress-nginx-controller-7c9f5d4b8f-abc12   1/1     Running   kind-worker    ✅
ingress-nginx-controller-7c9f5d4b8f-def34   1/1     Running   kind-worker2   ✅
ingress-nginx-controller-7c9f5d4b8f-ghi56   1/1     Running   kind-worker3   ✅

Application Pods (with Node placement):
NAME                                   READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
datetime-api-csharp-5b755f6575-7cmh9   1/1     Running   0          30m   10.244.5.2   kind-worker3   <none>           <none>
datetime-api-csharp-5b755f6575-bbxvn   1/1     Running   0          30m   10.244.3.2   kind-worker2   <none>           <none>
datetime-api-csharp-5b755f6575-qdb5x   1/1     Running   0          30m   10.244.4.2   kind-worker    <none>           <none>
datetime-api-go-69d7d7c5c-gxfbg        1/1     Running   0          30m   10.244.4.4   kind-worker    <none>           <none>
datetime-api-go-69d7d7c5c-h4p6c        1/1     Running   0          30m   10.244.3.5   kind-worker2   <none>           <none>
datetime-api-go-69d7d7c5c-sdm75        1/1     Running   0          30m   10.244.5.4   kind-worker3   <none>           <none>
datetime-web-csharp-78cb6c4558-4jb4s   1/1     Running   0          30m   10.244.4.3   kind-worker    <none>           <none>
datetime-web-csharp-78cb6c4558-nllpm   1/1     Running   0          30m   10.244.5.3   kind-worker3   <none>           <none>
datetime-web-go-5c776fd996-fdlf8       1/1     Running   0          30m   10.244.5.5   kind-worker3   <none>           <none>
datetime-web-go-5c776fd996-knz8p       1/1     Running   0          30m   10.244.3.4   kind-worker2   <none>           <none>

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

HAProxy Load Balancer:
CONTAINER ID   IMAGE                 PORTS                                           STATUS
abc123def456   haproxy:2.9-alpine    0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp,...    Up 30 minutes
```

### Test Sonuçları

```bash
$ curl http://api-csharp.local/api/datetime
{
  "date": "29.10.2025",
  "time": "15:45:30",
  "dayOfWeek": "Çarşamba",
  "timestamp": "2025-10-29T15:45:30+03:00",
  "goApiData": {
    "timezone": "Europe/Istanbul",
    "offset": "+03:00"
  }
}

$ curl http://api-go.local/health
{
  "status": "healthy",
  "timestamp": "2025-10-29T15:45:30Z",
  "uptime": "30m15s"
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
✓ Kind cluster mevcut (6 nodes: 3 control-plane + 3 worker)

2. NGINX Ingress Controller
✓ Ingress namespace mevcut
✓ 3 ingress pods running
✓ All ingress pods on worker nodes ✅
✓ hostNetwork: true (Doğru)
✓ ValidatingWebhook yok (İdeal)

3. HAProxy Load Balancer
✓ HAProxy container running
✓ Health checks configured
✓ All 3 workers UP

4. Deployments
✓ C# API deployment (3 replicas)
✓ Go API deployment (3 replicas)
✓ C# Web deployment (2 replicas)
✓ Go Web deployment (2 replicas)

5. Services & Endpoints
✓ 4 ClusterIP services
✓ All services have endpoints

6. Endpoint Testleri
✓ C# API health endpoint
✓ C# API datetime endpoint
✓ Go API health endpoint
✓ C# Web accessible
✓ Go Web accessible

ÖZET
Toplam: 20 | Başarılı: 20 | Başarısız: 0 | Oran: 100%

🎉 TÜM TESTLER BAŞARILI! 🎉
```

---

## 📚 Önemli Dosyalar

### Zorunlu Dosyalar

```
datetime-k8s/
├── api-csharp/                        # C# API (32.6 MB Alpine image)
│   ├── Program.cs                     # Minimal API + Resiliency
│   ├── DateTimeApi.csproj
│   └── Dockerfile.api                 # Multi-stage Alpine build
├── web-csharp/                        # Web (Turkish UI)
│   ├── index.html
│   ├── nginx.conf
│   └── Dockerfile.web
├── api-go/                            # Go API (~15 MB Alpine image)
│   ├── main.go                        # Go HTTP server
│   ├── handlers/
│   ├── models/
│   └── Dockerfile                     # Statically compiled Go
├── web-go/                            # Web (English UI)
│   ├── index.html
│   ├── nginx.conf
│   └── Dockerfile
├── k8s/
│   ├── api-csharp-deployment.yaml     # C# API (3 replicas)
│   ├── api-go-deployment.yaml         # Go API (3 replicas)
│   ├── web-csharp-deployment.yaml     # Web (2 replicas)
│   ├── web-go-deployment.yaml         # Web (2 replicas)
│   ├── kind-config.yaml               # ⭐ 3+3 HA cluster
│   ├── ingress.yaml                   # 4 domain routing
│   ├── ingress-nginx-deployment.yaml  # ⭐ Worker nodes (3 replicas)
│   └── haproxy-lb.cfg                 # ⭐ Load balancer
├── Makefile                           # ⭐ Ana otomasyon
```

### Dokümantasyon Dosyaları (20+ docs)

```
docs/
├── ARCHITECTURE.md                # Mimari diyagramlar
├── DOCKER_OPTIMIZATION.md         # Image optimization (277 MB → 32.6 MB)
├── SERVICE_TO_SERVICE_COMMUNICATION.md  # C# → Go, Circuit Breaker
├── HAPROXY_LOADBALANCER.md        # HAProxy setup
├── CHANGES_SUMMARY.md             # Değişiklik özeti
├── PROJECT_SUMMARY.md             # Proje özeti
├── QUICK_START.md                 # Bu dosya
├── WORKER_NODES.md                # Multi-node cluster
├── INGRESS_ROUTING.md             # Traffic routing
├── LOAD_BALANCING.md              # Load balancing
└── ... (20+ documents TR + EN)
```

---

## 🎓 Önemli Notlar

### 1. ARM64 (M1/M2/M3 Mac) Kullanıcıları

`k8s/ingress-nginx-deployment.yaml` dosyası ARM64 için optimize edilmiştir:

```yaml
# SHA256 digest YOK - platform otomatik seçilir
image: registry.k8s.io/ingress-nginx/controller:v1.13.3
```

### 2. Multi-Node HA Cluster

Varsayılan olarak **6 node** çalışır:

- **3 Control-Plane** (etcd quorum için)
- **3 Worker** (application pods için)

```bash
$ kubectl get nodes
NAME                  STATUS   ROLES           AGE
kind-control-plane    Ready    control-plane   30m
kind-control-plane2   Ready    control-plane   30m
kind-control-plane3   Ready    control-plane   30m
kind-worker           Ready    <none>          30m
kind-worker2          Ready    <none>          30m
kind-worker3          Ready    <none>          30m
```

### 3. Ingress Controller Yerleşimi ⭐

**KRİTİK**: Ingress Controller **WORKER NODE'LARDA** çalışır (3 replika):

```bash
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-worker, kind-worker2, kind-worker3 ✅
```

**NEDEN?**
- ✅ HA (High Availability) - 3 replika
- ✅ Load balancing - HAProxy distributes
- ✅ Optimal performance - Separation of concerns
- ✅ Production-like - Control plane for management only

**Eski Hata**: Control-plane'de çalıştırmaya çalışıyordu ❌

### 4. HAProxy Load Balancer

HAProxy container, worker node'lardaki ingress controller'lara trafik dağıtır:

```bash
# HAProxy stats dashboard
curl http://localhost:8404

# Backend'ler
- kind-worker:80    (UP)
- kind-worker2:80   (UP)
- kind-worker3:80   (UP)
```

### 5. /etc/hosts

```bash
# Otomatik eklenir (sudo gerekir)
127.0.0.1 api-csharp.local web-csharp.local api-go.local web-go.local
::1 api-csharp.local web-csharp.local api-go.local web-go.local

# Kontrol
cat /etc/hosts | grep local
```

### 6. Docker Image Optimization

**C# API**: 277 MB → **32.6 MB** (-%88.2)
- Alpine Linux base
- Self-contained + trimmed
- Invariant globalization

**Go API**: ~**15 MB**
- Statically compiled
- No CGO dependencies

### 7. Polyglot Microservices

**4 Applications**:
1. **C# API** - .NET 9, datetime service, calls Go API
2. **Go API** - High-performance, timezone/calculator
3. **C# Web** - Turkish UI, consumes C# API
4. **Go Web** - English UI, consumes Go API

**Service-to-Service**:
- C# API → Go API (Circuit Breaker, Retry, Rate Limiting)

### 8. Webhook'lar Devre Dışı

Kind'da admission webhook'lar gereksiz ve sorun çıkarır. Projemizde devre dışı bırakıldı.

---

## 🚨 Sık Karşılaşılan Hatalar

### Hata 1: "Service does not have any active Endpoint"

**Neden**: Service'ler pod'ları bulamıyor.

**Çözüm**:

```bash
kubectl apply -f k8s/
kubectl get endpoints  # Kontrol et
```

### Hata 2: "ImagePullBackOff"

**Neden**: SHA256 digest ARM64'te çalışmıyor veya image pull hatası.

**Çözüm**:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

### Hata 3: "Failed to connect to api-csharp.local"

**Neden**: /etc/hosts eksik veya HAProxy çalışmıyor.

**Çözüm**:

```bash
# /etc/hosts ekle
make update-hosts

# HAProxy kontrol
docker ps | grep haproxy

# HAProxy yeniden başlat
make setup-haproxy
```

### Hata 4: "secret ingress-nginx-admission not found"

**Neden**: Webhook sertifikası eksik.

**Çözüm**: `k8s/ingress-nginx-deployment.yaml` webhook'suz:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

### Hata 5: "Ingress pods on control-plane"

**Neden**: Eski manifest kullanılıyor.

**Çözüm**: Yeni manifest kullan:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml

# Kontrol: Worker node'larda mı?
kubectl get pods -n ingress-nginx -o wide
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

# 4. Logları izle
make logs-api
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
make logs-api        # C# API
make logs-api-go     # Go API

# 3. Pod'a bağlan
kubectl exec -it <pod-name> -- /bin/sh

# 4. Network test (cluster içinden)
kubectl run test --image=curlimages/curl -it --rm -- \
  curl http://datetime-api-csharp-service/health
```

### Load Testing

```bash
# 1. Scale up
make scale-api REPLICAS=10
make scale-api-go REPLICAS=10

# 2. Parallel requests
for i in {1..1000}; do
  curl -s http://api-csharp.local/api/datetime &
done
wait

# 3. Monitor
kubectl top pods

# 4. Scale down
make scale-api REPLICAS=3
make scale-api-go REPLICAS=3
```

### Circuit Breaker Test

```bash
# 1. Go API'yi durdur
kubectl scale deployment datetime-api-go --replicas=0

# 2. C# API hala çalışıyor mu?
curl http://api-csharp.local/api/datetime
# Circuit breaker devrede, fallback response

# 3. Logları kontrol et
make logs-api  # Circuit breaker logs

# 4. Go API'yi geri getir
kubectl scale deployment datetime-api-go --replicas=3
```

---

## 📊 Makefile Komut Özeti

### Temel Komutlar

| Komut         | Açıklama                     |
| ------------- | ---------------------------- |
| `make help`   | Tüm komutları listele        |
| `make deploy` | **Full deployment (3+3 HA)** |
| `make verify` | 20 doğrulama testi           |
| `make status` | Genel durum                  |
| `make test`   | Endpoint testleri            |

### Cluster Yönetimi

| Komut                  | Açıklama                     |
| ---------------------- | ---------------------------- |
| `make create-cluster`  | Kind cluster oluştur         |
| `make install-ingress` | NGINX Ingress kur            |
| `make setup-haproxy`   | HAProxy load balancer kur    |
| `make clean-cluster`   | Cluster sil                  |

### Debugging

| Komut               | Açıklama                |
| ------------------- | ----------------------- |
| `make show-nodes`   | Node detayları          |
| `make logs-api`     | C# API logları          |
| `make logs-api-go`  | Go API logları          |
| `make logs-web`     | Web logları             |
| `make fix-ingress`  | Ingress düzelt          |
| `make fix-webhooks` | Webhook'ları temizle    |

### Build & Update

| Komut               | Açıklama                  |
| ------------------- | ------------------------- |
| `make build-all`    | Tüm images (C# + Go)      |
| `make build-api`    | C# API build              |
| `make build-api-go` | Go API build              |
| `make load-images`  | Images → Kind cluster     |
| `make quick-update` | Hızlı kod güncelleme      |

### Scaling & Management

| Komut                       | Açıklama                |
| --------------------------- | ----------------------- |
| `make scale-api REPLICAS=5` | C# API scale            |
| `make scale-api-go REPLICAS=5` | Go API scale         |
| `make scale-web REPLICAS=3` | Web scale               |
| `make restart-api`          | C# API restart          |
| `make restart-api-go`       | Go API restart          |
| `make restart-web`          | Web restart             |

### Cleanup

| Komut             | Açıklama                |
| ----------------- | ----------------------- |
| `make clean`      | K8s kaynakları sil      |
| `make clean-all`  | Cluster + kaynaklar sil |
| `make redeploy`   | Tam yeniden deploy      |

---

## 🎯 Checklist

Başarılı deployment için:

- [ ] Docker, Kind, kubectl kurulu
- [ ] Proje dosyaları doğru klasörlerde
- [ ] `make deploy` çalıştırıldı
- [ ] 6 nodes var (3 control-plane + 3 worker - HA)
- [ ] **Ingress Controller worker node'larda (3 replika)** ✅
- [ ] HAProxy container running
- [ ] 13 application pods Running
  - [ ] 3x datetime-api-csharp
  - [ ] 3x datetime-api-go
  - [ ] 2x datetime-web-csharp
  - [ ] 2x datetime-web-go
  - [ ] 3x ingress-nginx-controller
- [ ] 4 ClusterIP services
- [ ] Endpoint'ler mevcut
- [ ] /etc/hosts güncel
- [ ] `curl http://api-csharp.local/api/datetime` çalışıyor
- [ ] `curl http://api-go.local/health` çalışıyor
- [ ] `curl http://web-csharp.local` çalışıyor
- [ ] `curl http://web-go.local` çalışıyor
- [ ] `make verify` başarılı (20/20 test)

---

## 🆘 Yardım

### Sorun Giderme

1. `make verify` → Otomatik sorun tespiti (20 test)
2. `kubectl describe pod <pod-name>` → Pod detayları
3. `kubectl logs <pod-name>` → Pod logları
4. `docker logs haproxy-lb` → HAProxy logları

### Dokümantasyon

- **[README](../README.md)** → Genel bilgi
- **[PROJECT_SUMMARY](PROJECT_SUMMARY.md)** → Proje özeti
- **[CHANGES_SUMMARY](CHANGES_SUMMARY.md)** → Değişiklikler
- **[ARCHITECTURE](ARCHITECTURE.md)** → Mimari diyagramlar
- **[DOCKER_OPTIMIZATION](DOCKER_OPTIMIZATION.md)** → Image optimization
- **[SERVICE_TO_SERVICE_COMMUNICATION](SERVICE_TO_SERVICE_COMMUNICATION.md)** → C# → Go
- **[WORKER_NODES](WORKER_NODES.md)** → Multi-node cluster
- **[INGRESS_ROUTING](INGRESS_ROUTING.md)** → Network routing
- **[HAPROXY_LOADBALANCER](HAPROXY_LOADBALANCER.md)** → HAProxy setup
- **[LOAD_BALANCING](LOAD_BALANCING.md)** → Load balancing

### Komutlar

```bash
make help          # Tüm komutları görüntüle
kubectl get all    # Tüm kaynakları görüntüle
kubectl get all -n ingress-nginx  # Ingress kaynakları
```

---

## 🎉 Başarı!

Eğer bu adımları tamamladıysanız:

✅ **HA Kubernetes Cluster çalışıyor** (3+3 nodes)
✅ **NGINX Ingress Controller aktif** (worker nodes, 3 replicas)
✅ **HAProxy Load Balancer** running
✅ **Polyglot APIs erişilebilir** (C# + Go)
✅ **Web uygulamaları çalışıyor** (Turkish + English)
✅ **Load balancing aktif** (round-robin)
✅ **Service-to-service communication** (Circuit Breaker enabled)
✅ **Production-like environment** hazır

**Tebrikler!** 🚀

### Elde Ettiğiniz Sistem

| Özellik | Değer |
|---------|-------|
| **Nodes** | 6 (3 control-plane + 3 worker) |
| **Application Pods** | 13 (3 C# API + 3 Go API + 4 Web + 3 Ingress) |
| **Services** | 4 ClusterIP |
| **Domains** | 4 (api-csharp.local, api-go.local, web-csharp.local, web-go.local) |
| **Load Balancer** | HAProxy (health check enabled) |
| **Image Sizes** | C# API: 32.6 MB, Go API: ~15 MB |
| **Deployment Time** | 3-5 minutes |
| **Success Rate** | ~100% |

---

**İlk kez kuruyorsanız**: 5-10 dakika sürer
**Sorun yaşıyorsanız**: `make verify` komutuyla sorunları tespit edin
**Her şey çalışıyorsa**: Keyifli geliştirmeler! 🎨

---

**Son Güncelleme**: 2025-10-29
**Versiyon**: 2.0
**Proje**: DateTime Kubernetes Polyglot Microservices
