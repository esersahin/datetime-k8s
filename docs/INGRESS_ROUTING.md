<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](INGRESS_ROUTING.en.md) | 🇹🇷 [Türkçe](INGRESS_ROUTING.md) |
| :---------------------------------: | :-----------------------------: |

</div>

---

# Ingress Routing: HA Mimarisi ile Multi-Layer Yönlendirme

## 📋 İçindekiler

1. [Mimari Genel Bakış](#-mimari-genel-bakış)
2. [Trafik Akışı (Multi-Layer)](#-trafik-akışı-multi-layer)
3. [Nasıl Çalışır?](#-nasıl-çalışır)
4. [Teknik Detaylar](#-teknik-detaylar)
5. [Load Balancing Katmanları](#-load-balancing-katmanları)
6. [Test ve Doğrulama](#-test-ve-doğrulama)
7. [Sorun Giderme](#-sorun-giderme)
8. [Özet](#-özet)

---

Bu dokümanda High Availability (HA) mimarisinde çok katmanlı yönlendirme mekanizması açıklanmaktadır:
- **Layer 1**: HAProxy → 3 Ingress Controller (worker node'larda)
- **Layer 2**: Ingress Controller → Kubernetes Services
- **Layer 3**: Services → Application Pods

## 🏗️ Mimari Genel Bakış

### HA Cluster Yapısı

```
┌─────────────────────────────────────────────────────────┐
│         3 Control Plane Nodes (HA - Yönetim)           │
│  • Kubernetes API Server, etcd, Scheduler               │
│  • Ingress Controller ÇALIŞMAZ                          │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│            3 Worker Nodes (HA - Workload)               │
│  • Ingress Controller (3 replica)                       │
│  • Application Pods                                     │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
               ┌─────────────────┐
               │   HAProxy LB    │
               │  localhost:80   │
               │  localhost:443  │
               └─────────────────┘
```

## 🔄 Trafik Akışı (Multi-Layer)

### Layer 1: HAProxy → Ingress Controllers

```
┌──────────────────────────────────────────────────────────┐
│          🌐 Browser/Client                               │
│     http://api-csharp.local/api/datetime                 │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│          🔀 HAProxy Load Balancer                        │
│          Docker Container (localhost:80/443)             │
│                                                          │
│  Backend: k8s_workers                                    │
│    - kind-worker:80     (weight 1)                       │
│    - kind-worker2:80    (weight 1)                       │
│    - kind-worker3:80    (weight 1)                       │
│  Algorithm: roundrobin                                   │
└────────┬─────────┬──────────┬──────────────────────────┘
         │         │          │
         │         │          │
         ▼         ▼          ▼
┌────────────┐ ┌────────────┐ ┌────────────┐
│  WORKER-1  │ │  WORKER-2  │ │  WORKER-3  │
│            │ │            │ │            │
│  Ingress   │ │  Ingress   │ │  Ingress   │
│  Replica 1 │ │  Replica 2 │ │  Replica 3 │
│  :80/443   │ │  :80/443   │ │  :80/443   │
└─────┬──────┘ └─────┬──────┘ └─────┬──────┘
      └──────────────┴──────────────┘
                     │
```

### Layer 2: Ingress → Services

```
         ┌───────────────────────────────┐
         │  NGINX Ingress Controller     │
         │  (Seçilen replica)            │
         │                               │
         │  Rules:                       │
         │  • api-csharp.local → Service │
         │  • web-csharp.local → Service │
         └───────────┬───────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
┌───────────────────┐   ┌───────────────────┐
│ datetime-api-     │   │ datetime-web-     │
│ csharp-service    │   │ csharp-service    │
│ ClusterIP:80      │   │ ClusterIP:80      │
│ Selector:         │   │ Selector:         │
│   app=datetime-   │   │   app=datetime-   │
│   api-csharp      │   │   web-csharp      │
└─────────┬─────────┘   └─────────┬─────────┘
          │                       │
```

### Layer 3: Services → Application Pods

```
          │                       │
     ┌────┴────┐             ┌────┴────┐
     │         │             │         │
     ▼         ▼             ▼         ▼
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│Worker-1 │ │Worker-2 │ │Worker-1 │ │Worker-2 │
│         │ │         │ │         │ │         │
│ API-Pod │ │ API-Pod │ │ Web-Pod │ │ Web-Pod │
│ :5000   │ │ :5000   │ │ :80     │ │ :80     │
└─────────┘ └─────────┘ └─────────┘ └─────────┘
```

## 🎯 Nasıl Çalışır?

### 1. HAProxy Load Balancer (İlk Katman)

HAProxy, trafik giriş noktasıdır ve 3 worker node'a dağıtım yapar:

```yaml
# haproxy/haproxy.cfg
backend k8s_workers
    mode http
    balance roundrobin
    option httpchk GET /healthz
    server worker1 172.18.0.4:80 check weight 1
    server worker2 172.18.0.5:80 check weight 1
    server worker3 172.18.0.6:80 check weight 1
```

**Özellikler:**
- ✅ Round-robin load balancing
- ✅ Health check (/healthz endpoint)
- ✅ Automatic failover (unhealthy node bypass)
- ✅ Localhost:80/443 exposure

### 2. Ingress Controller (Worker Node'larda - 3 Replica)

Her worker node'da 1 Ingress Controller replica çalışır:

```yaml
# k8s/ingress-nginx-deployment.yaml
spec:
  replicas: 3  # HA için 3 replica
  template:
    spec:
      hostNetwork: true  # Worker node'un 80/443 portunu dinler
      nodeSelector:
        ingress-ready: "true"  # Worker node'larda çalış
```

```yaml
# kind-config.yaml (Worker nodes)
nodes:
  - role: worker
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    # extraPortMappings YOK - HAProxy kullanılıyor
```

**Neden Worker Node'larda?**
- ✅ Control-plane temiz kalır (sadece yönetim)
- ✅ HA: 3 replica, fault tolerance
- ✅ Scalability: Worker node ekle/çıkar
- ✅ Production best practice

### 3. Ingress Rules (Layer 2)

Ingress Controller, host header'a göre Service'lere yönlendirir:

```yaml
# k8s/ingress.yaml
rules:
  - host: api-csharp.local
    http:
      paths:
        - path: /
          backend:
            service:
              name: datetime-api-csharp-service
  - host: web-csharp.local
    http:
      paths:
        - path: /
          backend:
            service:
              name: datetime-web-csharp-service
```

### 4. Service Discovery (Layer 3)

Service'ler pod'ları **label selector** ile bulur:

```yaml
# datetime-api-csharp-service
spec:
  type: ClusterIP
  selector:
    app: datetime-api-csharp # Bu label'a sahip TÜM pod'ları bulur
  ports:
    - port: 80
      targetPort: 5000
```

Service, **hangi node'da olursa olsun** bu label'a sahip tüm pod'ları otomatik bulur.

Service, trafiği pod'lara **otomatik** dağıtır:

- Round-robin (varsayılan)
- Session affinity (sticky sessions)
- Health check'e göre

## 🔍 Teknik Detaylar

### Multi-Layer Architecture

Sistemde 3 load balancing katmanı vardır:

```
┌─────────────────────────────────────────────────┐
│ Layer 1: HAProxy (External LB)                  │
│  • localhost:80 → 3 worker nodes                │
│  • Health check, failover                       │
│  • Round-robin distribution                     │
└─────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│ Layer 2: Ingress Controllers (3 replicas)       │
│  • Worker-1, Worker-2, Worker-3                 │
│  • Host-based routing (api-csharp.local, etc.)  │
│  • SSL termination                              │
└─────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│ Layer 3: Kubernetes Services (ClusterIP)        │
│  • Label selector → Pod discovery                │
│  • kube-proxy → iptables rules                  │
│  • Round-robin to pods                          │
└─────────────────────────────────────────────────┘
```

### Node Architecture

```
Control-Plane Nodes (3):
├── Kubernetes Control Components
│   ├── API Server
│   ├── etcd
│   ├── Scheduler
│   └── Controller Manager
└── kube-proxy (network rules)

Worker Node 1-3:
├── Ingress Controller Pod (hostNetwork=true)
│   └── NGINX listening on :80/:443
├── Application Pods
│   ├── datetime-api-csharp (10.244.x.2)
│   └── datetime-web-csharp (10.244.x.3)
└── kube-proxy (network rules)

HAProxy Container (Docker):
└── Load balances to all 3 workers
```

### ClusterIP Service

```yaml
type: ClusterIP # Cluster içinden erişilebilir
```

Service, bir **virtual IP** alır:

- `datetime-api-csharp-service`: 10.96.xxx.xxx:80
- Bu IP, tüm pod IP'lerinin önünde
- kube-proxy bu IP'yi pod IP'lerine yönlendirir

### Network Flow (Multi-Layer)

```
1. İstek gelir: http://api-csharp.local/api/datetime

2. HAProxy (Layer 1):
   - Frontend localhost:80 ile request yakalanır
   - Backend k8s_workers seçilir
   - Round-robin: worker2 seçilir (172.18.0.5:80)
   - Health check: ✓ worker2 healthy
   - Request forward → worker2:80

3. Ingress Controller (Layer 2 - Worker2'de):
   - NGINX, hostNetwork ile :80 dinliyor
   - Host header kontrol: api-csharp.local ✓
   - Ingress rule match: datetime-api-csharp-service
   - Service IP'ye forward: 10.96.xxx.xxx:80

4. kube-proxy (Layer 3 - her node'da):
   - Service IP'yi yakalır: 10.96.xxx.xxx:80
   - Endpoint listesi (label selector ile):
     * 10.244.1.2:5000 (worker1)
     * 10.244.2.2:5000 (worker2)
   - Round-robin/iptables: 10.244.1.2:5000 seçilir

5. Application Pod (Worker1):
   - datetime-api-csharp pod request alır
   - /api/datetime endpoint işlenir
   - Response: {"time": "2025-01-15T10:30:00"}

6. Response Flow (tersine):
   - Pod → Service → Ingress Controller (worker2)
   → HAProxy → Client
```

### Örnek: 10 Request Flow

```bash
curl http://api-csharp.local/api/datetime  # 10 kez

# HAProxy distribution (Layer 1):
Request 1  → Worker1 Ingress → Service → Pod A  # Worker1
Request 2  → Worker2 Ingress → Service → Pod B  # Worker2
Request 3  → Worker3 Ingress → Service → Pod A  # Worker3
Request 4  → Worker1 Ingress → Service → Pod B  # Worker1
Request 5  → Worker2 Ingress → Service → Pod A  # Worker2
...

# Her request farklı Ingress replica ve farklı pod'a gidebilir
# İki katman load balancing: HAProxy + K8s Service
```

## 📊 Load Balancing Katmanları

### Layer 1: HAProxy Load Balancing

```cfg
# haproxy/haproxy.cfg
backend k8s_workers
    mode http
    balance roundrobin  # Round-robin algoritması
    option httpchk GET /healthz  # Health check
    http-check expect status 200

    server worker1 172.18.0.4:80 check weight 1  # Eşit ağırlık
    server worker2 172.18.0.5:80 check weight 1
    server worker3 172.18.0.6:80 check weight 1
```

**Özellikler:**
- ✅ Round-robin: Her worker eşit trafik alır
- ✅ Health check: Unhealthy worker bypass edilir
- ✅ Automatic failover: Worker down olursa diğerleri devam eder

### Layer 2: Ingress Annotations

```yaml
# k8s/ingress.yaml
annotations:
  nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
  nginx.ingress.kubernetes.io/load-balance: "round_robin"
  nginx.ingress.kubernetes.io/upstream-hash-by: "$request_uri"  # Optional
```

**Stratejiler:**
- `round_robin`: Sırayla pod'lara dağıt (varsayılan)
- `ip_hash`: Client IP'ye göre aynı pod
- `least_conn`: En az bağlantılı pod

### Layer 3: Service Session Affinity

```yaml
# k8s/datetime-api-csharp-service.yaml (optional)
sessionAffinity: ClientIP  # Sticky session
sessionAffinityConfig:
  clientIP:
    timeoutSeconds: 300  # 5 dakika aynı pod
```

**Kullanım Senaryoları:**
- ✅ Session affinity gerekli: E-ticaret sepeti, login sessions
- ❌ Stateless API: Session affinity GEREKMEZ (daha iyi load balancing)

## 🧪 Test ve Doğrulama

### 1. HA Cluster Durumu

```bash
# Tüm node'ları kontrol et
kubectl get nodes

# Beklenen:
# NAME                  STATUS   ROLES           AGE   VERSION
# kind-control-plane    Ready    control-plane   10m   v1.31.0
# kind-control-plane2   Ready    control-plane   10m   v1.31.0
# kind-control-plane3   Ready    control-plane   10m   v1.31.0
# kind-worker           Ready    <none>          10m   v1.31.0
# kind-worker2          Ready    <none>          10m   v1.31.0
# kind-worker3          Ready    <none>          10m   v1.31.0
```

### 2. Ingress Controller Replicas (Worker Node'larda)

```bash
# Ingress Controller pod'ları nerede? (3 replica)
kubectl get pods -n ingress-nginx -o wide

# Beklenen:
# NAME                                     READY   STATUS    NODE
# ingress-nginx-controller-xxx             1/1     Running   kind-worker
# ingress-nginx-controller-yyy             1/1     Running   kind-worker2
# ingress-nginx-controller-zzz             1/1     Running   kind-worker3

# Replica sayısı doğru mu?
kubectl get deployment -n ingress-nginx ingress-nginx-controller
# READY: 3/3
```

### 3. HAProxy Durumu

```bash
# HAProxy çalışıyor mu?
docker ps | grep haproxy

# ÇIKTI:
# <container-id>  haproxy:2.8  ...  0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp

# HAProxy stats (opsiyonel)
curl http://localhost:8404/stats
# Worker health status görülebilir
```

### 4. Uygulama Pod'ları Lokasyonu

```bash
# Uygulama pod'ları nerede?
kubectl get pods -o wide

# Beklenen:
# NAME                           NODE
# datetime-api-csharp-xxx        kind-worker veya kind-worker2
# datetime-web-csharp-xxx        kind-worker veya kind-worker2
```

### 5. Service Endpoint'leri

```bash
# Service hangi pod'lara yönlendiriyor?
kubectl get endpoints datetime-api-csharp-service
kubectl get endpoints datetime-web-csharp-service

# Çıktı:
# NAME                             ENDPOINTS
# datetime-api-csharp-service      10.244.1.2:5000,10.244.2.2:5000
# datetime-web-csharp-service      10.244.1.3:80,10.244.2.3:80
```

### 6. Multi-Layer Trafik Testi

```bash
# HAProxy üzerinden test (Layer 1 + 2 + 3)
for i in {1..10}; do
  curl -s http://api-csharp.local/api/datetime | jq .time
done

# Her istekte:
# - HAProxy farklı worker seçer (Layer 1)
# - Seçilen worker'daki Ingress işler (Layer 2)
# - Service farklı pod seçer (Layer 3)

# HAProxy stats kontrol
curl http://localhost:8404/stats | grep k8s_workers -A 10
```

### 7. HA Failover Testi

```bash
# Worker1'i simüle et (Ingress replica çöksün)
kubectl delete pod -n ingress-nginx <worker1-ingress-pod>

# Test et - HAProxy otomatik worker2/worker3'e yönlendirir
curl http://api-csharp.local/api/datetime
# Başarılı! ✅ Zero downtime

# Pod otomatik yeniden oluşturulur
kubectl get pods -n ingress-nginx -o wide
```

## 🔧 Sorun Giderme

### Sorun 1: "503 Service Temporarily Unavailable"

```bash
# Pod'lar hazır mı?
kubectl get pods

# Service endpoint'leri var mı?
kubectl get endpoints datetime-api-csharp-service

# Çözüm: Pod'ların Ready olmasını bekleyin
kubectl wait --for=condition=ready pod -l app=datetime-api-csharp
```

### Sorun 2: Ingress Control-Plane'de Çalışıyor ❌ YANLIŞ!

```bash
# Kontrol et
kubectl get pods -n ingress-nginx -o wide

# Eğer control-plane'deyse, HATALI! Worker node'larda olmalı
# NAME                                     NODE
# ingress-nginx-controller-xxx            kind-control-plane  ❌ YANLIŞ!

# Çözüm: Deployment'ı düzelt
kubectl delete deployment -n ingress-nginx ingress-nginx-controller
kubectl apply -f k8s/ingress-nginx-deployment.yaml

# Veya cluster'ı yeniden oluştur
make clean-all
make deploy
```

### Sorun 3: HAProxy Erişim Çalışmıyor

```bash
# HAProxy çalışıyor mu?
docker ps | grep haproxy

# HAProxy log kontrol
docker logs <haproxy-container-id>

# Worker node'lar erişilebilir mi?
docker exec <haproxy-container-id> ping -c 1 kind-worker

# Çözüm: HAProxy'yi yeniden başlat
cd haproxy
docker-compose down
docker-compose up -d
```

### Sorun 4: Sadece 1-2 Ingress Replica Çalışıyor

```bash
# Replica sayısı kontrol
kubectl get deployment -n ingress-nginx ingress-nginx-controller
# READY: 2/3  ❌ 3 olmalı!

# Worker node label'ları kontrol
kubectl get nodes --show-labels | grep ingress-ready

# Çözüm: Eksik label ekle
kubectl label node kind-worker3 ingress-ready=true --overwrite
kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller
```

### Sorun 5: Trafik Sadece Bir Worker'a Gidiyor

```bash
# HAProxy config kontrol
cat haproxy/haproxy.cfg | grep -A 10 "backend k8s_workers"

# Balance algorithm roundrobin mi?
# server satırları doğru mu?

# HAProxy stats kontrol
curl http://localhost:8404/stats | grep k8s_workers -A 10

# Çözüm: HAProxy config düzelt ve reload
cd haproxy
docker-compose down
docker-compose up -d
```

## 📝 Özet

### Multi-Layer Architecture

| Layer | Bileşen                   | Lokasyon                  | Görevi                            | Replica |
| ----- | ------------------------- | ------------------------- | --------------------------------- | ------- |
| **1** | **HAProxy**               | Docker container          | External LB, failover, localhost  | 1       |
| **2** | **Ingress Controllers**   | Worker nodes (3)          | Host-based routing, SSL           | 3       |
| **3** | **Services**              | Virtual IP (cluster-wide) | Pod discovery, load balancing     | N/A     |
| **4** | **Application Pods**      | Worker nodes              | Application logic                 | 2+      |
| **-** | **kube-proxy**            | Her node                  | iptables rules, network routing   | 6       |
| **-** | **Control Plane**         | 3 control-plane nodes     | Kubernetes management (API, etcd) | 3       |

### Neden Bu Yapı İdeal?

#### HA & Fault Tolerance
- ✅ **3 Control Plane**: etcd quorum, API server HA
- ✅ **3 Ingress Replica**: Bir worker çökerse diğerleri devam eder
- ✅ **HAProxy Failover**: Unhealthy worker otomatik bypass edilir
- ✅ **Multiple App Pods**: Service-level load balancing

#### Separation of Concerns
- ✅ **Control-Plane**: Sadece Kubernetes yönetimi (API, scheduler, etcd)
- ✅ **Worker Nodes**: Workload (Ingress + application pods)
- ✅ **HAProxy**: External load balancing (Kubernetes dışı)

#### Scalability & Performance
- ✅ **Horizontal Scaling**: Worker node ekle → otomatik Ingress replica
- ✅ **Multi-Layer LB**: HAProxy + Ingress + Service = optimal distribution
- ✅ **Zero Downtime**: RollingUpdate ile kesintisiz deployment

#### Production-Ready
- ✅ **Best Practice**: Industry-standard HA architecture
- ✅ **Observable**: HAProxy stats, Ingress metrics, pod logs
- ✅ **Maintainable**: Declarative YAML, version-controlled

---

**Sonuç**: 3 katmanlı HA mimarisi ile **production-grade** bir sistem elde ediyoruz. HAProxy (Layer 1), Ingress Controllers (Layer 2) ve Kubernetes Services (Layer 3) birlikte çalışarak **yüksek erişilebilirlik, fault tolerance ve optimal load balancing** sağlıyor.
