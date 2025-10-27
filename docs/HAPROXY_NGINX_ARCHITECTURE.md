<div align="center">

### 🌐 Diğer Dillerde Oku

| 🇬🇧 [English](HAPROXY_NGINX_ARCHITECTURE.en.md) | 🇹🇷 [Türkçe](HAPROXY_NGINX_ARCHITECTURE.md) |
| :----------------------------------------------: | :------------------------------------------: |

</div>

---

# HAProxy ve NGINX Ingress Mimarisi

## 📋 İçindekiler

1. [Giriş](#-giriş)
2. [Sistem Bileşenleri](#-sistem-bileşenleri)
3. [İki Katmanlı Load Balancing Mimarisi](#-i̇ki-katmanlı-load-balancing-mimarisi)
4. [Detaylı Traffic Flow](#-detaylı-traffic-flow)
5. [HAProxy ve NGINX: Teknoloji Karşılaştırması](#-haproxy-ve-nginx-teknoloji-karşılaştırması)
6. [HAProxy vs NGINX Ingress Karşılaştırması](#-haproxy-vs-nginx-ingress-karşılaştırması)
7. [Neden İki Katman?](#-neden-i̇ki-katman)
8. [Örnek Senaryolar](#-örnek-senaryolar)
9. [Pratik Komutlar ve Testler](#-pratik-komutlar-ve-testler)
10. [Analoji ile Açıklama](#-analoji-ile-açıklama)
11. [Özet](#-özet)

---

## 🎯 Giriş

Bu dokümanda, datetime-k8s projesinde kullanılan **HAProxy** ve **NGINX Ingress Controller** arasındaki farkları, nasıl birlikte çalıştıklarını ve neden iki katmanlı bir mimari kullandığımızı detaylı olarak açıklayacağız.

**Ana Soru**: "Gerçekten HAProxy mı kullandık yoksa NGINX'in load balancing yapmasını mı sağladık?"

**Kısa Cevap**: **Evet, gerçekten HAProxy kullanıyoruz!** Ve NGINX Ingress ile birlikte **iki katmanlı** bir load balancing yapısı oluşturduk.

---

## 🏗️ Sistem Bileşenleri

### 1. HAProxy Container (External Load Balancer)

**Doğrulama Komutları**:

```bash
# HAProxy container'ını kontrol et
docker ps --filter name=kind-http-lb --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
```

**Çıktı**:
```
NAMES          IMAGE                PORTS
kind-http-lb   haproxy:2.8-alpine   0.0.0.0:80->80/tcp, [::]:80->80/tcp,
                                    0.0.0.0:443->443/tcp, [::]:443->443/tcp,
                                    0.0.0.0:8404->8404/tcp, [::]:8404->8404/tcp
```

**HAProxy Versiyonunu Kontrol Et**:

```bash
docker exec kind-http-lb haproxy -v
```

**Çıktı**:
```
HAProxy version 2.8.16-3a5d368 2025/10/03 - https://haproxy.org/
Status: long-term supported branch - will stop receiving fixes around Q2 2028.
```

**HAProxy Config Dosyasını Görüntüle**:

```bash
docker exec kind-http-lb cat /usr/local/etc/haproxy/haproxy.cfg | head -40
```

**Config İçeriği**:
```haproxy
# HAProxy Load Balancer Configuration for Kind Cluster
# Otomatik olarak tüm worker node'lara traffic dağıtır
# Worker node'lar DNS ile çözümlenir (kind-worker, kind-worker2, kind-worker3)

global
    log stdout format raw local0
    maxconn 4096

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 2000ms
    timeout client  50000ms
    timeout server  50000ms

    # Hızlı failover için
    timeout check 1000ms
    retries 2

# HTTP Traffic (port 80)
frontend http_frontend
    bind *:80
    mode http
    default_backend workers_http

# HTTP Load Balancer Backend
backend workers_http
    mode http
    balance roundrobin

    option httpchk GET /healthz
    http-check expect status 200-499

    # Worker node'lar - DNS ile otomatik çözümlenir
    server worker1 kind-worker:80 check inter 2s fall 2 rise 2 resolvers docker resolve-prefer ipv4
    server worker2 kind-worker2:80 check inter 2s fall 2 rise 2 resolvers docker resolve-prefer ipv4
    server worker3 kind-worker3:80 check inter 2s fall 2 rise 2 resolvers docker resolve-prefer ipv4
```

---

### 2. Worker Nodes (Kind Containers)

**Worker Node'ları Kontrol Et**:

```bash
docker ps --filter name=kind-worker --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

**Çıktı**:
```
NAMES          STATUS          PORTS
kind-worker3   Up 15 minutes
kind-worker    Up 15 minutes
kind-worker2   Up 15 minutes
```

**Not**: Worker node'ların **port mapping'i yok**! (extraPortMappings kaldırıldı)
- HAProxy üzerinden erişim sağlanıyor
- hostNetwork: true sayesinde worker container'ların port 80'i dinliyor

---

### 3. NGINX Ingress Controller Pods

**NGINX Ingress Pod'larını Kontrol Et**:

```bash
kubectl get pods -n ingress-nginx -o wide
```

**Çıktı**:
```
NAME                                        READY   STATUS    NODE
ingress-nginx-controller-7f8d89bb7f-brb6k   1/1     Running   kind-worker2
ingress-nginx-controller-7f8d89bb7f-fgb9l   1/1     Running   kind-worker
ingress-nginx-controller-7f8d89bb7f-qdzm4   1/1     Running   kind-worker3
```

**hostNetwork Ayarını Kontrol Et**:

```bash
kubectl get pods -n ingress-nginx -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,HOST-NETWORK:.spec.hostNetwork
```

**Çıktı**:
```
NAME                                        NODE           HOST-NETWORK
ingress-nginx-controller-7f8d89bb7f-brb6k   kind-worker2   true
ingress-nginx-controller-7f8d89bb7f-fgb9l   kind-worker    true
ingress-nginx-controller-7f8d89bb7f-qdzm4   kind-worker3   true
```

**hostNetwork: true** → NGINX pod'ları worker container'ın port 80'ini dinliyor

---

### 4. Ingress Resources

**Ingress Rule'larını Kontrol Et**:

```bash
kubectl get ingress -A
```

**Çıktı**:
```
NAMESPACE   NAME               CLASS   HOSTS                                          ADDRESS     PORTS   AGE
default     datetime-ingress   nginx   api-csharp.local,api-go.local,web-csharp.local,web-go.local  localhost   80      10m
```

**Ingress Detaylarını Görüntüle**:

```bash
kubectl get ingress datetime-ingress -o yaml | grep -A 10 "rules:"
```

**Çıktı**:
```yaml
  rules:
  - host: api-csharp.local
    http:
      paths:
      - backend:
          service:
            name: datetime-api-csharp-service
            port:
              number: 80
  - host: web-csharp.local
    http:
      paths:
      - backend:
          service:
            name: datetime-web-csharp-service
```

---

## 🔄 İki Katmanlı Load Balancing Mimarisi

### Katman 1: HAProxy (External Load Balancer)

**Lokasyon**: Docker container (kind network içinde, ama Kubernetes dışında)
**Adı**: `kind-http-lb`
**Görevi**: Host'tan gelen trafiği worker node'lara dağıtmak

```
┌────────────────────────────────────────────┐
│  MacBook (Host Machine)                    │
│                                            │
│  curl http://api-csharp.local/api/datetime │
│           ↓                                │
│  localhost:80 (HAProxy dinliyor)           │
└────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────┐
│  HAProxy Container (kind-http-lb)        │
│                                          │
│  Frontend: *:80                          │
│  Backend: workers_http                   │
│    ├─ worker1: kind-worker:80            │
│    ├─ worker2: kind-worker2:80           │
│    └─ worker3: kind-worker3:80           │
│                                          │
│  Algoritma: Round-robin                  │
│  Health Check: GET /healthz (2s)         │
└──────────────────────────────────────────┘
           ↓
     (Round-robin seçimi)
           ↓
┌─────────┬──────────┬──────────┐
│ Worker1 │ Worker2  │ Worker3  │  ← Kind Containers
│ :80     │ :80      │ :80      │
└─────────┴──────────┴──────────┘
```

**HAProxy Ne Yapar?**
- ✅ **Seçim**: 3 worker'dan birini seçer (round-robin)
- ✅ **Failover**: Bir worker DOWN ise, diğerlerine yönlendirir
- ✅ **Health Check**: Her 2 saniyede bir `/healthz` endpoint'ini kontrol eder
- ✅ **DNS-based**: Worker IP'leri değişse bile çalışır (kind-worker, kind-worker2, kind-worker3)

---

### Katman 2: NGINX Ingress Controller (Internal Router)

**Lokasyon**: Kubernetes pod'ları (her worker node'da 1 tane)
**Adı**: `ingress-nginx-controller`
**Görevi**: Host header'a göre trafiği doğru Kubernetes Service'e yönlendirmek

```
Worker Node (örnek: kind-worker)
┌────────────────────────────────────────────┐
│                                            │
│  Port :80 (hostNetwork: true sayesinde)    │
│           ↓                                │
│  ┌──────────────────────────────────────┐  │
│  │ NGINX Ingress Controller POD         │  │
│  │                                      │  │
│  │ Host header kontrolü:                │  │
│  │                                      │  │
│  │ IF Host == "api-csharp.local"        │  │
│  │    → api-csharp-service:80           │  │
│  │                                      │  │
│  │ IF Host == "web-csharp.local"        │  │
│  │    → web-csharp-service:80           │  │
│  │                                      │  │
│  │ IF Host == "api-go.local"            │  │
│  │    → api-go-service:80               │  │
│  │                                      │  │
│  │ IF Host == "web-go.local"            │  │
│  │    → web-go-service:80               │  │
│  └──────────────────────────────────────┘  │
│           ↓                                │
│  ┌──────────────────────────────────────┐  │
│  │ Kubernetes Services                  │  │
│  │  ├─ api-csharp-service               │  │
│  │  ├─ web-csharp-service               │  │
│  │  ├─ api-go-service                   │  │
│  │  └─ web-go-service                   │  │
│  └──────────────────────────────────────┘  │
│           ↓                                │
│  ┌──────────────────────────────────────┐  │
│  │ Application Pods                     │  │
│  │  ├─ api-csharp-deployment-xxx        │  │
│  │  ├─ web-csharp-deployment-xxx        │  │
│  │  ├─ api-go-deployment-xxx            │  │
│  │  └─ web-go-deployment-xxx            │  │
│  └──────────────────────────────────────┘  │
│                                            │
└────────────────────────────────────────────┘
```

**NGINX Ingress Ne Yapar?**
- ✅ **Host-based Routing**: HTTP Host header'ına bakar (`api-csharp.local`, `web-csharp.local`, vb.)
- ✅ **Service Mapping**: Doğru Kubernetes Service'e yönlendirir
- ✅ **SSL Termination**: HTTPS trafiğini decrypt eder (443 için)
- ✅ **Path-based Routing**: Aynı host için farklı path'lere farklı service'ler atanabilir

---

## 📊 Detaylı Traffic Flow

### Tam Request Akışı: `curl http://api-csharp.local/api/datetime`

```
═══════════════════════════════════════════════════════════════════
          COMPLETE TRAFFIC FLOW EXAMPLE
═══════════════════════════════════════════════════════════════════

Request: curl http://api-csharp.local/api/datetime

┌─────────────────────────────────────────────────────────────────┐
│ STEP 1: Client → HAProxy (External Load Balancer)               │
└─────────────────────────────────────────────────────────────────┘

  Client (curl)
    │
    │ DNS: api-csharp.local → 127.0.0.1 (via /etc/hosts)
    │
    ↓
  localhost:80
    │
    │ Docker Port Mapping: 0.0.0.0:80 → kind-http-lb:80
    │
    ↓
  HAProxy Container (kind-http-lb)
    │
    │ Görevi: 3 worker'dan birini seç (round-robin)
    │
    │ Backend Configuration:
    │   server worker1 kind-worker:80 check
    │   server worker2 kind-worker2:80 check  ← Diyelim bu seçildi
    │   server worker3 kind-worker3:80 check
    │
    ↓
  kind-worker2:80 (Docker container)


┌─────────────────────────────────────────────────────────────────┐
│ STEP 2: Worker Node → NGINX Ingress (Internal Router)           │
└─────────────────────────────────────────────────────────────────┘

  kind-worker2 Container
    │
    │ Port :80 açık (hostNetwork: true sayesinde)
    │
    ↓
  NGINX Ingress Controller Pod
  (kind-worker2 üzerinde çalışıyor)
    │
    │ Görevi: HTTP Host header'ına bak ve route et
    │
    │ HTTP Headers:
    │   Host: api-csharp.local
    │   GET /api/datetime
    │
    │ Ingress Rules Check:
    │   IF Host == "api-csharp.local" THEN
    │     backend: api-csharp-service:80  ← MATCH!
    │
    ↓
  Kubernetes Service: api-csharp-service
    │
    │ Type: ClusterIP
    │ Cluster IP: 10.96.xxx.xxx
    │ Port: 80
    │
    ↓


┌─────────────────────────────────────────────────────────────────┐
│ STEP 3: Service → Application Pod (Pod Load Balancing)          │
└─────────────────────────────────────────────────────────────────┘

  datetime-api-csharp-service (Kubernetes Service)
    │
    │ Görevi: Endpoint'lerden birini seç (kube-proxy)
    │
    │ Endpoints:
    │   - api-csharp-deployment-xxx-pod1 (10.244.1.5:8080)
    │   - api-csharp-deployment-xxx-pod2 (10.244.2.7:8080) ← Diyelim bu seçildi
    │   - api-csharp-deployment-xxx-pod3 (10.244.3.9:8080)
    │
    ↓
  Application Pod: api-csharp-deployment-xxx-pod2
    │
    │ Container: ASP.NET Core API
    │ Port: 8080
    │
    │ MinimalAPI Endpoint: 
    │   GET /api/datetime
    │
    ↓
  Response:
  {
    "date": "26.10.2025",
    "time": "13:32:36",
    "dayOfWeek": "Pazar",
    "timestamp": "2025-10-26T13:32:36"
  }


┌─────────────────────────────────────────────────────────────────┐
│ STEP 4: Response Path (Same Route Back)                         │
└─────────────────────────────────────────────────────────────────┘

  Application Pod
    ↓
  api-csharp-service
    ↓
  NGINX Ingress Controller (kind-worker2)
    ↓
  HAProxy (kind-http-lb)
    ↓
  Client (curl)
```

**Test Komutu**:

```bash
curl -v http://api-csharp.local/api/datetime
```

**Çıktı Analizi**:
```
* Connected to api-csharp.local (::1) port 80        ← HAProxy'ye bağlandı
> Host: api-csharp.local                             ← NGINX Ingress bunu kullanacak
< HTTP/1.1 200 OK
{"date":"26.10.2025","time":"13:32:36",...}  ← Application pod'dan gelen response
```

---

## 🔬 HAProxy ve NGINX: Teknoloji Karşılaştırması

### Temel Soru: HAProxy NGINX Kullanıyor mu?

**HAYIR!** HAProxy ve NGINX **tamamen farklı, bağımsız** teknolojilerdir. HAProxy arkada NGINX kullanmıyor, kendi motor ve algoritmaları ile çalışıyor.

---

### HAProxy - Özel Load Balancer

**Teknoloji Detayları:**
- **Yazıldığı Dil**: C (yüksek performans için)
- **Motor**: Kendi özel event-driven engine'i
- **İlk Çıkış**: 2000 (Willy Tarreau tarafından)
- **Versiyon**: 2.8 LTS (Long Term Support)
- **Lisans**: GPLv2

**Odak Noktası:**
- Layer 4 (TCP) ve Layer 7 (HTTP/HTTPS) load balancing
- Maksimum performans ve minimum latency
- Production-grade HA (High Availability)

**Güçlü Yönleri:**
- ✅ **Çok Yüksek Performans**: Saniyede milyonlarca connection
- ✅ **Gelişmiş Health Check**: Layer 4, Layer 7, custom health checks
- ✅ **Session Persistence**: Sticky sessions, source IP tracking
- ✅ **Detaylı İstatistikler**: Real-time stats page (:8404)
- ✅ **Failover**: Otomatik sunucu arıza tespiti ve yönlendirme
- ✅ **TCP ve HTTP**: Her iki protokolde de uzmanlaşmış
- ✅ **Düşük Kaynak Tüketimi**: Minimal memory ve CPU kullanımı

**Kullanım Alanları:**
- External load balancing (Cloud LB gibi)
- TCP/HTTP traffic distribution
- High-traffic websites (GitHub, Reddit, Stack Overflow)
- Database connection pooling
- API gateway load balancing

**Bizim Kullanımımız:**
```
HAProxy → Worker Node Selection
- kind-worker:80
- kind-worker2:80
- kind-worker3:80

Algoritma: Round-robin
Health Check: GET /healthz (Layer 7)
Failover: Otomatik
Stats: http://localhost:8404
```

---

### NGINX - Web Server + Reverse Proxy

**Teknoloji Detayları:**
- **Yazıldığı Dil**: C (event-driven architecture)
- **Motor**: Kendi asenkron, event-driven motor
- **İlk Çıkış**: 2004 (Igor Sysoev tarafından)
- **Versiyon**: 1.25+ (open source), NGINX Plus (commercial)
- **Lisans**: 2-clause BSD

**Odak Noktası:**
- Web server (static content serving)
- Reverse proxy ve HTTP routing
- Content caching ve compression
- SSL/TLS termination

**Güçlü Yönleri:**
- ✅ **Host-based Routing**: Virtual hosts, server_name matching
- ✅ **Path-based Routing**: Location blocks, regex matching
- ✅ **SSL/TLS**: Advanced SSL configuration, SNI support
- ✅ **Content Caching**: Proxy cache, FastCGI cache
- ✅ **Request Rewriting**: URL rewriting, redirects
- ✅ **Static Content**: Yüksek performanslı static file serving
- ✅ **HTTP/2 ve HTTP/3**: Modern protocol support

**Kullanım Alanları:**
- Web serving (static files)
- Reverse proxy (HTTP routing)
- API gateway (HTTP layer)
- SSL termination
- Kubernetes Ingress Controller
- Microservices routing

**Bizim Kullanımımız (Ingress Controller Olarak):**
```
NGINX Ingress → Service Routing
- api-csharp.local → datetime-api-csharp-service
- web-csharp.local → datetime-web-csharp-service
- api-go.local → datetime-api-go-service
- web-go.local → datetime-web-go-service

Yöntem: Host header matching
Lokasyon: Kubernetes pod (3 replica)
SSL: Terminasyon desteği
```

---

### Karşılaştırma Tablosu

| **ÖZELLİK** | **HAProxy** | **NGINX** |
|-------------|-------------|-----------|
| **Temel Amaç** | Load Balancer | Web Server + Reverse Proxy |
| **Yazıldığı Dil** | C | C |
| **Motor** | Event-driven (özel) | Event-driven (asenkron) |
| **Layer 4 (TCP)** | ⭐⭐⭐⭐⭐ Mükemmel | ⭐⭐⭐ İyi |
| **Layer 7 (HTTP)** | ⭐⭐⭐⭐⭐ Mükemmel | ⭐⭐⭐⭐⭐ Mükemmel |
| **Web Serving** | ❌ Yok | ⭐⭐⭐⭐⭐ Mükemmel |
| **Static Files** | ❌ Yok | ⭐⭐⭐⭐⭐ Çok hızlı |
| **Caching** | ❌ Yok | ⭐⭐⭐⭐⭐ Gelişmiş |
| **Load Balancing** | ⭐⭐⭐⭐⭐ Uzmanlaşmış | ⭐⭐⭐⭐ İyi |
| **Health Checks** | ⭐⭐⭐⭐⭐ Çok gelişmiş | ⭐⭐⭐ Temel |
| **Session Persistence** | ⭐⭐⭐⭐⭐ Gelişmiş | ⭐⭐⭐ İyi |
| **Stats/Monitoring** | ⭐⭐⭐⭐⭐ Built-in (:8404) | ⭐⭐ Stub status |
| **SSL/TLS** | ⭐⭐⭐⭐ İyi | ⭐⭐⭐⭐⭐ Çok gelişmiş |
| **URL Rewriting** | ⭐⭐ Sınırlı | ⭐⭐⭐⭐⭐ Çok güçlü |
| **Performans** | ⭐⭐⭐⭐⭐ Çok yüksek | ⭐⭐⭐⭐⭐ Çok yüksek |
| **Kaynak Kullanımı** | ⭐⭐⭐⭐⭐ Minimal | ⭐⭐⭐⭐ Düşük |
| **Konfigürasyon** | haproxy.cfg | nginx.conf |
| **Community** | Aktif | Çok aktif |
| **Commercial** | HAProxy Enterprise | NGINX Plus |

---

### Neden İkisi Birlikte Kullanılıyor?

#### Gerçek Dünya Senaryoları:

**Cloud Provider Mimarisi:**
```
User → Cloud Load Balancer → Kubernetes → NGINX Ingress → Services
        (HAProxy benzeri)                   (HTTP routing)
```

**AWS:**
```
User → ALB/ELB → Kubernetes → NGINX Ingress → Services
      (Layer 7 LB)           (Host routing)
```

**GCP:**
```
User → Cloud Load Balancing → Kubernetes → NGINX Ingress → Services
      (Global LB)                          (Ingress rules)
```

**On-Premise (Bizim Mimarimiz):**
```
User → HAProxy → Kubernetes → NGINX Ingress → Services
      (External LB)          (Internal Router)
```

#### Her Biri Farklı Katmanda Çalışıyor:

**Katman 1 - HAProxy (Infrastructure Level)**:
- **Görev**: Worker node'lar arası traffic dağıtımı
- **Seviye**: Infrastructure/Network level
- **Karar**: "Hangi worker node'a göndereyim?"
- **Bildiği**: Worker IP/DNS adresleri
- **Bilmediği**: Kubernetes Service'ler, Pod'lar, Ingress rules

**Katman 2 - NGINX Ingress (Application Level)**:
- **Görev**: HTTP host/path bazlı routing
- **Seviye**: Application/HTTP level
- **Karar**: "Bu Host header'ı hangi Service'e gidiyor?"
- **Bildiği**: Kubernetes Service'ler, Ingress rules
- **Bilmediği**: Worker node'ların durumu

**Analoji:**
```
HAProxy = Havaalanı Ulaşım Servisi
  → Hangi terminale gideceğini belirler
  → Terminal 1, 2 veya 3'e götürür

NGINX Ingress = Terminaldeki Yönlendirme Tabelaları
  → Hangi gate'e gideceğini gösterir
  → Host header'a göre route eder
```

---

### Alternatif Senaryolar

#### Senaryo 1: Sadece HAProxy
```
User → HAProxy → Services (ExternalIP)
```
❌ **Sorunlar:**
- Kubernetes-native değil
- Ingress resource kullanılamıyor
- Host-based routing manuel config gerektirir
- Service discovery zorlaşır

#### Senaryo 2: Sadece NGINX Ingress
```
User → NGINX Ingress (NodePort) → Services
```
❌ **Sorunlar:**
- Worker node failover yok
- Port mapping karmaşası (8080, 8081, 8082)
- HA sağlamıyor
- Production-like değil

#### Senaryo 3: İki Katman (Bizim Yöntemimiz) ✅
```
User → HAProxy → NGINX Ingress → Services
```
✅ **Avantajlar:**
- Worker-level HA (HAProxy)
- Application-level routing (NGINX)
- Kubernetes-native (Ingress resources)
- Production-like mimari
- Kolay failover

---

### Özet: Bağımsız Ama Tamamlayıcı

HAProxy ve NGINX:
- ✅ **Tamamen farklı** yazılımlar
- ✅ **Bağımsız** motorlar ve algoritmalar
- ✅ **Birbirini tamamlayan** özellikler
- ✅ **Farklı katmanlarda** çalışıyor
- ✅ **Birlikte mükemmel** bir çözüm oluşturuyor

HAProxy, NGINX'in önünde **external load balancer** rolünde, NGINX ise arkasında **internal HTTP router** rolünde çalışıyor.

---

## 🔍 HAProxy vs NGINX Ingress Karşılaştırması

| **ÖZELLİK**         | **HAProxy**                               | **NGINX Ingress**                      |
| ------------------- | ----------------------------------------- | -------------------------------------- |
| **Lokasyon**        | Docker container (Kubernetes dışı)        | Kubernetes pod (Her worker'da)         |
| **Ana Görev**       | Worker node seçimi (load balancing)       | Service routing (host-based)           |
| **Routing Kriteri** | Round-robin (worker1,2,3)                 | HTTP Host header (api-csharp.local, etc.)     |
| **Layer**           | Layer 4/7                                 | Layer 7                                |
| **Health Check**    | GET /healthz (her 2 saniye)               | Kubernetes readinessProbe              |
| **Failover**        | Evet (worker DOWN ise diğerlerine)        | Evet (pod DOWN ise diğer pod'a)        |
| **SSL Termination** | Evet (443 için)                           | Evet (443 için)                        |
| **Hedef**           | Worker nodes (kind-worker:80)             | Kubernetes Services (datetime-api-csharp-service:80)   |
| **Configuration**   | haproxy.cfg                               | Ingress YAML                           |
| **Stats Page**      | Evet (:8404)                              | Hayır                                  |
| **DNS Resolution**  | Evet (Docker DNS: 127.0.0.11)             | Kubernetes CoreDNS                     |
| **Replica Count**   | 1 (Single point, but external)            | 3 (Her worker'da 1)                    |

---

## 💡 Neden İki Katman?

### ❓ SORU: Neden sadece NGINX Ingress kullanmıyoruz?

### 💡 CEVAP:

#### 1️⃣ Worker Node Failover

**Problem**:
- NGINX Ingress her worker'da 1 pod (hostNetwork: true)
- Eğer worker1 çökerse, worker1:80 portuna erişilemez
- Worker node'ların port mapping'i yok (extraPortMappings kaldırıldı)

**Çözüm**:
- HAProxy worker1 DOWN olduğunu görür
- HAProxy worker2/3'e yönlendirir
- Servis kesintisiz devam eder

**Test**:
```bash
# Worker1'i durdur
docker stop kind-worker

# Hala çalışıyor mu?
curl http://api-csharp.local/api/datetime
# ✅ ÇALIŞIYOR! (worker2 ve worker3 üzerinden)
```

---

#### 2️⃣ Standard Port Access (80/443)

**Problem**:
- Worker node'ların port mappingi yok
- Kullanıcı `http://localhost:8080`, `http://localhost:8081` gibi portlar kullanmak zorunda kalır

**Çözüm**:
- HAProxy localhost:80'i tüm worker'lara dağıtıyor
- Kullanıcı port numarası yazmadan erişebiliyor
- Production-like: `http://api-csharp.local` (port yok!)

**Karşılaştırma**:
```bash
# HAProxy OLMADAN (eski yöntem):
curl http://localhost:8080/api/datetime  # worker1
curl http://localhost:8081/api/datetime  # worker2
curl http://localhost:8082/api/datetime  # worker3

# HAProxy İLE (şimdiki yöntem):
curl http://api-csharp.local/api/datetime       # HAProxy route ediyor ✅
```

---

#### 3️⃣ High Availability (HA)

**Senaryo**: 3 worker var: worker1, worker2, worker3

```
Normal Durum:
  ✅ worker1 → UP
  ✅ worker2 → UP
  ✅ worker3 → UP
  ✅ HAProxy → Round-robin (1→2→3→1→2→3...)

Worker1 Çöktü:
  ❌ worker1 → DOWN
  ✅ worker2 → UP
  ✅ worker3 → UP
  ✅ HAProxy → Round-robin (2→3→2→3...)
  ✅ Health check: worker1 her 2 saniyede kontrol ediliyor

Worker1 Tekrar Ayağa Kalktı:
  ✅ worker1 → UP (2 successful health check sonrası)
  ✅ worker2 → UP
  ✅ worker3 → UP
  ✅ HAProxy → Round-robin (1→2→3→1→2→3...)
```

**HAProxy Stats'i Kontrol Et**:

```bash
# Stats page
curl -s http://localhost:8404

# Veya tarayıcıda:
open http://localhost:8404
```

**Stats Çıktısı** (worker1 DOWN olduğunda):
```
Backend: workers_http
├─ worker1  ❌ DOWN      (Last check: Connection refused)
├─ worker2  ✅ UP        (L7OK/200 in 1ms)
└─ worker3  ✅ UP        (L7OK/200 in 0ms)

Active Servers: 2/3
```

---

#### 4️⃣ Production-like Setup

**Gerçek Production Ortamlarında**:

```
Cloud Provider (AWS/GCP/Azure)
    ↓
External Load Balancer
  - AWS: Application Load Balancer (ALB)
  - GCP: Google Cloud Load Balancing
  - Azure: Azure Load Balancer
  - On-Premise: HAProxy, F5, NGINX Plus
    ↓
Kubernetes Cluster
    ↓
Ingress Controller (Internal)
  - NGINX Ingress
  - Traefik
  - Istio Gateway
    ↓
Services & Pods
```

**Bizim Setup**:

```
localhost:80
    ↓
HAProxy (External LB - Cloud LB'yi simüle ediyor)
    ↓
Kind Cluster (3 control-plane + 3 worker)
    ↓
NGINX Ingress Controller (Internal Router)
    ↓
Services & Pods
```

**Avantajı**: Production'a geçerken sadece HAProxy → Cloud LB değişimi yeterli!

---

## 🎬 Örnek Senaryolar

### Senaryo 1: Normal Durum

```
✅ worker1, worker2, worker3 → Hepsi UP
✅ HAProxy round-robin yapıyor
✅ NGINX Ingress her worker'da çalışıyor

Test:
  $ curl http://api-csharp.local/api/datetime
  → HAProxy: worker1 seçildi
  → NGINX (worker1): api-csharp.local → datetime-api-csharp-service
  → datetime-api-csharp-service: pod-1 seçildi
  → Response: 200 OK
```

**Komut**:
```bash
for i in {1..6}; do
  echo "Request $i:";
  curl -s http://api-csharp.local/api/datetime | jq -r '.time';
done
```

**Çıktı** (HAProxy round-robin):
```
Request 1: 13:45:10  ← worker1
Request 2: 13:45:11  ← worker2
Request 3: 13:45:12  ← worker3
Request 4: 13:45:13  ← worker1
Request 5: 13:45:14  ← worker2
Request 6: 13:45:15  ← worker3
```

---

### Senaryo 2: Worker1 Çöktü

```
❌ worker1 → DOWN
✅ worker2, worker3 → UP
✅ HAProxy worker1'i atladı, sadece worker2/3'e gönderiyor
✅ Servis çalışmaya devam ediyor
```

**Test**:

```bash
# Worker1'i durdur
docker stop kind-worker

# HAProxy stats kontrol et
curl -s http://localhost:8404 | grep -A 2 "workers_http/worker1"
# Çıktı: worker1 DOWN

# Servis hala çalışıyor mu?
curl http://api-csharp.local/api/datetime
# ✅ ÇALIŞIYOR! (worker2 veya worker3 üzerinden)

# Worker1'i tekrar başlat
docker start kind-worker

# 4-6 saniye sonra (2 successful health check)
curl -s http://localhost:8404 | grep -A 2 "workers_http/worker1"
# Çıktı: worker1 UP
```

**HAProxy Logs**:
```bash
docker logs kind-http-lb --tail 20
```

**Örnek Log**:
```
[WARNING]  Server workers_http/worker1 is DOWN, reason: Layer7 wrong status, code: 502
[INFO]     Server workers_http/worker1 is UP, reason: Layer7 check passed
```

---

### Senaryo 3: Worker1 ve Worker2 Çöktü

```
❌ worker1, worker2 → DOWN
✅ worker3 → UP
✅ HAProxy sadece worker3'e gönderiyor
✅ Servis çalışmaya devam ediyor (reduced capacity)
```

**Test**:

```bash
# Worker1 ve Worker2'yi durdur
docker stop kind-worker kind-worker2

# Servis hala çalışıyor mu?
for i in {1..5}; do
  curl -s http://api-csharp.local/api/datetime | jq -r '.time';
done
# ✅ ÇALIŞIYOR! (sadece worker3 üzerinden)

# HAProxy stats
curl -s http://localhost:8404 | grep -E "(worker1|worker2|worker3)" | grep "UP\|DOWN"
# worker1: DOWN
# worker2: DOWN
# worker3: UP
```

---

### Senaryo 4: Bir NGINX Ingress Pod'u Çöktü

```
✅ worker1, worker2, worker3 → Hepsi UP
❌ worker2'deki NGINX pod çöktü
✅ HAProxy worker2'ye yönlendirdiğinde 502 Bad Gateway alacak
✅ HAProxy health check worker2'yi DOWN olarak işaretler
✅ HAProxy worker1/3'e yönlendirmeye başlar
```

**Test**:

```bash
# Worker2'deki NGINX pod'unu sil
kubectl delete pod -n ingress-nginx -l app.kubernetes.io/component=controller --field-selector spec.nodeName=kind-worker2

# HAProxy health check başarısız olacak
# 2 failed check sonrası worker2 DOWN işaretlenecek

# HAProxy stats
curl -s http://localhost:8404 | grep "worker2"
# worker2: DOWN (L7: Connection refused veya 502)

# Kubernetes yeni pod oluşturacak
kubectl get pods -n ingress-nginx -w

# Yeni pod Ready olduğunda
# 2 successful check sonrası worker2 tekrar UP işaretlenecek
```

---

## 🛠️ Pratik Komutlar ve Testler

### HAProxy Komutları

#### 1. HAProxy Container Durumu

```bash
docker ps --filter name=kind-http-lb --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

#### 2. HAProxy Stats Sayfası

```bash
# CLI
curl -s http://localhost:8404

# Tarayıcı
open http://localhost:8404
```

#### 3. HAProxy Logs

```bash
# Son 50 log
docker logs kind-http-lb --tail 50

# Canlı log takibi
docker logs kind-http-lb --follow

# Health check logları
docker logs kind-http-lb --follow | grep "health check"
```

#### 4. HAProxy Config Kontrolü

```bash
# Config dosyasını görüntüle
docker exec kind-http-lb cat /usr/local/etc/haproxy/haproxy.cfg

# Config syntax check
docker exec kind-http-lb haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
```

#### 5. HAProxy Restart (Config değişikliği sonrası)

```bash
docker restart kind-http-lb
```

---

### NGINX Ingress Komutları

#### 1. NGINX Ingress Pod'ları

```bash
# Pod'ları listele
kubectl get pods -n ingress-nginx -o wide

# Detaylı bilgi
kubectl describe pod -n ingress-nginx -l app.kubernetes.io/component=controller

# Logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
```

#### 2. NGINX Ingress Service

```bash
# Service bilgisi
kubectl get svc -n ingress-nginx

# Service endpoints
kubectl get endpoints -n ingress-nginx
```

#### 3. Ingress Resources

```bash
# Tüm Ingress'leri listele
kubectl get ingress -A

# Detaylı bilgi
kubectl describe ingress datetime-ingress

# YAML çıktısı
kubectl get ingress datetime-ingress -o yaml
```

#### 4. NGINX Config İçerisinde İnceleme

```bash
# NGINX pod'una exec
POD_NAME=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n ingress-nginx $POD_NAME -- /bin/bash

# İçeride:
nginx -T | grep "server_name api-csharp.local"
```

---

### Traffic Test Komutları

#### 1. Basit Request Testi

```bash
# GET request
curl http://api-csharp.local/api/datetime

# JSON çıktısı
curl -s http://api-csharp.local/api/datetime | jq

# Verbose (header'ları göster)
curl -v http://api-csharp.local/api/datetime
```

#### 2. Round-robin Testi

```bash
# 10 request gönder ve timing'i ölç
for i in {1..10}; do
  echo -n "Request $i: ";
  time curl -s http://api-csharp.local/api/datetime > /dev/null;
done
```

#### 3. Load Test

```bash
# Apache Bench (100 request, 10 concurrent)
ab -n 100 -c 10 http://api-csharp.local/api/datetime

# Veya hey (https://github.com/rakyll/hey)
hey -n 100 -c 10 http://api-csharp.local/api/datetime
```

#### 4. Farklı Host'lar

```bash
# api-csharp.local
curl -s http://api-csharp.local/api/datetime | jq -r '.time'

# api-go.local
curl -s http://api-go.local/health | jq

# web-csharp.local
curl -s http://web-csharp.local | grep "<title>"

# web-go.local
curl -s http://web-go.local | grep "<title>"
```

#### 5. Worker Failover Testi

```bash
# Terminal 1: Sürekli request gönder
while true; do
  curl -s http://api-csharp.local/api/datetime | jq -r '.time';
  sleep 1;
done

# Terminal 2: Worker1'i durdur
docker stop kind-worker

# Terminal 1'de request'ler kesintisiz devam etmeli!

# Terminal 2: Worker1'i tekrar başlat
docker start kind-worker

# 4-6 saniye sonra worker1 tekrar pool'a katılacak
```

---

## 🎓 Analoji ile Açıklama

### Restoran Analojisi

Bir restoran düşünün:

#### **HAProxy** = Restoranın Kapısındaki Görevli (Hostess)

- **Görev**: Müşterileri boş masalara/kasalara yönlendirmek
- **3 Kasa Var**:
  - Kasa 1 (worker1)
  - Kasa 2 (worker2)
  - Kasa 3 (worker3)
- **Algoritma**: Sırayla yönlendirme (round-robin)
- **Health Check**: Kasaların açık olup olmadığını sürekli kontrol ediyor
- **Failover**: Bir kasa kapalı ise, müşteriyi diğer kasaya yönlendiriyor

**Örnek**:
```
Müşteri 1: Kasa 1'e git
Müşteri 2: Kasa 2'ye git
Müşteri 3: Kasa 3'e git
Müşteri 4: Kasa 1'e git
...

(Kasa 1 kapandı!)
Müşteri 5: Kasa 2'ye git
Müşteri 6: Kasa 3'e git
Müşteri 7: Kasa 2'ye git
...
```

---

#### **NGINX Ingress** = Kasadaki Çalışan

- **Görev**: Müşterinin siparişini doğru bölüme yönlendirmek
- **Sipariş Türleri**:
  - Pizza siparişi → Pizzacı'ya (datetime-api-csharp-service)
  - Hamburger siparişi → Burger'ci'ye (datetime-web-csharp-service)
  - İçecek siparişi → Bar'a (datetime-api-go-service)
  - Tatlı siparişi → Pastane'ye (datetime-web-go-service)

**Örnek**:
```
Müşteri: "Pizza istiyorum" (Host: api-csharp.local)
Kasa: "Pizzacı'ya yönlendiriyorum" (datetime-api-csharp-service)

Müşteri: "Hamburger istiyorum" (Host: web-csharp.local)
Kasa: "Burger'ci'ye yönlendiriyorum" (datetime-web-csharp-service)
```

---

### Tam Akış Analojisi

```
1. Müşteri restoran kapısına gelir
   → curl http://api-csharp.local/api/datetime

2. Hostess müşteriyi Kasa 2'ye yönlendirir
   → HAProxy: kind-worker2 seçildi (round-robin)

3. Müşteri Kasa 2'ye gider
   → Request worker2:80'e ulaşır

4. Kasa çalışanı siparişe bakar: "Pizza istiyorsunuz"
   → NGINX Ingress: Host header'ı kontrol ediyor (api-csharp.local)

5. Kasa çalışanı "Pizzacı'ya yönlendiriyorum" der
   → NGINX Ingress: datetime-api-csharp-service'e route ediyor

6. Pizzacı siparişi hazırlar
   → datetime-api-csharp-service → api-csharp-deployment pod'u response döndürür

7. Pizza müşteriye ulaşır
   → Response client'a döner
```

---

## 📚 Özet

### Katman Yapısı

```
┌─────────────────────────────────────────────────────────────────┐
│ KATMAN 1: HAProxy Load Balancer (L4/L7)                         │
├─────────────────────────────────────────────────────────────────┤
│ • Ne Yapar: Worker node seçimi                                  │
│ • Algoritma: Round-robin                                        │
│ • Health Check: GET /healthz (Layer 7)                          │
│ • Failover: Evet (bir worker DOWN ise diğerlerine yönlendirir)  │
│ • Lokasyon: Docker container (Kubernetes dışında)               │
│ • Config: k8s/haproxy-lb.cfg                                    │
│ • Stats: http://localhost:8404                                  │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│ KATMAN 2: NGINX Ingress Controller (L7)                         │
├─────────────────────────────────────────────────────────────────┤
│ • Ne Yapar: Host-based routing (api-csharp.local → datetime-api-csharp-service) │
│ • Algoritma: Ingress rules (host matching)                      │
│ • SSL Termination: Evet (HTTPS → HTTP)                          │
│ • Lokasyon: Kubernetes pod (her worker'da 1 tane)               │
│ • Config: k8s/ingress-nginx-deployment.yaml + Ingress YAML      │
│ • hostNetwork: true (worker container'ın port 80'ini dinler)    │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│ KATMAN 3: Kubernetes Service (kube-proxy) (L4)                  │
├─────────────────────────────────────────────────────────────────┤
│ • Ne Yapar: Pod seçimi                                          │
│ • Algoritma: Round-robin (default)                              │
│ • Lokasyon: Kubernetes control plane                            │
│ • Config: Service YAML                                          │
└─────────────────────────────────────────────────────────────────┘
                          ↓
                  Application Pods
```

---

### Ana Sorulara Cevaplar

#### ❓ HAProxy mı kullanıyoruz?
✅ **Evet!** `kind-http-lb` container'ı HAProxy 2.8 çalıştırıyor.

#### ❓ NGINX Ingress nerede?
✅ **Kubernetes pod'ları olarak!** Her worker node'da 1 NGINX Ingress pod çalışıyor (3 replica).

#### ❓ İkisi birlikte nasıl çalışıyor?
✅ **İki katmanlı yapı:**
   1. HAProxy: Worker seçimi (External LB)
   2. NGINX: Service routing (Internal Router)

#### ❓ Neden iki katman?
✅ **4 Ana Sebep:**
   1. Worker node failover
   2. Standard port access (80/443)
   3. High availability
   4. Production-like setup

#### ❓ Hangisi load balancing yapıyor?
✅ **İkisi de!**
   - HAProxy: Worker node'lar arasında
   - NGINX Ingress: Kubernetes Service'lere routing
   - Kubernetes Service: Pod'lar arasında

---

### Hızlı Test Komutları

```bash
# 1. HAProxy çalışıyor mu?
docker ps --filter name=kind-http-lb

# 2. HAProxy stats sayfası
open http://localhost:8404

# 3. NGINX Ingress pod'ları
kubectl get pods -n ingress-nginx -o wide

# 4. Traffic test
curl http://api-csharp.local/api/datetime

# 5. Failover test
docker stop kind-worker
curl http://api-csharp.local/api/datetime  # Hala çalışmalı!
docker start kind-worker

# 6. Round-robin test
for i in {1..6}; do curl -s http://api-csharp.local/api/datetime | jq -r '.time'; done
```

---

## 🎉 Sonuç

Bu mimari sayesinde:

✅ **Production-like ortam**: Cloud LB + Kubernetes Ingress gibi
✅ **High Availability**: Worker node arıza toleransı
✅ **Easy Access**: Port numarası gereksiz (standard :80/:443)
✅ **Automatic Failover**: HAProxy health checks + DNS-based routing
✅ **Scalability**: İstediğiniz kadar worker ekleyebilirsiniz
✅ **Monitoring**: HAProxy stats page (:8404)

---

**Happy Learning! 🚀**

*Bu doküman, HAProxy ve NGINX Ingress Controller arasındaki farkları ve birlikte nasıl çalıştıklarını anlamak için hazırlanmıştır.*
