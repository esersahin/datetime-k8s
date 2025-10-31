<div align="center">

### 🌐 Diğer Dillerde Oku / Read in Other Languages

| 🇹🇷 [Türkçe](ARCHITECTURE_C4.md) | 🇬🇧 [English](ARCHITECTURE_C4.en.md) |
| :--------------------: | :------------------------: |

</div>

---

# C4 Model - Mimari Diyagramlar

Bu sayfa, DateTime Kubernetes projesinin **C4 Model** standardı kullanarak mimari yapısını açıklar.

## 📋 İçindekiler

1. [C4 Model Nedir?](#-c4-model-nedir)
2. [Level 1: System Context](#-level-1-system-context)
3. [Level 2: Container Diagram](#-level-2-container-diagram)
4. [Level 3: Component - CSharp API](#-level-3-component---csharp-api)
5. [Level 3: Component - Go API](#-level-3-component---go-api)
6. [Deployment Diagram](#-deployment-diagram)
7. [Neden C4 Model?](#-neden-c4-model)
8. [Diğer Mimari Diyagramlar](#-diğer-mimari-diyagramlar)

---

## 🎯 C4 Model Nedir?

**C4 Model**, yazılım mimarisini 4 farklı soyutlama seviyesinde görselleştirme yaklaşımıdır:

- **Level 1 - Context**: Sistem ve çevresi (kullanıcılar, dış sistemler)
- **Level 2 - Container**: Teknoloji seçimleri (API, Web, Database)
- **Level 3 - Component**: Container'ların içindeki bileşenler
- **Level 4 - Code**: UML class diagram (opsiyonel)

**Ek Olarak:**
- **Deployment**: Sistemin altyapıda nasıl dağıtıldığı

### Hedef Kitle

| Seviye | Hedef Kitle | Detay Seviyesi |
|--------|-------------|----------------|
| **Context** | CEO, CTO, Müşteri | Büyük resim - Kim kullanıyor? |
| **Container** | Architect, DevOps | Teknoloji stack |
| **Component** | Developer, Tech Lead | İç yapı, pattern'ler |
| **Deployment** | DevOps, SRE | Altyapı, node'lar |

---

## 🌍 Level 1: System Context

**Amaç:** Sistemin büyük resmini gösterir. Kim kullanıyor? Hangi dış sistemlerle konuşuyor?

![C4 Context Diagram](diagrams/c4-context.png)

### Açıklama

**Kullanıcılar:**
- **End User**: Tarayıcıdan uygulamayı kullanan son kullanıcı
- **Developer**: API'leri test eden ve sistemi izleyen geliştirici

**Sistem:**
- **DateTime Microservices**: CSharp ve Go ile yazılmış polyglot mikroservisler
- **Resiliency Patterns**: Circuit breaker, retry, rate limiting

**İlişkiler:**
- End User → HTTP/HTTPS ile sisteme erişir
- Developer → HTTP ve kubectl ile test ve monitoring yapar

### Notlar
- Bu seviyede **teknik detay yok**
- **İş değeri** odaklı
- Stakeholder'lara sunumlar için ideal

---

## 📦 Level 2: Container Diagram

**Amaç:** Sistemin teknoloji seçimlerini ve container'ların nasıl iletişim kurduğunu gösterir.

![C4 Container Diagram](diagrams/c4-container.png)

### Açıklama

**Kubernetes Cluster (Kind):**

**1. NGINX Ingress Controller**
- Trafik yönlendirme
- Round Robin load balancing
- Host-based routing (api-csharp.local, web-csharp.local, api-go.local, web-go.local)

**2. CSharp Stack (.NET 9)**
- **Web UI**: Nginx + HTML/JS (Türkçe tarih gösterimi)
- **CSharp API**: .NET 9 Minimal API (Resiliency patterns ile)

**3. Go Stack (Go 1.25)**
- **Web UI Go**: Nginx + HTML/JS (Dünya saatleri)
- **Go API**: Go HTTP Server (Timezone features)

**4. CoreDNS**
- Service discovery
- Kubernetes DNS

### İletişim Akışı

```
User → Ingress → CSharp Web → CSharp API
                              ↓
User → Ingress → Go Web → Go API
                    ↑
CSharp API ────────┘ (Service-to-service + Circuit Breaker)
```

### Notlar
- **Container** ≠ Docker container
- Container = Çalıştırılabilir/deployable birim
- Her container farklı teknoloji kullanabilir

---

## 🔧 Level 3: Component - CSharp API

**Amaç:** CSharp API'nin içindeki bileşenleri ve resiliency pattern'lerini gösterir.

![C4 Component CSharp](diagrams/c4-component-csharp.png)

### Bileşenler

**1. API Endpoints (Minimal API)**
- `/api/datetime` - Türkçe tarih/saat
- `/health` - Health check
- `/api/go-time` - Go API'den veri çekme

**2. Resiliency Layer (Microsoft.Extensions.Http.Resilience)**
- Tüm resiliency pattern'lerini yönetir
- Dependency Injection ile entegre

**3. Circuit Breaker**
- 3 durum: Closed, Open, Half-Open
- 30 saniye içinde %50 hata → Open
- 30 saniye sonra Half-Open (test)

**4. Retry Policy**
- Exponential backoff
- Jitter (randomness)
- Max 3 deneme

**5. Rate Limiter**
- Token bucket algoritması
- Global: 100 req/sec
- Go API: 20 req/sec

**6. Timeout Handler**
- Request başına: 10s
- Toplam (retry ile): 30s

**7. HTTP Client (HttpClientFactory)**
- Go API'yi DNS üzerinden çağırır
- Resilient HTTP calls

**8. DateTime Service**
- Türkçe tarih formatlaması
- İş mantığı

### Akış

```
Endpoints → Resiliency Layer → HTTP Client → DNS → Go API
         ↘ DateTime Service (local logic)
```

---

## 🚀 Level 3: Component - Go API

**Amaç:** Go API'nin içindeki bileşenleri ve resiliency pattern'lerini gösterir.

![C4 Component Go](diagrams/c4-component-go.png)

### Bileşenler

**1. HTTP Router (net/http)**
- `/health` - Health check
- `/api-csharp/*` - API endpoints
- `/api/worldclock` - Dünya saatleri

**2. HTTP Handlers**
- İş mantığı handler'ları
- handlers package

**3. Circuit Breaker (sony/gobreaker)**
- Failure tracking
- Protection

**4. Rate Limiter (golang.org/x/time/rate)**
- Token bucket
- Global: 150 req/sec
- CSharp API: 30 req/sec

**5. Timezone Service**
- Timezone conversion
- World clock business logic

**6. Data Models**
- Request/Response DTOs
- models package

**7. Utilities**
- Helper functions
- utils package

### Akış

```
Router → Handlers → Circuit Breaker → Timezone Service
              ↓         ↓
         Rate Limiter   Models
              ↓
         DNS → CSharp API (opsiyonel)
```

---

## 🏗️ Deployment Diagram

**Amaç:** Sistemin Kubernetes altyapısında nasıl dağıtıldığını gösterir.

![C4 Deployment](diagrams/c4-deployment.png)

### Altyapı Hiyerarşisi

```
Local Machine (macOS/Linux)
├── HAProxy Load Balancer (Docker Container)
│   ├── Port 80/443 - HTTP/HTTPS traffic
│   └── Port 8404 - Stats dashboard
└── Docker Desktop
    └── Kind Cluster (Kubernetes v1.34 - HA Setup)
        ├── Control Plane Nodes (HA - 3 Nodes)
        │   ├── Control Plane 1 (API Server, etcd 1/3)
        │   ├── Control Plane 2 (API Server, etcd 2/3)
        │   └── Control Plane 3 (API Server, etcd 3/3, CoreDNS)
        ├── Worker Node 1 (ingress-ready=true)
        │   ├── NGINX Ingress Controller (1/3 - hostNetwork:true)
        │   ├── CSharp API Pod (1/2)
        │   ├── Go API Pod (1/3)
        │   └── CSharp Web Pod (1/2)
        ├── Worker Node 2 (ingress-ready=true)
        │   ├── NGINX Ingress Controller (2/3 - hostNetwork:true)
        │   ├── CSharp API Pod (2/2)
        │   ├── Go API Pod (2/3)
        │   └── Go Web Pod (1/2)
        └── Worker Node 3 (ingress-ready=true)
            ├── NGINX Ingress Controller (3/3 - hostNetwork:true)
            ├── Go API Pod (3/3)
            ├── CSharp Web Pod (2/2)
            └── Go Web Pod (2/2)
```

### Pod Dağılımı

| Node | Pods | Roller |
|------|------|--------|
| **Control Plane 1-3** | API Server, etcd (3-node cluster), CoreDNS | HA cluster yönetimi, etcd quorum |
| **Worker 1** | Ingress (1/3), C# API (1/2), Go API (1/3), C# Web (1/2) | Uygulama workload'ları |
| **Worker 2** | Ingress (2/3), C# API (2/2), Go API (2/3), Go Web (1/2) | Uygulama workload'ları |
| **Worker 3** | Ingress (3/3), Go API (3/3), C# Web (2/2), Go Web (2/2) | Uygulama workload'ları |

### Trafik Akışı

```
User Request
    ↓
HAProxy Load Balancer (Layer 1)
    ↓ (Round-robin + Health Check)
Worker Node (1, 2, or 3)
    ↓
NGINX Ingress Controller (Layer 2 - hostNetwork:true)
    ↓ (Host-based routing)
Kubernetes Service (Layer 3)
    ↓ (kube-proxy round-robin)
├─→ CSharp API Pod 1 (Worker 1)
└─→ CSharp API Pod 2 (Worker 2)
        ↓
    DNS Lookup (CoreDNS)
        ↓
    Go API Service
        ↓
    Go API Pod 1/2/3 (Round Robin)
```

---

## 🎯 Neden C4 Model?

### 1. **Standardizasyon**
✅ Endüstri standardı
✅ Tüm dünyada tanınan notasyon
✅ Kolay anlaşılır

### 2. **Çoklu Soyutlama Seviyeleri**
✅ **Context** → CEO, stakeholder'lar için
✅ **Container** → Architect, DevOps için
✅ **Component** → Developer'lar için
✅ **Deployment** → SRE, Infrastructure team için

### 3. **Net İletişim**
✅ **KIM** kullanıyor (Person, System)
✅ **NE** teknoloji (Container)
✅ **NASIL** çalışıyor (Component)
✅ **NEREDE** çalışıyor (Deployment)

### 4. **Dokümantasyon Değeri**
✅ Kod ile birlikte version control
✅ Sistem evrimleştikçe kolayca güncellenir
✅ Yeni team member'lar için onboarding
✅ Self-documenting architecture

### 5. **Profesyonellik**

| Özellik | Özel Diyagram | C4 Model |
|---------|---------------|----------|
| Standart | ❌ Hayır | ✅ Evet |
| Hedef kitle | 🎯 Tek | 🎯🎯🎯🎯 Çoklu |
| Öğrenme eğrisi | 📚 Her proje farklı | 📚 Tek sefer öğren |
| Sunum | 📊 Açıklama gerekir | 📊 Self-explanatory |
| Kariyerde kullanım | ⚠️ Sınırlı | ✅ Her projede |

---

## 📚 Diğer Mimari Diyagramlar

Bu proje için **2 tip mimari dokümantasyon** bulunmaktadır:

### 1. **C4 Model (Bu Dosya)**
- Endüstri standardı
- Çoklu seviyeler (Context, Container, Component, Deployment)
- Farklı hedef kitleler için
- **Dosya**: [ARCHITECTURE_C4.md](ARCHITECTURE_C4.md)

### 2. **Detaylı Teknik Diyagramlar**
- Circuit breaker state machine
- Rate limiting - Token bucket algoritması
- Request flow sequence
- Technology stack mindmap
- **Dosya**: [ARCHITECTURE.md](ARCHITECTURE.md)

### Hangisini Kullanmalıyım?

| Senaryo | Önerilen Dokümantasyon |
|---------|------------------------|
| Stakeholder sunumu | 👉 C4 Model (Context) |
| DevOps deployment | 👉 C4 Model (Deployment) |
| Developer onboarding | 👉 C4 Model (Component) |
| Teknik detay | 👉 ARCHITECTURE.md |
| Circuit breaker nasıl çalışır? | 👉 ARCHITECTURE.md |
| Token bucket algoritması | 👉 ARCHITECTURE.md |

**💡 Öneri**: Her iki dokümantasyonu da kullanın! C4 Model büyük resim için, ARCHITECTURE.md teknik detaylar için.

---

## 🔗 İlgili Dokümantasyon

- **Detaylı Teknik Diyagramlar**: [ARCHITECTURE.md](ARCHITECTURE.md)
- **Service-to-Service Communication**: [SERVICE_TO_SERVICE_COMMUNICATION.md](SERVICE_TO_SERVICE_COMMUNICATION.md)
- **C4 Diyagram Kaynakları**: [c4-diagrams.md](c4-diagrams.md)
- **Ana README**: [README.md](../README.md)

---

**C4 Model Versiyonu:** 1.0
**Son Güncelleme:** 2025-10-07
**Kaynak:** [C4 Model - c4model.com](https://c4model.com)

