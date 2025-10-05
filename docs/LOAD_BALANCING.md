<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](docs/LOAD_BALANCING.en.md) | 🇹🇷 [Türkçe](docs/LOAD_BALANCING.md) |
|:---:|:---:|

</div>

---

﻿# Load Balancing Yapılandırması

Bu dokümanda ingress.yaml'da kullanabileceğiniz farklı load balancing stratejileri açıklanmaktadır.

## 🔀 Load Balancing Stratejileri

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
İstek 1 → Pod A
İstek 2 → Pod B
İstek 3 → Pod A
İstek 4 → Pod B
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
→ Yeni istek Pod B'ye gider
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

### Şu Anki Yapılandırma

```yaml
# ingress.yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$binary_remote_addr"
```

Bu, **IP Hash** stratejisi kullanıyor.

### Senaryo 1: Stateless API (Önerilen)

Eğer API'niz tamamen stateless ise (session yok):

```yaml
# ingress.yaml - Round Robin
metadata:
  annotations:
    # Bu satırı kaldırın veya round_robin yapın
    # nginx.ingress.kubernetes.io/upstream-hash-by: "$binary_remote_addr"
    nginx.ingress.kubernetes.io/load-balance: "round_robin"
```

**Avantajlar**:

- ✅ Daha iyi yük dağılımı
- ✅ Bir pod kapanırsa otomatik dağıtım
- ✅ Basit ve öngörülebilir

### Senaryo 2: Session Bazlı Uygulama

Eğer kullanıcı session'ı var:

```yaml
# ingress.yaml - IP Hash + Service Session Affinity
metadata:
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$binary_remote_addr"
```

VE Service'te:

```yaml
# api-deployment.yaml & web-deployment.yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 300
```

**Avantajlar**:

- ✅ Session tutarlılığı
- ✅ Cache hit oranı yüksek
- ✅ Kullanıcı deneyimi tutarlı

### Senaryo 3: WebSocket Kullanımı

Eğer WebSocket bağlantıları var:

```yaml
# ingress.yaml - Least Connections
metadata:
  annotations:
    nginx.ingress.kubernetes.io/load-balance: "least_conn"
    # WebSocket için
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

### Test 1: Round Robin

```bash
# Round robin ayarla
make set-lb-roundrobin  # veya kubectl patch

# 10 istek gönder
for i in {1..10}; do
  curl -s http://api.local/api/datetime | jq -r '.time'
done

# Pod loglarını kontrol et - her iki pod da log görmeli
kubectl logs -l app=datetime-api --tail=5
```

### Test 2: IP Hash (Sticky)

```bash
# IP hash ayarla
make set-lb-iphash

# Aynı client'tan 10 istek
for i in {1..10}; do
  curl -s http://api.local/api/datetime | jq -r '.time'
done

# Sadece 1 pod log görmeli (aynı IP → aynı pod)
kubectl logs -l app=datetime-api --tail=5
```

### Test 3: Farklı IP'lerden Test

```bash
# IP hash ayarla
make set-lb-iphash

# Farklı source IP'lerden (Docker container'lar)
for i in {1..5}; do
  docker run --rm --network kind curlimages/curl:latest \
    curl -s http://api.local/api/datetime
done

# Her container farklı IP, farklı pod'lara gidebilir
```

---

## 📊 Karşılaştırma

| Strateji        | Avantaj         | Dezavantaj       | Kullanım      |
| --------------- | --------------- | ---------------- | ------------- |
| **Round Robin** | Eşit dağılım    | Session tutmaz   | Stateless API |
| **IP Hash**     | Session tutarlı | Dengesiz dağılım | Stateful app  |
| **Least Conn**  | Dinamik yük     | Kompleks         | WebSocket     |
| **Custom Hash** | Esnek           | Karmaşık         | Özel ihtiyaç  |

---

## 🎯 Projemiz İçin Öneri

### DateTime API & Web Uygulaması

**Durum**: Tamamen stateless (session yok, sadece datetime döndürüyor)

**Önerilen Yapılandırma**:

```yaml
# ingress.yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    # Round robin (varsayılan) - en iyi yük dağılımı
    nginx.ingress.kubernetes.io/load-balance: "round_robin"
```

```yaml
# Service'lerde session affinity KALDIRILSIN
# api-deployment.yaml & web-deployment.yaml
spec:
  # Bu satırları kaldırın:
  # sessionAffinity: ClientIP
  # sessionAffinityConfig: ...
```

**Neden**:

- ✅ Her pod eşit yük alır
- ✅ Bir pod restart olsa sorun çıkmaz
- ✅ Scale etmek kolay
- ✅ Basit ve öngörülebilir

---

## 📝 Özet

**Şu anki yapılandırma**: IP Hash (sticky sessions)  
**DateTime projesi için ideal**: Round Robin (stateless)

**Değiştirmek için**:

```bash
# ingress.yaml'ı düzenle
nano k8s/ingress.yaml

# nginx.ingress.kubernetes.io/upstream-hash-by satırını kaldır
# Veya round_robin ekle

# Uygula
kubectl apply -f k8s/ingress.yaml

# Veya Makefile ile
make set-lb-roundrobin
```
