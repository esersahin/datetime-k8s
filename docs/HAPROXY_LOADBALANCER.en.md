# HAProxy Load Balancer - HA Kubernetes Erişimi

## 🎯 Amaç

Kind Kubernetes cluster'ına **standart port 80/443** üzerinden **yüksek erişilebilirlik (HA)** ile erişim sağlamak.

## 📊 Architecture (HA Cluster)

```
┌──────────────────────────────────────────────────┐
│         User (Browser/curl)                      │
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

## 🏗️ Cluster Structure

### Kubernetes Cluster Topology

```bash
kubectl get nodes -o wide
```

**Output:**

```
NAME                  STATUS   ROLES           AGE   VERSION
kind-control-plane    Ready    control-plane   20m   v1.31.0
kind-control-plane2   Ready    control-plane   20m   v1.31.0
kind-control-plane3   Ready    control-plane   20m   v1.31.0
kind-worker           Ready    <none>          19m   v1.31.0
kind-worker2          Ready    <none>          19m   v1.31.0
kind-worker3          Ready    <none>          19m   v1.31.0
```

**HA Structure:**

- **3 Control-Plane Nodes**: Kubernetes management plane (etcd, API server, etc.)
- **3 Worker Nodes**: Application workloads and Ingress Controller
- **3 Ingress Replicas**: 1 NGINX Ingress pod per worker node (hostNetwork: true)

### NGINX Ingress Controller Deployment

```bash
kubectl get pods -n ingress-nginx -o wide
```

**Output:**

```
NAME                                        READY   STATUS    NODE
ingress-nginx-controller-xxx                1/1     Running   kind-worker
ingress-nginx-controller-yyy                1/1     Running   kind-worker2
ingress-nginx-controller-zzz                1/1     Running   kind-worker3
```

**Important:**

- `hostNetwork: true` → Each Ingress pod listens on worker container's port 80/443
- `replicas: 3` → 1 replica per worker node for HA
- `nodeSelector: ingress-ready=true` → Runs only on worker nodes

---

## 🚀 Automatic Installation

### Full Deployment (Including HAProxy)

```bash
make deploy
```

This command automatically:

1. ✅ Creates HA Kind cluster (3 control-planes + 3 workers)
2. ✅ Installs NGINX Ingress controller (3 replicas, hostNetwork: true)
3. ✅ Deploys applications (C# & Go API/Web)
4. ✅ **Starts HAProxy load balancer (DNS-based routing)**

### Sadece HAProxy Kurulumu

```bash
make install-haproxy
```

### HAProxy Kaldırma

```bash
make remove-haproxy
```

## 📁 Dosyalar

### 1. HAProxy Configuration

**File**: `k8s/haproxy-lb.cfg`

```haproxy
# HAProxy Load Balancer Configuration for Kind Cluster
# DNS-based load balancing to 3 worker nodes

backend workers_http
    mode http
    balance roundrobin

    option httpchk GET /healthz
    http-check expect status 200-499

    # DNS-based worker node resolution
    server worker1 kind-worker:80 check inter 2s fall 2 rise 2 resolvers docker resolve-prefer ipv4
    server worker2 kind-worker2:80 check inter 2s fall 2 rise 2 resolvers docker resolve-prefer ipv4
    server worker3 kind-worker3:80 check inter 2s fall 2 rise 2 resolvers docker resolve-prefer ipv4
```

**Features:**

- ✅ **DNS usage** - Not affected by IP changes (kind-worker, kind-worker2, kind-worker3)
- ✅ **Health check** - Checks `/healthz` endpoint every 2 seconds
- ✅ **Fast failover** - Worker marked DOWN after 2 failed checks
- ✅ **Automatic recovery** - Worker returns to UP status after 2 successful checks
- ✅ **Round-robin** - Requests distributed sequentially to workers (worker1→worker2→worker3)
- ✅ **Layer 7 check** - HTTP status code validation (200-499 considered successful)

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

| Port | Protokol  | Description          |
| ---- | --------- | -------------------- |
| 80   | HTTP      | Ana web trafiği (HA) |
| 443  | HTTPS/TCP | SSL trafiği (HA)     |
| 8404 | HTTP      | HAProxy statistics   |

### DNS Çözümlemesi

HAProxy, Docker'ın built-in DNS'ini kullanır (`127.0.0.11:53`). Bu sayede worker node IP'leri değişse bile otomatik olarak çözümlenir.

## 🔍 HA Testing

### Scenario 1: Normal State (All Workers UP)

```bash
# Cluster status
kubectl get nodes | grep worker
# kind-worker    Ready    <none>   20m   v1.31.0
# kind-worker2   Ready    <none>   20m   v1.31.0
# kind-worker3   Ready    <none>   20m   v1.31.0

# HAProxy stats
curl -s http://localhost:8404 | grep "workers_http"
# Backend: workers_http - Active: 3/3

# Test - Round-robin in action
for i in {1..6}; do
  curl -s http://api-csharp.local/api/datetime | jq -r '.time'
done
# Requests go to worker1 → worker2 → worker3 → worker1 ... sequentially
```

### Scenario 2: Worker Node Failure (Failover Test)

```bash
# Stop worker1
docker stop kind-worker

# HAProxy automatically marks worker1 as DOWN (within 4 seconds)
curl -s http://localhost:8404 | grep "worker1"
# worker1: DOWN

# Services still accessible (via worker2 & worker3)
curl http://api-csharp.local/api/datetime
# ✅ WORKING! HAProxy routes to worker2 and worker3
```

### Scenario 3: Worker Node Recovery (Recovery Test)

```bash
# Start worker1 again
docker start kind-worker

# Wait 4-6 seconds (for 2 successful health checks)
sleep 6

# HAProxy automatically adds worker1 back to the pool
curl -s http://localhost:8404 | grep "worker1"
# worker1: UP

# Worker1 is back in round-robin rotation
curl http://api-csharp.local/api/datetime
# ✅ WORKING! Now all worker1, worker2, worker3 are in use
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

- [QUICK_START.md](QUICK_START.en.md) - Hızlı başlangıç
- [ARCHITECTURE.md](ARCHITECTURE.en.md) - Mimari detayları

---

**Last Updated:** 2025-10-31
**Version:** 2.1
**Project:** DateTime Kubernetes Polyglot Microservices
