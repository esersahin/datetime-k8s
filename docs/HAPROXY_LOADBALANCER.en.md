# HAProxy Load Balancer - HA Kubernetes Erişimi

## 🎯 Amaç

Kind Kubernetes cluster'ına **standart port 80/443** üzerinden **yüksek erişilebilirlik (HA)** ile erişim sağlamak.

## 📊 Mimari

```
┌─────────────────────────────────────────┐
│         Kullanıcı (Browser/curl)        │
│     http://api-csharp.local (port 80)   │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│      HAProxy Load Balancer              │
│      Container: kind-http-lb            │
│      Port: 80, 443, 8404 (stats)        │
│      Network: kind                      │
└──────────────┬──────────────────────────┘
               │
               ├──────────┬──────────┬─────────
               ▼          ▼          ▼
       ┌──────────┐ ┌──────────┐ ┌──────────┐
       │ Worker 1 │ │ Worker 2 │ │ Worker 3 │
       │  :80     │ │  :80     │ │  :80     │
       └────┬─────┘ └────┬─────┘ └────┬─────┘
            │            │            │
            └────────────┴────────────┘
                   ▼
         ┌──────────────────────┐
         │  Ingress Controller  │
         │  (3 replicas)        │
         └──────────────────────┘
                   ▼
         ┌──────────────────────┐
         │  Application Pods    │
         └──────────────────────┘
```

## 🚀 Otomatik Kurulum

### Tam Deployment (HAProxy dahil)
```bash
make deploy
```

Bu komut otomatik olarak:
1. ✅ Kind cluster oluşturur (3 control-planes + 3 workers)
2. ✅ Ingress controller kurar
3. ✅ Uygulamaları deploy eder
4. ✅ **HAProxy load balancer'ı başlatır**

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
# DNS ile worker node çözümlemesi
server worker1 kind-worker:80 check inter 2s fall 2 rise 2 resolvers docker
server worker2 kind-worker2:80 check inter 2s fall 2 rise 2 resolvers docker
server worker3 kind-worker3:80 check inter 2s fall 2 rise 2 resolvers docker
```

**Özellikler:**
- ✅ DNS kullanımı - IP değişikliklerinden etkilenmez
- ✅ Health check - Her 2 saniyede kontrol
- ✅ Hızlı failover - 2 başarısız check sonrası DOWN
- ✅ Otomatik recovery - 2 başarılı check sonrası UP

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
| Port | Protokol  |     Description      |
|------|-----------|----------------------|
| 80   | HTTP      | Ana web trafiği (HA) |
| 443  | HTTPS/TCP | SSL trafiği (HA)     |
| 8404 | HTTP      | HAProxy statistics   |

### DNS Çözümlemesi
HAProxy, Docker'ın built-in DNS'ini kullanır (`127.0.0.11:53`). Bu sayede worker node IP'leri değişse bile otomatik olarak çözümlenir.

## 🔍 HA Testi

### Worker Node Durdurma
```bash
# Worker1'i durdur
docker stop kind-worker

# Servisler hala erişilebilir (worker2 & worker3)
curl http://api-csharp.local/api/datetime
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
