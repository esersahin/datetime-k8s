<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](LOAD_BALANCING.en.md) | 🇹🇷 [Türkçe](LOAD_BALANCING.md) |
| :--------------------------------: | :----------------------------: |

</div>

---

# Load Balancing Yapılandırması

## 📋 İçindekiler

1. [Multi-Layer Load Balancing Mimarisi](#-multi-layer-load-balancing-mimarisi)
2. [Load Balancing Stratejileri](#-load-balancing-stratejileri)
3. [Mevcut Projemiz İçin Öneriler](#-mevcut-projemiz-için-öneriler)
4. [Yapılandırma Değiştirme](#-yapılandırma-değiştirme)
5. [Test Etme](#-test-etme)
6. [Karşılaştırma](#-karşılaştırma)
7. [Projemiz İçin Öneri](#-projemiz-için-öneri)
8. [Özet](#-özet)

---

Bu dokümanda projemizdeki çok katmanlı load balancing mimarisi ve ingress.yaml'da kullanabileceğiniz farklı load balancing stratejileri açıklanmaktadır.

## 🏗️ Multi-Layer Load Balancing Mimarisi

Projemizde **4 katmanlı** load balancing yapısı bulunmaktadır:

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: HAProxy Load Balancer (Docker Container)          │
│  ↓ Round-robin distribution to 3 worker nodes               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: NGINX Ingress Controllers (3 replicas)            │
│  ↓ Running on worker nodes (kind-worker, worker2, worker3)  │
│  ↓ hostNetwork: true (localhost:80/443)                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: Kubernetes Services (ClusterIP)                   │
│  ↓ 4 services: api-csharp, api-go, web-csharp, web-go       │
│  ↓ Selector-based pod discovery                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 4: Application Pods (13 pods total)                  │
│  ↓ 3 replicas per application × 4 apps                      │
│  ↓ Distributed across 3 worker nodes                        │
└─────────────────────────────────────────────────────────────┘
```

### Traffic Flow (Tam Akış)

```
Client Request (http://api-csharp.local/api/datetime)
         ↓
    localhost:80 (macOS)
         ↓
┌────────────────────────────────────────────────────┐
│ HAProxy Container (Layer 1)                        │
│ - Round-robin to 3 worker nodes                    │
│ - Health checks on port 80                         │
│ - Stats dashboard: localhost:8404                  │
└────────────────────────────────────────────────────┘
         ↓ (randomly picks one)
    ┌────┴────┬────────────┐
    ↓         ↓            ↓
kind-worker  kind-worker2  kind-worker3
    ↓         ↓            ↓
┌────────────────────────────────────────────────────┐
│ NGINX Ingress Controller (Layer 2)                 │
│ - 1 replica per worker node (3 total)              │
│ - hostNetwork: true                                │
│ - Listens on port 80/443                           │
│ - Routes based on Host header                      │
└────────────────────────────────────────────────────┘
         ↓ (matches Host: api-csharp.local)
┌────────────────────────────────────────────────────┐
│ ClusterIP Service (Layer 3)                        │
│ datetime-api-csharp-service:80                     │
│ - selector: app=datetime-api-csharp                │
│ - sessionAffinity: None (Round Robin)              │
└────────────────────────────────────────────────────┘
         ↓ (round-robin to 3 endpoints)
    ┌────┴────┬────────────┐
    ↓         ↓            ↓
┌────────────────────────────────────────────────────┐
│ Application Pods (Layer 4)                         │
│ - datetime-api-csharp-xxxxx-1 (10.244.4.2)         │
│ - datetime-api-csharp-xxxxx-2 (10.244.3.2)         │
│ - datetime-api-csharp-xxxxx-3 (10.244.5.2)         │
└────────────────────────────────────────────────────┘
         ↓
    Response (JSON)
```

### Layer-by-Layer Açıklama

#### Layer 1: HAProxy Load Balancer
- **Teknoloji**: HAProxy 2.8+ (Docker container)
- **Görev**: 3 worker node'a trafiği dağıtır
- **Algoritma**: Round-robin
- **Port Mapping**: 80:80, 443:443, 8404:8404 (stats)
- **Health Check**: Her worker node'un 80 portunu kontrol eder
- **Config**: `haproxy.cfg`

```bash
# HAProxy stats
curl http://localhost:8404

# Backend status
docker exec haproxy-lb cat /etc/haproxy/haproxy.cfg
```

#### Layer 2: NGINX Ingress Controller
- **Teknoloji**: NGINX Ingress Controller v1.13.3
- **Yerleşim**: Worker nodes (kind-worker, kind-worker2, kind-worker3)
- **Replika**: 3 (her worker node'da 1)
- **hostNetwork**: true (doğrudan 80/443 portlarını dinler)
- **Görev**: Host header'a göre routing (api-csharp.local, api-go.local, ...)

```bash
# Ingress Controller durumu
kubectl get pods -n ingress-nginx -o wide
# Expected: 3 pods on worker nodes

# Ingress rules
kubectl get ingress datetime-ingress -o yaml
```

#### Layer 3: Kubernetes Services
- **Teknoloji**: ClusterIP Services
- **Adet**: 4 (api-csharp, api-go, web-csharp, web-go)
- **Görev**: Pod discovery ve load balancing
- **Algoritma**: Round Robin (sessionAffinity: None)
- **Endpoint**: Her service 3 pod endpoint'i

```bash
# Service'leri listele
kubectl get svc

# Endpoint'leri görüntüle
kubectl get endpoints
# Expected: 3 endpoints per service
```

#### Layer 4: Application Pods
- **Toplam**: 13 pod (3 per app × 4 apps + 1 spare)
- **Dağılım**: Worker nodes arasında eşit dağıtılmış
- **Teknoloji**:
  - C# API (.NET 9) - 32.6 MB
  - Go API (Go 1.21) - ~15 MB
  - C# Web (NGINX + Static HTML)
  - Go Web (NGINX + Static HTML)

```bash
# Pod'ları listele (node placement ile)
kubectl get pods -o wide

# Pod'lar worker node'larda dağıtılmış olmalı
```

---

## 🔀 Load Balancing Stratejileri

Bu bölüm **Layer 2 (Ingress)** ve **Layer 3 (Service)** için geçerlidir.

### 1. Round Robin (Varsayılan)

**Ne yapar**: İstekleri sırayla pod'lara dağıtır.

```yaml
# ingress.yaml
metadata:
  annotations:
    # Varsayılan davranış - annotation gerekmez
    # Veya açıkça belirtmek için:
    nginx.ingress.kubernetes.io/load-balance: "round_robin"
```

**Kullanım Senaryosu**:

- Tüm pod'lar eşit kapasitede
- Stateless uygulamalar
- Session yok veya external session store kullanılıyor

**Örnek Akış**:

```
İstek 1 → Pod A (10.244.4.2)
İstek 2 → Pod B (10.244.3.2)
İstek 3 → Pod C (10.244.5.2)
İstek 4 → Pod A (10.244.4.2)
```

### 2. IP Hash (Sticky Sessions - Client IP Bazlı)

**Ne yapar**: Aynı client IP her zaman aynı pod'a yönlendirilir.

```yaml
# ingress.yaml
metadata:
  annotations:
    # Client IP bazlı hash
    nginx.ingress.kubernetes.io/upstream-hash-by: "$binary_remote_addr"
```

**Kullanım Senaryosu**:

- Session verisi pod'da saklanıyor
- WebSocket bağlantıları
- Kullanıcı bazlı cache
- Stateful uygulamalar

**Örnek Akış**:

```
Client 1.2.3.4 → Her zaman Pod A
Client 5.6.7.8 → Her zaman Pod B
Client 9.10.11.12 → Her zaman Pod C
```

### 3. Least Connections

**Ne yapar**: En az aktif bağlantısı olan pod'a yönlendirir.

```yaml
# ingress.yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/load-balance: "least_conn"
```

**Kullanım Senaryosu**:

- Uzun süreli bağlantılar (WebSocket, SSE)
- Değişken işlem süreleri
- Dinamik yük dağılımı

**Örnek Akış**:

```
Pod A: 5 aktif bağlantı
Pod B: 2 aktif bağlantı
Pod C: 8 aktif bağlantı
→ Yeni istek Pod B'ye gider (en az bağlantı)
```

### 4. Custom Hash (Özel Alan Bazlı)

**Ne yapar**: İstekteki belirli bir alana göre hash yapar.

```yaml
# ingress.yaml
metadata:
  annotations:
    # Cookie bazlı
    nginx.ingress.kubernetes.io/upstream-hash-by: "$cookie_user_id"

    # Veya header bazlı
    nginx.ingress.kubernetes.io/upstream-hash-by: "$http_x_user_id"

    # Veya URI bazlı
    nginx.ingress.kubernetes.io/upstream-hash-by: "$request_uri"
```

**Kullanım Senaryosu**:

- Cookie bazlı session
- User ID bazlı routing
- API key bazlı routing

---

## 🎯 Mevcut Projemiz İçin Öneriler

### Şu Anki Yapılandırma (Uygulanmış) ✅

Projemizde **4 layer load balancing** aktif:

```yaml
# Layer 1: HAProxy (haproxy.cfg)
backend worker_nodes
    mode http
    balance roundrobin  # Round-robin to 3 workers
    option httpchk GET /healthz
    server worker1 172.20.0.6:80 check
    server worker2 172.20.0.5:80 check
    server worker3 172.20.0.3:80 check
```

```yaml
# Layer 2: Ingress (k8s/ingress.yaml)
metadata:
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/load-balance: "round_robin"  # Round Robin
```

```yaml
# Layer 3: Services (k8s/*-deployment.yaml)
spec:
  sessionAffinity: None  # Round Robin
  # Kubernetes default load balancing
```

```yaml
# Layer 4: Pods
# 3 replicas per application
# Distributed across worker nodes
```

### Senaryo 1: Stateless API (✅ Şu Anki Yapılandırma)

**Bizim durum**: Tüm API'ler tamamen stateless (session yok)

**Yapılandırma**:
- ✅ HAProxy: Round Robin
- ✅ Ingress: Round Robin
- ✅ Service: Round Robin (sessionAffinity: None)

**Avantajlar**:
- ✅ Optimal yük dağılımı (4 katmanda)
- ✅ Bir pod/node kapanırsa otomatik dağıtım
- ✅ Basit ve öngörülebilir
- ✅ Scale etmek kolay

### Senaryo 2: Session Bazlı Uygulama

Eğer gelecekte session eklenmesi gerekirse:

```yaml
# ingress.yaml - IP Hash + Service Session Affinity
metadata:
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$binary_remote_addr"
```

VE Service'te:

```yaml
# *-deployment.yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 300  # 5 dakika
```

**Not**: HAProxy'de de session affinity eklenmeli:

```
# haproxy.cfg
balance source  # IP-based (roundrobin yerine)
```

### Senaryo 3: WebSocket Kullanımı

Eğer WebSocket bağlantıları eklenirse:

```yaml
# ingress.yaml - Least Connections
metadata:
  annotations:
    nginx.ingress.kubernetes.io/load-balance: "least_conn"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
```

---

## 🔄 Yapılandırma Değiştirme

### Yöntem 1: YAML Dosyasını Düzenle

```bash
# ingress.yaml'ı düzenle
nano k8s/ingress.yaml

# Değişikliği uygula
kubectl apply -f k8s/ingress.yaml

# Ingress'i kontrol et
kubectl describe ingress datetime-ingress
```

### Yöntem 2: kubectl patch

```bash
# Round robin'e geç
kubectl patch ingress datetime-ingress -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/load-balance":"round_robin"}}}'

# IP hash'e geç
kubectl patch ingress datetime-ingress -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/upstream-hash-by":"$binary_remote_addr"}}}'

# Least connections'a geç
kubectl patch ingress datetime-ingress -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/load-balance":"least_conn"}}}'
```

### Yöntem 3: Makefile Target'ı Ekle

Makefile'a yeni target'lar ekleyebiliriz:

```makefile
# Makefile'a ekle
set-lb-roundrobin: ## Load balancing: Round Robin
	@echo "$(YELLOW)Setting load balance to round_robin...$(NC)"
	@kubectl patch ingress datetime-ingress -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/load-balance":"round_robin"}}}'
	@echo "$(GREEN)✓ Load balancing set to round_robin$(NC)"

set-lb-iphash: ## Load balancing: IP Hash
	@echo "$(YELLOW)Setting load balance to IP hash...$(NC)"
	@kubectl patch ingress datetime-ingress -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/upstream-hash-by":"$$binary_remote_addr"}}}'
	@echo "$(GREEN)✓ Load balancing set to IP hash$(NC)"

set-lb-leastconn: ## Load balancing: Least Connections
	@echo "$(YELLOW)Setting load balance to least_conn...$(NC)"
	@kubectl patch ingress datetime-ingress -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/load-balance":"least_conn"}}}'
	@echo "$(GREEN)✓ Load balancing set to least_conn$(NC)"

show-lb: ## Show current load balancing config
	@echo "$(BLUE)Current Load Balancing Configuration:$(NC)"
	@kubectl get ingress datetime-ingress -o jsonpath='{.metadata.annotations}' | jq
```

**Kullanım**:

```bash
make set-lb-roundrobin
make set-lb-iphash
make set-lb-leastconn
make show-lb
```

---

## 🧪 Test Etme

### Test 1: Multi-Layer Load Balancing

```bash
# Tüm layer'ları test et
for i in {1..12}; do
  echo "Request $i:"
  curl -s http://api-csharp.local/api/datetime | jq -r '.date'
done

# Beklenen: Her 3 pod'a eşit dağılım (her pod 4 istek)

# Pod loglarını kontrol et
kubectl logs -l app=datetime-api-csharp --tail=20

# HAProxy stats
curl http://localhost:8404/stats
```

### Test 2: HAProxy Backend Health

```bash
# HAProxy backend durumu
curl -s http://localhost:8404/stats | grep worker

# Beklenen: 3/3 worker UP
# worker1 (kind-worker): UP
# worker2 (kind-worker2): UP
# worker3 (kind-worker3): UP
```

### Test 3: Ingress Controller Distribution

```bash
# Ingress Controller'ların worker node yerleşimini kontrol et
kubectl get pods -n ingress-nginx -o wide

# Beklenen:
# ingress-nginx-controller-xxxxx  kind-worker   ✅
# ingress-nginx-controller-xxxxx  kind-worker2  ✅
# ingress-nginx-controller-xxxxx  kind-worker3  ✅
```

### Test 4: Round Robin (Layer 3 - Service)

```bash
# Round robin ayarla (zaten varsayılan)
make set-lb-roundrobin

# 10 istek gönder
for i in {1..10}; do
  curl -s http://api-csharp.local/api/datetime | jq -r '.time'
done

# Pod loglarını kontrol et - her pod log görmeli
kubectl logs -l app=datetime-api-csharp --tail=5
```

### Test 5: IP Hash (Sticky)

```bash
# IP hash ayarla
make set-lb-iphash

# Aynı client'tan 10 istek
for i in {1..10}; do
  curl -s http://api-csharp.local/api/datetime | jq -r '.time'
done

# Sadece 1 pod log görmeli (aynı IP → aynı pod)
kubectl logs -l app=datetime-api-csharp --tail=5
```

### Test 6: Farklı IP'lerden Test

```bash
# IP hash ayarla
make set-lb-iphash

# Farklı source IP'lerden (Docker container'lar)
for i in {1..5}; do
  docker run --rm --network kind curlimages/curl:latest \
    curl -s http://api-csharp.local/api/datetime
done

# Her container farklı IP, farklı pod'lara gidebilir
```

---

## 📊 Karşılaştırma

### Load Balancing Stratejileri

| Strateji        | Avantaj         | Dezavantaj       | Kullanım      |
| --------------- | --------------- | ---------------- | ------------- |
| **Round Robin** | Eşit dağılım    | Session tutmaz   | Stateless API |
| **IP Hash**     | Session tutarlı | Dengesiz dağılım | Stateful app  |
| **Least Conn**  | Dinamik yük     | Kompleks         | WebSocket     |
| **Custom Hash** | Esnek           | Karmaşık         | Özel ihtiyaç  |

### Multi-Layer Architecture Benefits

| Layer | Teknoloji | Görev | Redundancy |
| ----- | --------- | ----- | ---------- |
| **Layer 1** | HAProxy | Worker node distribution | Single container (can be HA) |
| **Layer 2** | NGINX Ingress | Host-based routing | 3 replicas (HA) |
| **Layer 3** | ClusterIP Service | Pod discovery | Kubernetes-managed (HA) |
| **Layer 4** | Application Pods | Business logic | 3 replicas per app (HA) |

**Toplam HA**: 4 katmanlı redundancy

---

## 🎯 Projemiz İçin Öneri

### DateTime API & Web Uygulaması

**Durum**: Tamamen stateless (session yok, sadece datetime döndürüyor)

**✅ Uygulanmış Yapılandırma** (Mevcut):

```yaml
# Layer 1: HAProxy (haproxy.cfg)
backend worker_nodes
    balance roundrobin  # ✅ Round Robin

# Layer 2: Ingress (k8s/ingress.yaml)
metadata:
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/load-balance: "round_robin"  # ✅ Round Robin

# Layer 3: Services (k8s/*-deployment.yaml)
spec:
  sessionAffinity: None  # ✅ Round Robin

# Layer 4: Pods
replicas: 3  # ✅ 3 replicas per application
```

**Neden**:

- ✅ Her pod eşit yük alır (4 katmanda)
- ✅ Bir pod/node restart olsa sorun çıkmaz
- ✅ HAProxy sağlık kontrolü ile otomatik failover
- ✅ 3 Ingress Controller ile HA
- ✅ Scale etmek kolay (tüm katmanlarda)
- ✅ Basit ve öngörülebilir
- ✅ Stateless API'ler için en iyi seçenek

### Architecture Highlights

```
High Availability (HA) at Every Layer:
┌────────────────────────────────────────┐
│ HAProxy: 1 container (can be scaled)   │
├────────────────────────────────────────┤
│ Ingress: 3 replicas (worker nodes)     │
├────────────────────────────────────────┤
│ Services: Kubernetes-managed (HA)      │
├────────────────────────────────────────┤
│ Pods: 3 replicas per app × 4 apps      │
└────────────────────────────────────────┘

Total: 13 application pods + 3 ingress pods
Cluster: 3 control-plane + 3 worker nodes
```

---

## 📝 Özet

### Mevcut Yapılandırma (Güncel) ✅

**Multi-Layer Load Balancing**:
1. **HAProxy (Layer 1)**: Round-robin → 3 worker nodes
2. **NGINX Ingress (Layer 2)**: Round-robin → Pods (3 replicas on workers)
3. **ClusterIP Service (Layer 3)**: Round-robin → Pods (sessionAffinity: None)
4. **Application Pods (Layer 4)**: 3 replicas per app, distributed

**Sonuç**: Optimal dağılım, 4 katmanlı redundancy, production-ready HA

**DateTime projesi için ideal**: ✅ Multi-layer Round Robin (stateless)

### Değiştirmek için

```bash
# Layer 2 (Ingress) değiştir
nano k8s/ingress.yaml
kubectl apply -f k8s/ingress.yaml

# Layer 1 (HAProxy) değiştir
nano haproxy.cfg
docker restart haproxy-lb

# Veya Makefile ile
make set-lb-roundrobin
make set-lb-iphash
make set-lb-leastconn
```

### Monitoring

```bash
# Layer 1: HAProxy stats
curl http://localhost:8404/stats

# Layer 2: Ingress Controller
kubectl get pods -n ingress-nginx -o wide

# Layer 3: Services & Endpoints
kubectl get endpoints

# Layer 4: Pods
kubectl get pods -o wide
```

---

## 🔍 Troubleshooting

### Problem: Dengesiz yük dağılımı

**Sebep**: Bir layer'da yanlış yapılandırma

**Çözüm**:
```bash
# Her layer'ı kontrol et
# Layer 1
curl http://localhost:8404/stats

# Layer 2
kubectl get ingress datetime-ingress -o yaml

# Layer 3
kubectl get svc -o yaml

# Layer 4
kubectl top pods  # Resource kullanımı
```

### Problem: Bir worker node DOWN

**Beklenen**: HAProxy otomatik olarak o worker'ı devre dışı bırakır

**Doğrula**:
```bash
# HAProxy backend status
curl http://localhost:8404/stats | grep worker

# Ingress Controller durumu
kubectl get pods -n ingress-nginx -o wide
```

---

**Son Güncelleme**: 2025-10-29
**Versiyon**: 2.0
**Proje**: DateTime Kubernetes Polyglot Microservices with Multi-Layer Load Balancing
