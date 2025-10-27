![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![.NET](https://img.shields.io/badge/.NET-512BD4?style=for-the-badge&logo=dotnet&logoColor=white)
![Go](https://img.shields.io/badge/Go-00ADD8?style=for-the-badge&logo=go&logoColor=white)
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

Complete Kubernetes deployment solution for .NET 9 Minimal API, Go API, and Nginx web applications. Polyglot microservices architecture with C# and Go implementations.

## 🏗️ Architecture

![Architecture Overview](docs/diagrams/architecture-overview.png)

_Polyglot microservices with inter-service communication, circuit breaker, retry policy, and rate limiting_

**Featured Capabilities:**

- 🔄 **Circuit Breaker** - Automatic protection during failures
- 🔁 **Retry Policy** - Smart retry with exponential backoff
- ⏱️ **Rate Limiting** - Rate limiting with token bucket algorithm
- 🌐 **Service Discovery** - Automatic service discovery with Kubernetes DNS
- 🛡️ **Resiliency Patterns** - Production-ready resilience patterns

[📊 Click for detailed architecture diagrams →](docs/ARCHITECTURE.en.md)

## 📋 Table of Contents

1. [What is This Project For?](#-what-is-this-project-for)
2. [Features](#-features)
3. [Screenshots](#-screenshots)
4. [Deployment Output](#-deployment-output)
5. [TL;DR (Quick Start)](#-tldr-quick-start)
6. [Project Structure](#-project-structure)
7. [Quick Start](#-quick-start)
8. [Script Usage Order and Descriptions](#-script-usage-order-and-descriptions)
9. [Deployment](#-deployment)
10. [Access](#-access)
11. [Monitoring and Debug](#-monitoring-and-debug)
12. [Test Commands](#-test-commands)
13. [Scaling](#-scaling)
14. [Cleanup](#-cleanup)
15. [Troubleshooting](#-troubleshooting)
16. [Notes](#-notes)
17. [Usage Guide](#-usage-guide)
18. [Documentation](#-documentation)
19. [Contributing](#-contributing)
20. [License](#-license)
21. [Acknowledgments](#-acknowledgments)

---

## 🎯 What is This Project For?

This project is **not production-ready**. It is designed for the following purposes:

### ✅ Use Cases

- **📚 Learning**: Learn Kubernetes concepts (pods, services, ingress, multi-node) through hands-on practice
- **🔬 Testing**: Test new Kubernetes configurations in a safe environment
- **💻 Local Development**: Develop and debug applications in a production-like environment
- **🎓 Education**: Use for Kubernetes workshops and training materials
- **🧪 Simulation**: Simulate production scenarios like multi-node clusters and load balancing
- **🛡️ Resiliency Patterns**: Learn resilience patterns like circuit breaker, retry policy, and rate limiting
- **🔗 Service-to-Service Communication**: Test polyglot (C# + Go) microservices communication and service discovery
- **⚡ Performance Testing**: Try algorithms like token bucket and exponential backoff in a real environment

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

- ✅ 3 control-plane nodes (HA setup)
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

- 🚀 **Multi-Node Kubernetes Cluster**: 3 Control-Planes + 3 Worker Nodes (HA Setup)
- ⚡ **Automated Deployment**: Full setup with a single command (`make deploy`)
- 🔧 **Mac Optimized**: Automatic fixes for hostNetwork and webhook issues
- 📦 **Kind Integration**: Local Kubernetes cluster (running in Docker)
- 🌐 **Ingress Support**:
  - **C# Application**
    - **API URL:** `http://api-csharp.local`
    - **WebUI URL:** `http://web-csharp.local`
  - **Go Application**
    - **API URL:** `http://api-go.local`
    - **WebUI URL:** `http://web-go.local`
- 🐳 **Docker Build**: Automated image building and loading
- 🎯 **Makefile Commands**: 25+ ready-to-use commands
- 📊 **Monitoring**: Log tracking, status checks
- 🔄 **Scaling**: Easy replica management
- 🧪 **Testing**: Automated endpoint testing

## 📸 Screenshots

### Web Application for C# Rest API

![Web Application](screenshots/web-app-for-csharp-api.png)

_DateTime web application - Turkish date and time display_

### C# Rest API Health Endpoint

![API Response](screenshots/api-response-csharp.png)

_JSON response for C# Rest API Health Endpoint_

### Web Application for Go Rest API

![Web Application](screenshots/web-app-for-go-api.png)

_DateTime web application - Worldwide world clocks_

### Go Rest API Health Endpoint

![Go API Response](screenshots/api-response-go.png)

_JSON response for Go Rest API Health Endpoint_

### Docker Desktop - Kubernetes

![Docker Desktop](screenshots/docker-desktop.png)

_Kind cluster running on Docker Desktop_

### Terminal - Deployment Success

## 📋 Deployment Output

<details>
<summary><b>🚀 Click to See Full Deployment Output</b> (all steps of make deploy command)</summary>

```bash
⏱️  Deployment başlatılıyor...
🚀 Kind cluster kontrol ediliyor...
No kind clusters found.
Kind cluster oluşturuluyor (3 control-planes + 3 workers - HA setup)...
✓ k8s/kind-config.yaml mevcut, kullanılıyor
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.34.0) 🖼
 ✓ Preparing nodes 📦 📦 📦 📦 📦 📦
 ✓ Configuring the external load balancer ⚖️
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining more control-plane nodes 🎮
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Thanks for using kind! 😊
✓ Multi-node Kind cluster oluşturuldu

Cluster Node'ları:
NAME                  STATUS     ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION     CONTAINER-RUNTIME
kind-control-plane    Ready      control-plane   37s   v1.34.0   172.20.0.8    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-control-plane2   NotReady   control-plane   11s   v1.34.0   172.20.0.6    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-control-plane3   NotReady   control-plane   2s    v1.34.0   172.20.0.5    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker           NotReady   <none>          0s    v1.34.0   172.20.0.3    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker2          NotReady   <none>          1s    v1.34.0   172.20.0.4    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker3          NotReady   <none>          0s    v1.34.0   172.20.0.7    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
📥 NGINX Ingress Controller kontrol ediliyor...
NGINX Ingress Controller kuruluyor (Kind için optimize edilmiş)...
Özel ingress-nginx-deployment.yaml kullanılıyor...
namespace/ingress-nginx created
serviceaccount/ingress-nginx created
configmap/ingress-nginx-controller created
clusterrole.rbac.authorization.k8s.io/ingress-nginx created
clusterrolebinding.rbac.authorization.k8s.io/ingress-nginx created
role.rbac.authorization.k8s.io/ingress-nginx created
rolebinding.rbac.authorization.k8s.io/ingress-nginx created
service/ingress-nginx-controller created
deployment.apps/ingress-nginx-controller created
ingressclass.networking.k8s.io/nginx created
pod/ingress-nginx-controller-7f8d89bb7f-h2927 condition met
pod/ingress-nginx-controller-7f8d89bb7f-jjxxj condition met
pod/ingress-nginx-controller-7f8d89bb7f-lcjkk condition met
✓ NGINX Ingress Controller kuruldu
🔧 Ingress yapılandırması kontrol ediliyor...
hostNetwork ayarı düzeltiliyor...
deployment.apps/ingress-nginx-controller patched (no change)
deployment "ingress-nginx-controller" successfully rolled out
pod/ingress-nginx-controller-7f8d89bb7f-h2927 condition met
pod/ingress-nginx-controller-7f8d89bb7f-jjxxj condition met
pod/ingress-nginx-controller-7f8d89bb7f-lcjkk condition met
✓ hostNetwork ayarı düzeltildi

Ingress Controller Durumu:
NAME                                        READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
ingress-nginx-controller-7f8d89bb7f-h2927   1/1     Running   0          85s   172.20.0.7   kind-worker3   <none>           <none>
ingress-nginx-controller-7f8d89bb7f-jjxxj   1/1     Running   0          85s   172.20.0.3   kind-worker    <none>           <none>
ingress-nginx-controller-7f8d89bb7f-lcjkk   1/1     Running   0          85s   172.20.0.4   kind-worker2   <none>           <none>
🧹 Admission webhook'ları temizleniyor...
✓ Webhook'lar temizlendi
🔨 API imajı build ediliyor...
[+] Building 0.1s (15/15) FINISHED                                                                                                                    docker:desktop-linux
 => [internal] load build definition from Dockerfile.api                                                                                                              0.0s
 => => transferring dockerfile: 1.13kB                                                                                                                                0.0s
 => [internal] load metadata for mcr.microsoft.com/dotnet/aspnet:9.0                                                                                                  0.0s
 => [internal] load metadata for mcr.microsoft.com/dotnet/sdk:9.0                                                                                                     0.0s
 => [internal] load .dockerignore                                                                                                                                     0.0s
 => => transferring context: 2B                                                                                                                                       0.0s
 => [build 1/6] FROM mcr.microsoft.com/dotnet/sdk:9.0                                                                                                                 0.0s
 => [internal] load build context                                                                                                                                     0.0s
 => => transferring context: 70B                                                                                                                                      0.0s
 => [stage-1 1/3] FROM mcr.microsoft.com/dotnet/aspnet:9.0                                                                                                            0.0s
 => CACHED [stage-1 2/3] WORKDIR /app                                                                                                                                 0.0s
 => CACHED [build 2/6] WORKDIR /src                                                                                                                                   0.0s
 => CACHED [build 3/6] COPY DateTimeApi.csproj .                                                                                                                      0.0s
 => CACHED [build 4/6] RUN dotnet restore                                                                                                                             0.0s
 => CACHED [build 5/6] COPY Program.cs .                                                                                                                              0.0s
 => CACHED [build 6/6] RUN dotnet publish -c Release -o /app/publish                                                                                                  0.0s
 => CACHED [stage-1 3/3] COPY --from=build /app/publish .                                                                                                             0.0s
 => exporting to image                                                                                                                                                0.0s
 => => exporting layers                                                                                                                                               0.0s
 => => writing image sha256:b0738cd9536fdc63210c05f13954a8c77673eff7f92c74014699def6a3c46477                                                                          0.0s
 => => naming to docker.io/library/datetime-api-csharp:latest                                                                                                                0.0s

View build details: docker-desktop://dashboard/build/desktop-linux/desktop-linux/x2yhh1ypurkawvx9y63olf75q

What's next:
    View a summary of image vulnerabilities and recommendations → docker scout quickview
✓ API imajı oluşturuldu
🔨 Web imajı build ediliyor...
[+] Building 1.3s (9/9) FINISHED                                                                                                                      docker:desktop-linux
 => [internal] load build definition from Dockerfile.web                                                                                                              0.0s
 => => transferring dockerfile: 197B                                                                                                                                  0.0s
 => [internal] load metadata for docker.io/library/nginx:alpine                                                                                                       1.3s
 => [auth] library/nginx:pull token for registry-1.docker.io                                                                                                          0.0s
 => [internal] load .dockerignore                                                                                                                                     0.0s
 => => transferring context: 2B                                                                                                                                       0.0s
 => [1/3] FROM docker.io/library/nginx:alpine@sha256:61e01287e546aac28a3f56839c136b31f590273f3b41187a36f46f6a03bbfe22                                                 0.0s
 => [internal] load build context                                                                                                                                     0.0s
 => => transferring context: 62B                                                                                                                                      0.0s
 => CACHED [2/3] COPY index.html /usr/share/nginx/html/                                                                                                               0.0s
 => CACHED [3/3] COPY nginx.conf /etc/nginx/conf.d/default.conf                                                                                                       0.0s
 => exporting to image                                                                                                                                                0.0s
 => => exporting layers                                                                                                                                               0.0s
 => => writing image sha256:eddd34922e5346518e0edc7745bf2421d4fbeb7dfa0207b0d24d886d4ee7277a                                                                          0.0s
 => => naming to docker.io/library/datetime-web:latest                                                                                                                0.0s

View build details: docker-desktop://dashboard/build/desktop-linux/desktop-linux/mhoak3i8fu8okao6mi328zi3b

What's next:
    View a summary of image vulnerabilities and recommendations → docker scout quickview
✓ Web imajı oluşturuldu
🔨 API-Go imajı build ediliyor...
[+] Building 1.2s (18/18) FINISHED                                                                                                                    docker:desktop-linux
 => [internal] load build definition from Dockerfile                                                                                                                  0.0s
 => => transferring dockerfile: 505B                                                                                                                                  0.0s
 => [internal] load metadata for docker.io/library/golang:1.25-alpine                                                                                                 1.2s
 => [internal] load metadata for docker.io/library/alpine:latest                                                                                                      1.2s
 => [auth] library/golang:pull token for registry-1.docker.io                                                                                                         0.0s
 => [auth] library/alpine:pull token for registry-1.docker.io                                                                                                         0.0s
 => [internal] load .dockerignore                                                                                                                                     0.0s
 => => transferring context: 2B                                                                                                                                       0.0s
 => [builder 1/6] FROM docker.io/library/golang:1.25-alpine@sha256:aee43c3ccbf24fdffb7295693b6e33b21e01baec1b2a55acc351fde345e9ec34                                   0.0s
 => [stage-1 1/4] FROM docker.io/library/alpine:latest@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412                                        0.0s
 => [internal] load build context                                                                                                                                     0.0s
 => => transferring context: 721B                                                                                                                                     0.0s
 => CACHED [stage-1 2/4] RUN apk --no-cache add ca-certificates tzdata                                                                                                0.0s
 => CACHED [stage-1 3/4] WORKDIR /root/                                                                                                                               0.0s
 => CACHED [builder 2/6] WORKDIR /app                                                                                                                                 0.0s
 => CACHED [builder 3/6] COPY go.mod go.sum* ./                                                                                                                       0.0s
 => CACHED [builder 4/6] RUN go mod download                                                                                                                          0.0s
 => CACHED [builder 5/6] COPY . .                                                                                                                                     0.0s
 => CACHED [builder 6/6] RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .                                                                        0.0s
 => CACHED [stage-1 4/4] COPY --from=builder /app/main .                                                                                                              0.0s
 => exporting to image                                                                                                                                                0.0s
 => => exporting layers                                                                                                                                               0.0s
 => => writing image sha256:a2add624fdf204057d2e49e7e11c0945cf02779a03c8cb019c24b847b7cbe9ef                                                                          0.0s
 => => naming to docker.io/library/datetime-api-go:latest                                                                                                             0.0s

View build details: docker-desktop://dashboard/build/desktop-linux/desktop-linux/4d87b60dvvwlqknssctc7hmgu

What's next:
    View a summary of image vulnerabilities and recommendations → docker scout quickview
✓ API-Go imajı oluşturuldu
🔨 Web-Go imajı build ediliyor...
[+] Building 0.3s (8/8) FINISHED                                                                                                                      docker:desktop-linux
 => [internal] load build definition from Dockerfile                                                                                                                  0.0s
 => => transferring dockerfile: 191B                                                                                                                                  0.0s
 => [internal] load metadata for docker.io/library/nginx:alpine                                                                                                       0.2s
 => [internal] load .dockerignore                                                                                                                                     0.0s
 => => transferring context: 2B                                                                                                                                       0.0s
 => [1/3] FROM docker.io/library/nginx:alpine@sha256:61e01287e546aac28a3f56839c136b31f590273f3b41187a36f46f6a03bbfe22                                                 0.0s
 => [internal] load build context                                                                                                                                     0.0s
 => => transferring context: 63B                                                                                                                                      0.0s
 => CACHED [2/3] COPY index.html /usr/share/nginx/html/                                                                                                               0.0s
 => CACHED [3/3] COPY nginx.conf /etc/nginx/conf.d/default.conf                                                                                                       0.0s
 => exporting to image                                                                                                                                                0.0s
 => => exporting layers                                                                                                                                               0.0s
 => => writing image sha256:064bb63a27b659ddc55d82f9a3e9c772e40861990fd90e0988d33535e17dadc5                                                                          0.0s
 => => naming to docker.io/library/datetime-web-go:latest                                                                                                             0.0s

View build details: docker-desktop://dashboard/build/desktop-linux/desktop-linux/8d46yehlld6x1hszawlj7m62m

What's next:
    View a summary of image vulnerabilities and recommendations → docker scout quickview
✓ Web-Go imajı oluşturuldu
✓ Tüm imajlar oluşturuldu
📦 İmajlar Kind cluster'a yükleniyor...
Image: "datetime-api-csharp:latest" with ID "sha256:b0738cd9536fdc63210c05f13954a8c77673eff7f92c74014699def6a3c46477" not yet present on node "kind-control-plane", loading...
Image: "datetime-api-csharp:latest" with ID "sha256:b0738cd9536fdc63210c05f13954a8c77673eff7f92c74014699def6a3c46477" not yet present on node "kind-worker3", loading...
Image: "datetime-api-csharp:latest" with ID "sha256:b0738cd9536fdc63210c05f13954a8c77673eff7f92c74014699def6a3c46477" not yet present on node "kind-control-plane3", loading...
Image: "datetime-api-csharp:latest" with ID "sha256:b0738cd9536fdc63210c05f13954a8c77673eff7f92c74014699def6a3c46477" not yet present on node "kind-control-plane2", loading...
Image: "datetime-api-csharp:latest" with ID "sha256:b0738cd9536fdc63210c05f13954a8c77673eff7f92c74014699def6a3c46477" not yet present on node "kind-worker2", loading...
Image: "datetime-api-csharp:latest" with ID "sha256:b0738cd9536fdc63210c05f13954a8c77673eff7f92c74014699def6a3c46477" not yet present on node "kind-worker", loading...
Image: "datetime-web-csharp:latest" with ID "sha256:eddd34922e5346518e0edc7745bf2421d4fbeb7dfa0207b0d24d886d4ee7277a" not yet present on node "kind-control-plane", loading...
Image: "datetime-web-csharp:latest" with ID "sha256:eddd34922e5346518e0edc7745bf2421d4fbeb7dfa0207b0d24d886d4ee7277a" not yet present on node "kind-worker3", loading...
Image: "datetime-web-csharp:latest" with ID "sha256:eddd34922e5346518e0edc7745bf2421d4fbeb7dfa0207b0d24d886d4ee7277a" not yet present on node "kind-control-plane3", loading...
Image: "datetime-web-csharp:latest" with ID "sha256:eddd34922e5346518e0edc7745bf2421d4fbeb7dfa0207b0d24d886d4ee7277a" not yet present on node "kind-control-plane2", loading...
Image: "datetime-web-csharp:latest" with ID "sha256:eddd34922e5346518e0edc7745bf2421d4fbeb7dfa0207b0d24d886d4ee7277a" not yet present on node "kind-worker2", loading...
Image: "datetime-web-csharp:latest" with ID "sha256:eddd34922e5346518e0edc7745bf2421d4fbeb7dfa0207b0d24d886d4ee7277a" not yet present on node "kind-worker", loading...
Image: "datetime-api-go:latest" with ID "sha256:a2add624fdf204057d2e49e7e11c0945cf02779a03c8cb019c24b847b7cbe9ef" not yet present on node "kind-control-plane", loading...
Image: "datetime-api-go:latest" with ID "sha256:a2add624fdf204057d2e49e7e11c0945cf02779a03c8cb019c24b847b7cbe9ef" not yet present on node "kind-worker3", loading...
Image: "datetime-api-go:latest" with ID "sha256:a2add624fdf204057d2e49e7e11c0945cf02779a03c8cb019c24b847b7cbe9ef" not yet present on node "kind-control-plane3", loading...
Image: "datetime-api-go:latest" with ID "sha256:a2add624fdf204057d2e49e7e11c0945cf02779a03c8cb019c24b847b7cbe9ef" not yet present on node "kind-control-plane2", loading...
Image: "datetime-api-go:latest" with ID "sha256:a2add624fdf204057d2e49e7e11c0945cf02779a03c8cb019c24b847b7cbe9ef" not yet present on node "kind-worker2", loading...
Image: "datetime-api-go:latest" with ID "sha256:a2add624fdf204057d2e49e7e11c0945cf02779a03c8cb019c24b847b7cbe9ef" not yet present on node "kind-worker", loading...
Image: "datetime-web-go:latest" with ID "sha256:064bb63a27b659ddc55d82f9a3e9c772e40861990fd90e0988d33535e17dadc5" not yet present on node "kind-control-plane", loading...
Image: "datetime-web-go:latest" with ID "sha256:064bb63a27b659ddc55d82f9a3e9c772e40861990fd90e0988d33535e17dadc5" not yet present on node "kind-worker3", loading...
Image: "datetime-web-go:latest" with ID "sha256:064bb63a27b659ddc55d82f9a3e9c772e40861990fd90e0988d33535e17dadc5" not yet present on node "kind-control-plane3", loading...
Image: "datetime-web-go:latest" with ID "sha256:064bb63a27b659ddc55d82f9a3e9c772e40861990fd90e0988d33535e17dadc5" not yet present on node "kind-control-plane2", loading...
Image: "datetime-web-go:latest" with ID "sha256:064bb63a27b659ddc55d82f9a3e9c772e40861990fd90e0988d33535e17dadc5" not yet present on node "kind-worker2", loading...
Image: "datetime-web-go:latest" with ID "sha256:064bb63a27b659ddc55d82f9a3e9c772e40861990fd90e0988d33535e17dadc5" not yet present on node "kind-worker", loading...
✓ İmajlar yüklendi
📦 Kubernetes kaynakları uygulanıyor...
deployment.apps/datetime-api-csharp created
service/datetime-api-csharp-service created
✓ API deployment uygulandı
deployment.apps/datetime-web-csharp created
service/datetime-web-service-csharp created
✓ Web deployment uygulandı
deployment.apps/datetime-api-go created
service/datetime-api-go-service created
✓ API-Go deployment uygulandı
deployment.apps/datetime-web-go created
service/datetime-web-go-service created
✓ Web-Go deployment uygulandı
ingress.networking.k8s.io/datetime-ingress created
✓ Ingress uygulandı

⏳ Deployment'ların hazır olması bekleniyor...
deployment.apps/datetime-api-csharp condition met
deployment.apps/datetime-web-csharp condition met
deployment.apps/datetime-api-go condition met
deployment.apps/datetime-web-go condition met
✓ Tüm deployment'lar hazır
⚖️  HAProxy load balancer kontrol ediliyor...
HAProxy load balancer başlatılıyor...
✓ HAProxy load balancer başlatıldı

HAProxy Bilgisi:
  Port 80  : HTTP Traffic (HA Load Balancing)
  Port 443 : HTTPS Traffic (HA Load Balancing)
  Port 8404: HAProxy Stats (http://localhost:8404)
📝 /etc/hosts dosyası güncelleniyor...
✓ /etc/hosts zaten güncel

======================================
🎉 Deployment tamamlandı! 🎉
======================================

⏱️  Toplam Süre: 2 dakika 55 saniye

📊 Durum Bilgisi:
NAME                               READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
datetime-api-5dcc57466c-5d9sh      1/1     Running   0          10s   10.244.3.2   kind-worker2   <none>           <none>
datetime-api-5dcc57466c-945q2      1/1     Running   0          10s   10.244.5.2   kind-worker3   <none>           <none>
datetime-api-go-69d7d7c5c-5hn8p    1/1     Running   0          10s   10.244.3.4   kind-worker2   <none>           <none>
datetime-api-go-69d7d7c5c-sntnc    1/1     Running   0          10s   10.244.5.3   kind-worker3   <none>           <none>
datetime-api-go-69d7d7c5c-znzr6    1/1     Running   0          10s   10.244.4.3   kind-worker    <none>           <none>
datetime-web-567d9789cd-ljlzw      1/1     Running   0          10s   10.244.3.3   kind-worker2   <none>           <none>
datetime-web-567d9789cd-p779z      1/1     Running   0          10s   10.244.4.2   kind-worker    <none>           <none>
datetime-web-go-5c776fd996-gq9tq   1/1     Running   0          10s   10.244.4.4   kind-worker    <none>           <none>
datetime-web-go-5c776fd996-nrfpk   1/1     Running   0          10s   10.244.5.4   kind-worker3   <none>           <none>

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
datetime-api-go-service   ClusterIP   10.96.159.205   <none>        80/TCP    10s
datetime-api-service      ClusterIP   10.96.8.181     <none>        80/TCP    10s
datetime-web-go-service   ClusterIP   10.96.63.248    <none>        80/TCP    10s
datetime-web-service      ClusterIP   10.96.84.28     <none>        80/TCP    10s
kubernetes                ClusterIP   10.96.0.1       <none>        443/TCP   2m43s

NAME               CLASS   HOSTS                                          ADDRESS   PORTS   AGE
datetime-ingress   nginx   api-csharp.local,api-go.local,web-csharp.local + 1 more...             80      10s

======================================
🌐 Uygulamaya Erişim:
======================================
  C# Uygulamaları:
    Web: http://web-csharp.local
    API: http://api-csharp.local/api/datetime

  Go Uygulamaları:
    Web-Go: http://web-go.local
    API-Go: http://api-go.local/health
```

**Deployment Time:** M1-Max (32 GB)

- First deployment: ~2-2.5 minutes
- With cached build: ~1 minute 45 seconds ✅

**Created Resources:**

- ✅ Multi-node Kubernetes cluster (3 control-planes + 3 workers - HA setup)
- ✅ NGINX Ingress Controller (on worker nodes, 2 replicas)
- ✅ 2x datetime-api pods (on worker nodes)
- ✅ 2x datetime-web pods (on worker nodes)
- ✅ Services and Ingress configuration

</details>

## ⚡ TL;DR (Quick Start)

### Using Shell Script

```bash
# 1. Create project directory
mkdir -p datetime-k8s/{api-csharp,web-csharp,k8s}

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
open http://web-csharp.local
```

### Using Makefile (Recommended! 🎯)

```bash
# 1. Create project directory and place files
mkdir -p datetime-k8s/{api-csharp,web-csharp,k8s}

# 2. Copy all files to respective folders:
#    - Makefile -> datetime-k8s/
#    - api-csharp/* -> datetime-k8s/api/
#    - web-csharp/* -> datetime-k8s/web/
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
open http://web-csharp.local
```

**That's it!** 🎉 The application is up and running.

---

## 📁 Project Structure

```
datetime-k8s/
├── api-csharp/                        # .NET 9 API (C#)
│   ├── Program.cs                     # .NET 9 Minimal API
│   ├── DateTimeApi.csproj             # Project file
│   └── Dockerfile.api                 # API Docker image
├── web-csharp/                        # Nginx Web App (for C# API)
│   ├── index.html                     # Web UI (Vanilla JS)
│   ├── nginx.conf                     # Nginx configuration
│   └── Dockerfile.web                 # Web Docker image
├── api-go/                            # Go API
│   ├── main.go                        # Go HTTP server
│   ├── handlers/                      # HTTP handlers
│   ├── models/                        # Data models
│   ├── utils/                         # Utility functions
│   ├── go.mod                         # Go module
│   ├── Dockerfile                     # API-Go Docker image
│   └── README.md                      # API-Go documentation
├── web-go/                            # Nginx Web App (for Go API)
│   ├── index.html                     # Web UI (Vanilla JS)
│   ├── nginx.conf                     # Nginx configuration
│   └── Dockerfile                     # Web-Go Docker image
├── k8s/                               # Kubernetes Manifests
│   ├── api-csharp-deployment.yaml     # API (C#) Deployment + Service
│   ├── api-go-deployment.yaml         # API-Go Deployment + Service
│   ├── haproxy-lb.cfg                 # HAProxy Load Balancer Configuration
│   ├── ingress-nginx-deployment.yaml  # 🆕 Ingress Controller (Kind optimized)
│   ├── ingress.yaml                   # Ingress (api-csharp.local, web-csharp.local, api-go.local, web-go.local)
│   ├── kind-config.yaml               # ⚙️ Kind cluster config (3 control-plane + 3 worker HA)
│   ├── web-csharp-deployment.yaml     # Web (C#) Deployment + Service
│   └── web-go-deployment.yaml         # Web-Go Deployment + Service
├── docs/                              # Documents
│   ├── ARCHITECTURE.en.md             # 📘 System architecture overview
│   ├── ARCHITECTURE.md                # 📘 System architecture overview (TR)
│   ├── ARCHITECTURE_C4.en.md          # 📘 C4 model architecture diagrams
│   ├── ARCHITECTURE_C4.md             # 📘 C4 model architecture diagrams (TR)
│   ├── architecture-diagram.md        # 📘 Architecture diagram documentation
│   ├── c4-diagrams.md                 # 📘 C4 diagram generation guide
│   ├── CHANGES_SUMMARY.en.md          # 📄 Summary of changes
│   ├── CHANGES_SUMMARY.md             # 📄 Summary of changes (TR)
│   ├── HAPROXY_LOADBALANCER.en.md     # 📘 HAProxy load balancer setup
│   ├── HAPROXY_LOADBALANCER.md        # 📘 HAProxy load balancer setup (TR)
│   ├── HAPROXY_NGINX_ARCHITECTURE.en.md # 📘 HAProxy vs NGINX architecture
│   ├── HAPROXY_NGINX_ARCHITECTURE.md  # 📘 HAProxy vs NGINX architecture (TR)
│   ├── INGRESS_CONTROLLER_FIX.en.md   # 📘 Ingress fix methods
│   ├── INGRESS_CONTROLLER_FIX.md      # 📘 Ingress fix methods (TR)
│   ├── INGRESS_ROUTING.en.md          # 📘 Ingress routing explanation
│   ├── INGRESS_ROUTING.md             # 📘 Ingress routing explanation (TR)
│   ├── INGRESS_SETUP.en.md            # 📘 Ingress setup guide
│   ├── INGRESS_SETUP.md               # 📘 Ingress setup guide (TR)
│   ├── INGRESS-WORKER-NODE-MIGRATION.en.md # 📘 Ingress worker node migration
│   ├── INGRESS-WORKER-NODE-MIGRATION.md # 📘 Ingress worker node migration (TR)
│   ├── LOAD_BALANCING.en.md           # 📘 Load balancing strategies
│   ├── LOAD_BALANCING.md              # 📘 Load balancing strategies (TR)
│   ├── MACOS_NETWORK_FIX.en.md        # 📘 macOS network troubleshooting
│   ├── MACOS_NETWORK_FIX.md           # 📘 macOS network troubleshooting (TR)
│   ├── PROJECT_SUMMARY.en.md          # 📘 Summary of components and key points
│   ├── PROJECT_SUMMARY.md             # 📘 Summary of components (TR)
│   ├── QUICK_START.en.md              # 📘 Quick start guide
│   ├── QUICK_START.md                 # 📘 Quick start guide (TR)
│   ├── SERVICE_TO_SERVICE_COMMUNICATION.en.md # 📘 Service-to-service calls
│   ├── SERVICE_TO_SERVICE_COMMUNICATION.md # 📘 Service-to-service calls (TR)
│   ├── TROUBLESHOOTING.en.md          # 📘 Troubleshooting guide
│   ├── TROUBLESHOOTING.md             # 📘 Troubleshooting guide (TR)
│   ├── WORKER_NODES.en.md             # 📘 Multi-node cluster guide
│   └── WORKER_NODES.md                # 📘 Multi-node cluster guide (TR)
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

| File                 | Function                                                             | Auto-created?                                        |
| -------------------- | -------------------------------------------------------------------- | ---------------------------------------------------- |
| **kind-config.yaml** | Kind cluster configuration (3 control-planes + 3 workers - HA setup) | ✅ Yes (with `make create-cluster` or `make deploy`) |

**Note**: If `kind-config.yaml` doesn't exist, Makefile will create it automatically. For more info, see [WORKER_NODES](docs/WORKER_NODES.en.md).

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
mkdir -p datetime-k8s/{api-csharp,web-csharp,k8s}
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
docker build -t datetime-api-csharp:latest -f Dockerfile.api .
cd ../web
docker build -t datetime-web-csharp:latest -f Dockerfile.web .
cd ..
cd api-go
docker build -t datetime-api-go:latest .
cd ../web-go
docker build -t datetime-web-go:latest .
cd ..

# 4. Load images to Kind
kind load docker-image datetime-api-csharp:latest
kind load docker-image datetime-web-csharp:latest

# 5. Apply Kubernetes resources
kubectl apply -f k8s/api-csharp-deployment.yaml
kubectl apply -f k8s/web-csharp-deployment.yaml
kubectl apply -f k8s/ingress.yaml

# 6. Update /etc/hosts file
echo "127.0.0.1 api-csharp.local web-csharp.local" | sudo tee -a /etc/hosts
```

## 🌐 Access

### C# Applications

- **Web Application**: http://web-csharp.local
- **API Endpoint**: http://api-csharp.local/api/datetime
- **Health Check**: http://api-csharp.local/health

### Go Applications

- **Web-Go Application**: http://web-go.local
- **API-Go Health**: http://api-go.local/health
- **API-Go Endpoints**:
  - Timezone Converter: http://api-go.local/api/timezone/convert
  - Time Calculator: http://api-go.local/api/time/calculate
  - World Clock: http://api-go.local/api/worldclock
  - Countdown: http://api-go.local/api/countdown
  - Business Days: http://api-go.local/api/businessdays

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
kubectl logs -l app=datetime-api-csharp -f
kubectl logs -l app=datetime-web-csharp -f
kubectl logs <pod-name> -f

# Check Services
kubectl get services
kubectl describe service datetime-api-csharp-service
kubectl describe service datetime-web-csharp-service

# Ingress Status
kubectl get ingress
kubectl describe ingress datetime-ingress

# Port Forward (for testing)
kubectl port-forward service/datetime-api-csharp-service 8080:80
kubectl port-forward service/datetime-web-csharp-service 8081:80
```

## 🧪 Test Commands

### Using Makefile (Recommended)

```bash
# Automated endpoint tests
make test

# Manual tests
curl http://api-csharp.local/api/datetime
curl http://api-csharp.local/health
curl http://web-csharp.local
```

### Manual Tests

```bash
# API test
curl http://api-csharp.local/api/datetime
curl http://api-csharp.local/health

# Web test
curl http://web-csharp.local

# Detailed test
curl -v http://api-csharp.local/api/datetime

# JSON format
curl -s http://api-csharp.local/api/datetime | jq .
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
kubectl scale deployment datetime-api-csharp --replicas=3

# Scale Web
kubectl scale deployment datetime-web-csharp --replicas=3

# Check status
kubectl get pods -l app=datetime-api-csharp
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
kubectl delete -f k8s/api-csharp-deployment.yaml
kubectl delete -f k8s/web-csharp-deployment.yaml
kubectl delete -f k8s/ingress.yaml

# Delete Kind cluster
kind delete cluster

# Clean /etc/hosts (manual)
sudo nano /etc/hosts
# Delete api-csharp.local and web-csharp.local lines
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
- **Multi-Node Cluster**: Uses 3 control-planes + 3 worker nodes configuration by default (HA setup)
  - Control-plane: Kubernetes management components and Ingress Controller
  - Worker nodes: Application pods (datetime-api-csharp, datetime-web-csharp)
  - For details: [WORKER_NODES](docs/WORKER_NODES.en.md)
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
cd api && docker build -t datetime-api-csharp:latest -f Dockerfile.api . && cd ..
kind load docker-image datetime-api-csharp:latest
kubectl rollout restart deployment datetime-api-csharp
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
kubectl logs -l app=datetime-api-csharp -f
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

### Architecture

- **🎯 C4 Model Diagrams**: [ARCHITECTURE_C4](docs/ARCHITECTURE_C4.en.md) - Industry-standard C4 Model architecture (Context, Container, Component, Deployment)
- **🏗️ Detailed Technical Diagrams**: [ARCHITECTURE](docs/ARCHITECTURE.en.md) - Circuit breaker, rate limiting, request flow diagrams
- **📐 Architecture Diagram Documentation**: [Architecture Diagram](docs/architecture-diagram.md) - Creating and maintaining architecture diagrams
- **🎨 C4 Diagram Generation Guide**: [C4 Diagrams](docs/c4-diagrams.md) - Creating and managing C4 model diagrams

### Development

- **🚀 Quick Start**: [QUICK_START](docs/QUICK_START.en.md) - Quick start guide for the project
- **🔗 Service-to-Service Communication**: [SERVICE_TO_SERVICE_COMMUNICATION](docs/SERVICE_TO_SERVICE_COMMUNICATION.en.md) - Inter-service communication, resiliency, and rate limiting
- **📋 Project Summary**: [PROJECT_SUMMARY](docs/PROJECT_SUMMARY.en.md) - Summary of project components and key points

### Deployment and Strategies

- **🎯 Deployment Strategies**: [DEPLOYMENT_STRATEGIES](docs/DEPLOYMENT_STRATEGIES.en.md) - Comparison of Rolling Update, Canary, and Blue-Green deployments with recommendations
- **📝 Changes Summary**: [CHANGES_SUMMARY](docs/CHANGES_SUMMARY.en.md) - Summary of project changes

### Troubleshooting & Configuration

- **🔧 Troubleshooting**: [TROUBLESHOOTING](docs/TROUBLESHOOTING.en.md) - General troubleshooting guide
- **🌐 Ingress Routing**: [INGRESS_ROUTING](docs/INGRESS_ROUTING.en.md) - Ingress routing explanation and configuration
- **📦 Ingress Setup**: [INGRESS_SETUP](docs/INGRESS_SETUP.en.md) - NGINX Ingress Controller setup guide
- **🔨 Ingress Controller Fix**: [INGRESS_CONTROLLER_FIX](docs/INGRESS_CONTROLLER_FIX.en.md) - Methods to fix Ingress issues
- **🔄 Ingress Controller Migration**: [INGRESS_WORKER_NODE_MIGRATION](docs/INGRESS-WORKER-NODE-MIGRATION.en.md) - Guide for migrating Ingress controller to worker nodes, deployment optimization and troubleshooting
- **⚡ macOS Network Fix**: [MACOS_NETWORK_FIX](docs/MACOS_NETWORK_FIX.en.md) - 5 second delay issue fix
- **👥 Multi-node Cluster**: [WORKER_NODES](docs/WORKER_NODES.en.md) - Multi-node cluster setup and management guide

### Load Balancing

- **⚖️ Load Balancing Strategies**: [LOAD_BALANCING](docs/LOAD_BALANCING.en.md) - Kubernetes load balancing strategies and best practices
- **🔀 HAProxy Load Balancer**: [HAPROXY_LOADBALANCER](docs/HAPROXY_LOADBALANCER.en.md) - HAProxy load balancer setup and configuration
- **🔄 HAProxy vs NGINX Architecture**: [HAPROXY_NGINX_ARCHITECTURE](docs/HAPROXY_NGINX_ARCHITECTURE.en.md) - Comparison of HAProxy and NGINX architecture

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
