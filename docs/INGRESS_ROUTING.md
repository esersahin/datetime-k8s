<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](INGRESS_ROUTING.en.md) | 🇹🇷 [Türkçe](INGRESS_ROUTING.md) |
| :---------------------------------: | :-----------------------------: |

</div>

---

# Ingress Routing: Control-Plane'den Worker Node'lara

## 📋 İçindekiler

1. [Trafik Akışı](#-trafik-akışı)
2. [Nasıl Çalışır?](#-nasıl-çalışır)
3. [Teknik Detaylar](#-teknik-detaylar)
4. [Güncellenmiş YAML Dosyaları](#-güncellenmiş-yaml-dosyaları)
5. [Test ve Doğrulama](#-test-ve-doğrulama)
6. [Load Balancing Stratejileri](#-load-balancing-stratejileri)
7. [Sorun Giderme](#-sorun-giderme)
8. [Özet](#-özet)

---

Bu dokümanda Ingress Controller'ın control-plane'de çalışırken worker node'lardaki pod'lara nasıl trafik yönlendirdiği açıklanmaktadır.

## 🔄 Trafik Akışı

```
┌────────────────────────────────────────────────────────┐
│                 İstekler (HTTP/HTTPS)                  │
│     http://api-csharp.local, http://web-csharp.local   │
└────────────────────────┬───────────────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────────────┐
│              Kind Cluster (localhost:80)               │
└────────────────────────┬───────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│          🎛️  CONTROL-PLANE NODE (kind-control-plane)            │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │     NGINX Ingress Controller Pod                          │  │
│  │  - Host Network: true                                     │  │
│  │  - Port 80/443 listening                                  │  │
│  │  - Rules: api-csharp.local → datetime-api-csharp-service  │  │
│  │           web-csharp.local → datetime-web-csharp-service  │  │
│  └───────────────────────┬───────────────────────────────────┘  │
└──────────────────────────┼──────────────────────────────────────┘
                           │
                           ▼
          ┌────────────────┴─────────────────┐
          │                                  │
          ▼                                  ▼
┌──────────────────────────────┐   ┌──────────────────────────────┐
│ datetime-api-csharp-service  │   │ datetime-web-csharp-service  │
│  Type: ClusterIP             │   │  Type: ClusterIP             │
│  Port: 80                    │   │  Port: 80                    │
│  Selector:                   │   │  Selector:                   │
│    app=datetime-api-csharp   │   │    app=datetime-web-csharp   │
└──────────┬───────────────────┘   └──────────┬───────────────────┘
           │                                 │
           │                                 │
   ┌───────┴──────────┐              ┌───────┴──────────┐
   │                  │              │                  │
   ▼                  ▼              ▼                  ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ 💼 WORKER 1 │  │ 💼 WORKER 2 │  │ 💼 WORKER 1 │  │ 💼 WORKER 2 │
│ kind-worker │  │kind-worker2 │  │ kind-worker │  │kind-worker2 │
│             │  │             │  │             │  │             │
│ API Pod 1   │  │ API Pod 2   │  │ Web Pod 1   │  │ Web Pod 2   │
└─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘
```

## 🎯 Nasıl Çalışır?

### 1. Ingress Controller (Control-Plane'de)

Ingress Controller control-plane'de çalışır çünkü:

- ✅ `hostNetwork: true` ile host'un 80/443 portlarını dinler
- ✅ `extraPortMappings` ile Docker host'a bağlıdır
- ✅ `ingress-ready=true` label'ı control-plane'de

```yaml
# kind-config.yaml
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80 # Ingress Controller buradan dinler
        hostPort: 80 # Host'a bağlanır
```

### 2. Service Discovery (Kubernetes DNS)

Service'ler pod'ları **label selector** ile bulur:

```yaml
# datetime-api-csharp-service
spec:
  selector:
    app: datetime-api-csharp # Bu label'a sahip TÜM pod'ları bulur
```

Service, **hangi node'da olursa olsun** bu label'a sahip tüm pod'ları otomatik bulur.

### 3. Ingress Rules

Ingress, Service isimlerine göre yönlendirme yapar:

```yaml
# ingress.yaml
rules:
  - host: api-csharp.local
    http:
      paths:
        - path: /
          backend:
            service:
              name: datetime-api-csharp-service # Service'e yönlendir
```

### 4. Load Balancing

Service, trafiği pod'lara **otomatik** dağıtır:

- Round-robin (varsayılan)
- Session affinity (sticky sessions)
- Health check'e göre

## 🔍 Teknik Detaylar

### Kubernetes Service Mesh

Kubernetes'te her node'da **kube-proxy** çalışır:

```
Control-Plane Node:
├── Ingress Controller (Pod)
│   └── Trafiği Service'e yönlendirir
└── kube-proxy
    └── Service'i worker node'lardaki pod IP'lerine çevirir

Worker Node 1:
├── datetime-api-csharp Pod (10.244.1.2)
├── datetime-web-csharp Pod (10.244.1.3)
└── kube-proxy
    └── Network rules yönetir

Worker Node 2:
├── datetime-api-csharp Pod (10.244.2.2)
├── datetime-web-csharp Pod (10.244.2.3)
└── kube-proxy
    └── Network rules yönetir
```

### ClusterIP Service

```yaml
type: ClusterIP # Cluster içinden erişilebilir
```

Service, bir **virtual IP** alır:

- `datetime-api-csharp-service`: 10.96.xxx.xxx:80
- Bu IP, tüm pod IP'lerinin önünde
- kube-proxy bu IP'yi pod IP'lerine yönlendirir

### Network Flow

```
1. İstek gelir: http://api-csharp.local/api/datetime

2. Ingress Controller (control-plane):
   - Host header kontrol: api-csharp.local ✓
   - Service bulunur: datetime-api-csharp-service
   - Service IP'ye forward: 10.96.xxx.xxx:80

3. kube-proxy (her node'da):
   - Service IP'yi yakalır: 10.96.xxx.xxx:80
   - Backend pod'ları listeler:
     * 10.244.1.2:5000 (worker1)
     * 10.244.2.2:5000 (worker2)
   - Round-robin: 10.244.1.2:5000 seçilir

4. Network routing:
   - Packet worker1'e gönderilir
   - API pod cevap verir
   - Cevap Ingress'e geri döner
   - Client'a gönderilir
```

## ✅ Güncellenmiş YAML Dosyaları

### ingress.yaml Değişiklikleri

```yaml
annotations:
  # Eklendi: Backend protocol
  nginx.ingress.kubernetes.io/backend-protocol: "HTTP"

  # Eklendi: Load balancing stratejisi
  nginx.ingress.kubernetes.io/load-balance: "round_robin"

  # Kaldırıldı: rewrite-target (gereksiz)
  # nginx.ingress.kubernetes.io/rewrite-target: /
```

### Service Değişiklikleri

```yaml
# Eklendi: Session affinity
sessionAffinity: ClientIP
sessionAffinityConfig:
  clientIP:
    timeoutSeconds: 300 # 5 dakika aynı pod'a yönlendirir
```

**Avantajı**: Aynı client aynı pod'a yönlendirilir (sticky session).

## 🧪 Test ve Doğrulama

### 1. Ingress Controller Lokasyonu

```bash
# Ingress Controller nerede çalışıyor?
kubectl get pods -n ingress-nginx -o wide

# Beklenen:
# NAME                                     NODE
# ingress-nginx-controller-xxx            kind-control-plane
```

### 2. Uygulama Pod'ları Lokasyonu

```bash
# Uygulama pod'ları nerede?
kubectl get pods -o wide

# Beklenen:
# NAME                           NODE
# datetime-api-csharp-xxx              kind-worker veya kind-worker2
# datetime-web-csharp-xxx              kind-worker veya kind-worker2
```

### 3. Service Endpoint'leri

```bash
# Service hangi pod'lara yönlendiriyor?
kubectl get endpoints datetime-api-csharp-service
kubectl get endpoints datetime-web-csharp-service

# Çıktı:
# NAME                             ENDPOINTS
# datetime-api-csharp-service      10.244.1.2:5000,10.244.2.2:5000
# datetime-web-csharp-service      10.244.1.3:80,10.244.2.3:80
```

### 4. Trafik Testi

```bash
# API'ye istek at
for i in {1..10}; do
  curl -s http://api-csharp.local/api/datetime | jq .time
done

# Her istekte farklı pod cevap verebilir (round-robin)
```

### 5. Pod Loglarında İzleme

```bash
# Terminalden 1: API Pod 1 logları
kubectl logs -f datetime-api-csharp-xxx-pod1

# Terminal 2: API Pod 2 logları
kubectl logs -f datetime-api-csharp-xxx-pod2

# Terminal 3: İstek gönder
curl http://api-csharp.local/api/datetime

# Hangi terminal'de log görürseniz, o pod cevap verdi
```

### 6. Network Debugging

```bash
# Service DNS çözümleme
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup datetime-api-csharp-service

# Service'e direkt erişim (cluster içinden)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://datetime-api-csharp-service/api/datetime
```

## 📊 Load Balancing Stratejileri

### Round Robin (Varsayılan)

```yaml
nginx.ingress.kubernetes.io/load-balance: "round_robin"
```

İstekler sırayla pod'lara dağıtılır:

- İstek 1 → Pod 1
- İstek 2 → Pod 2
- İstek 3 → Pod 1
- İstek 4 → Pod 2

### IP Hash

```yaml
nginx.ingress.kubernetes.io/load-balance: "ip_hash"
```

Aynı client IP her zaman aynı pod'a yönlendirilir.

### Session Affinity

```yaml
# Service level
sessionAffinity: ClientIP
```

Client IP bazlı sticky session (5 dakika).

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

### Sorun 2: Ingress Worker Node'da Çalışıyor

```bash
# Kontrol et
kubectl get pods -n ingress-nginx -o wide

# Eğer worker'daysa, kind-config.yaml yanlış
# ingress-ready=true sadece control-plane'de olmalı

# Çözüm: Cluster'ı yeniden oluştur
make clean-cluster
make deploy
```

### Sorun 3: Trafik Sadece Bir Pod'a Gidiyor

```bash
# Load balancing algoritmasını kontrol et
kubectl describe ingress datetime-ingress

# Session affinity kapalı mı?
kubectl get service datetime-api-csharp-service -o yaml | grep sessionAffinity

# Çözüm: Session affinity'yi kaldır veya timeout'u düşür
```

## 📝 Özet

| Bileşen                | Lokasyon                  | Görevi                        |
| ---------------------- | ------------------------- | ----------------------------- |
| **Ingress Controller** | control-plane             | HTTP isteklerini yakalar      |
| **Service**            | Virtual IP (cluster-wide) | Pod'ları bulur ve yönlendirir |
| **Pod'lar**            | worker1, worker2          | Uygulamayı çalıştırır         |
| **kube-proxy**         | Her node                  | Network rules yönetir         |

### Neden Bu Yapı İdeal?

✅ **Separation of Concerns**: Control-plane yönetim, worker'lar uygulama  
✅ **Scalability**: Worker node ekle/çıkar, Ingress etkilenmez  
✅ **High Availability**: Bir worker çökerse, diğeri devam eder  
✅ **Load Balancing**: Otomatik trafik dağılımı  
✅ **Production-like**: Gerçek cluster'lara benzer yapı

---

**Sonuç**: Ingress Controller control-plane'de çalışmasına rağmen Service ve kube-proxy sayesinde worker node'lardaki pod'lara sorunsuz trafik yönlendiriyor. Bu Kubernetes'in tasarımı gereği tamamen normal ve doğru bir yapıdır.
