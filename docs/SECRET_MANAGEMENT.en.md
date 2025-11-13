# Secret Management

## 📋 Table of Contents

- [Overview](#overview)
- [Why Secret Management Matters?](#why-secret-management-matters)
- [Best Practices](#best-practices)
- [Level 1: .env File Approach](#level-1-env-file-approach-recommended)
- [Level 2: YAML File Approach](#level-2-yaml-file-approach)
- [Level 3: Production-Ready Approach](#level-3-production-ready-approach)
- [Current Implementation](#current-implementation)
- [Usage Guide](#usage-guide)
- [Troubleshooting](#troubleshooting)
- [Security Checklist](#security-checklist)

---

## Overview

This project uses **HashiCorp Vault** and **External Secrets Operator** for secure secret management. Secrets (passwords, API keys, tokens, etc.) are stored encrypted in Vault and injected securely into application pods.

### Architecture

```
.env File (Local Developer)
    ↓
Makefile (vault-setup command)
    ↓
HashiCorp Vault (Running in Kubernetes)
    ↓
External Secrets Operator
    ↓
Kubernetes Secrets (Auto-created)
    ↓
Application Pods (Injected as env variables)
```

---

## Why Secret Management Matters?

### ❌ Bad Approaches

```makefile
# BAD: Hard-coded secrets
database_url="postgresql://user:password123@host/db"

# BAD: Secrets committed to Git
git add Makefile
git commit -m "update database config"  # ← Password stays in Git history!

# BAD: Visible in public repo
# Everyone on GitHub, GitLab, Bitbucket can see
```

### ⚠️ Risks

| Risk | Description | Impact |
|------|-------------|--------|
| **Data Breach** | Secrets exposed | Critical |
| **Unauthorized Access** | Malicious actors access system | Critical |
| **Compliance Violation** | GDPR, PCI-DSS breach | High |
| **Audit Problems** | Who accessed what, when? | Medium |
| **Rotation Difficulty** | Code changes when password changes | Medium |

### ✅ Good Approach

```makefile
# GOOD: Read from environment variable
database_url="${DB_URL}"  # ← From .env file, not committed to Git

# GOOD: Write to Vault
vault kv put secret/app database_url="${DB_URL}"

# GOOD: Kubernetes Secret auto-created
# External Secrets Operator handles it
```

---

## Best Practices

### 1. ✅ Never Commit Secrets to Git

```bash
# .gitignore
.env
.env.local
.env.*.local
vault-keys.json
secrets.yaml
```

### 2. ✅ Use Environment Variables

```bash
# .env file (not committed to Git)
DB_PASSWORD=my-secret-password
API_KEY=my-api-key

# Makefile
database_url="${DB_PASSWORD}"
```

### 3. ✅ Provide Template File

```bash
# .env.example (committed to Git)
DB_PASSWORD=your-password-here
API_KEY=your-api-key-here
```

### 4. ✅ Different Secrets for Different Environments

```
Development: Test data
Staging: Near-production but separate
Production: Real credentials
```

### 5. ✅ Least Privilege Principle

Each service should only access secrets it needs:

```yaml
# C# API only accesses its own secrets
secret/datetime/api-csharp

# Go API only accesses its own secrets
secret/datetime/api-go
```

### 6. ✅ Secret Rotation

Regularly rotate secrets:

```bash
# Generate new JWT secret
openssl rand -base64 32

# Update in Vault
vault kv patch secret/app jwt_secret="new-secret"

# Restart pods
kubectl rollout restart deployment/app
```

### 7. ✅ Audit Logging

Who accessed which secret, when?

```bash
# Enable Vault audit logging
vault audit enable file file_path=/vault/logs/audit.log

# View logs
kubectl exec -n vault vault-0 -- cat /vault/logs/audit.log
```

---

## Level 1: .env File Approach (Recommended)

### ✅ Advantages

- Simple and fast (5 minutes to implement)
- Not committed to Git
- Each developer uses their own values
- Standard approach (most projects use this)
- Documented with .env.example

### ⚠️ Disadvantages

- Each developer must create .env file
- Manual secret rotation
- CI/CD requires additional setup

### 📁 File Structure

```
datetime-k8s/
├── .env                 # Real secrets (NOT committed to Git!)
├── .env.example         # Template (committed to Git)
├── .gitignore           # .env listed here
└── Makefile             # Reads from .env
```

### 📝 .env File

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

### 🔧 Makefile Integration

```makefile
# Load .env file
-include .env
export

vault-setup: vault-unseal
	@echo "Reading secrets from .env file..."
	@if [ ! -f ".env" ]; then \
		echo "❌ ERROR: .env file not found!"; \
		echo "Please copy .env.example: cp .env.example .env"; \
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

## Level 2: YAML File Approach

### 📁 File Structure

```
datetime-k8s/
├── secrets.yaml         # Real secrets (NOT committed to Git!)
├── secrets.yaml.example # Template (committed to Git)
└── Makefile             # Reads from secrets.yaml
```

### 📝 secrets.yaml

```yaml
# secrets.yaml (NOT committed to Git!)
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

### 🔧 Makefile Integration

```makefile
vault-setup:
	@if [ ! -f "secrets.yaml" ]; then \
		echo "❌ secrets.yaml not found!"; \
		echo "Copy secrets.yaml.example"; \
		exit 1; \
	fi
	# Read from YAML and write to Vault
	CSHARP_DB_URL=$$(yq eval '.csharp.database_url' secrets.yaml); \
	kubectl exec -n vault vault-0 -- vault kv put secret/datetime/api-csharp \
		database_url="$$CSHARP_DB_URL"
```

---

## Level 3: Production-Ready Approach

### 🏗️ Architecture

```
Developer Laptop (.env)
    ↓
Git Push (code, no secrets)
    ↓
CI/CD Pipeline (GitHub Actions, GitLab CI)
    ↓
CI/CD Secrets (GitHub Secrets, GitLab Variables)
    ↓
Staging Vault (Test environment)
    ↓
Manual Approval Gate
    ↓
Production Vault (HA Cluster)
    ↓
Kubernetes Secrets (External Secrets Operator)
    ↓
Application Pods
```

### 🔐 Environment-Based Secret Management

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

# Development: Use .env
vault-setup-dev:
	@source .env && vault kv put secret/dev/app ...

# Staging: Use CI/CD variables
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
# Development: Everyone can access
path "secret/data/datetime/development/*" {
  capabilities = ["read", "list", "create", "update"]
}

# Staging: Only CI/CD and senior devs
path "secret/data/datetime/staging/*" {
  capabilities = ["read", "list"]
}

# Production: Only Ops team
path "secret/data/datetime/production/*" {
  capabilities = ["read"]
}
```

### 🔄 Automatic Secret Rotation

```makefile
vault-rotate-jwt:
	@echo "Rotating JWT secret..."
	@NEW_JWT=$$(openssl rand -base64 32)
	@vault kv patch secret/datetime/production/api-csharp \
		jwt_secret="$$NEW_JWT"
	@kubectl rollout restart deployment/datetime-api-csharp
	@echo "$$(date) | JWT rotated" >> audit.log
```

---

## Current Implementation

This project uses **Level 1** implementation.

### ✅ What Was Done

1. ✅ Created `.env` file with current secret values
2. ✅ Created `.env.example` template
3. ✅ Added `.env` to `.gitignore`
4. ✅ Updated Makefile to read from `.env`
5. ✅ Removed hard-coded secrets from Makefile

### 📁 Project Files

```
datetime-k8s/
├── .env                          # ← NEW: Real secrets
├── .env.example                  # ← NEW: Template
├── .gitignore                    # ← UPDATED: Added .env
├── Makefile                      # ← UPDATED: Reads from .env
├── vault-keys.json               # ← Vault unseal keys (not committed)
├── docs/
│   ├── SECRET_MANAGEMENT.md      # ← Turkish version
│   ├── SECRET_MANAGEMENT.en.md   # ← This file
│   └── VAULT.md                  # ← Detailed Vault docs
└── k8s/
    ├── vault-deployment.yaml     # ← Vault pod definition
    └── external-secrets.yaml     # ← External Secrets config
```

### 🔐 Secret Flow

```
1. Developer creates .env file
   ├─ cp .env.example .env
   └─ nano .env  (enter real values)

2. Run make setup-vault
   ├─ Makefile reads .env
   └─ Writes secrets to Vault

3. External Secrets Operator
   ├─ Pulls secrets from Vault
   └─ Creates Kubernetes Secret

4. Application Pods
   ├─ Get env vars from Kubernetes Secret
   └─ Application runs
```

---

## Usage Guide

### 🚀 Initial Setup (New Developer)

```bash
# 1. Clone repo
git clone <repo-url>
cd datetime-k8s

# 2. Create .env file
cp .env.example .env

# 3. Edit .env file
nano .env
# or
code .env

# 4. Enter real secret values
# - Database passwords
# - API keys
# - JWT secrets
# - Redis URLs

# 5. Setup Vault
make setup-vault

# 6. Deploy entire system
make deploy
```

### 🔄 Existing Usage

```bash
# Setup Vault and write secrets (reads from .env)
make setup-vault

# Check Vault status
make vault-status

# View secrets in Vault
make vault-secrets

# Deploy
make deploy
```

### ✏️ Updating Secrets

```bash
# 1. Edit .env file
nano .env
# Example: Change CSHARP_DB_URL

# 2. Update Vault
make vault-setup

# 3. Wait for ExternalSecret sync (1 hour) or force sync
kubectl annotate externalsecret datetime-api-csharp-secrets \
  force-sync=$(date +%s) --overwrite

# 4. Restart pods (to get new secrets)
kubectl rollout restart deployment datetime-api-csharp
```

### 🔍 Verifying Secrets

```bash
# 1. Check if secrets exist in Vault
ROOT_TOKEN=$(jq -r '.root_token' vault-keys.json)
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN
kubectl exec -n vault vault-0 -- vault kv get secret/datetime/api-csharp

# 2. Check if Kubernetes Secret was created
kubectl get secret datetime-api-csharp-secrets

# 3. View secret contents (base64 decoded)
kubectl get secret datetime-api-csharp-secrets -o json | \
  jq '.data | map_values(@base64d)'

# 4. Check if pods see secrets
kubectl exec deployment/datetime-api-csharp -- env | grep TIMEZONE
```

---

## Troubleshooting

### ❌ Problem: .env file not found

**Error:**
```
❌ ERROR: .env file not found!
Please copy .env.example: cp .env.example .env
```

**Solution:**
```bash
cp .env.example .env
nano .env  # Enter real values
```

---

### ❌ Problem: Secrets not written to Vault

**Error:**
```
Error writing data to secret/datetime/api-csharp: permission denied
```

**Solution 1: Check Vault login**
```bash
ROOT_TOKEN=$(jq -r '.root_token' vault-keys.json)
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN
```

**Solution 2: Is Vault sealed?**
```bash
make vault-status
# If Sealed: true
make vault-unseal
```

**Solution 3: Check policy**
```bash
kubectl exec -n vault vault-0 -- vault policy read datetime-app
```

---

### ❌ Problem: .env variables empty in Makefile

**Error:**
```
timezone="" log_level=""  # Empty values!
```

**Solution 1: Is .env exported?**
```makefile
# Should be at the beginning of Makefile
-include .env
export
```

**Solution 2: Correct variable syntax?**
```makefile
# WRONG
timezone="$CSHARP_TIMEZONE"  # Single $ in Makefile

# CORRECT
timezone="$$CSHARP_TIMEZONE"  # Double $$ in shell commands
```

**Solution 3: Manual test**
```bash
source .env
echo $CSHARP_TIMEZONE  # Should show value
```

---

### ❌ Problem: Git trying to commit .env

**Error:**
```bash
git add .
# .env file being staged!
```

**Solution 1: Check .gitignore**
```bash
cat .gitignore | grep ".env"
# Should contain .env
```

**Solution 2: Clear Git cache**
```bash
git rm --cached .env
git commit -m "Remove .env from git"
```

**Solution 3: Commit .gitignore**
```bash
git add .gitignore
git commit -m "Add .env to .gitignore"
```

---

### ❌ Problem: ExternalSecret not syncing

**Error:**
```bash
kubectl get externalsecret
# STATUS: SecretSyncedError
```

**Solution 1: Check secret path**
```bash
# Does secret exist in Vault?
kubectl exec -n vault vault-0 -- vault kv get secret/datetime/api-csharp
```

**Solution 2: Check SecretStore**
```bash
kubectl describe secretstore vault-backend
# Status should be: Valid
```

**Solution 3: Force sync**
```bash
kubectl annotate externalsecret datetime-api-csharp-secrets \
  force-sync=$(date +%s) --overwrite
```

**Solution 4: Check External Secrets Operator logs**
```bash
kubectl logs -n external-secrets deployment/external-secrets
```

---

## Security Checklist

### ✅ Before Commit

- [ ] Is `.env` in `.gitignore`?
- [ ] Is `vault-keys.json` in `.gitignore`?
- [ ] No hard-coded secrets? (Makefile, YAML, code)
- [ ] Is `.env.example` up to date?
- [ ] No real values in `.env.example`?

### ✅ Vault Security

- [ ] Is Vault unsealed?
- [ ] Is root token secure? (vault-keys.json chmod 600)
- [ ] Do policies follow least privilege?
- [ ] Is audit logging enabled?
- [ ] Does each API only access its own secrets?

### ✅ Kubernetes Security

- [ ] Is ServiceAccount datetime-app created?
- [ ] Is RBAC configured correctly?
- [ ] Does ExternalSecret use correct SecretStore?
- [ ] Is secret refresh interval appropriate? (default: 1h)
- [ ] Do pods use correct secrets?

### ✅ Production Readiness

- [ ] Different secrets for different environments?
- [ ] Secret rotation plan in place?
- [ ] Backup strategy defined?
- [ ] Disaster recovery plan documented?
- [ ] Incident response plan ready?

---

## Comparison Table

| Feature | Level 1 (.env) | Level 2 (YAML) | Level 3 (Production) |
|---------|----------------|----------------|---------------------|
| **Simplicity** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Security** | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Environment Separation** | ❌ | ⚠️ Partial | ✅ Full |
| **CI/CD Integration** | ⚠️ Manual | ⚠️ Manual | ✅ Automatic |
| **Audit Logging** | ❌ | ❌ | ✅ |
| **Secret Rotation** | ⚠️ Manual | ⚠️ Manual | ✅ Automatic |
| **Access Control** | ❌ | ❌ | ✅ RBAC |
| **Setup Time** | 5 minutes | 10 minutes | 2-3 hours |
| **Maintenance Cost** | Low | Medium | High |
| **Recommended For** | Development | Development/Staging | Production |

---

## Resources

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [External Secrets Operator](https://external-secrets.io/)
- [Kubernetes Secrets Best Practices](https://kubernetes.io/docs/concepts/security/secrets-good-practices/)
- [12-Factor App: Config](https://12factor.net/config)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

---

## Summary

✅ This project uses **Level 1 (.env file)** approach.

✅ Secrets stored in `.env` file and **NOT committed to Git**.

✅ Makefile reads from `.env` and writes to Vault.

✅ Vault secrets converted to Kubernetes Secrets via External Secrets Operator.

✅ Application pods receive secrets as environment variables.

🔒 **Best practices implemented!**

---

**Last Updated:** 2025-11-09
**Version:** 1.0
