# HashiCorp Vault Integration

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Components](#components)
- [Installation](#installation)
- [Vault Configuration](#vault-configuration)
- [Secret Management](#secret-management)
- [Makefile Commands](#makefile-commands)
- [Security](#security)
- [Troubleshooting](#troubleshooting)

---

## Overview

This project uses **HashiCorp Vault** and **External Secrets Operator** to securely manage sensitive information (secrets).

### Why Vault?

**Problem:**
- Kubernetes Secrets are base64 encoded (not encrypted!)
- Secrets committed to Git pose security risks
- Secret rotation and audit logging are difficult
- No centralized secret management

**Solution: HashiCorp Vault**
- ✅ Encrypts and stores secrets centrally
- ✅ Fine-grained access control (RBAC)
- ✅ Audit logging (who, when, which secret)
- ✅ Dynamic secrets and automatic rotation
- ✅ Kubernetes native authentication

---

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                      │
│                                                            │
│  ┌──────────────────┐        ┌─────────────────────┐       │
│  │   Vault Pod      │◄───────│  External Secrets   │       │
│  │  (vault ns)      │        │    Operator         │       │
│  │                  │        │  (external-secrets) │       │
│  │  - KV v2 Engine  │        └─────────────────────┘       │
│  │  - K8s Auth      │                 │                    │
│  │  - Policies      │                 │                    │
│  └──────────────────┘                 │                    │
│          │                             ▼                   │
│          │                  ┌─────────────────────┐        │
│          │                  │  ExternalSecret CRD │        │
│          │                  │  (datetime-api)     │        │
│          │                  └─────────────────────┘        │
│          │                             │                   │
│          │                             ▼                   │
│          │                  ┌─────────────────────┐        │
│          │                  │  Kubernetes Secret  │        │
│          │                  │  (auto-created)     │        │
│          │                  └─────────────────────┘        │
│          │                             │                   │
│          │                             │                   │
│          ▼                             ▼                   │
│  ┌───────────────────────────────────────────────┐         │
│  │         Application Pods                      │         │
│  │  ┌──────────────┐  ┌──────────────┐           │         │
│  │  │ C# API Pod   │  │ Go API Pod   │           │         │
│  │  │ (env vars)   │  │ (env vars)   │           │         │
│  │  └──────────────┘  └──────────────┘           │         │
│  │   ServiceAccount: datetime-app                │         │
│  └───────────────────────────────────────────────┘         │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### Flow

1. **Vault Init**: Vault is initialized and unseal keys + root token are created
2. **Vault Unseal**: Vault is unsealed with 3/5 unseal keys
3. **Auth Setup**: Kubernetes auth method is configured
4. **Policy Creation**: `datetime-app` policy is created
5. **Secret Storage**: Secrets are stored in Vault (`secret/datetime/*`)
6. **External Secrets Operator**: SecretStore and ExternalSecret CRDs are created
7. **Sync**: Operator fetches secrets from Vault and creates Kubernetes Secrets
8. **Injection**: Pods receive secrets as environment variables

---

## Components

### 1. vault-deployment.yaml

This file contains all resources needed for Vault to run on Kubernetes.

#### Namespace
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: vault
```
**Description**: Creates a separate namespace for Vault (isolation).

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

**Description**:
- **listener.tcp.address**: Vault API listening address (0.0.0.0:8200)
- **listener.tcp.tls_disable**: TLS disabled (for dev/test, should be `false` in production!)
- **storage.file**: File-based storage backend (use Consul/etcd in production)
- **ui**: Web UI enabled (http://localhost:8200/ui)
- **log_level**: Log level (`info`)

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

**Description**:
- 1GB disk space for Vault data persistence
- `ReadWriteOnce`: Can be mounted to a single node
- Data persists even if pod restarts

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

**Description**:
- **StatefulSet**: For stable network identity and persistent storage
- **replicas: 1**: Single instance (should be 3-5 for HA)
- **image**: Vault 1.15 official image
- **ports**:
  - `8200`: HTTP API
  - `8201`: Internal cluster communication
- **VAULT_ADDR**: Local address for Vault CLI
- **VAULT_API_ADDR**: Address for other pods in cluster
- **volumeMounts**:
  - Config file
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

**Description**:
- **livenessProbe**: Checks if pod is alive
- **readinessProbe**: Checks if pod is ready to accept traffic
- **standbyok=true**: Consider standby Vault as healthy
- **perfstandbyok=true**: Consider performance standby as healthy

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

**Description**:
- **requests**: Minimum resource guarantee
- **limits**: Maximum resource usage
- Vault is lightweight, these values are sufficient

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

**Description**:
- **ClusterIP**: Accessible from within cluster
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

**Description**:
- **ServiceAccount**: For Vault pod to access Kubernetes API
- **ClusterRoleBinding**: Grants `system:auth-delegator` role
- **system:auth-delegator**: Access to TokenReview API (required for Kubernetes auth)

---

### 2. external-secrets.yaml

This file defines how External Secrets Operator fetches secrets from Vault.

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

**Description**:
- **SecretStore**: Stores Vault connection info
- **server**: Vault address in cluster
- **path**: KV secrets engine path (`secret`)
- **version**: KV v2 (versioning and metadata support)
- **auth.kubernetes**: Use Kubernetes auth method
  - **mountPath**: Auth path in Vault (`kubernetes`)
  - **role**: Vault role name (`datetime-app`)
  - **serviceAccountRef**: Which ServiceAccount to authenticate with

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

**Description**:
- **ExternalSecret**: Fetches C# API secrets from Vault and creates Kubernetes Secret
- **refreshInterval**: Sync every 1 hour (for secret rotation)
- **secretStoreRef**: Which SecretStore to use
- **target.name**: Name of Kubernetes Secret to create
- **target.creationPolicy**: `Owner` (Secret deleted when ExternalSecret is deleted)
- **data**: Which secrets to fetch from Vault
  - **secretKey**: Key name in Kubernetes Secret (env var name)
  - **remoteRef.key**: Path in Vault (`secret/data/datetime/api-csharp`)
  - **remoteRef.property**: Field name in Vault secret

**Stored in Vault as:**
```
secret/data/datetime/api-csharp:
  timezone: "Europe/Istanbul"
  log_level: "debug"
  database_url: "postgresql://csharp-user:password@postgres:5432/datetime_csharp_db"
  api_key: "csharp-api-key-12345"
  jwt_secret: "csharp-jwt-secret-67890"
  redis_url: "redis://redis:6379/0"
```

**Converted to Kubernetes Secret as:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: datetime-api-csharp-secrets
data:
  TIMEZONE: RXVyb3BlL0lzdGFuYnVs  # base64
  LOG_LEVEL: ZGVidWc=
  DATABASE_URL: cG9zdGdyZXNxbC8vY3NoYXJwLXVzZXI6Li4u  # base64
  API_KEY: Y3NoYXJwLWFwaS1rZXktMTIzNDU=
  JWT_SECRET: Y3NoYXJwLWp3dC1zZWNyZXQtNjc4OTA=
  REDIS_URL: cmVkaXM6Ly9yZWRpczozNjc5LzA=
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

**Description**:
- **ExternalSecret**: Fetches Go API secrets from Vault and creates Kubernetes Secret
- **refreshInterval**: Sync every 1 hour (for secret rotation)
- **secretStoreRef**: Which SecretStore to use
- **target.name**: Name of Kubernetes Secret to create
- **target.creationPolicy**: `Owner` (Secret deleted when ExternalSecret is deleted)
- **data**: Which secrets to fetch from Vault
  - **secretKey**: Key name in Kubernetes Secret (env var name)
  - **remoteRef.key**: Path in Vault (`secret/data/datetime/api-go`)
  - **remoteRef.property**: Field name in Vault secret

**Stored in Vault as:**
```
secret/data/datetime/api-go:
  timezone: "UTC"
  log_level: "info"
  database_url: "postgresql://go-user:password@postgres:5432/datetime_go_db"
  api_key: "go-api-key-98765"
  jwt_secret: "go-jwt-secret-54321"
  redis_url: "redis://redis:6379/1"
```

**Converted to Kubernetes Secret as:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: datetime-api-go-secrets
data:
  TIMEZONE: VVRD  # base64
  LOG_LEVEL: aW5mbw==
  DATABASE_URL: cG9zdGdyZXNxbC8vZ28tdXNlcjouLi4=  # base64
  API_KEY: Z28tYXBpLWtleS05ODc2NQ==
  JWT_SECRET: Z28tand0LXNlY3JldC01NDMyMQ==
  REDIS_URL: cmVkaXM6Ly9yZWRpczozNjc5LzE=
```

---

### 3. Application Deployment (api-csharp-deployment.yaml, api-go-deployment.yaml)

#### C# API Deployment
```yaml
spec:
  template:
    spec:
      serviceAccountName: datetime-app  # Required for Vault auth
      containers:
        - name: api-csharp
          env:
            # All secrets from C# API's independent Vault path
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

#### Go API Deployment
```yaml
spec:
  template:
    spec:
      serviceAccountName: datetime-app  # Required for Vault auth
      containers:
        - name: api-go
          env:
            # All secrets from Go API's independent Vault path
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

**Description**:
- **serviceAccountName**: Uses `datetime-app` ServiceAccount for Vault auth
- **env.valueFrom.secretKeyRef**: Injected as env var from Kubernetes Secret
- Each API has its own independent secret (no shared secrets)
- Secrets don't update without pod restart (restart required for rotation)

---

## Installation

### 1. Automatic Installation (Recommended)

```bash
# Deploy entire system (including Vault)
make deploy
```

This command does the following in order:
1. Creates Kind cluster
2. Installs Ingress controller
3. Builds and loads Docker images
4. **Installs and configures Vault** (setup-vault)
5. Deploys Kubernetes resources
6. Installs HAProxy load balancer
7. Updates `/etc/hosts` file

---

### 2. Manual Installation

```bash
# 1. Install Vault
make install-vault

# 2. Initialize Vault (creates unseal keys)
make vault-init

# 3. Unseal Vault
make vault-unseal

# 4. Configure Vault (auth, policy, secrets)
make vault-setup

# 5. Install External Secrets Operator
make install-external-secrets

# 6. Deploy ExternalSecrets
kubectl apply -f k8s/external-secrets.yaml

# 7. Deploy Applications
kubectl apply -f k8s/api-csharp-deployment.yaml
kubectl apply -f k8s/api-go-deployment.yaml
```

---

## Vault Configuration

### Vault Init Process

```bash
make vault-init
```

This command:
1. Connects to Vault pod
2. Runs `vault operator init`
3. Creates 5 unseal keys (threshold: 3)
4. Creates root token
5. Saves all info to `vault-keys.json` file

**vault-keys.json content:**
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

⚠️ **CRITICAL**: This file must NOT be committed to Git! (already in `.gitignore`)

---

### Vault Unseal Process

Vault starts in "sealed" state. Unsealing unlocks the encryption key.

```bash
make vault-unseal
```

This command:
1. Reads `vault-keys.json` file
2. Uses 3 unseal keys to unseal Vault (threshold: 3/5)
3. Vault can now read and write secrets

**Shamir's Secret Sharing**:
- Total keys: 5
- Threshold: 3
- Vault can be unsealed with any 3 keys
- Single person cannot unseal vault (security)

---

### Vault Setup Process

```bash
make vault-setup
```

This command does the following:

#### 1. Login to Vault
```bash
vault login <root_token>
```

#### 2. Enable Kubernetes Auth
```bash
vault auth enable kubernetes
```

#### 3. Configure Kubernetes Auth
```bash
vault write auth/kubernetes/config \
  token_reviewer_jwt="<sa_token>" \
  kubernetes_host="https://kubernetes.default.svc" \
  kubernetes_ca_cert="<ca_cert>"
```

**Description**:
- **token_reviewer_jwt**: Vault's ServiceAccount token
- **kubernetes_host**: Kubernetes API server address
- **kubernetes_ca_cert**: Cluster CA certificate

#### 4. Enable KV Secrets Engine
```bash
vault secrets enable -path=secret kv-v2
```

**Description**:
- KV v2: Versioning and metadata support
- Path: `secret/`

#### 5. Create Policy
```bash
vault policy write datetime-app - <<EOF
path "secret/data/datetime/*" {
  capabilities = ["read", "list"]
}
EOF
```

**Description**:
- **Policy**: `datetime-app`
- **Path**: `secret/data/datetime/*` (all datetime secrets)
- **Capabilities**: `read`, `list` (read-only)

#### 6. Create Service Account
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: datetime-app
  namespace: default
EOF
```

#### 7. Create Kubernetes Auth Role
```bash
vault write auth/kubernetes/role/datetime-app \
  bound_service_account_names=datetime-app \
  bound_service_account_namespaces=default \
  policies=datetime-app \
  ttl=24h
```

**Description**:
- **Role**: `datetime-app`
- **bound_service_account_names**: Only authenticate with `datetime-app` SA
- **bound_service_account_namespaces**: Only `default` namespace
- **policies**: Apply `datetime-app` policy
- **ttl**: Token valid for 24 hours

#### 8. Create Secrets for Each API

Each API has completely independent secrets (following the least privilege principle):

```bash
# C# API secrets - FULLY INDEPENDENT
vault kv put secret/datetime/api-csharp \
  timezone="Europe/Istanbul" \
  log_level="debug" \
  database_url="postgresql://csharp-user:csharp-pass@postgres:5432/datetime_csharp_db" \
  api_key="csharp-api-key-12345" \
  jwt_secret="csharp-jwt-secret-67890" \
  redis_url="redis://redis:6379/0"

# Go API secrets - FULLY INDEPENDENT
vault kv put secret/datetime/api-go \
  timezone="UTC" \
  log_level="info" \
  database_url="postgresql://go-user:go-pass@postgres:5432/datetime_go_db" \
  api_key="go-api-key-98765" \
  jwt_secret="go-jwt-secret-54321" \
  redis_url="redis://redis:6379/1"
```

**Important Notes**:
- NO common secret path anymore - each API is fully independent
- Different credentials ensure least privilege (C# API cannot access Go API's database)
- Different timezone and log_level for different requirements
- Different Redis databases (0 for C#, 1 for Go)

---

## Secret Management

### Reading Secrets

Each API has its own independent secret path:

```bash
# Login with root token
ROOT_TOKEN=$(jq -r '.root_token' vault-keys.json)
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN

# Read C# API secrets
kubectl exec -n vault vault-0 -- vault kv get secret/datetime/api-csharp

# Read Go API secrets
kubectl exec -n vault vault-0 -- vault kv get secret/datetime/api-go
```

**C# API Output:**
```
====== Data ======
Key            Value
---            -----
timezone       Europe/Istanbul
log_level      debug
api_key        csharp-api-key-12345
database_url   postgresql://csharp-user:csharp-pass@postgres:5432/datetime_csharp_db
jwt_secret     csharp-jwt-secret-67890
redis_url      redis://redis:6379/0
```

**Go API Output:**
```
====== Data ======
Key            Value
---            -----
timezone       UTC
log_level      info
api_key        go-api-key-98765
database_url   postgresql://go-user:go-pass@postgres:5432/datetime_go_db
jwt_secret     go-jwt-secret-54321
redis_url      redis://redis:6379/1
```

---

### Writing/Updating Secrets

Manage secrets independently for each API:

```bash
# Update C# API secrets
kubectl exec -n vault vault-0 -- vault kv put secret/datetime/api-csharp \
  timezone="Europe/Istanbul" \
  log_level="debug" \
  database_url="postgresql://csharp-user:newpass@postgres:5432/datetime_csharp_db" \
  api_key="new-csharp-api-key" \
  jwt_secret="csharp-jwt-secret-67890" \
  redis_url="redis://redis:6379/0"

# Update Go API secrets
kubectl exec -n vault vault-0 -- vault kv put secret/datetime/api-go \
  timezone="UTC" \
  log_level="info" \
  database_url="postgresql://go-user:newpass@postgres:5432/datetime_go_db" \
  api_key="new-go-api-key" \
  jwt_secret="go-jwt-secret-54321" \
  redis_url="redis://redis:6379/1"

# Update only one field (patch) - C# API
kubectl exec -n vault vault-0 -- vault kv patch secret/datetime/api-csharp \
  api_key="updated-csharp-api-key"

# Update only one field (patch) - Go API
kubectl exec -n vault vault-0 -- vault kv patch secret/datetime/api-go \
  log_level="warn"
```

---

### Secret Versioning

```bash
# List all versions - C# API
kubectl exec -n vault vault-0 -- vault kv metadata get secret/datetime/api-csharp

# List all versions - Go API
kubectl exec -n vault vault-0 -- vault kv metadata get secret/datetime/api-go

# Read specific version
kubectl exec -n vault vault-0 -- vault kv get -version=2 secret/datetime/api-csharp
kubectl exec -n vault vault-0 -- vault kv get -version=2 secret/datetime/api-go

# Rollback to old version
kubectl exec -n vault vault-0 -- vault kv rollback -version=1 secret/datetime/api-csharp
kubectl exec -n vault vault-0 -- vault kv rollback -version=1 secret/datetime/api-go
```

---

### Deleting Secrets

```bash
# Soft delete latest version (recoverable) - C# API
kubectl exec -n vault vault-0 -- vault kv delete secret/datetime/api-csharp

# Soft delete latest version (recoverable) - Go API
kubectl exec -n vault vault-0 -- vault kv delete secret/datetime/api-go

# Delete specific version
kubectl exec -n vault vault-0 -- vault kv delete -versions=2 secret/datetime/api-csharp
kubectl exec -n vault vault-0 -- vault kv delete -versions=2 secret/datetime/api-go

# Permanently delete (PERMANENT!)
kubectl exec -n vault vault-0 -- vault kv metadata delete secret/datetime/api-csharp
kubectl exec -n vault vault-0 -- vault kv metadata delete secret/datetime/api-go
```

---

## Makefile Commands

### Vault Installation Commands

| Command | Description |
|---------|-------------|
| `make install-vault` | Deploys Vault to Kubernetes |
| `make vault-init` | Initializes Vault (creates unseal keys) |
| `make vault-unseal` | Unseals Vault (opens it) |
| `make vault-setup` | Fully configures Vault (auth + policy + secrets) |
| `make setup-vault` | **MAIN COMMAND** (does everything) |

### Vault Management Commands

| Command | Description |
|---------|-------------|
| `make vault-status` | Shows Vault status |
| `make vault-ui` | Opens port-forward for Vault UI (http://localhost:8200/ui) |
| `make vault-secrets` | Lists secrets in Vault |
| `make clean-vault` | Completely removes Vault |

### External Secrets Commands

| Command | Description |
|---------|-------------|
| `make install-external-secrets` | Installs External Secrets Operator (Helm) |

### Usage Examples

```bash
# Install and configure Vault
make setup-vault

# Check Vault status
make vault-status

# Access Vault UI
make vault-ui
# Open in browser: http://localhost:8200/ui
# Token: jq -r '.root_token' vault-keys.json

# View secrets
make vault-secrets

# Clean up Vault
make clean-vault
```

---

## Security

### 1. vault-keys.json Security

⚠️ **CRITICAL**: `vault-keys.json` file contains sensitive information!

**Content**:
- 5 unseal keys
- Root token

**Security Measures**:
```bash
# File permissions (only owner can read)
chmod 600 vault-keys.json

# In .gitignore (not committed to Git)
echo "vault-keys.json" >> .gitignore

# Use external KMS in production
# - AWS KMS
# - Azure Key Vault
# - GCP Cloud KMS
```

**Production Recommendation**:
```bash
# Auto-unseal with AWS KMS
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

⚠️ **Current State**: TLS disabled (`tls_disable: true`)

**For Production**:
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
# Create TLS certificate (with cert-manager)
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: vault-tls
  namespace: vault
spec:
  secretName: vault-tls
  issuerRef:
    name: letsencrypt-prod
  dnsNames:
    - vault.example.com
EOF
```

---

### 3. RBAC and Least Privilege

**ServiceAccount permissions**:
```yaml
# datetime-app ServiceAccount has access to all datetime secrets
vault policy write datetime-app - <<EOF
path "secret/data/datetime/*" {
  capabilities = ["read", "list"]
}
EOF
```

**Per-API policies** (optional, for stricter isolation):
```yaml
# C# API can only access its own secrets
vault policy write datetime-csharp-app - <<EOF
path "secret/data/datetime/api-csharp" {
  capabilities = ["read", "list"]
}
EOF

# Go API can only access its own secrets
vault policy write datetime-go-app - <<EOF
path "secret/data/datetime/api-go" {
  capabilities = ["read", "list"]
}
EOF
```

**Developer access**:
```yaml
# Developers can only read all secrets
vault policy write developer - <<EOF
path "secret/data/datetime/*" {
  capabilities = ["read", "list"]
}
EOF

# Or per-API developer access
vault policy write developer-csharp - <<EOF
path "secret/data/datetime/api-csharp" {
  capabilities = ["read", "list"]
}
EOF

vault policy write developer-go - <<EOF
path "secret/data/datetime/api-go" {
  capabilities = ["read", "list"]
}
EOF
```

**Admin access**:
```yaml
# Admins can do everything
vault policy write admin - <<EOF
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF
```

---

### 4. Audit Logging

```bash
# Enable audit logging
kubectl exec -n vault vault-0 -- vault audit enable file \
  file_path=/vault/logs/audit.log

# View audit logs
kubectl exec -n vault vault-0 -- cat /vault/logs/audit.log | jq .
```

**Audit log example**:
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

**Manual rotation for C# API**:
```bash
# 1. Update C# API secret in Vault
kubectl exec -n vault vault-0 -- vault kv put secret/datetime/api-csharp \
  timezone="Europe/Istanbul" \
  log_level="debug" \
  database_url="postgresql://csharp-user:newpass@postgres:5432/datetime_csharp_db" \
  api_key="new-csharp-api-key" \
  jwt_secret="csharp-jwt-secret-67890" \
  redis_url="redis://redis:6379/0"

# 2. Wait for ExternalSecret sync (1 hour) or force sync
kubectl annotate externalsecret datetime-api-csharp-secrets \
  force-sync=$(date +%s) --overwrite

# 3. Restart C# API pods (to update env vars)
kubectl rollout restart deployment datetime-api-csharp
```

**Manual rotation for Go API**:
```bash
# 1. Update Go API secret in Vault
kubectl exec -n vault vault-0 -- vault kv put secret/datetime/api-go \
  timezone="UTC" \
  log_level="info" \
  database_url="postgresql://go-user:newpass@postgres:5432/datetime_go_db" \
  api_key="new-go-api-key" \
  jwt_secret="go-jwt-secret-54321" \
  redis_url="redis://redis:6379/1"

# 2. Wait for ExternalSecret sync (1 hour) or force sync
kubectl annotate externalsecret datetime-api-go-secrets \
  force-sync=$(date +%s) --overwrite

# 3. Restart Go API pods (to update env vars)
kubectl rollout restart deployment datetime-api-go
```

**Automatic rotation** (future):
- Use dynamic secrets
- Vault Agent Injector with sidecar pattern
- Secret refresh without pod restart

---

## Troubleshooting

### 1. Vault Pod Not Starting

**Symptom**:
```bash
kubectl get pods -n vault
NAME      READY   STATUS             RESTARTS   AGE
vault-0   0/1     CrashLoopBackOff   5          5m
```

**Solution 1: Check logs**:
```bash
kubectl logs -n vault vault-0
```

**Solution 2: Check PVC**:
```bash
kubectl get pvc -n vault
# If PVC is "Pending", there might be storage class issues
```

**Solution 3: Check ConfigMap**:
```bash
kubectl get cm -n vault vault-config -o yaml
# Is there a JSON syntax error?
```

---

### 2. Vault is Sealed

**Symptom**:
```bash
make vault-status
# Output: "Sealed: true"
```

**Solution**:
```bash
# Unseal it
make vault-unseal

# If vault-keys.json doesn't exist, reinitialize (DATA WILL BE LOST!)
make vault-init
```

---

### 3. External Secrets Not Syncing

**Symptom**:
```bash
kubectl get externalsecret
NAME                           STORE           REFRESH INTERVAL   STATUS
datetime-api-csharp-secrets    vault-backend   1h                 SecretSyncedError
datetime-api-go-secrets        vault-backend   1h                 SecretSyncedError
```

**Solution 1: Describe ExternalSecret**:
```bash
kubectl describe externalsecret datetime-api-csharp-secrets
kubectl describe externalsecret datetime-api-go-secrets
# Check Events section
```

**Solution 2: Test SecretStore**:
```bash
kubectl get secretstore vault-backend -o yaml
# Check Status section
```

**Solution 3: Test Vault connection**:
```bash
# Can External Secrets Operator pod reach Vault?
kubectl exec -n external-secrets <operator-pod> -- \
  curl http://vault.vault.svc.cluster.local:8200/v1/sys/health
```

**Solution 4: Test auth**:
```bash
# Test Vault login with ServiceAccount token
SA_TOKEN=$(kubectl get secret -o jsonpath='{.data.token}' \
  $(kubectl get sa datetime-app -o jsonpath='{.secrets[0].name}') | base64 -d)

kubectl exec -n vault vault-0 -- vault write auth/kubernetes/login \
  role=datetime-app jwt=$SA_TOKEN
```

---

### 4. Pod Cannot See Secrets

**Symptom**:
```bash
kubectl logs datetime-api-csharp-xxx
# Error: environment variable DATABASE_URL not found
```

**Solution 1: Check if Secret exists**:
```bash
# For C# API
kubectl get secret datetime-api-csharp-secrets
# If not, ExternalSecret hasn't synced

# For Go API
kubectl get secret datetime-api-go-secrets
# If not, ExternalSecret hasn't synced
```

**Solution 2: Check Secret content**:
```bash
# For C# API
kubectl get secret datetime-api-csharp-secrets -o yaml
# Are there keys under data:?

# For Go API
kubectl get secret datetime-api-go-secrets -o yaml
# Are there keys under data:?
```

**Solution 3: Check pod mount**:
```bash
kubectl describe pod datetime-api-csharp-xxx
# Is there secret ref in Environment section?

kubectl describe pod datetime-api-go-xxx
# Is there secret ref in Environment section?
```

**Solution 4: Check ServiceAccount**:
```bash
kubectl get pod datetime-api-csharp-xxx -o yaml | grep serviceAccountName
# Should be datetime-app

kubectl get pod datetime-api-go-xxx -o yaml | grep serviceAccountName
# Should be datetime-app
```

---

### 5. Permission Denied Error

**Symptom**:
```bash
kubectl logs -n vault vault-0
# Error: permission denied (path: secret/data/datetime/api-csharp or api-go)
```

**Solution 1: Check policy**:
```bash
kubectl exec -n vault vault-0 -- vault policy read datetime-app
# Is path "secret/data/datetime/*" there?
# This should allow access to both api-csharp and api-go paths
```

**Solution 2: Check role**:
```bash
kubectl exec -n vault vault-0 -- vault read auth/kubernetes/role/datetime-app
# Is policies: datetime-app there?
```

**Solution 3: Update policy**:
```bash
kubectl exec -n vault vault-0 -- vault policy write datetime-app - <<EOF
path "secret/data/datetime/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/datetime/*" {
  capabilities = ["read", "list"]
}
EOF
```

---

### 6. Cannot Access Vault UI

**Symptom**:
```bash
make vault-ui
# Connection refused
```

**Solution 1: Check port-forward**:
```bash
kubectl port-forward -n vault svc/vault 8200:8200
# Is it open?
```

**Solution 2: Check Vault service**:
```bash
kubectl get svc -n vault
# Does vault service exist and is port 8200 open?
```

**Solution 3: Check Vault UI enabled**:
```bash
kubectl exec -n vault vault-0 -- vault status
# UI should be enabled
```

---

### 7. Makefile Commands Not Working

**Symptom**:
```bash
make vault-init
# Error: vault-keys.json already exists
```

**Solution 1: Force reinit**:
```bash
# WARNING: Existing data will be lost!
rm vault-keys.json
make vault-init
```

**Solution 2: Vault already initialized**:
```bash
make vault-status
# If Initialized: true, vault-init is not needed
```

---

## Useful Commands

### Vault CLI Commands

```bash
# Exec into Vault pod
kubectl exec -n vault vault-0 -it -- sh

# Login
vault login <root_token>

# KV commands
vault kv list secret/datetime
vault kv get secret/datetime/api-csharp
vault kv get secret/datetime/api-go
vault kv put secret/datetime/api-csharp key=value
vault kv put secret/datetime/api-go key=value
vault kv delete secret/datetime/api-csharp
vault kv delete secret/datetime/api-go

# Policy commands
vault policy list
vault policy read datetime-app
vault policy write datetime-app policy.hcl

# Auth commands
vault auth list
vault auth enable kubernetes
vault auth disable kubernetes

# Status
vault status
vault operator unseal
vault operator seal
```

---

### Kubernetes Commands

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
# Local development (this project)
make setup-vault  # Dev environment

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

## References

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Vault Kubernetes Auth](https://www.vaultproject.io/docs/auth/kubernetes)
- [External Secrets Operator](https://external-secrets.io/)
- [Vault Best Practices](https://www.vaultproject.io/docs/internals/security)

---

## Summary

This project uses **HashiCorp Vault** and **External Secrets Operator** to:

✅ Store secrets securely in a central location (Vault)
✅ Provide access with Kubernetes native authentication
✅ Apply fine-grained access control with RBAC
✅ Auto-sync with ExternalSecret CRD
✅ Inject secrets as environment variables into applications
✅ Support secret versioning and rotation
✅ Maintain access logs with audit logging

**Makefile integration** allows the entire system to be installed and configured with a single command (`make deploy`).
