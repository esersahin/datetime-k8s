# HashiCorp Vault Entegrasyonu

## 📋 İçindekiler

- [Genel Bakış](#genel-bakış)
- [Mimari](#mimari)
- [Bileşenler](#bileşenler)
- [Kurulum](#kurulum)
- [Vault Yapılandırması](#vault-yapılandırması)
- [Secret Yönetimi](#secret-yönetimi)
- [Makefile Komutları](#makefile-komutları)
- [Güvenlik](#güvenlik)
- [Troubleshooting](#troubleshooting)

---

## Genel Bakış

Bu proje, hassas bilgileri (secrets) güvenli bir şekilde yönetmek için **HashiCorp Vault** ve **External Secrets Operator** kullanır.

### Neden Vault?

**Sorun:**
- Kubernetes Secret'ları base64 ile kodlanır (şifrelenmez!)
- Git'e commit edilen secret'lar güvenlik riski oluşturur
- Secret rotation ve audit logging zordur
- Merkezi secret yönetimi yoktur

**Çözüm: HashiCorp Vault**
- ✅ Secret'ları şifreler ve merkezi bir yerde saklar
- ✅ Fine-grained access control (RBAC)
- ✅ Audit logging (kim, ne zaman, hangi secret'a erişti)
- ✅ Dynamic secrets ve automatic rotation
- ✅ Kubernetes native authentication

---

## Mimari

```
┌───────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                     │
│                                                           │
│  ┌──────────────────┐        ┌─────────────────────┐      │
│  │   Vault Pod      │◄───────│  External Secrets   │      │
│  │  (vault ns)      │        │    Operator         │      │
│  │                  │        │  (external-secrets) │      │
│  │  - KV v2 Engine  │        └─────────────────────┘      │
│  │  - K8s Auth      │                 │                   │
│  │  - Policies      │                 │                   │
│  └──────────────────┘                 │                   │
│          │                             ▼                  │
│          │                  ┌─────────────────────┐       │
│          │                  │  ExternalSecret CRD │       │
│          │                  │  (datetime-api)     │       │
│          │                  └─────────────────────┘       │
│          │                             │                  │
│          │                             ▼                  │
│          │                  ┌─────────────────────┐       │
│          │                  │  Kubernetes Secret  │       │
│          │                  │  (auto-created)     │       │
│          │                  └─────────────────────┘       │
│          │                             │                  │
│          │                             │                  │
│          ▼                             ▼                  │
│  ┌───────────────────────────────────────────────┐        │
│  │         Application Pods                      │        │
│  │  ┌──────────────┐  ┌──────────────┐           │        │
│  │  │ C# API Pod   │  │ Go API Pod   │           │        │
│  │  │ (env vars)   │  │ (env vars)   │           │        │
│  │  └──────────────┘  └──────────────┘           │        │
│  │   ServiceAccount: datetime-app                │        │
│  └───────────────────────────────────────────────┘        │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### Akış

1. **Vault Init**: Vault başlatılır ve unseal keys + root token oluşturulur
2. **Vault Unseal**: Vault 3/5 unseal key ile açılır
3. **Auth Setup**: Kubernetes auth method yapılandırılır
4. **Policy Creation**: Her API için ayrı policy oluşturulur (`api-csharp-policy`, `api-go-policy`)
5. **Secret Storage**: Her API için ayrı secret path'ler oluşturulur (`secret/datetime/api-csharp`, `secret/datetime/api-go`)
6. **External Secrets Operator**: SecretStore ve her API için ayrı ExternalSecret CRD'leri oluşturulur
7. **Sync**: Operator, Vault'tan her API için ayrı secret'ları çeker ve Kubernetes Secret oluşturur
8. **Injection**: Pod'lar kendi secret'larını environment variable olarak alır

---

## Bileşenler

### 1. vault-deployment.yaml

Bu dosya Vault'un Kubernetes üzerinde çalışması için gerekli tüm kaynakları içerir.

#### Namespace
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: vault
```
**Açıklama**: Vault için ayrı bir namespace oluşturur (izolasyon).

---

#### ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: vault
data:
  vault.json: |
    {
      "listener": [{
        "tcp": {
          "address": "0.0.0.0:8200",
          "tls_disable": true
        }
      }],
      "storage": {
        "file": {
          "path": "/vault/data"
        }
      },
      "ui": true,
      "log_level": "info"
    }
```

**Açıklama**:
- **listener.tcp.address**: Vault API'nin dinlediği adres (0.0.0.0:8200)
- **listener.tcp.tls_disable**: TLS kapalı (dev/test ortamı için, production'da `false` olmalı!)
- **storage.file**: File-based storage backend (production'da Consul/etcd kullanılmalı)
- **ui**: Web UI aktif (http://localhost:8200/ui)
- **log_level**: Log seviyesi (`info`)

---

#### PersistentVolumeClaim
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: vault-data
  namespace: vault
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

**Açıklama**:
- Vault data persistence için 1GB disk alanı
- `ReadWriteOnce`: Tek bir node'a mount edilebilir
- Pod restart olsa bile data kaybolmaz

---

#### StatefulSet
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: vault
  namespace: vault
spec:
  serviceName: vault
  replicas: 1
  selector:
    matchLabels:
      app: vault
  template:
    spec:
      containers:
        - name: vault
          image: hashicorp/vault:1.15
          ports:
            - name: http
              containerPort: 8200
            - name: internal
              containerPort: 8201
          env:
            - name: VAULT_ADDR
              value: "http://127.0.0.1:8200"
            - name: VAULT_API_ADDR
              value: "http://vault.vault.svc.cluster.local:8200"
          args:
            - server
            - -config=/vault/config/vault.json
          volumeMounts:
            - name: vault-config
              mountPath: /vault/config
            - name: vault-data
              mountPath: /vault/data
```

**Açıklama**:
- **StatefulSet**: Stable network identity ve persistent storage için
- **replicas: 1**: Single instance (HA için 3-5 olmalı)
- **image**: Vault 1.15 official image
- **ports**:
  - `8200`: HTTP API
  - `8201`: Internal cluster communication
- **VAULT_ADDR**: Vault CLI için local address
- **VAULT_API_ADDR**: Cluster'daki diğer pod'ların erişeceği address
- **volumeMounts**:
  - Config dosyası
  - Data persistence

---

#### Probes
```yaml
livenessProbe:
  httpGet:
    path: /v1/sys/health?standbyok=true
    port: 8200
  initialDelaySeconds: 30
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /v1/sys/health?standbyok=true&perfstandbyok=true
    port: 8200
  initialDelaySeconds: 10
  periodSeconds: 5
```

**Açıklama**:
- **livenessProbe**: Pod'un canlı olup olmadığını kontrol eder
- **readinessProbe**: Pod'un trafiği kabul etmeye hazır olup olmadığını kontrol eder
- **standbyok=true**: Standby mode'daki Vault'u da healthy say
- **perfstandbyok=true**: Performance standby'ı da healthy say

---

#### Resources
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

**Açıklama**:
- **requests**: Minimum kaynak garantisi
- **limits**: Maksimum kaynak kullanımı
- Vault hafif bir uygulama, bu değerler yeterli

---

#### Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: vault
  namespace: vault
spec:
  type: ClusterIP
  ports:
    - name: http
      port: 8200
      targetPort: 8200
    - name: internal
      port: 8201
      targetPort: 8201
  selector:
    app: vault
```

**Açıklama**:
- **ClusterIP**: Cluster içinden erişilebilir
- **DNS**: `vault.vault.svc.cluster.local`
- **Port 8200**: API access
- **Port 8201**: Cluster communication

---

#### ServiceAccount & RBAC
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault
  namespace: vault
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-server-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: vault
    namespace: vault
```

**Açıklama**:
- **ServiceAccount**: Vault pod'unun Kubernetes API'sine erişmesi için
- **ClusterRoleBinding**: `system:auth-delegator` rolü verir
- **system:auth-delegator**: TokenReview API'sine erişim (Kubernetes auth için gerekli)

---

### 2. external-secrets.yaml

Bu dosya External Secrets Operator'ın Vault'tan secret'ları nasıl çekeceğini tanımlar.

#### SecretStore
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: default
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "datetime-app"
          serviceAccountRef:
            name: "datetime-app"
```

**Açıklama**:
- **SecretStore**: Vault connection bilgilerini tutar
- **server**: Vault'un cluster içindeki adresi
- **path**: KV secrets engine path (`secret`)
- **version**: KV v2 (versioning ve metadata desteği)
- **auth.kubernetes**: Kubernetes auth method kullan
  - **mountPath**: Vault'taki auth path (`kubernetes`)
  - **role**: Vault role adı (`datetime-app`)
  - **serviceAccountRef**: Hangi ServiceAccount ile auth yapılacak

---

#### ExternalSecret - C# API Secrets
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: datetime-api-csharp-secrets
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: datetime-api-csharp-secrets
    creationPolicy: Owner
  data:
    - secretKey: TIMEZONE
      remoteRef:
        key: datetime/api-csharp
        property: timezone
    - secretKey: LOG_LEVEL
      remoteRef:
        key: datetime/api-csharp
        property: log_level
    - secretKey: DATABASE_URL
      remoteRef:
        key: datetime/api-csharp
        property: database_url
    - secretKey: API_KEY
      remoteRef:
        key: datetime/api-csharp
        property: api_key
    - secretKey: JWT_SECRET
      remoteRef:
        key: datetime/api-csharp
        property: jwt_secret
    - secretKey: REDIS_URL
      remoteRef:
        key: datetime/api-csharp
        property: redis_url
```

**Açıklama**:
- **ExternalSecret**: Vault'tan C# API secret'ları çeker ve Kubernetes Secret oluşturur
- **refreshInterval**: 1 saatte bir sync yap (secret rotation için)
- **secretStoreRef**: Hangi SecretStore kullanılacak
- **target.name**: Oluşturulacak Kubernetes Secret'ın adı
- **target.creationPolicy**: `Owner` (ExternalSecret silinince Secret de silinir)
- **data**: Vault'tan hangi secret'lar çekilecek
  - **secretKey**: Kubernetes Secret'taki key adı (env var adı)
  - **remoteRef.key**: Vault'taki path (`secret/data/datetime/api-csharp`)
  - **remoteRef.property**: Vault secret içindeki field adı

**Vault'ta bu şekilde saklanır (C# API):**
```
secret/data/datetime/api-csharp:
  timezone: "Europe/Istanbul"
  log_level: "debug"
  database_url: "postgresql://csharp-user:pass123@postgres:5432/csharp_db"
  api_key: "csharp-api-key-12345"
  jwt_secret: "csharp-jwt-secret-67890"
  redis_url: "redis://redis:6379/0"
```

**Kubernetes Secret'a şu şekilde dönüşür:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: datetime-api-csharp-secrets
data:
  TIMEZONE: RXVyb3BlL0lzdGFuYnVs  # base64
  LOG_LEVEL: ZGVidWc=
  DATABASE_URL: cG9zdGdyZXNxbC8vY3NoYXJwLXVzZXI6...  # base64
  API_KEY: Y3NoYXJwLWFwaS1rZXktMTIzNDU=
  JWT_SECRET: Y3NoYXJwLWp3dC1zZWNyZXQtNjc4OTA=
  REDIS_URL: cmVkaXM6Ly9yZWRpczo2Mzc5LzA=
```

---

#### ExternalSecret - Go API Secrets
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: datetime-api-go-secrets
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: datetime-api-go-secrets
    creationPolicy: Owner
  data:
    - secretKey: TIMEZONE
      remoteRef:
        key: datetime/api-go
        property: timezone
    - secretKey: LOG_LEVEL
      remoteRef:
        key: datetime/api-go
        property: log_level
    - secretKey: DATABASE_URL
      remoteRef:
        key: datetime/api-go
        property: database_url
    - secretKey: API_KEY
      remoteRef:
        key: datetime/api-go
        property: api_key
    - secretKey: JWT_SECRET
      remoteRef:
        key: datetime/api-go
        property: jwt_secret
    - secretKey: REDIS_URL
      remoteRef:
        key: datetime/api-go
        property: redis_url
```

**Açıklama**:
- **Go API secrets**: Her API'nin kendi bağımsız secret'ları var (güvenlik ve izolasyon için)
- **Farklı değerler**: Go API'nin timezone="UTC", log_level="info", farklı database user/pass vb.
- **Least privilege prensibi**: Her API sadece kendi ihtiyaç duyduğu secret'lara erişir

**Vault'ta bu şekilde saklanır (Go API):**
```
secret/data/datetime/api-go:
  timezone: "UTC"
  log_level: "info"
  database_url: "postgresql://go-user:pass456@postgres:5432/go_db"
  api_key: "go-api-key-98765"
  jwt_secret: "go-jwt-secret-54321"
  redis_url: "redis://redis:6379/1"
```

**Önemli**: C# API ve Go API'nin secret'ları **tamamen bağımsız** ve **farklı değerlere** sahip!

---

### 3. Application Deployment

#### C# API Deployment (api-csharp-deployment.yaml)

```yaml
spec:
  template:
    spec:
      serviceAccountName: datetime-app  # Vault auth için gerekli
      containers:
        - name: api
          env:
            # C# API'ye özel secret'lar
            - name: TZ
              valueFrom:
                secretKeyRef:
                  name: datetime-api-csharp-secrets
                  key: TIMEZONE
            - name: LOG_LEVEL
              valueFrom:
                secretKeyRef:
                  name: datetime-api-csharp-secrets
                  key: LOG_LEVEL
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: datetime-api-csharp-secrets
                  key: DATABASE_URL
            - name: API_KEY
              valueFrom:
                secretKeyRef:
                  name: datetime-api-csharp-secrets
                  key: API_KEY
```

**Açıklama**:
- **serviceAccountName**: Vault auth için `datetime-app` ServiceAccount kullanılır
- **datetime-api-csharp-secrets**: C# API'nin **kendi bağımsız** secret'ı
- **env.valueFrom.secretKeyRef**: Kubernetes Secret'tan env var olarak inject edilir
- Pod restart olmadan secret güncellenmez (rotation için restart gerekir)

---

#### Go API Deployment (api-go-deployment.yaml)

```yaml
spec:
  template:
    spec:
      serviceAccountName: datetime-app  # Vault auth için gerekli
      containers:
        - name: api
          env:
            # Go API'ye özel secret'lar
            - name: TZ
              valueFrom:
                secretKeyRef:
                  name: datetime-api-go-secrets
                  key: TIMEZONE
            - name: LOG_LEVEL
              valueFrom:
                secretKeyRef:
                  name: datetime-api-go-secrets
                  key: LOG_LEVEL
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: datetime-api-go-secrets
                  key: DATABASE_URL
            - name: API_KEY
              valueFrom:
                secretKeyRef:
                  name: datetime-api-go-secrets
                  key: API_KEY
```

**Açıklama**:
- **datetime-api-go-secrets**: Go API'nin **kendi bağımsız** secret'ı
- **Farklı değerler**: Go API Europe/Istanbul yerine UTC timezone kullanır
- **İzolasyon**: Her API sadece kendi secret'ına erişir (least privilege)

---

## Kurulum

### 1. Otomatik Kurulum (Önerilen)

```bash
# Tüm sistemi deploy et (Vault dahil)
make deploy
```

Bu komut sırasıyla şunları yapar:
1. Kind cluster oluşturur
2. Ingress controller kurar
3. Docker imajlarını build eder ve yükler
4. **Vault'u kurar ve yapılandırır** (setup-vault)
5. Kubernetes kaynaklarını deploy eder
6. HAProxy load balancer'ı kurar
7. `/etc/hosts` dosyasını günceller

---

### 2. Manuel Kurulum

```bash
# 1. Vault'u kur
make install-vault

# 2. Vault'u initialize et (unseal keys oluşturur)
make vault-init

# 3. Vault'u unseal et
make vault-unseal

# 4. Vault'u yapılandır (auth, policy, secrets)
make vault-setup

# 5. External Secrets Operator'ı kur
make install-external-secrets

# 6. ExternalSecret'ları deploy et
kubectl apply -f k8s/external-secrets.yaml

# 7. Application'ları deploy et
kubectl apply -f k8s/api-csharp-deployment.yaml
kubectl apply -f k8s/api-go-deployment.yaml
```

---

## Vault Yapılandırması

### Vault Init Süreci

```bash
make vault-init
```

Bu komut:
1. Vault pod'una bağlanır
2. `vault operator init` çalıştırır
3. 5 adet unseal key oluşturur (threshold: 3)
4. Root token oluşturur
5. Tüm bilgileri `vault-keys.json` dosyasına kaydeder

**vault-keys.json içeriği:**
```json
{
  "unseal_keys_b64": [
    "key1...",
    "key2...",
    "key3...",
    "key4...",
    "key5..."
  ],
  "root_token": "hvs.xxxxxxxxxxxxx"
}
```

⚠️ **ÇOK ÖNEMLİ**: Bu dosya GIT'e commit edilmemeli! (`.gitignore`'da var)

---

### Vault Unseal Süreci

Vault başladığında "sealed" (mühürlü) durumda olur. Unsealing, encryption key'i unlock eder.

```bash
make vault-unseal
```

Bu komut:
1. `vault-keys.json` dosyasını okur
2. 3 adet unseal key kullanarak Vault'u açar (threshold: 3/5)
3. Vault artık secret'ları okuyup yazabilir duruma gelir

**Shamir's Secret Sharing**:
- Total keys: 5
- Threshold: 3
- Herhangi 3 key ile vault açılabilir
- Tek kişi vault'u açamaz (security)

---

### Vault Setup Süreci

```bash
make vault-setup
```

Bu komut şunları yapar:

#### 1. Vault'a Login
```bash
vault login <root_token>
```

#### 2. Kubernetes Auth Enable
```bash
vault auth enable kubernetes
```

#### 3. Kubernetes Auth Yapılandırma
```bash
vault write auth/kubernetes/config \
  token_reviewer_jwt="<sa_token>" \
  kubernetes_host="https://kubernetes.default.svc" \
  kubernetes_ca_cert="<ca_cert>"
```

**Açıklama**:
- **token_reviewer_jwt**: Vault'un ServiceAccount token'ı
- **kubernetes_host**: Kubernetes API server adresi
- **kubernetes_ca_cert**: Cluster CA certificate

#### 4. KV Secrets Engine Enable
```bash
vault secrets enable -path=secret kv-v2
```

**Açıklama**:
- KV v2: Versioning ve metadata desteği
- Path: `secret/`

#### 5. Policy Oluşturma

Her API için ayrı policy oluşturulur (least privilege prensibi):

**C# API Policy:**
```bash
vault policy write api-csharp-policy - <<EOF
path "secret/data/datetime/api-csharp" {
  capabilities = ["read", "list"]
}
path "secret/metadata/datetime/api-csharp" {
  capabilities = ["read", "list"]
}
EOF
```

**Go API Policy:**
```bash
vault policy write api-go-policy - <<EOF
path "secret/data/datetime/api-go" {
  capabilities = ["read", "list"]
}
path "secret/metadata/datetime/api-go" {
  capabilities = ["read", "list"]
}
EOF
```

**Genel Policy (backward compatibility için):**
```bash
vault policy write datetime-app - <<EOF
path "secret/data/datetime/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/datetime/*" {
  capabilities = ["read", "list"]
}
EOF
```

**Açıklama**:
- Her API **sadece kendi secret'ına** erişebilir
- **api-csharp-policy**: Sadece `secret/data/datetime/api-csharp` erişimi
- **api-go-policy**: Sadece `secret/data/datetime/api-go` erişimi
- **datetime-app**: Tüm datetime secret'larına erişim (External Secrets Operator için)
- **Capabilities**: `read`, `list` (read-only)

#### 6. Service Account Oluşturma
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: datetime-app
  namespace: default
EOF
```

#### 7. Kubernetes Auth Role Oluşturma
```bash
vault write auth/kubernetes/role/datetime-app \
  bound_service_account_names=datetime-app \
  bound_service_account_namespaces=default \
  policies=datetime-app \
  ttl=24h
```

**Açıklama**:
- **Role**: `datetime-app`
- **bound_service_account_names**: Sadece `datetime-app` SA ile auth
- **bound_service_account_namespaces**: Sadece `default` namespace
- **policies**: `datetime-app` policy uygula
- **ttl**: Token 24 saat geçerli

#### 8. Örnek Secret'lar Oluşturma

Her API için **tamamen bağımsız** ve **farklı değerlere sahip** secret'lar oluşturulur:

**C# API Secrets:**
```bash
vault kv put secret/datetime/api-csharp \
  timezone="Europe/Istanbul" \
  log_level="debug" \
  database_url="postgresql://csharp-user:csharp-pass123@postgres:5432/csharp_db" \
  api_key="csharp-api-key-12345" \
  jwt_secret="csharp-jwt-secret-67890" \
  redis_url="redis://redis:6379/0"
```

**Go API Secrets:**
```bash
vault kv put secret/datetime/api-go \
  timezone="UTC" \
  log_level="info" \
  database_url="postgresql://go-user:go-pass456@postgres:5432/go_db" \
  api_key="go-api-key-98765" \
  jwt_secret="go-jwt-secret-54321" \
  redis_url="redis://redis:6379/1"
```

**Önemli Noktalar:**
- **Artık "common" secret path'i YOK!**
- Her API'nin **timezone** ve **log_level** değerleri kendi secret'ında
- C# API: `timezone="Europe/Istanbul"`, `log_level="debug"`
- Go API: `timezone="UTC"`, `log_level="info"`
- Her API farklı database user/pass kullanır (güvenlik)
- Her API farklı redis database index kullanır (izolasyon)

---

## Secret Yönetimi

### Secret Okuma

Her API'nin secret'larını ayrı ayrı okuyabilirsiniz:

**C# API secret'larını oku:**
```bash
# Root token ile login
ROOT_TOKEN=$(jq -r '.root_token' vault-keys.json)
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN

# C# API secret'ları
kubectl exec -n vault vault-0 -- vault kv get secret/datetime/api-csharp
```

**Çıktı:**
```
====== Data ======
Key            Value
---            -----
timezone       Europe/Istanbul
log_level      debug
api_key        csharp-api-key-12345
database_url   postgresql://csharp-user:csharp-pass123@postgres:5432/csharp_db
jwt_secret     csharp-jwt-secret-67890
redis_url      redis://redis:6379/0
```

**Go API secret'larını oku:**
```bash
kubectl exec -n vault vault-0 -- vault kv get secret/datetime/api-go
```

**Çıktı:**
```
====== Data ======
Key            Value
---            -----
timezone       UTC
log_level      info
api_key        go-api-key-98765
database_url   postgresql://go-user:go-pass456@postgres:5432/go_db
jwt_secret     go-jwt-secret-54321
redis_url      redis://redis:6379/1
```

---

### Secret Yazma/Güncelleme

Her API'nin secret'larını **bağımsız olarak** güncelleyebilirsiniz:

**C# API secret'larını güncelle:**
```bash
# Tüm secret'ları güncelle
kubectl exec -n vault vault-0 -- vault kv put secret/datetime/api-csharp \
  timezone="Europe/Istanbul" \
  log_level="info" \
  database_url="postgresql://csharp-user:new-pass@postgres:5432/csharp_db" \
  api_key="new-csharp-api-key"

# Sadece bir field'ı güncelle (patch)
kubectl exec -n vault vault-0 -- vault kv patch secret/datetime/api-csharp \
  log_level="warn"
```

**Go API secret'larını güncelle:**
```bash
# Sadece Go API'nin timezone'unu değiştir
kubectl exec -n vault vault-0 -- vault kv patch secret/datetime/api-go \
  timezone="Europe/London"
```

---

### Secret Versioning

**C# API secret versioning:**
```bash
# Tüm versiyonları listele
kubectl exec -n vault vault-0 -- vault kv metadata get secret/datetime/api-csharp

# Belirli bir versiyonu oku
kubectl exec -n vault vault-0 -- vault kv get -version=2 secret/datetime/api-csharp

# Eski versiyona rollback
kubectl exec -n vault vault-0 -- vault kv rollback -version=1 secret/datetime/api-csharp
```

**Go API secret versioning:**
```bash
# Go API versiyonları
kubectl exec -n vault vault-0 -- vault kv metadata get secret/datetime/api-go
kubectl exec -n vault vault-0 -- vault kv get -version=2 secret/datetime/api-go
```

---

### Secret Silme

**C# API secret'larını sil:**
```bash
# Son versiyonu soft delete (geri alınabilir)
kubectl exec -n vault vault-0 -- vault kv delete secret/datetime/api-csharp

# Belirli bir versiyonu sil
kubectl exec -n vault vault-0 -- vault kv delete -versions=2 secret/datetime/api-csharp

# Tamamen sil (KALICI!)
kubectl exec -n vault vault-0 -- vault kv metadata delete secret/datetime/api-csharp
```

**Go API secret'larını sil:**
```bash
kubectl exec -n vault vault-0 -- vault kv delete secret/datetime/api-go
```

---

### Tüm Secret'ları Listeleme

```bash
# Datetime altındaki tüm secret path'leri
kubectl exec -n vault vault-0 -- vault kv list secret/datetime

# Çıktı:
# Keys
# ----
# api-csharp
# api-go
```

---

## Makefile Komutları

### Vault Kurulum Komutları

| Komut | Açıklama |
|-------|----------|
| `make install-vault` | Vault'u Kubernetes'e deploy eder |
| `make vault-init` | Vault'u initialize eder (unseal keys oluşturur) |
| `make vault-unseal` | Vault'u unseal eder (açar) |
| `make vault-setup` | Vault'u tam yapılandırır (auth + policy + secrets) |
| `make setup-vault` | **ANA KOMUT** (tümünü yapar) |

### Vault Yönetim Komutları

| Komut | Açıklama |
|-------|----------|
| `make vault-status` | Vault durumunu gösterir |
| `make vault-ui` | Vault UI için port-forward açar (http://localhost:8200/ui) |
| `make vault-secrets` | Vault'taki secret'ları listeler |
| `make clean-vault` | Vault'u tamamen kaldırır |

### External Secrets Komutları

| Komut | Açıklama |
|-------|----------|
| `make install-external-secrets` | External Secrets Operator'ı kurar (Helm) |

### Kullanım Örnekleri

```bash
# Vault kurulumu ve yapılandırma
make setup-vault

# Vault durumunu kontrol et
make vault-status

# Vault UI'a eriş
make vault-ui
# Browser'da aç: http://localhost:8200/ui
# Token: jq -r '.root_token' vault-keys.json

# Secret'ları görüntüle
make vault-secrets

# Vault'u temizle
make clean-vault
```

---

## Güvenlik

### 1. vault-keys.json Güvenliği

⚠️ **KRİTİK**: `vault-keys.json` dosyası hassas bilgiler içerir!

**İçerik**:
- 5 adet unseal key
- Root token

**Güvenlik Önlemleri**:
```bash
# Dosya izinleri (sadece owner okuyabilir)
chmod 600 vault-keys.json

# .gitignore'da var (Git'e commit edilmez)
echo "vault-keys.json" >> .gitignore

# Production'da external KMS kullan
# - AWS KMS
# - Azure Key Vault
# - GCP Cloud KMS
```

**Production Önerisi**:
```bash
# AWS KMS ile auto-unseal
vault.json:
{
  "seal": {
    "awskms": {
      "region": "us-west-2",
      "kms_key_id": "alias/vault-kms-unseal"
    }
  }
}
```

---

### 2. TLS/HTTPS

⚠️ **Mevcut Durum**: TLS kapalı (`tls_disable: true`)

**Production için**:
```yaml
# vault-config ConfigMap
data:
  vault.json: |
    {
      "listener": [{
        "tcp": {
          "address": "0.0.0.0:8200",
          "tls_disable": false,
          "tls_cert_file": "/vault/tls/tls.crt",
          "tls_key_file": "/vault/tls/tls.key"
        }
      }]
    }
```

```bash
# TLS certificate oluştur (cert-manager ile)
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: vault-tls
  namespace: vault
spec:
  secretName: vault-tls
  issuer Ref:
    name: letsencrypt-prod
  dnsNames:
    - vault.example.com
EOF
```

---

### 3. RBAC ve Least Privilege

**ServiceAccount izinleri**:
```yaml
# datetime-app ServiceAccount'un tüm datetime secret'larına erişimi var
vault policy write datetime-app - <<EOF
path "secret/data/datetime/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/datetime/*" {
  capabilities = ["read", "list"]
}
EOF
```

**API-specific policies (opsiyonel, daha sıkı güvenlik için)**:
```yaml
# C# API sadece kendi secret'ına erişebilir
vault policy write api-csharp-policy - <<EOF
path "secret/data/datetime/api-csharp" {
  capabilities = ["read", "list"]
}
path "secret/metadata/datetime/api-csharp" {
  capabilities = ["read", "list"]
}
EOF

# Go API sadece kendi secret'ına erişebilir
vault policy write api-go-policy - <<EOF
path "secret/data/datetime/api-go" {
  capabilities = ["read", "list"]
}
path "secret/metadata/datetime/api-go" {
  capabilities = ["read", "list"]
}
EOF
```

**Developer access**:
```yaml
# Developer'lar sadece okuyabilir
vault policy write developer - <<EOF
path "secret/data/datetime/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/datetime/*" {
  capabilities = ["read", "list"]
}
EOF
```

**Admin access**:
```yaml
# Admin'ler her şeyi yapabilir
vault policy write admin - <<EOF
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF
```

**Least Privilege Prensibi**:
- Her API **kendi secret'ına** erişir: `api-csharp` → `secret/datetime/api-csharp`
- Artık **common secret yok**, her API'nin timezone ve log_level'ı kendi secret'ında
- External Secrets Operator: Tüm API secret'larını okuyabilir (`datetime-app` policy)
- Production'da API-specific ServiceAccount'lar kullanılabilir (daha sıkı izolasyon)

---

### 4. Audit Logging

```bash
# Audit logging enable et
kubectl exec -n vault vault-0 -- vault audit enable file \
  file_path=/vault/logs/audit.log

# Audit log'ları incele
kubectl exec -n vault vault-0 -- cat /vault/logs/audit.log | jq .
```

**Audit log örneği**:
```json
{
  "time": "2024-01-15T10:30:00Z",
  "type": "request",
  "auth": {
    "client_token": "hvs.xxx",
    "accessor": "hmac-sha256:xxx",
    "display_name": "kubernetes-datetime-app"
  },
  "request": {
    "path": "secret/data/datetime/api",
    "operation": "read"
  }
}
```

---

### 5. Secret Rotation

**Manuel rotation - C# API:**
```bash
# 1. Vault'ta C# API secret'ı güncelle
kubectl exec -n vault vault-0 -- vault kv patch secret/datetime/api-csharp \
  database_url="postgresql://csharp-user:new-pass@postgres:5432/csharp_db"

# 2. ExternalSecret sync bekle (1 saat) veya force sync
kubectl annotate externalsecret datetime-api-csharp-secrets \
  force-sync=$(date +%s) --overwrite

# 3. Sadece C# API pod'larını restart et
kubectl rollout restart deployment datetime-api-csharp
```

**Manuel rotation - Go API:**
```bash
# 1. Vault'ta Go API secret'ı güncelle
kubectl exec -n vault vault-0 -- vault kv patch secret/datetime/api-go \
  database_url="postgresql://go-user:new-pass@postgres:5432/go_db"

# 2. ExternalSecret sync bekle (1 saat) veya force sync
kubectl annotate externalsecret datetime-api-go-secrets \
  force-sync=$(date +%s) --overwrite

# 3. Sadece Go API pod'larını restart et
kubectl rollout restart deployment datetime-api-go
```

**Önemli**: Her API'nin secret'ı **bağımsız** olarak rotate edilir. Bir API'nin secret'ı değiştiğinde diğer API etkilenmez!

**Otomatik rotation** (gelecekte):
- Dynamic secrets kullan
- Vault Agent Injector ile sidecar pattern
- Secret refresh without pod restart

---

## Troubleshooting

### 1. Vault Pod Başlamıyor

**Semptom**:
```bash
kubectl get pods -n vault
NAME      READY   STATUS             RESTARTS   AGE
vault-0   0/1     CrashLoopBackOff   5          5m
```

**Çözüm 1: Log kontrol**:
```bash
kubectl logs -n vault vault-0
```

**Çözüm 2: PVC kontrol**:
```bash
kubectl get pvc -n vault
# PVC "Pending" ise storage class sorunu olabilir
```

**Çözüm 3: ConfigMap kontrol**:
```bash
kubectl get cm -n vault vault-config -o yaml
# JSON syntax hatası var mı?
```

---

### 2. Vault Sealed Durumda

**Semptom**:
```bash
make vault-status
# Output: "Sealed: true"
```

**Çözüm**:
```bash
# Unseal et
make vault-unseal

# vault-keys.json yoksa yeniden init et (DATA KAYBEDİLİR!)
make vault-init
```

---

### 3. External Secrets Sync Olmuyor

**Semptom**:
```bash
kubectl get externalsecret
NAME                           STORE           REFRESH INTERVAL   STATUS
datetime-api-csharp-secrets    vault-backend   1h                 SecretSyncedError
datetime-api-go-secrets        vault-backend   1h                 SecretSyncedError
```

**Çözüm 1: ExternalSecret describe**:
```bash
# C# API ExternalSecret kontrol
kubectl describe externalsecret datetime-api-csharp-secrets
# Events kısmına bak

# Go API ExternalSecret kontrol
kubectl describe externalsecret datetime-api-go-secrets
```

**Çözüm 2: SecretStore test**:
```bash
kubectl get secretstore vault-backend -o yaml
# Status kısmını kontrol et
```

**Çözüm 3: Vault connection**:
```bash
# External Secrets Operator pod'undan Vault'a erişebiliyor mu?
kubectl exec -n external-secrets <operator-pod> -- \
  curl http://vault.vault.svc.cluster.local:8200/v1/sys/health
```

**Çözüm 4: Auth test**:
```bash
# ServiceAccount token ile Vault'a login test et
SA_TOKEN=$(kubectl get secret -o jsonpath='{.data.token}' \
  $(kubectl get sa datetime-app -o jsonpath='{.secrets[0].name}') | base64 -d)

kubectl exec -n vault vault-0 -- vault write auth/kubernetes/login \
  role=datetime-app jwt=$SA_TOKEN
```

---

### 4. Pod Secret'ları Görmüyor

**Semptom**:
```bash
kubectl logs datetime-api-csharp-xxx
# Error: environment variable DATABASE_URL not found
```

**Çözüm 1: Secret oluşmuş mu?**:
```bash
# C# API secret kontrol
kubectl get secret datetime-api-csharp-secrets
# Yoksa ExternalSecret sync olamamıştır

# Go API secret kontrol
kubectl get secret datetime-api-go-secrets
```

**Çözüm 2: Secret içeriği**:
```bash
# C# API secret içeriği
kubectl get secret datetime-api-csharp-secrets -o yaml
# data: altında TIMEZONE, LOG_LEVEL, DATABASE_URL vb. var mı?

# Go API secret içeriği
kubectl get secret datetime-api-go-secrets -o yaml
```

**Çözüm 3: Pod mount**:
```bash
kubectl describe pod datetime-api-csharp-xxx
# Environment kısmında datetime-api-csharp-secrets ref var mı?
```

**Çözüm 4: Doğru secret adı kullanılıyor mu?**:
```bash
# Deployment'ta doğru secret adı kullanılmalı:
# - C# API: datetime-api-csharp-secrets
# - Go API: datetime-api-go-secrets
# ESKİ ADI KULLANMA: datetime-api-secrets veya datetime-common-secrets
```

**Çözüm 4: ServiceAccount**:
```bash
kubectl get pod datetime-api-csharp-xxx -o yaml | grep serviceAccountName
# datetime-app olmalı
```

---

### 5. Permission Denied Hatası

**Semptom**:
```bash
kubectl logs -n vault vault-0
# Error: permission denied (path: secret/data/datetime/api-csharp)
```

**Çözüm 1: Policy kontrol**:
```bash
# Genel policy kontrol
kubectl exec -n vault vault-0 -- vault policy read datetime-app
# path "secret/data/datetime/*" var mı?

# C# API policy kontrol (opsiyonel, eğer kullanılıyorsa)
kubectl exec -n vault vault-0 -- vault policy read api-csharp-policy

# Go API policy kontrol (opsiyonel, eğer kullanılıyorsa)
kubectl exec -n vault vault-0 -- vault policy read api-go-policy
```

**Çözüm 2: Role kontrol**:
```bash
kubectl exec -n vault vault-0 -- vault read auth/kubernetes/role/datetime-app
# policies: datetime-app var mı?
```

**Çözüm 3: Policy güncelle**:
```bash
# Genel policy (tüm API'lere erişim)
kubectl exec -n vault vault-0 -- vault policy write datetime-app - <<EOF
path "secret/data/datetime/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/datetime/*" {
  capabilities = ["read", "list"]
}
EOF
```

**Çözüm 4: Secret path kontrol**:
```bash
# Secret'ların doğru path'te olduğunu kontrol et
kubectl exec -n vault vault-0 -- vault kv list secret/datetime

# Çıktı şöyle olmalı:
# Keys
# ----
# api-csharp
# api-go
#
# OLMAMALI: api, common (eski yapı)
```

---

### 6. Vault UI'a Erişemiyorum

**Semptom**:
```bash
make vault-ui
# Connection refused
```

**Çözüm 1: Port-forward kontrol**:
```bash
kubectl port-forward -n vault svc/vault 8200:8200
# Açık mı?
```

**Çözüm 2: Vault service**:
```bash
kubectl get svc -n vault
# vault service var mı ve port 8200 açık mı?
```

**Çözüm 3: Vault UI enable**:
```bash
kubectl exec -n vault vault-0 -- vault status
# UI: enabled olmalı
```

---

### 7. Makefile Komutları Çalışmıyor

**Semptom**:
```bash
make vault-init
# Error: vault-keys.json already exists
```

**Çözüm 1: Force reinit**:
```bash
# UYARI: Mevcut data kaybolur!
rm vault-keys.json
make vault-init
```

**Çözüm 2: Vault zaten initialized**:
```bash
make vault-status
# Initialized: true ise vault-init'e gerek yok
```

---

## Yararlı Komutlar

### Vault CLI Komutları

```bash
# Vault pod'a exec
kubectl exec -n vault vault-0 -it -- sh

# Login
vault login <root_token>

# KV komutları
vault kv list secret/datetime
vault kv get secret/datetime/api
vault kv put secret/datetime/api key=value
vault kv delete secret/datetime/api

# Policy komutları
vault policy list
vault policy read datetime-app
vault policy write datetime-app policy.hcl

# Auth komutları
vault auth list
vault auth enable kubernetes
vault auth disable kubernetes

# Status
vault status
vault operator unseal
vault operator seal
```

---

### Kubernetes Komutları

```bash
# Vault namespace
kubectl get all -n vault
kubectl logs -n vault vault-0 -f
kubectl describe pod -n vault vault-0

# External Secrets Operator
kubectl get all -n external-secrets
kubectl logs -n external-secrets deployment/external-secrets

# ExternalSecrets
kubectl get externalsecret
kubectl describe externalsecret datetime-api-csharp-secrets
kubectl describe externalsecret datetime-api-go-secrets
kubectl get secret datetime-api-csharp-secrets -o yaml
kubectl get secret datetime-api-go-secrets -o yaml

# SecretStore
kubectl get secretstore
kubectl describe secretstore vault-backend
```

---

## Best Practices

### 1. Production Deployment

- ✅ HA setup: 3-5 Vault replicas
- ✅ TLS enabled (cert-manager)
- ✅ Auto-unseal (AWS KMS, Azure Key Vault)
- ✅ Consul/etcd storage backend (not file)
- ✅ Audit logging enabled
- ✅ Regular backups
- ✅ Disaster recovery plan

### 2. Secret Management

- ✅ Least privilege (minimal policy)
- ✅ Regular secret rotation
- ✅ Version control (rollback capability)
- ✅ Audit trail (who accessed what)
- ✅ Separate secrets per environment (dev/staging/prod)

### 3. Development Workflow

```bash
# Local development (bu proje)
make setup-vault  # Dev ortamı

# Staging
# - TLS enabled
# - Separate Vault instance
# - Limited access

# Production
# - HA setup
# - Auto-unseal
# - Strict RBAC
# - Audit logging
# - Backup/DR
```

---

## Referanslar

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Vault Kubernetes Auth](https://www.vaultproject.io/docs/auth/kubernetes)
- [External Secrets Operator](https://external-secrets.io/)
- [Vault Best Practices](https://www.vaultproject.io/docs/internals/security)

---

## Vault Yapısı (v1.0)

### Mimari Değişikliği

```
Vault
└── secret/data/datetime/
    ├── api-csharp/              # C# API - TAMAMEN BAĞIMSIZ
    │   ├── timezone             # Europe/Istanbul
    │   ├── log_level            # debug
    │   ├── database_url         # csharp-user credentials
    │   ├── api_key              # csharp-api-key-12345
    │   ├── jwt_secret           # csharp-jwt-secret-67890
    │   └── redis_url            # redis://redis:6379/0
    │
    └── api-go/                  # Go API - TAMAMEN BAĞIMSIZ
        ├── timezone             # UTC
        ├── log_level            # info
        ├── database_url         # go-user credentials
        ├── api_key              # go-api-key-98765
        ├── jwt_secret           # go-jwt-secret-54321
        └── redis_url            # redis://redis:6379/1
```

### Önemli Değişiklikler

1. **Common Secret Path Kaldırıldı**: Artık `secret/datetime/common` yok!
2. **Her API Bağımsız**: Her API'nin kendi timezone, log_level, database credentials vb. var
3. **Farklı Değerler**: C# API ve Go API farklı değerler kullanır (güvenlik)
4. **İki Ayrı ExternalSecret**: `datetime-api-csharp-secrets` ve `datetime-api-go-secrets`
5. **İzolasyon**: Bir API'nin secret'ı değiştiğinde diğer API etkilenmez

### Migration Checklist

Eski yapıdan yeni yapıya geçiş için:

- [ ] Eski secret'ları sil: `secret/datetime/api` ve `secret/datetime/common`
- [ ] Yeni secret'ları oluştur: `secret/datetime/api-csharp` ve `secret/datetime/api-go`
- [ ] ExternalSecret dosyalarını güncelle: `datetime-api-csharp-secrets` ve `datetime-api-go-secrets`
- [ ] Deployment dosyalarını güncelle: Secret adlarını değiştir
- [ ] Her API için timezone ve log_level tanımla
- [ ] Test et: Her API kendi secret'larını görebiliyor mu?

---

## Özet

Bu projede **HashiCorp Vault** ve **External Secrets Operator** kullanılarak:

✅ Secret'lar merkezi bir yerde güvenli şekilde saklanır (Vault)
✅ Kubernetes native authentication ile erişim sağlanır
✅ RBAC ile fine-grained access control uygulanır
✅ **Her API tamamen bağımsız secret'lara sahip** (least privilege)
✅ **Artık common secret yok**, her API kendi timezone/log_level kullanır
✅ ExternalSecret CRD ile otomatik sync yapılır
✅ Application'lar secret'ları environment variable olarak alır
✅ Secret versioning ve rotation desteklenir
✅ Audit logging ile erişim kayıtları tutulur

**Makefile entegrasyonu** ile tek komutla (`make deploy`) tüm sistem kurulur ve yapılandırılır.
