# macOS Network Performans Sorunu ve Çözümü

## 🐛 Sorun

macOS'ta Kind cluster'ına localhost üzerinden erişirken **5 saniye gecikme** yaşanıyor.

### Belirtiler

```bash
# Test
time curl -s http://api-go.local/health

# Sonuç: ~5 saniye
curl -s http://api-go.local/health  0.01s user 0.01s system 0% cpu 5.025 total
```

- Her HTTP isteği 5 saniye gecikmeli dönüyor
- Cluster içinden (pod to pod) hızlı: **0.00s**
- Localhost'tan ingress'e yavaş: **5+ saniye**
- Tüm `.local` domain'leri etkileniyor

## 🔍 Sorunun Kaynağı

**macOS DNS Resolver + IPv6 Timeout Sorunu**

macOS, `.local` ile biten domain'ler için:
1. IPv4 (A) kaydı arar
2. IPv6 (AAAA) kaydı arar - **Burada 5 saniye timeout**
3. IPv6 bulamazsa, IPv4'e geri döner

`/etc/hosts`'ta sadece IPv4 (127.0.0.1) varsa, macOS yine de IPv6 aramayı dener ve **5 saniye bekler**.

### Neden Sadece macOS'ta?

- Linux: Farklı DNS resolver davranışı
- Docker Desktop macOS: vpnkit kullanır, ekstra overhead
- Kind + macOS kombinasyonu sorunu tetikliyor

## ✅ Çözüm: IPv6 Entry Eklemek

### Otomatik Çözüm (Makefile)

Artık Makefile otomatik olarak IPv6 ekliyor:

```bash
make update-hosts
# veya
make deploy
```

Şu satırları `/etc/hosts`'a ekler:

```
127.0.0.1 api-csharp.local web-csharp.local api-go.local web-go.local
::1 api-csharp.local web-csharp.local api-go.local web-go.local  # ← Bu IPv6 kaydı 5 saniye sorununu çözer
```

### Manuel Çözüm

Eğer Makefile kullanmıyorsanız:

```bash
sudo sh -c 'echo "::1 api-csharp.local web-csharp.local api-go.local web-go.local" >> /etc/hosts'
```

## 🧪 Test

Düzeltme sonrası test edin:

```bash
# Önce
time curl -s http://api-go.local/health
# Sonuç: ~5 saniye ❌

# IPv6 eklendikten sonra
time curl -s http://api-go.local/health
# Sonuç: ~0.01 saniye ✅
```

## 📊 Karşılaştırma

| Durum | IPv4 Only | IPv4 + IPv6 |
|-------|-----------|-------------|
| İlk istek | 5.02s ❌ | 0.01s ✅ |
| İkinci istek | 5.01s ❌ | 0.01s ✅ |
| Cluster içi | 0.00s ✅ | 0.00s ✅ |

## 🔗 Referanslar

Bu bilinen bir macOS sorunu:

1. **macOS DNS + IPv6 Timeout**:
   - `.local` domain'ler için Bonjour aktif
   - IPv6 lookup timeout: 5 saniye
   - Çözüm: Her host için hem IPv4 hem IPv6 eklemek

2. **Kubernetes GitHub Issues**:
   - [kubernetes/kubernetes#56903](https://github.com/kubernetes/kubernetes/issues/56903) - DNS intermittent delays of 5s
   - [kubernetes-sigs/kind#2280](https://github.com/kubernetes-sigs/kind/issues/2280) - Network setup delays

3. **Stack Overflow**:
   - [10-second delay for .local TLD in Mac OS X](https://superuser.com/questions/370559/10-second-delay-for-local-tld-in-mac-os-x-lion)
   - [Chrome Slow to Resolve /etc/hosts on macOS](https://superuser.com/questions/1189379/chrome-slow-to-resolve-etc-hosts-on-macos-os-x)

## ⚠️ Notlar

- **Bu sorun sadece local development'ta** (Kind, Minikube, Docker Desktop)
- **Production cluster'larda (EKS, GKE, AKS) bu sorun yok**
- Linux ve Windows'ta bu sorun yaşanmaz
- Alternative çözüm: `.test` veya `.dev` domain kullanmak yerine `.local`

## 🎯 Özet

```bash
# Sorun
127.0.0.1 api-csharp.local  # ← 5 saniye gecikme

# Çözüm
127.0.0.1 api-csharp.local  # IPv4
::1 api-csharp.local        # IPv6 ← Bu satır 5 saniye sorununu çözer!
```

macOS'ta `.local` domain kullanırken **mutlaka IPv6 (::1) entry** ekleyin!

---

**Son Güncelleme:** 2025-10-31
**Versiyon:** 1.0
**Proje:** DateTime Kubernetes Polyglot Microservices
