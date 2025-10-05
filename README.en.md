![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![.NET](https://img.shields.io/badge/.NET-512BD4?style=for-the-badge&logo=dotnet&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![NGINX](https://img.shields.io/badge/NGINX-009639?style=for-the-badge&logo=nginx&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)

<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](README.en.md) | 🇹🇷 [Türkçe](README.md) |
| :------------------------: | :--------------------: |

</div>

---

# DateTime Kubernetes Application

Complete Kubernetes deployment solution for .NET 9 Minimal API and Nginx web application.

## 🎯 What is This Project For?

This project is **not production-ready**. It is designed for the following purposes:

### ✅ Use Cases

- **📚 Learning**: Learn Kubernetes concepts (pods, services, ingress, multi-node) through hands-on practice
- **🔬 Testing**: Test new Kubernetes configurations in a safe environment
- **💻 Local Development**: Develop and debug applications in a production-like environment
- **🎓 Education**: Use for Kubernetes workshops and training materials
- **🧪 Simulation**: Simulate production scenarios like multi-node clusters and load balancing

### ❌ What's Missing for Production

<details>
<summary><b>What do you need for a real production environment?</b></summary>

**Security**:
- ❌ No HTTPS/TLS certificates
- ❌ No secret management (Vault, Sealed Secrets)
- ❌ No network policies
- ❌ No RBAC (Role-Based Access Control) configuration
- ❌ No Pod Security Standards

**High Availability**:
- ❌ Single control-plane (need at least 3 for HA)
- ❌ No persistent storage (PV/PVC) strategy
- ❌ No backup/restore mechanism
- ❌ No disaster recovery plan

**Monitoring & Observability**:
- ❌ No Prometheus/Grafana monitoring
- ❌ No centralized logging (ELK, Loki)
- ❌ No distributed tracing (Jaeger, Tempo)
- ❌ No alerting mechanism

**Infrastructure**:
- ❌ Need real cluster instead of Kind (EKS, GKE, AKS, on-prem)
- ❌ No cloud load balancer integration
- ❌ No auto-scaling (HPA, VPA, Cluster Autoscaler)
- ❌ Missing resource limits and requests
- ❌ No Quality of Service (QoS) configuration

**CI/CD & Deployment**:
- ❌ No automated testing pipeline
- ❌ No container registry integration (Docker Hub, ECR, GCR)
- ❌ No GitOps (ArgoCD, Flux)
- ❌ No blue-green or canary deployment strategy
- ❌ No rollback mechanism

</details>

> **💡 Note**: This project provides a **production-like development environment**. For actual production use, all the above gaps must be addressed.

---

## ✨ Features

- 🚀 **Multi-Node Kubernetes Cluster**: 1 Control-Plane + 2 Worker Nodes
- ⚡ **Automated Deployment**: Full setup with a single command (`make deploy`)
- 🔧 **Mac Optimized**: Automatic fixes for hostNetwork and webhook issues
- 📦 **Kind Integration**: Local Kubernetes cluster (running in Docker)
- 🌐 **Ingress Support**: http://api.local and http://web.local
- 🐳 **Docker Build**: Automated image building and loading
- 🎯 **Makefile Commands**: 25+ ready-to-use commands
- 📊 **Monitoring**: Log tracking, status checks
- 🔄 **Scaling**: Easy replica management
- 🧪 **Testing**: Automated endpoint testing

## 📸 Screenshots

### Web Application

![Web Application](screenshots/web-app.png)

_DateTime web application - Turkish date and time display_

### API Response

![API Response](screenshots/api-response.png)

_REST API JSON response_

### Docker Desktop - Kubernetes

![Docker Desktop](screenshots/docker-desktop.png)

_Kind cluster running on Docker Desktop_

### Terminal - Deployment Success

## 📋 Deployment Output

<details>
<summary><b>🚀 Click to See Full Deployment Output</b> (all steps of make deploy command)</summary>

```bash
🚀 Checking Kind cluster...
No kind clusters found.
Creating Kind cluster (1 control-plane + 2 workers)...
✓ Using existing kind-config.yaml
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.34.0) 🖼
 ✓ Preparing nodes 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
✓ Multi-node Kind cluster created

📥 Checking NGINX Ingress Controller...
Installing NGINX Ingress Controller (Kind optimized)...
✓ NGINX Ingress Controller installed

🔧 Checking Ingress configuration...
✓ hostNetwork setting fixed
✓ Ingress Controller moved to control-plane

🔨 Building API image...
✓ API image created

🔨 Building Web image...
✓ Web image created

📦 Loading images to Kind cluster...
✓ Images loaded

📦 Applying Kubernetes resources...
✓ API deployment applied
✓ Web deployment applied
✓ Ingress applied

⏳ Waiting for deployments to be ready...
✓ All deployments ready

======================================
🎉 Deployment completed! 🎉
======================================

⏱️  Total Time: 1 minute 45 seconds

📊 Status Information:
NAME                            READY   STATUS    RESTARTS   AGE
datetime-api-7c496c6d89-xxxxx   1/1     Running   0          10s
datetime-api-7c496c6d89-yyyyy   1/1     Running   0          10s
datetime-web-567d9789cd-xxxxx   1/1     Running   0          10s
datetime-web-567d9789cd-yyyyy   1/1     Running   0          10s

======================================
🌐 Application Access:
======================================
  Web Application: http://web.local
  API: http://api.local/api/datetime
```

**Deployment Time:** M1-Max (32 GB)

- First deployment: ~2-2.5 minutes
- With cached build: ~1 minute 45 seconds ✅

**Created Resources:**

- ✅ Multi-node Kubernetes cluster (1 control-plane + 2 workers)
- ✅ NGINX Ingress Controller (on control-plane)
- ✅ 2x datetime-api pods (on worker nodes)
- ✅ 2x datetime-web pods (on worker nodes)
- ✅ Services and Ingress configuration

</details>

## ⚡ TL;DR (Quick Start)

### Using Shell Script

```bash
# 1. Create project directory
mkdir -p datetime-k8s/{api,web,k8s}

# 2. Run setup script (optional - just shows directory structure)
chmod +x setup-project.sh
./setup-project.sh

# 3. Copy all files to respective folders

# 4. Enter project directory
cd datetime-k8s

# 5. Make scripts executable
chmod +x *.sh

# 6. Deploy!
./deploy.sh

# 7. Test (optional)
./verify-deployment.sh

# 8. Open in browser
open http://web.local
```

### Using Makefile (Recommended! 🎯)

```bash
# 1. Create project directory and place files
mkdir -p datetime-k8s/{api,web,k8s}

# 2. Copy all files to respective folders:
#    - Makefile -> datetime-k8s/
#    - api/* -> datetime-k8s/api/
#    - web/* -> datetime-k8s/web/
#    - k8s/* -> datetime-k8s/k8s/
#    - *.yaml, *.sh -> datetime-k8s/

# 3. Enter project directory
cd datetime-k8s

# 4. Check directory structure (optional)
make setup

# 5. Deploy with a single command!
make deploy

# 6. Verify
make verify

# 7. Open in browser
open http://web.local
```

**That's it!** 🎉 The application is up and running.

---

## 📁 Project Structure

```
datetime-k8s/
├── api/                               # .NET 9 API
│   ├── Program.cs                     # .NET 9 Minimal API
│   ├── DateTimeApi.csproj             # Project file
│   └── Dockerfile.api                 # API Docker image
├── web/                               # Nginx Web App
│   ├── index.html                     # Web UI (Vanilla JS)
│   ├── nginx.conf                     # Nginx configuration
│   └── Dockerfile.web                 # Web Docker image
├── k8s/                               # Kubernetes Manifests
│   ├── api-deployment.yaml            # API Deployment + Service
│   ├── web-deployment.yaml            # Web Deployment + Service
│   ├── kind-config.yaml               # ⚙️ Kind cluster config (multi-node)
│   ├── ingress.yaml                   # Ingress (api.local, web.local)
│   └── ingress-nginx-deployment.yaml  # 🆕 Ingress Controller (Kind optimized)
├── docs/                              # Documents
│   ├── CHANGES_SUMMARY.en.md          # 📄 Summary of changes
│   ├── INGRESS_CONTROLLER_FIX.en.md   # 📘 Ingress fix methods
│   ├── INGRESS_ROUTING.en.md          # 📘 Ingress routing explanation
│   ├── INGRESS_SETUP.en.md            # 📘 Ingress setup guide
│   ├── LOAD_BALANCING.en.md           # 📘 Load balancing strategies
│   ├── PROJECT_SUMMARY.en.md          # 📘 Summary of components and key points
│   ├── QUICK_START.en.md              # 📘 Setup, deploy, test and other operations
│   ├── TROUBLESHOOTING.en.md          # 📘 Troubleshooting guide
│   └── WORKER_NODES.en.md             # 📘 Multi-node cluster guide
├── Makefile                           # 🎯 Main automation (RECOMMENDED!)
├── deploy.sh                          # 🚀 Deployment script
├── verify-deployment.sh               # 🔍 Verification and test script
├── fix-ingress.sh                     # 🔧 hostNetwork fix
├── fix-webhooks.sh                    # 🔧 Webhook cleanup
├── patch-ingress-controller.sh        # 🔧 Ingress patch
├── setup-project.sh                   # 📁 Directory structure creation
├── CONTRIBUTING.en.md                 # 📖 How to contribute?
└── README.en.md                       # 📖 Main documentation
```

### 📜 Script and Makefile Comparison

| Feature           | Makefile                         | Shell Scripts             |
| ----------------- | -------------------------------- | ------------------------- |
| Ease of Use       | ⭐⭐⭐⭐⭐ `make deploy`         | ⭐⭐⭐⭐ `./deploy.sh`    |
| Modularity        | ⭐⭐⭐⭐⭐ Each command separate | ⭐⭐⭐ Monolithic         |
| Error Handling    | ⭐⭐⭐⭐⭐ Automatic             | ⭐⭐⭐⭐ Manual           |
| Advanced Features | ⭐⭐⭐⭐⭐ Scale, restart, etc.  | ⭐⭐⭐ Basic operations   |
| Learning Curve    | ⭐⭐⭐ Makefile knowledge        | ⭐⭐⭐⭐ Bash knowledge   |
| Multi-Node        | ✅ Auto config creation          | ✅ Manual config required |

### 📜 Script Descriptions

| Script                   | Function                     | Usage Frequency      |
| ------------------------ | ---------------------------- | -------------------- |
| **deploy.sh**            | Full deployment from scratch | Once (initial setup) |
| **verify-deployment.sh** | Status check and test        | Always (for testing) |
| **fix-ingress.sh**       | For hostNetwork issue        | As needed            |
| **fix-webhooks.sh**      | For webhook issue            | As needed            |

### 📄 Configuration File

| File                 | Function                                                 | Auto-created?                                        |
| -------------------- | -------------------------------------------------------- | ---------------------------------------------------- |
| **kind-config.yaml** | Kind cluster configuration (1 control-plane + 2 workers) | ✅ Yes (with `make create-cluster` or `make deploy`) |

**Note**: If `kind-config.yaml` doesn't exist, Makefile will create it automatically. For more info, see [WORKER_NODES](WORKER_NODES.en.md).

### 🎯 Quick Reference

**Makefile Commands** (full list with make help):

- Deployment: `make deploy`, `make redeploy`, `make clean-all`
- Monitoring: `make status`, `make show-nodes`, `make logs-api`, `make verify`
- Debugging: `make fix-ingress`, `make fix-webhooks`, `make test`
- Scaling: `make scale-api REPLICAS=3`, `make restart-api`
- Build: `make build-all`, `make quick-update`

**Shell Scripts**:

- Full Deploy: `./deploy.sh`
- Verify: `./verify-deployment.sh`
- Fix: `./fix-ingress.sh`, `./fix-webhooks.sh`
- Setup: `./setup-project.sh`

## 🚀 Quick Start

### Prerequisites

- Docker
- Kind (Kubernetes in Docker)
- kubectl

### Installation Commands

```bash
# 1. Install Kind (if not already installed)
# macOS
brew install kind

# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# 2. Install kubectl (if not already installed)
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# 3. Clone the project or create files
mkdir -p datetime-k8s/{api,web,k8s}
cd datetime-k8s
```

## 📜 Script Usage Order and Descriptions

The project has 4 scripts used for different purposes. Here's the usage order:

### 🎯 Normal Setup Flow (First-Time Installation)

```bash
# STEP 1: Make all scripts executable
chmod +x deploy.sh fix-ingress.sh fix-webhooks.sh verify-deployment.sh

# STEP 2: Run the main deployment script (ONE COMMAND IS ENOUGH!)
./deploy.sh
```

**What does `deploy.sh` do?**

- ✅ Creates Kind cluster
- ✅ Installs NGINX Ingress Controller
- ✅ Automatically fixes hostNetwork setting
- ✅ Automatically cleans admission webhooks
- ✅ Builds Docker images
- ✅ Loads images to Kind
- ✅ Deploys Kubernetes resources
- ✅ Updates /etc/hosts file
- ✅ Verifies everything works

```bash
# STEP 3 (OPTIONAL): Verify
./verify-deployment.sh
```

**What does `verify-deployment.sh` do?**

- 🔍 Checks cluster status
- 🔍 Tests all deployments
- 🔍 Verifies Ingress configuration
- 🔍 Tests endpoints
- 🔍 Checks hostNetwork and webhook settings
- 📊 Provides detailed report

### 🔧 Troubleshooting Scenarios

**Scenario 1: Only Ingress hostNetwork issue**

```bash
./fix-ingress.sh
```

**What does `fix-ingress.sh` do?**

- 🔧 Only checks NGINX Ingress Controller
- 🔧 Sets hostNetwork to true
- 🔧 Restarts controller

**Scenario 2: Only Admission Webhook issue**

```bash
./fix-webhooks.sh
```

**What does `fix-webhooks.sh` do?**

- 🔧 Deletes ValidatingWebhookConfiguration
- 🔧 Cleans webhook jobs
- 🔧 Deletes webhook pods

**Scenario 3: Start everything from scratch**

```bash
# First cleanup
kind delete cluster
kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission 2>/dev/null || true

# Then redeploy
./deploy.sh
```

**Scenario 4: Check if everything works**

```bash
./verify-deployment.sh
```

### 📊 Summary Table

| Script                 | When to Use              | Priority     | Auto-fix                 |
| ---------------------- | ------------------------ | ------------ | ------------------------ |
| `deploy.sh`            | Initial setup / Redeploy | 🥇 Primary   | ✅ hostNetwork + webhook |
| `verify-deployment.sh` | Status check / Test      | 🥈 Secondary | ❌ Report only           |
| `fix-ingress.sh`       | Only hostNetwork issue   | 🔧 Special   | ✅ hostNetwork           |
| `fix-webhooks.sh`      | Only webhook issue       | 🔧 Special   | ✅ Webhooks              |

### ⚡ Quick Commands

```bash
# One-command full setup
chmod +x *.sh && ./deploy.sh

# Post-deployment test
./verify-deployment.sh

# Fix individual issues
./fix-ingress.sh    # For hostNetwork
./fix-webhooks.sh   # For Webhooks

# Clean everything and start over
kind delete cluster && ./deploy.sh
```

## 🎯 Deployment

### ✨ Deployment with Makefile (Recommended! 🎯)

```bash
# View all commands
make help

# Full deployment with one command
make deploy

# Verify deployment
make verify

# Status information
make status
```

#### Makefile Main Commands

| Command          | Description                        |
| ---------------- | ---------------------------------- |
| `make help`      | Lists all commands                 |
| `make deploy`    | **Full deployment (MAIN CMD)**     |
| `make verify`    | Verifies deployment                |
| `make test`      | Tests endpoints                    |
| `make status`    | Shows cluster status               |
| `make logs-api`  | Follows API logs                   |
| `make logs-web`  | Follows Web logs                   |
| `make clean`     | Deletes K8s resources              |
| `make clean-all` | Deletes everything (incl. cluster) |
| `make redeploy`  | Completely redeploys               |

#### Makefile Advanced Commands

| Command                     | Description              |
| --------------------------- | ------------------------ |
| `make build-api`            | Builds only API image    |
| `make build-web`            | Builds only Web image    |
| `make build-all`            | Builds all images        |
| `make create-cluster`       | Creates Kind cluster     |
| `make install-ingress`      | Installs NGINX Ingress   |
| `make fix-ingress`          | Fixes hostNetwork        |
| `make fix-webhooks`         | Cleans webhooks          |
| `make scale-api REPLICAS=3` | Scales API to 3 replicas |
| `make scale-web REPLICAS=3` | Scales Web to 3 replicas |
| `make restart-api`          | Restarts API             |
| `make restart-web`          | Restarts Web             |
| `make quick-update`         | Updates only images      |

### ✨ Deployment with Shell Script (Alternative)

```bash
# Make scripts executable
chmod +x deploy.sh fix-ingress.sh fix-webhooks.sh verify-deployment.sh

# Run full deployment
./deploy.sh

# Verification (optional)
./verify-deployment.sh
```

That's it! 🎉 `deploy.sh` handles everything automatically.

### 🛠️ Manual Deployment (Step by Step)

If you want to do each step manually:

```bash
# 1. Create Kind cluster (using kind-config.yaml)
kind create cluster --config=kind-config.yaml

# OR with inline config:
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
  labels:
    worker-group: group-1
- role: worker
  labels:
    worker-group: group-2
EOF

# 2. Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for Ingress Controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# 3. Build Docker images
cd api
docker build -t datetime-api:latest -f Dockerfile.api .
cd ../web
docker build -t datetime-web:latest -f Dockerfile.web .
cd ..

# 4. Load images to Kind
kind load docker-image datetime-api:latest
kind load docker-image datetime-web:latest

# 5. Apply Kubernetes resources
kubectl apply -f k8s/api-deployment.yaml
kubectl apply -f k8s/web-deployment.yaml
kubectl apply -f k8s/ingress.yaml

# 6. Update /etc/hosts file
echo "127.0.0.1 api.local web.local" | sudo tee -a /etc/hosts
```

## 🌐 Access

- **Web Application**: http://web.local
- **API Endpoint**: http://api.local/api/datetime
- **Health Check**: http://api.local/health

## 📊 Monitoring and Debug

### Using Makefile (Recommended)

```bash
# View logs
make logs              # All logs (last 50 lines)
make logs-api          # Follow API logs (real-time)
make logs-web          # Follow Web logs (real-time)

# Status check
make status            # General status
make verify            # Detailed verification

# Test
make test              # Endpoint tests
```

#### Using kubectl (Manual)

```bash
# View Pods
kubectl get pods
kubectl get pods -o wide
kubectl get pods -w  # watch mode

# Examine Logs
kubectl logs -l app=datetime-api -f
kubectl logs -l app=datetime-web -f
kubectl logs <pod-name> -f

# Check Services
kubectl get services
kubectl describe service datetime-api-service
kubectl describe service datetime-web-service

# Ingress Status
kubectl get ingress
kubectl describe ingress datetime-ingress

# Port Forward (for testing)
kubectl port-forward service/datetime-api-service 8080:80
kubectl port-forward service/datetime-web-service 8081:80
```

## 🧪 Test Commands

### Using Makefile (Recommended)

```bash
# Automated endpoint tests
make test

# Manual tests
curl http://api.local/api/datetime
curl http://api.local/health
curl http://web.local
```

### Manual Tests

```bash
# API test
curl http://api.local/api/datetime
curl http://api.local/health

# Web test
curl http://web.local

# Detailed test
curl -v http://api.local/api/datetime

# JSON format
curl -s http://api.local/api/datetime | jq .
```

## 🔧 Scaling

### Using Makefile (Recommended)

```bash
# Scale API
make scale-api REPLICAS=3

# Scale Web
make scale-web REPLICAS=5

# Restart deployments
make restart-api
make restart-web

# Check status
make status
```

### Using kubectl (Manual)

```bash
# Scale API
kubectl scale deployment datetime-api --replicas=3

# Scale Web
kubectl scale deployment datetime-web --replicas=3

# Check status
kubectl get pods -l app=datetime-api
```

## 🗑️ Cleanup

### Using Makefile (Recommended)

```bash
# Delete only Kubernetes resources (cluster remains)
make clean

# Delete cluster as well
make clean-cluster

# Delete everything
make clean-all

# Clean and redeploy
make redeploy
```

### Using Shell Script / Manual

```bash
# Delete resources
kubectl delete -f k8s/api-deployment.yaml
kubectl delete -f k8s/web-deployment.yaml
kubectl delete -f k8s/ingress.yaml

# Delete Kind cluster
kind delete cluster

# Clean /etc/hosts (manual)
sudo nano /etc/hosts
# Delete api.local and web.local lines
```

## 🔧 Troubleshooting

### Quick Fixes with Makefile

```bash
# Verify entire system
make verify

# Fix only ingress issue
make fix-ingress

# Fix only webhook issue
make fix-webhooks

# Restart deployments
make restart-api
make restart-web

# Check logs
make logs-api
make logs-web

# Complete redeploy
make redeploy
```

### Recreating Kind Cluster

```bash
# Using Makefile
make clean-cluster
make create-cluster

# Manual
kind delete cluster
kind create cluster --config=kind-config.yaml

# OR auto-create with deploy.sh
./deploy.sh
```

### Mac Ingress hostNetwork Issue

On Mac with Kind, NGINX Ingress Controller might be configured for cloud environments without `hostNetwork: true`. In this case:

```bash
# Using Makefile (Recommended)
make fix-ingress

# Using shell script
chmod +x fix-ingress.sh
./fix-ingress.sh

# Manual check
kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.template.spec.hostNetwork}'

# Manual fix
kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '{"spec":{"template":{"spec":{"hostNetwork":true}}}}'
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx
```

### Mac Problematic Admission Webhooks Issue

NGINX Ingress Controller's ValidatingWebhookConfiguration can cause "connection refused" or "context deadline exceeded" errors on Mac/Kind. These webhooks are unnecessary in Kind cluster:

```bash
# Using Makefile (Recommended)
make fix-webhooks

# Using shell script
chmod +x fix-webhooks.sh
./fix-webhooks.sh

# Manual cleanup
kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission
kubectl delete jobs -n ingress-nginx ingress-nginx-admission-create ingress-nginx-admission-patch

# Verify webhooks are deleted
kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io | grep ingress
```

**Note:** `make deploy` or `deploy.sh` automatically fixes this issue.

### Pods not starting

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Ingress not working

```bash
kubectl get ingress
kubectl describe ingress datetime-ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Check Ingress Controller pod
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx <ingress-controller-pod-name>
```

### CORS errors

Check CORS annotations in Ingress:

```yaml
nginx.ingress.kubernetes.io/enable-cors: "true"
nginx.ingress.kubernetes.io/cors-allow-origin: "*"
```

### DNS not resolving

Check /etc/hosts file:

```bash
cat /etc/hosts | grep local
```

For detailed troubleshooting, see [TROUBLESHOOTING](docs/TROUBLESHOOTING.en.md)

## 📝 Notes

- **Image Pull Policy**: `imagePullPolicy: Never` is set for Kind
- **Replicas**: 2 replicas run for each service by default
- **Multi-Node Cluster**: Uses 1 control-plane + 2 worker nodes configuration by default
  - Control-plane: Kubernetes management components and Ingress Controller
  - Worker nodes: Application pods (datetime-api, datetime-web)
  - For details: [WORKER_NODES](WORKER_NODES.en.md)
- **Mac Optimization**: `make deploy` or `deploy.sh` automatically fixes Mac/Kind issues:
  - Sets hostNetwork to true
  - Cleans up problematic admission webhooks
- **Makefile vs Shell Scripts**:
  - **Makefile recommended**: More modular, flexible and powerful
  - **Auto-creates kind-config.yaml**: If file doesn't exist, `make create-cluster` creates it
  - Shell scripts: Alternative method, monolithic approach
- **Command Priority**: `make deploy` > `deploy.sh`

## 🎓 Usage Guide

### Which Method to Use?

#### Makefile (Recommended! 🎯)

**Advantages:**

- ✅ Individual operations possible (`make build-api`, `make scale-api`)
- ✅ Better error handling
- ✅ Advanced features (scale, restart, quick-update)
- ✅ Each command runs independently
- ✅ Colorized and better output

**Usage:**

```bash
make deploy                # Initial setup
make verify                # Check
make logs-api              # Log monitoring
make scale-api REPLICAS=3  # Scaling
```

#### Shell Scripts (Alternative)

**Advantages:**

- ✅ Single file, single command
- ✅ Bash knowledge sufficient
- ✅ Simple and understandable

**Usage:**

```bash
./deploy.sh             # Initial setup
./verify-deployment.sh  # Check
./fix-ingress.sh        # Fix
```

### Scenarios

**Scenario 1: Initial Setup**

```bash
# Make sure you're in the project directory first!
cd datetime-k8s

# Makefile (Recommended)
make setup    # Check if files are in place
make deploy   # Deploy
make verify   # Verify

# Shell Script
chmod +x *.sh
./deploy.sh
./verify-deployment.sh
```

**Scenario 2: Code Changes**

```bash
# Make sure you're in the project directory
cd datetime-k8s

# Makefile (Fast)
make quick-update

# Manual
cd api && docker build -t datetime-api:latest -f Dockerfile.api . && cd ..
kind load docker-image datetime-api:latest
kubectl rollout restart deployment datetime-api
```

**Scenario 3: Troubleshooting**

```bash
# Make sure you're in the project directory
cd datetime-k8s

# Makefile
make verify          # Identify problem
make fix-ingress     # or make fix-webhooks
make logs-api        # Check logs

# Shell Script
./verify-deployment.sh
./fix-ingress.sh
kubectl logs -l app=datetime-api -f
```

**Scenario 4: Complete Restart**

```bash
# Make sure you're in the project directory
cd datetime-k8s

# Makefile (Fastest)
make redeploy

# Manual
kind delete cluster
./deploy.sh
```

## 📚 Documentation

- Quick Start: [QUICK_START](docs/QUICK_START.en.md)
- Troubleshooting: [TROUBLESHOOTING](docs/TROUBLESHOOTING.en.md)
- Network: [INGRESS_ROUTING](docs/INGRESS_ROUTING.en.md)
- Multi-node: [WORKER_NODES](docs/WORKER_NODES.en.md)

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING](CONTRIBUTING.en.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Kubernetes community
- Kind project
- NGINX Ingress Controller team

---

**Project Status**: ✅ Production-like development environment
**Platform**: Kubernetes (Kind)
**Test Status**: ✅ All tests passing
**Documentation**: ✅ Comprehensive

**Happy Coding! 🚀**
