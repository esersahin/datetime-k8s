# Secret Management (Gizli Bilgi Yönetimi)

## 📋 İçindekiler

- [Genel Bakış](#genel-bakış)
- [Neden Secret Management Önemli?](#neden-secret-management-önemli)
- [Best Practices](#best-practices)
- [Seviye 1: .env Dosyası Yaklaşımı](#seviye-1-env-dosyası-yaklaşımı-önerilen)
- [Seviye 2: YAML Dosyası Yaklaşımı](#seviye-2-yaml-dosyası-yaklaşımı)
- [Seviye 3: Production-Ready Yaklaşım](#seviye-3-production-ready-yaklaşım)
- [Mevcut Implementasyon](#mevcut-implementasyon)
- [Kullanım Kılavuzu](#kullanım-kılavuzu)
- [Troubleshooting](#troubleshooting)
- [Güvenlik Kontrol Listesi](#güvenlik-kontrol-listesi)

---

## Genel Bakış

Bu projede **HashiCorp Vault** ve **External Secrets Operator** kullanılarak güvenli secret yönetimi sağlanmaktadır. Secret'lar (şifreler, API anahtarları, token'lar vb.) Vault'ta şifreli olarak saklanır ve uygulama pod'larına güvenli bir şekilde enjekte edilir.

### Mimari

```
.env Dosyası (Local Developer)
    ↓
Makefile (vault-setup komutu)
    ↓
HashiCorp Vault (Kubernetes'te çalışan)
    ↓
External Secrets Operator
    ↓
Kubernetes Secrets (Otomatik oluşturulur)
    ↓
Application Pods (env variables olarak inject edilir)
```

---

## Neden Secret Management Önemli?

### ❌ Kötü Yaklaşımlar

```makefile
# KÖTÜ: Hard-coded secrets
database_url="postgresql://user:password123@host/db"

# KÖTÜ: Secret'lar Git'e commit edilir
git add Makefile
git commit -m "update database config"  # ← Şifre Git history'de kalır!

# KÖTÜ: Public repo'da görünür
# GitHub, GitLab, Bitbucket'ta herkes görür
```

### ⚠️ Riskler

| Risk | Açıklama | Etki |
|------|----------|------|
| **Veri İhlali** | Secret'lar açığa çıkar | Kritik |
| **Yetkisiz Erişim** | Kötü niyetli kişiler sisteme erişir | Kritik |
| **Compliance İhlali** | GDPR, PCI-DSS vb. ihlali | Yüksek |
| **Audit Problemi** | Kim, ne zaman erişti belli değil | Orta |
| **Rotasyon Zorluğu** | Şifre değişince kod değişir | Orta |

### ✅ İyi Yaklaşım

```makefile
# İYİ: Environment variable'dan oku
database_url="${DB_URL}"  # ← .env dosyasından gelir, Git'e commit edilmez

# İYİ: Vault'a yaz
vault kv put secret/app database_url="${DB_URL}"

# İYİ: Kubernetes Secret otomatik oluşturulur
# External Secrets Operator halleder
```

---

## Best Practices

### 1. ✅ Secret'ları Git'e Commit Etmeyin

```bash
# .gitignore
.env
.env.local
.env.*.local
vault-keys.json
secrets.yaml
```

### 2. ✅ Environment Variable Kullanın

```bash
# .env dosyası (Git'e commit edilmez)
DB_PASSWORD=my-secret-password
API_KEY=my-api-key

# Makefile
database_url="${DB_PASSWORD}"
```

### 3. ✅ Template Dosyası Sağlayın

```bash
# .env.example (Git'e commit edilir)
DB_PASSWORD=your-password-here
API_KEY=your-api-key-here
```

### 4. ✅ Farklı Ortamlar İçin Farklı Secret'lar

```
Development: Test verileri
Staging: Gerçeğe yakın ama ayrı
Production: Gerçek credentials
```

### 5. ✅ Least Privilege Prensibi

Her servis sadece ihtiyacı olan secret'lara erişsin:

```yaml
# C# API sadece kendi secret'larına erişir
secret/datetime/api-csharp

# Go API sadece kendi secret'larına erişir
secret/datetime/api-go
```

### 6. ✅ Secret Rotation

Düzenli olarak secret'ları değiştirin:

```bash
# Yeni JWT secret oluştur
openssl rand -base64 32

# Vault'ta güncelle
vault kv patch secret/app jwt_secret="new-secret"

# Pod'ları restart et
kubectl rollout restart deployment/app
```

### 7. ✅ Audit Logging

Kim, ne zaman, hangi secret'a erişti?

```bash
# Vault audit logging
vault audit enable file file_path=/vault/logs/audit.log

# Logları incele
kubectl exec -n vault vault-0 -- cat /vault/logs/audit.log
```

---

## Seviye 1: .env Dosyası Yaklaşımı (Önerilen)

### ✅ Avantajlar

- Basit ve hızlı (5 dakikada uygulanır)
- Git'e commit edilmez
- Her developer kendi değerlerini kullanır
- Standart yaklaşım (çoğu proje böyle)
- .env.example ile dokümante edilir

### ⚠️ Dezavantajlar

- Her developer .env dosyası oluşturmalı
- Secret rotation manuel
- CI/CD için ek ayar gerekir

### 📁 Dosya Yapısı

```
datetime-k8s/
├── .env                 # Gerçek secret'lar (Git'e commit edilmez!)
├── .env.example         # Template (Git'e commit edilir)
├── .gitignore           # .env listelenmiş
└── Makefile             # .env'den okur
```

### 📝 .env Dosyası

```bash
# C# API Secrets
CSHARP_TIMEZONE=Europe/Istanbul
CSHARP_LOG_LEVEL=debug
CSHARP_DB_URL=postgresql://user:pass@host:5432/db
CSHARP_API_KEY=csharp-api-key-12345
CSHARP_JWT_SECRET=csharp-jwt-secret-67890
CSHARP_REDIS_URL=redis://host:6379

# Go API Secrets
GO_TIMEZONE=UTC
GO_LOG_LEVEL=info
GO_DB_URL=postgresql://user:pass@host:5432/db
GO_API_KEY=go-api-key-67890
GO_JWT_SECRET=go-jwt-secret-12345
GO_REDIS_URL=redis://host:6380
```

### 📝 .env.example (Template)

```bash
# C# API Secrets
CSHARP_TIMEZONE=Europe/Istanbul
CSHARP_LOG_LEVEL=debug
CSHARP_DB_URL=postgresql://username:password@host:5432/database_name
CSHARP_API_KEY=your-api-key-here
CSHARP_JWT_SECRET=your-jwt-secret-here
CSHARP_REDIS_URL=redis://host:6379
```

### 🔧 Makefile Entegrasyonu

```makefile
# .env dosyasını yükle
-include .env
export

vault-setup: vault-unseal
	@echo "Secret'lar .env dosyasından okunuyor..."
	@if [ ! -f ".env" ]; then \
		echo "❌ HATA: .env dosyası bulunamadı!"; \
		echo "Lütfen .env.example'ı kopyalayın: cp .env.example .env"; \
		exit 1; \
	fi
	kubectl exec -n vault vault-0 -- vault kv put secret/datetime/api-csharp \
		timezone="${CSHARP_TIMEZONE}" \
		log_level="${CSHARP_LOG_LEVEL}" \
		database_url="${CSHARP_DB_URL}" \
		api_key="${CSHARP_API_KEY}" \
		jwt_secret="${CSHARP_JWT_SECRET}" \
		redis_url="${CSHARP_REDIS_URL}"
```

---

## Seviye 2: YAML Dosyası Yaklaşımı

### 📁 Dosya Yapısı

```
datetime-k8s/
├── secrets.yaml         # Gerçek secret'lar (Git'e commit edilmez!)
├── secrets.yaml.example # Template (Git'e commit edilir)
└── Makefile             # secrets.yaml'dan okur
```

### 📝 secrets.yaml

```yaml
# secrets.yaml (Git'e commit edilmez!)
csharp:
  timezone: Europe/Istanbul
  log_level: debug
  database_url: postgresql://user:pass@host/db
  api_key: csharp-api-key-12345
  jwt_secret: csharp-jwt-secret-67890
  redis_url: redis://host:6379

go:
  timezone: UTC
  log_level: info
  database_url: postgresql://user:pass@host/db
  api_key: go-api-key-67890
  jwt_secret: go-jwt-secret-12345
  redis_url: redis://host:6380
```

### 🔧 Makefile Entegrasyonu

```makefile
vault-setup:
	@if [ ! -f "secrets.yaml" ]; then \
		echo "❌ secrets.yaml bulunamadı!"; \
		echo "secrets.yaml.example'ı kopyalayın"; \
		exit 1; \
	fi
	# YAML'dan oku ve Vault'a yaz
	CSHARP_DB_URL=$$(yq eval '.csharp.database_url' secrets.yaml); \
	kubectl exec -n vault vault-0 -- vault kv put secret/datetime/api-csharp \
		database_url="$$CSHARP_DB_URL"
```

---

## Seviye 3: Production-Ready Yaklaşım

### 🏗️ Mimari

```
Developer Laptop (.env)
    ↓
Git Push (kod, secret'sız)
    ↓
CI/CD Pipeline (GitHub Actions, GitLab CI)
    ↓
CI/CD Secrets (GitHub Secrets, GitLab Variables)
    ↓
Staging Vault (Test ortamı)
    ↓
Manual Approval Gate
    ↓
Production Vault (HA Cluster)
    ↓
Kubernetes Secrets (External Secrets Operator)
    ↓
Application Pods
```

### 🔐 Ortam Bazlı Secret Yönetimi

```makefile
ENVIRONMENT ?= development

vault-setup:
	@case "$(ENVIRONMENT)" in \
		development) \
			make vault-setup-dev ;; \
		staging) \
			make vault-setup-staging ;; \
		production) \
			make vault-setup-prod ;; \
	esac

# Development: .env kullan
vault-setup-dev:
	@source .env && vault kv put secret/dev/app ...

# Staging: CI/CD variables kullan
vault-setup-staging:
	@vault kv put secret/staging/app \
		database_url="$$CI_DB_URL" \
		api_key="$$CI_API_KEY"

# Production: Interactive + Audit
vault-setup-prod:
	@read -sp "DB Password: " DB_PASS && \
	vault kv put secret/prod/app database_url="$$DB_PASS"
	@echo "$$(date) | $$USER | Secret updated" >> audit.log
```

### 📊 Vault Path Separation

```
Vault Root
├── secret/datetime/development/
│   ├── api-csharp/
│   │   ├── database_url: postgresql://dev-user:dev-pass@localhost/dev_db
│   │   └── api_key: dev-key-12345
│   └── api-go/
│
├── secret/datetime/staging/
│   ├── api-csharp/
│   │   ├── database_url: postgresql://staging-user:***@staging-db/db
│   │   └── api_key: staging-key-67890
│   └── api-go/
│
└── secret/datetime/production/
    ├── api-csharp/
    │   ├── database_url: postgresql://prod-user:***@prod-db/db
    │   └── api_key: ***
    └── api-go/
```

### 🔒 RBAC (Role-Based Access Control)

```hcl
# Development: Herkes erişebilir
path "secret/data/datetime/development/*" {
  capabilities = ["read", "list", "create", "update"]
}

# Staging: Sadece CI/CD ve senior devs
path "secret/data/datetime/staging/*" {
  capabilities = ["read", "list"]
}

# Production: Sadece Ops team
path "secret/data/datetime/production/*" {
  capabilities = ["read"]
}
```

### 🔄 Otomatik Secret Rotation

```makefile
vault-rotate-jwt:
	@echo "JWT secret rotating..."
	@NEW_JWT=$$(openssl rand -base64 32)
	@vault kv patch secret/datetime/production/api-csharp \
		jwt_secret="$$NEW_JWT"
	@kubectl rollout restart deployment/datetime-api-csharp
	@echo "$$(date) | JWT rotated" >> audit.log
```

---

## Mevcut Implementasyon

Bu projede **Seviye 1** implementasyonu kullanılmaktadır.

### ✅ Yapılanlar

1. ✅ `.env` dosyası oluşturuldu (mevcut secret değerleriyle)
2. ✅ `.env.example` template oluşturuldu
3. ✅ `.gitignore`'a `.env` eklendi
4. ✅ Makefile `.env`'den okuyacak şekilde güncellendi
5. ✅ Hard-coded secret'lar Makefile'dan kaldırıldı

### 📁 Proje Dosyaları

```
datetime-k8s/
├── .env                          # ← YENİ: Gerçek secret'lar
├── .env.example                  # ← YENİ: Template
├── .gitignore                    # ← GÜNCELLENDİ: .env eklendi
├── Makefile                      # ← GÜNCELLENDİ: .env'den okur
├── vault-keys.json               # ← Vault unseal keys (Git'e commit edilmez)
├── docs/
│   ├── SECRET_MANAGEMENT.md      # ← Bu dosya
│   ├── SECRET_MANAGEMENT.en.md   # ← İngilizce versiyon
│   └── VAULT.md                  # ← Vault detaylı döküman
└── k8s/
    ├── vault-deployment.yaml     # ← Vault pod tanımı
    └── external-secrets.yaml     # ← External Secrets config
```

### 🔐 Secret'ların Akışı

```
1. Developer .env dosyası oluşturur
   ├─ cp .env.example .env
   └─ nano .env  (gerçek değerleri gir)

2. make setup-vault çalıştırır
   ├─ Makefile .env'i okur
   └─ Secret'ları Vault'a yazar

3. External Secrets Operator
   ├─ Vault'tan secret'ları çeker
   └─ Kubernetes Secret oluşturur

4. Application Pod'ları
   ├─ Kubernetes Secret'tan env var olarak alır
   └─ Uygulama çalışır
```

---

## Kullanım Kılavuzu

### 🚀 İlk Kurulum (Yeni Developer)

```bash
# 1. Repo'yu klonla
git clone <repo-url>
cd datetime-k8s

# 2. .env dosyası oluştur
cp .env.example .env

# 3. .env dosyasını düzenle
nano .env
# veya
code .env

# 4. Gerçek secret değerlerini gir
# - Database passwords
# - API keys
# - JWT secrets
# - Redis URLs

# 5. Vault'u kur ve yapılandır
make setup-vault

# 6. Tüm sistemi deploy et
make deploy
```

### 🔄 Mevcut Kullanım

```bash
# Vault'u kur ve secret'ları yaz (.env'den okur)
make setup-vault

# Vault durumunu kontrol et
make vault-status

# Vault'taki secret'ları görüntüle
make vault-secrets

# Deployment yap
make deploy
```

### ✏️ Secret'ları Güncelleme

```bash
# 1. .env dosyasını düzenle
nano .env
# Örnek: CSHARP_DB_URL'i değiştir

# 2. Vault'u güncelle
make vault-setup

# 3. ExternalSecret sync bekle (1 saat) veya force sync
kubectl annotate externalsecret datetime-api-csharp-secrets \
  force-sync=$(date +%s) --overwrite

# 4. Pod'ları restart et (yeni secret'ları alsın)
kubectl rollout restart deployment datetime-api-csharp
```

### 🔍 Secret'ları Doğrulama

```bash
# 1. Vault'ta secret'lar var mı?
ROOT_TOKEN=$(jq -r '.root_token' vault-keys.json)
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN
kubectl exec -n vault vault-0 -- vault kv get secret/datetime/api-csharp

# 2. Kubernetes Secret oluşmuş mu?
kubectl get secret datetime-api-csharp-secrets

# 3. Secret içeriğini görüntüle (base64 decoded)
kubectl get secret datetime-api-csharp-secrets -o json | \
  jq '.data | map_values(@base64d)'

# 4. Pod'lar secret'ları görüyor mu?
kubectl exec deployment/datetime-api-csharp -- env | grep TIMEZONE
```

---

## Troubleshooting

### ❌ Problem: .env dosyası bulunamadı

**Hata:**
```
❌ HATA: .env dosyası bulunamadı!
Lütfen .env.example'ı kopyalayın: cp .env.example .env
```

**Çözüm:**
```bash
cp .env.example .env
nano .env  # Gerçek değerleri gir
```

---

### ❌ Problem: Secret'lar Vault'a yazılmıyor

**Hata:**
```
Error writing data to secret/datetime/api-csharp: permission denied
```

**Çözüm 1: Vault login kontrol**
```bash
ROOT_TOKEN=$(jq -r '.root_token' vault-keys.json)
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN
```

**Çözüm 2: Vault sealed mi?**
```bash
make vault-status
# Sealed: true ise
make vault-unseal
```

**Çözüm 3: Policy kontrol**
```bash
kubectl exec -n vault vault-0 -- vault policy read datetime-app
```

---

### ❌ Problem: .env değişkenleri Makefile'da boş

**Hata:**
```
timezone="" log_level=""  # Boş değerler!
```

**Çözüm 1: .env export edilmiş mi?**
```makefile
# Makefile başında olmalı
-include .env
export
```

**Çözüm 2: Variable syntax doğru mu?**
```makefile
# YANLIŞ
timezone="$CSHARP_TIMEZONE"  # Tek $ kullan Makefile'da

# DOĞRU
timezone="$$CSHARP_TIMEZONE"  # Çift $$ kullan shell komutlarında
```

**Çözüm 3: Manuel test**
```bash
source .env
echo $CSHARP_TIMEZONE  # Değer görünmeli
```

---

### ❌ Problem: Git .env dosyasını commit etmeye çalışıyor

**Hata:**
```bash
git add .
# .env dosyası stage'e ekleniyor!
```

**Çözüm 1: .gitignore kontrol**
```bash
cat .gitignore | grep ".env"
# .env olmalı
```

**Çözüm 2: Git cache temizle**
```bash
git rm --cached .env
git commit -m "Remove .env from git"
```

**Çözüm 3: .gitignore'ı commit et**
```bash
git add .gitignore
git commit -m "Add .env to .gitignore"
```

---

### ❌ Problem: ExternalSecret sync olmuyor

**Hata:**
```bash
kubectl get externalsecret
# STATUS: SecretSyncedError
```

**Çözüm 1: Secret path kontrolü**
```bash
# Vault'ta secret var mı?
kubectl exec -n vault vault-0 -- vault kv get secret/datetime/api-csharp
```

**Çözüm 2: SecretStore kontrol**
```bash
kubectl describe secretstore vault-backend
# Status: Valid olmalı
```

**Çözüm 3: Force sync**
```bash
kubectl annotate externalsecret datetime-api-csharp-secrets \
  force-sync=$(date +%s) --overwrite
```

**Çözüm 4: External Secrets Operator log**
```bash
kubectl logs -n external-secrets deployment/external-secrets
```

---

## Güvenlik Kontrol Listesi

### ✅ Commit Öncesi

- [ ] `.env` dosyası `.gitignore`'da mı?
- [ ] `vault-keys.json` `.gitignore`'da mı?
- [ ] Hard-coded secret yok mu? (Makefile, YAML, kod)
- [ ] `.env.example` güncel mi?
- [ ] Gerçek değerler `.env.example`'da yok mu?

### ✅ Vault Güvenliği

- [ ] Vault sealed durumda değil mi?
- [ ] Root token güvenli mi? (vault-keys.json chmod 600)
- [ ] Policy'ler least privilege prensibi uyguluyor mu?
- [ ] Audit logging aktif mi?
- [ ] Her API kendi secret'ına erişiyor mu?

### ✅ Kubernetes Güvenliği

- [ ] ServiceAccount datetime-app oluşturulmuş mu?
- [ ] RBAC doğru yapılandırılmış mı?
- [ ] ExternalSecret doğru SecretStore kullanıyor mu?
- [ ] Secret refresh interval uygun mu? (default: 1h)
- [ ] Pod'lar doğru secret'ları kullanıyor mu?

### ✅ Production Hazırlığı

- [ ] Farklı ortamlar için farklı secret'lar var mı?
- [ ] Secret rotation planı var mı?
- [ ] Backup stratejisi var mı?
- [ ] Disaster recovery planı var mı?
- [ ] Incident response planı var mı?

---

## Karşılaştırma Tablosu

| Özellik | Seviye 1 (.env) | Seviye 2 (YAML) | Seviye 3 (Production) |
|---------|-----------------|-----------------|----------------------|
| **Basitlik** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Güvenlik** | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Ortam Ayrımı** | ❌ | ⚠️ Kısmi | ✅ Tam |
| **CI/CD Entegrasyonu** | ⚠️ Manuel | ⚠️ Manuel | ✅ Otomatik |
| **Audit Logging** | ❌ | ❌ | ✅ |
| **Secret Rotation** | ⚠️ Manuel | ⚠️ Manuel | ✅ Otomatik |
| **Access Control** | ❌ | ❌ | ✅ RBAC |
| **Kurulum Süresi** | 5 dakika | 10 dakika | 2-3 saat |
| **Bakım Maliyeti** | Düşük | Orta | Yüksek |
| **Önerilen Ortam** | Development | Development/Staging | Production |

---

## Kaynaklar

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [External Secrets Operator](https://external-secrets.io/)
- [Kubernetes Secrets Best Practices](https://kubernetes.io/docs/concepts/security/secrets-good-practices/)
- [12-Factor App: Config](https://12factor.net/config)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

---

## Özet

✅ Bu projede **Seviye 1 (.env dosyası)** yaklaşımı kullanılmaktadır.

✅ Secret'lar `.env` dosyasında saklanır ve **Git'e commit edilmez**.

✅ Makefile `.env`'den okur ve Vault'a yazar.

✅ Vault secret'ları External Secrets Operator ile Kubernetes Secret'a dönüştürür.

✅ Application pod'ları environment variable olarak secret'ları alır.

🔒 **Best practice uygulanmıştır!**

---

**Son Güncelleme:** 2025-11-09
**Versiyon:** 1.0
