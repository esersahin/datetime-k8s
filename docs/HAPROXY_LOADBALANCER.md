# HAProxy Load Balancer - HA Kubernetes Erişimi

## 🎯 Amaç

Kind Kubernetes cluster'ına **standart port 80/443** üzerinden **yüksek erişilebilirlik (HA)** ile erişim sağlamak.

## 📊 Mimari (HA Cluster)

```
┌──────────────────────────────────────────────────┐
│         Kullanıcı (Browser/curl)                 │
│     http://api-csharp.local (port 80)            │
└───────────────────┬──────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────┐
│      HAProxy Load Balancer (External)            │
│      Container: kind-http-lb                     │
│      Port: 80, 443, 8404 (stats)                 │
│      Network: kind                               │
│      Algorithm: Round-robin                      │
└───────────────────┬──────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────┐
│          Kind Kubernetes Cluster (HA)            │
│  ┌────────────────────────────────────────────┐  │
│  │   3 Control-Plane Nodes                    │  │
│  │   (Kubernetes management - HA)             │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │   3 Worker Nodes                           │  │
│  │   ┌──────────┬──────────┬──────────┐       │  │
│  │   │ Worker 1 │ Worker 2 │ Worker 3 │       │  │
│  │   │  :80     │  :80     │  :80     │       │  │
│  │   └────┬─────┴────┬─────┴────┬─────┘       │  │
│  │        │          │          │             │  │
│  │        └──────────┴──────────┘             │  │
│  │                   ▼                        │  │
│  │        ┌─────────────────────┐             │  │
│  │        │ Ingress Controller  │             │  │
│  │        │ (3 replicas - HA)   │             │  │
│  │        │ hostNetwork: true   │             │  │
│  │        │ 1 per worker node   │             │  │
│  │        └──────────┬──────────┘             │  │
│  │                   ▼                        │  │
│  │        ┌─────────────────────┐             │  │
│  │        │  Application Pods   │             │  │
│  │        │  (C# & Go services) │             │  │
│  │        └─────────────────────┘             │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

## 🏗️ Cluster Yapısı

### Kubernetes Cluster Topology

```bash
kubectl get nodes -o wide
```

**Çıktı:**
```
NAME                  STATUS   ROLES           AGE   VERSION
kind-control-plane    Ready    control-plane   20m   v1.31.0
kind-control-plane2   Ready    control-plane   20m   v1.31.0
kind-control-plane3   Ready    control-plane   20m   v1.31.0
kind-worker           Ready    <none>          19m   v1.31.0
kind-worker2          Ready    <none>          19m   v1.31.0
kind-worker3          Ready    <none>          19m   v1.31.0
```

**HA Yapısı:**
- **3 Control-Plane Nodes**: Kubernetes yönetim düzlemi (etcd, API server, vb.)
- **3 Worker Nodes**: Uygulama workload'ları ve Ingress Controller
- **3 Ingress Replicas**: Her worker node'da 1 NGINX Ingress pod (hostNetwork: true)

### NGINX Ingress Controller Deployment

```bash
kubectl get pods -n ingress-nginx -o wide
```

**Çıktı:**
```
NAME                                        READY   STATUS    NODE
ingress-nginx-controller-xxx                1/1     Running   kind-worker
ingress-nginx-controller-yyy                1/1     Running   kind-worker2
ingress-nginx-controller-zzz                1/1     Running   kind-worker3
```

**Önemli:**
- `hostNetwork: true` → Her Ingress pod worker container'ın port 80/443'ünü dinler
- `replicas: 3` → HA için her worker'da 1 replica
- `nodeSelector: ingress-ready=true` → Sadece worker node'larda çalışır

---

## 🚀 Otomatik Kurulum

### Tam Deployment (HAProxy dahil)
```bash
make deploy
```

Bu komut otomatik olarak:
1. ✅ HA Kind cluster oluşturur (3 control-planes + 3 workers)
2. ✅ NGINX Ingress controller kurar (3 replica, hostNetwork: true)
3. ✅ Uygulamaları deploy eder (C# & Go API/Web)
4. ✅ **HAProxy load balancer'ı başlatır (DNS-based routing)**

### Sadece HAProxy Kurulumu
```bash
make install-haproxy
```

### HAProxy Kaldırma
```bash
make remove-haproxy
```

## 📁 Dosyalar

### 1. HAProxy Yapılandırması
**Dosya**: `k8s/haproxy-lb.cfg`

```haproxy
# HAProxy Load Balancer Configuration for Kind Cluster
# 3 worker node'a DNS-based load balancing

backend workers_http
    mode http
    balance roundrobin

    option httpchk GET /healthz
    http-check expect status 200-499

    # DNS ile worker node çözümlemesi
    server worker1 kind-worker:80 check inter 2s fall 2 rise 2 resolvers docker resolve-prefer ipv4
    server worker2 kind-worker2:80 check inter 2s fall 2 rise 2 resolvers docker resolve-prefer ipv4
    server worker3 kind-worker3:80 check inter 2s fall 2 rise 2 resolvers docker resolve-prefer ipv4
```

**Özellikler:**
- ✅ **DNS kullanımı** - IP değişikliklerinden etkilenmez (kind-worker, kind-worker2, kind-worker3)
- ✅ **Health check** - Her 2 saniyede `/healthz` endpoint'ini kontrol eder
- ✅ **Hızlı failover** - 2 başarısız check sonrası worker DOWN olarak işaretlenir
- ✅ **Otomatik recovery** - 2 başarılı check sonrası worker tekrar UP durumuna geçer
- ✅ **Round-robin** - Request'ler worker'lara sırayla dağıtılır (worker1→worker2→worker3)
- ✅ **Layer 7 check** - HTTP status code kontrolü (200-499 başarılı sayılır)

### 2. Makefile Hedefleri

**Yeni Target'lar:**
- `install-haproxy`: HAProxy kurulumu
- `remove-haproxy`: HAProxy kaldırma
- `deploy`: Artık HAProxy'yi de kurar
- `clean-all`: HAProxy'yi de temizler

## 🌐 Erişim

### Standart Port 80 (HAProxy ile HA)
```bash
# C# Uygulamaları
http://api-csharp.local/api/datetime
http://web-csharp.local

# Go Uygulamaları  
http://api-go.local/health
http://web-go.local
```

### HAProxy Stats
```bash
http://localhost:8404
```

## ⚙️ HAProxy Yapılandırma Detayları

### Load Balancing
- **Algorithm**: Round-robin
- **Health Check**: GET /healthz
- **Check Interval**: 2 saniye
- **Failover Threshold**: 2 başarısız check
- **Recovery Threshold**: 2 başarılı check

### Port Mapping
| Port | Protokol  | Açıklama             |
|------|---------- |----------------------|
| 80   | HTTP      | Ana web trafiği (HA) |
| 443  | HTTPS/TCP | SSL trafiği (HA)     |
| 8404 | HTTP      | HAProxy statistics   |

### DNS Çözümlemesi
HAProxy, Docker'ın built-in DNS'ini kullanır (`127.0.0.11:53`). Bu sayede worker node IP'leri değişse bile otomatik olarak çözümlenir.

## 🔍 HA Testi

### Senaryo 1: Normal Durum (Tüm Worker'lar UP)

```bash
# Cluster durumu
kubectl get nodes | grep worker
# kind-worker    Ready    <none>   20m   v1.31.0
# kind-worker2   Ready    <none>   20m   v1.31.0
# kind-worker3   Ready    <none>   20m   v1.31.0

# HAProxy stats
curl -s http://localhost:8404 | grep "workers_http"
# Backend: workers_http - Active: 3/3

# Test - Round-robin görünüyor
for i in {1..6}; do
  curl -s http://api-csharp.local/api/datetime | jq -r '.time'
done
# Request'ler worker1 → worker2 → worker3 → worker1 ... sırasıyla gider
```

### Senaryo 2: Worker Node Durdurma (Failover Testi)

```bash
# Worker1'i durdur
docker stop kind-worker

# HAProxy otomatik olarak worker1'i DOWN işaretler (4 saniye içinde)
curl -s http://localhost:8404 | grep "worker1"
# worker1: DOWN

# Servisler hala erişilebilir (worker2 & worker3 üzerinden)
curl http://api-csharp.local/api/datetime
# ✅ ÇALIŞIYOR! HAProxy worker2 ve worker3'e yönlendiriyor
```

### Senaryo 3: Worker Node Başlatma (Recovery Testi)

```bash
# Worker1'i tekrar başlat
docker start kind-worker

# 4-6 saniye bekle (2 başarılı health check için)
sleep 6

# HAProxy otomatik olarak worker1'i tekrar pool'a ekler
curl -s http://localhost:8404 | grep "worker1"
# worker1: UP

# Worker1 tekrar round-robin'e dahil oldu
curl http://api-csharp.local/api/datetime
# ✅ ÇALIŞIYOR! Artık worker1, worker2, worker3 hepsi kullanılıyor
```

### HAProxy Stats Kontrolü
```bash
# Browser'da aç
open http://localhost:8404

# Veya curl ile
curl http://localhost:8404
```

### Worker Node Başlatma
```bash
# Worker1'i başlat
docker start kind-worker

# HAProxy otomatik olarak worker1'i tekrar pool'a ekler
# Stats'ta "UP" olarak görünür
```

## 🎯 Avantajlar

### IP Değişikliği Sorunu Çözüldü
- ✅ DNS kullanımı ile worker IP'leri sabit olmak zorunda değil
- ✅ Her `make deploy`'da aynı yapılandırma çalışır
- ✅ Manuel IP güncellemesi gerektirmez

### Otomatizasyon
- ✅ `make deploy` ile tek komutda her şey hazır
- ✅ Yapılandırma dosyası proje içinde (`k8s/haproxy-lb.cfg`)
- ✅ Makefile ile kolay yönetim

### HA ve Performans
- ✅ Herhangi bir worker düşse sistem çalışmaya devam eder
- ✅ Round-robin ile load balancing
- ✅ 2 saniye içinde failover
- ✅ Otomatik recovery

### Standart Port Kullanımı
- ✅ Port 80 - Standart HTTP
- ✅ Port 443 - Standart HTTPS
- ✅ `:80` yazmaya gerek yok - `http://api-csharp.local` yeterli

## 🛠️ Sorun Giderme

### HAProxy Logları
```bash
docker logs kind-http-lb
```

### HAProxy Durumu
```bash
docker ps | grep kind-http-lb
```

### HAProxy Yeniden Başlatma
```bash
make remove-haproxy
make install-haproxy
```

### Worker Node'ları Kontrol
```bash
kubectl get nodes
kubectl get pods -n ingress-nginx -o wide
```

## 📊 HAProxy Stats Sayfası

Stats sayfasında görülen bilgiler:
- ✅ Backend sunucu durumları (UP/DOWN)
- ✅ Request sayıları
- ✅ Response time'ları
- ✅ Health check sonuçları
- ✅ Connection pool bilgileri
- ✅ Error count'ları

## 🎓 İleri Düzey Kullanım

### Manuel HAProxy Başlatma
```bash
docker run -d \
  --name kind-http-lb \
  --network kind \
  -p 80:80 \
  -p 443:443 \
  -p 8404:8404 \
  -v $(PWD)/k8s/haproxy-lb.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
  haproxy:2.8-alpine
```

### Yapılandırma Değişikliği Sonrası Reload
```bash
# Container'ı yeniden başlat
docker restart kind-http-lb

# Veya tümüyle kaldır ve tekrar kur
make remove-haproxy
make install-haproxy
```

## ✅ Checklist

Başarılı kurulum için:
- [ ] `k8s/haproxy-lb.cfg` dosyası mevcut
- [ ] Kind cluster çalışıyor (`kubectl get nodes`)
- [ ] HAProxy container çalışıyor (`docker ps | grep kind-http-lb`)
- [ ] Worker node'lar Ready (`kubectl get nodes`)
- [ ] Ingress pods Running (`kubectl get pods -n ingress-nginx`)
- [ ] http://api-csharp.local erişilebilir
- [ ] http://localhost:8404 stats sayfası açılıyor
- [ ] Worker node durdurulduğunda sistem çalışmaya devam ediyor

## 🔗 İlgili Dökümanlar

- [QUICK_START.md](QUICK_START.md) - Hızlı başlangıç
- [ARCHITECTURE.md](ARCHITECTURE.md) - Mimari detayları

---

**Son Güncelleme:** 2025-10-31
**Versiyon:** 2.1
**Proje:** DateTime Kubernetes Polyglot Microservices
