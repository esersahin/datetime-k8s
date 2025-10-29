![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![.NET](https://img.shields.io/badge/.NET-512BD4?style=for-the-badge&logo=dotnet&logoColor=white)
![Go](https://img.shields.io/badge/Go-00ADD8?style=for-the-badge&logo=go&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![NGINX](https://img.shields.io/badge/NGINX-009639?style=for-the-badge&logo=nginx&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)

<div align="center">

### 🌐 Diğer Dillerde Oku / Read in Other Languages

| 🇹🇷 [Türkçe](README.md) | 🇬🇧 [English](README.en.md) |
| :--------------------: | :------------------------: |

</div>

---

# DateTime Kubernetes Application

.NET 9 Minimal API, Go API ve Nginx üzerinde çalışan web uygulamaları için tam Kubernetes deployment çözümü. C# ve Go implementasyonları ile polyglot mikroservis mimarisi.

## 🏗️ Mimari

![Architecture Overview](docs/diagrams/architecture-overview.png)

_Servisler arası iletişim, circuit breaker, retry policy ve rate limiting ile polyglot mikroservisler_

**Öne Çıkan Özellikler:**

- 🔄 **Circuit Breaker** - Hata durumunda otomatik koruma
- 🔁 **Retry Policy** - Exponential backoff ile akıllı yeniden deneme
- ⏱️ **Rate Limiting** - Token bucket algoritması ile hız sınırlama
- 🌐 **Service Discovery** - Kubernetes DNS ile otomatik servis keşfi
- 🛡️ **Resiliency Patterns** - Production-ready dayanıklılık kalıpları

[📊 Detaylı mimari diyagramlar için tıklayın →](docs/ARCHITECTURE.md)

## 📋 İçindekiler

1. [Bu Proje Ne İçin?](#-bu-proje-ne-için)
2. [Özellikler](#-özellikler)
3. [Screenshots](#-screenshots)
4. [Deployment Çıktısı](#-deployment-çıktısı)
5. [TL;DR (Çok Hızlı Başlangıç)](#-tldr-çok-hızlı-başlangıç)
6. [Proje Yapısı](#-proje-yapısı)
7. [Hızlı Başlangıç](#-hızlı-başlangıç)
8. [Script Kullanım Sırası ve Açıklamaları](#-script-kullanım-sırası-ve-açıklamaları)
9. [Deployment](#-deployment)
10. [Erişim](#-erişim)
11. [Monitoring and Debug](#-monitoring-and-debug)
12. [Test Komutları](#-test-komutları)
13. [Scaling](#-scaling)
14. [Temizleme](#-temizleme)
15. [Sorun Giderme](#-sorun-giderme)
16. [Notlar](#-notlar)
17. [Kullanım Kılavuzu](#-kullanım-kılavuzu)
18. [Dokümantasyon](#-dokümantasyon)
19. [Katkı](#-katkı)
20. [Lisans](#-lisans)
21. [Teşekkürler](#-teşekkürler)

---

## 🎯 Bu Proje Ne İçin?

Bu proje **gerçek production ortamı için hazır değildir**. Aşağıdaki amaçlar için tasarlanmıştır:

### ✅ Kullanım Alanları

- **📚 Öğrenme**: Kubernetes kavramlarını (pods, services, ingress, multi-node) pratik yaparak öğrenme
- **🔬 Test Etme**: Yeni Kubernetes yapılandırmalarını güvenli bir ortamda test etme
- **💻 Yerel Geliştirme**: Canlıya benzer ortamda uygulama geliştirme ve debugging
- **🎓 Eğitim**: Kubernetes workshop'ları ve eğitim materyalleri için kullanma
- **🧪 Simülasyon**: Multi-node, load balancing gibi production senaryolarını simüle etme
- **🛡️ Resiliency Pattern'leri**: Circuit breaker, retry policy, rate limiting gibi dayanıklılık kalıplarını öğrenme
- **🔗 Servisler Arası İletişim**: Polyglot (C# + Go) mikroservisler arası iletişimi ve service discovery'yi test etme
- **⚡ Performance Testing**: Token bucket algoritması, exponential backoff gibi algoritmaları gerçek ortamda deneme

### ❌ Production İçin Eksikler

<details>
<summary><b>Gerçek production ortamı için nelere ihtiyaç var?</b></summary>

**Güvenlik**:

- ❌ HTTPS/TLS sertifikaları yok
- ❌ Secret management (Vault, Sealed Secrets) yok
- ❌ Network policies yok
- ❌ RBAC (Role-Based Access Control) yapılandırması yok
- ❌ Pod Security Standards yok

**High Availability**:

- ✅ 3 control-plane node (HA setup)
- ❌ Persistent storage (PV/PVC) stratejisi yok
- ❌ Backup/restore mekanizması yok
- ❌ Disaster recovery planı yok

**Monitoring & Observability**:

- ❌ Prometheus/Grafana monitoring yok
- ❌ Centralized logging (ELK, Loki) yok
- ❌ Distributed tracing (Jaeger, Tempo) yok
- ❌ Alerting mekanizması yok

**Infrastructure**:

- ❌ Kind yerine gerçek cluster gerekli (EKS, GKE, AKS, on-prem)
- ❌ Cloud load balancer entegrasyonu yok
- ❌ Auto-scaling (HPA, VPA, Cluster Autoscaler) yok
- ❌ Resource limits ve requests eksik
- ❌ Quality of Service (QoS) yapılandırması yok

**CI/CD & Deployment**:

- ❌ Automated testing pipeline yok
- ❌ Container registry (Docker Hub, ECR, GCR) entegrasyonu yok
- ❌ GitOps (ArgoCD, Flux) yok
- ❌ Blue-green veya canary deployment stratejisi yok
- ❌ Rollback mekanizması yok

</details>

> **💡 Not**: Bu proje **canlıya benzer geliştirme ortamı** sağlar. Gerçek production kullanımı için yukarıdaki eksikliklerin tamamlanması gerekir.

---

## ✨ Özellikler

- 🚀 **Multi-Node Kubernetes Cluster**: 3 Control-Planes + 3 Worker Nodes (HA Setup)
- ⚡ **Otomatik Deployment**: Tek komutla (`make deploy`) tam kurulum
- 🔧 **Mac Optimized**: hostNetwork ve webhook sorunları otomatik düzeltilir
- 📦 **Kind Integration**: Local Kubernetes cluster (Docker içinde)
- 🌐 **Ingress Support**:
  - **C# Uygulaması**
    - **API URL:** `http://api-csharp.local`
    - **WebUI URL:** `http://web-csharp.local`
  - **Go Uygulaması**
    - **API URL:** `http://api-go.local`
    - **WebUI URL:** `http://web-go.local`
- 🐳 **Docker Build**: Otomatik imaj build ve yükleme
- 🎯 **Makefile Commands**: 25+ hazır komut
- 📊 **Monitoring**: Log izleme, durum kontrolleri
- 🔄 **Scaling**: Kolay replica yönetimi
- 🧪 **Testing**: Otomatik endpoint testleri

## 📸 Uygulama Görüntüleri

### C# Rest API için web uygulaması

![Web Application](screenshots/web-app-for-csharp-api.png)

_DateTime web uygulaması - Türkçe tarih ve saat gösterimi_

### C# Rest API Health bağlantı noktası

![C# API Response](screenshots/api-response-csharp.png)

_C# Rest API Health bağlantı noktası sorgulaması sonucunda alınan JSON yanıtı_

### Go Rest API için web uygulaması

![Web Application](screenshots/web-app-for-go-api.png)

_DateTime web uygulaması - Dünya saatleri gösterimi_

### Go Rest API Health bağlantı noktası

![Go API Response](screenshots/api-response-go.png)

_Go Rest API Health bağlantı noktası sorgulaması sonucunda alınan JSON yanıtı_

### Docker Desktop - Kubernetes

![Docker Desktop](screenshots/docker-desktop.png)

_Docker Desktop üzerinde çalışan Kind cluster_

### Terminal - Deployment Success

## 📋 Deployment Çıktısı

<details>
<summary><b>🚀 Tam Deployment Çıktısını Görmek İçin Tıklayın</b> (make deploy komutunun tüm adımları)</summary>

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
kind-control-plane    Ready      control-plane   44s   v1.34.0   172.20.0.8    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-control-plane2   NotReady   control-plane   12s   v1.34.0   172.20.0.4    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-control-plane3   NotReady   control-plane   2s    v1.34.0   172.20.0.5    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker           NotReady   <none>          1s    v1.34.0   172.20.0.6    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker2          NotReady   <none>          1s    v1.34.0   172.20.0.7    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker3          NotReady   <none>          1s    v1.34.0   172.20.0.3    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
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
pod/ingress-nginx-controller-7f8d89bb7f-q2znh condition met
pod/ingress-nginx-controller-7f8d89bb7f-qfmpz condition met
pod/ingress-nginx-controller-7f8d89bb7f-qwr57 condition met
✓ NGINX Ingress Controller kuruldu
🔧 Ingress yapılandırması kontrol ediliyor...
hostNetwork ayarı düzeltiliyor...
deployment.apps/ingress-nginx-controller patched (no change)
deployment "ingress-nginx-controller" successfully rolled out
pod/ingress-nginx-controller-7f8d89bb7f-q2znh condition met
pod/ingress-nginx-controller-7f8d89bb7f-qfmpz condition met
pod/ingress-nginx-controller-7f8d89bb7f-qwr57 condition met
✓ hostNetwork ayarı düzeltildi

Ingress Controller Durumu:
NAME                                        READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
ingress-nginx-controller-7f8d89bb7f-q2znh   1/1     Running   0          83s   172.20.0.7   kind-worker2   <none>           <none>
ingress-nginx-controller-7f8d89bb7f-qfmpz   1/1     Running   0          83s   172.20.0.3   kind-worker3   <none>           <none>
ingress-nginx-controller-7f8d89bb7f-qwr57   1/1     Running   0          83s   172.20.0.6   kind-worker    <none>           <none>
🧹 Admission webhook'ları temizleniyor...
✓ Webhook'lar temizlendi
🔨 API imajı build ediliyor...
[+] Building 0.1s (15/15) FINISHED                                                                                                                                                                                                                          docker:desktop-linux
 => [internal] load build definition from Dockerfile.api                                                                                                                                                                                                                    0.0s
 => => transferring dockerfile: 1.13kB                                                                                                                                                                                                                                      0.0s
 => [internal] load metadata for mcr.microsoft.com/dotnet/aspnet:9.0                                                                                                                                                                                                        0.0s
 => [internal] load metadata for mcr.microsoft.com/dotnet/sdk:9.0                                                                                                                                                                                                           0.0s
 => [internal] load .dockerignore                                                                                                                                                                                                                                           0.0s
 => => transferring context: 2B                                                                                                                                                                                                                                             0.0s
 => [build 1/6] FROM mcr.microsoft.com/dotnet/sdk:9.0                                                                                                                                                                                                                       0.0s
 => [internal] load build context                                                                                                                                                                                                                                           0.0s
 => => transferring context: 70B                                                                                                                                                                                                                                            0.0s
 => [stage-1 1/3] FROM mcr.microsoft.com/dotnet/aspnet:9.0                                                                                                                                                                                                                  0.0s
 => CACHED [stage-1 2/3] WORKDIR /app                                                                                                                                                                                                                                       0.0s
 => CACHED [build 2/6] WORKDIR /src                                                                                                                                                                                                                                         0.0s
 => CACHED [build 3/6] COPY DateTimeApi.csproj .                                                                                                                                                                                                                            0.0s
 => CACHED [build 4/6] RUN dotnet restore                                                                                                                                                                                                                                   0.0s
 => CACHED [build 5/6] COPY Program.cs .                                                                                                                                                                                                                                    0.0s
 => CACHED [build 6/6] RUN dotnet publish -c Release -o /app/publish                                                                                                                                                                                                        0.0s
 => CACHED [stage-1 3/3] COPY --from=build /app/publish .                                                                                                                                                                                                                   0.0s
 => exporting to image                                                                                                                                                                                                                                                      0.0s
 => => exporting layers                                                                                                                                                                                                                                                     0.0s
 => => writing image sha256:f7dfdc10ef2de0f11a79ab3d09d434d439a69d4d5fb3de6f1ece236ec2527ce6                                                                                                                                                                                0.0s
 => => naming to docker.io/library/datetime-api-csharp:latest                                                                                                                                                                                                               0.0s

View build details: docker-desktop://dashboard/build/desktop-linux/desktop-linux/vuswcaw3lsgfrs839ank26ipd

What's next:
    View a summary of image vulnerabilities and recommendations → docker scout quickview
✓ API imajı oluşturuldu
🔨 Web imajı build ediliyor...
[+] Building 1.4s (9/9) FINISHED                                                                                                                                                                                                                            docker:desktop-linux
 => [internal] load build definition from Dockerfile.web                                                                                                                                                                                                                    0.0s
 => => transferring dockerfile: 197B                                                                                                                                                                                                                                        0.0s
 => [internal] load metadata for docker.io/library/nginx:alpine                                                                                                                                                                                                             1.3s
 => [auth] library/nginx:pull token for registry-1.docker.io                                                                                                                                                                                                                0.0s
 => [internal] load .dockerignore                                                                                                                                                                                                                                           0.0s
 => => transferring context: 2B                                                                                                                                                                                                                                             0.0s
 => [1/3] FROM docker.io/library/nginx:alpine@sha256:61e01287e546aac28a3f56839c136b31f590273f3b41187a36f46f6a03bbfe22                                                                                                                                                       0.0s
 => [internal] load build context                                                                                                                                                                                                                                           0.0s
 => => transferring context: 62B                                                                                                                                                                                                                                            0.0s
 => CACHED [2/3] COPY index.html /usr/share/nginx/html/                                                                                                                                                                                                                     0.0s
 => CACHED [3/3] COPY nginx.conf /etc/nginx/conf.d/default.conf                                                                                                                                                                                                             0.0s
 => exporting to image                                                                                                                                                                                                                                                      0.0s
 => => exporting layers                                                                                                                                                                                                                                                     0.0s
 => => writing image sha256:5aade1f4711aabf20ab6cdd107d9cd940945296c28b78e922fe6043882d4df38                                                                                                                                                                                0.0s
 => => naming to docker.io/library/datetime-web-csharp:latest                                                                                                                                                                                                               0.0s

View build details: docker-desktop://dashboard/build/desktop-linux/desktop-linux/2igt336hlplqwsumcrbxckwb2

What's next:
    View a summary of image vulnerabilities and recommendations → docker scout quickview
✓ Web imajı oluşturuldu
🔨 API-Go imajı build ediliyor...
[+] Building 1.4s (18/18) FINISHED                                                                                                                                                                                                                          docker:desktop-linux
 => [internal] load build definition from Dockerfile                                                                                                                                                                                                                        0.0s
 => => transferring dockerfile: 505B                                                                                                                                                                                                                                        0.0s
 => [internal] load metadata for docker.io/library/alpine:latest                                                                                                                                                                                                            1.3s
 => [internal] load metadata for docker.io/library/golang:1.25-alpine                                                                                                                                                                                                       1.2s
 => [auth] library/golang:pull token for registry-1.docker.io                                                                                                                                                                                                               0.0s
 => [auth] library/alpine:pull token for registry-1.docker.io                                                                                                                                                                                                               0.0s
 => [internal] load .dockerignore                                                                                                                                                                                                                                           0.0s
 => => transferring context: 2B                                                                                                                                                                                                                                             0.0s
 => [builder 1/6] FROM docker.io/library/golang:1.25-alpine@sha256:aee43c3ccbf24fdffb7295693b6e33b21e01baec1b2a55acc351fde345e9ec34                                                                                                                                         0.0s
 => [stage-1 1/4] FROM docker.io/library/alpine:latest@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412                                                                                                                                              0.0s
 => [internal] load build context                                                                                                                                                                                                                                           0.0s
 => => transferring context: 721B                                                                                                                                                                                                                                           0.0s
 => CACHED [stage-1 2/4] RUN apk --no-cache add ca-certificates tzdata                                                                                                                                                                                                      0.0s
 => CACHED [stage-1 3/4] WORKDIR /root/                                                                                                                                                                                                                                     0.0s
 => CACHED [builder 2/6] WORKDIR /app                                                                                                                                                                                                                                       0.0s
 => CACHED [builder 3/6] COPY go.mod go.sum* ./                                                                                                                                                                                                                             0.0s
 => CACHED [builder 4/6] RUN go mod download                                                                                                                                                                                                                                0.0s
 => CACHED [builder 5/6] COPY . .                                                                                                                                                                                                                                           0.0s
 => CACHED [builder 6/6] RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .                                                                                                                                                                              0.0s
 => CACHED [stage-1 4/4] COPY --from=builder /app/main .                                                                                                                                                                                                                    0.0s
 => exporting to image                                                                                                                                                                                                                                                      0.0s
 => => exporting layers                                                                                                                                                                                                                                                     0.0s
 => => writing image sha256:e9f917ea634a5b192c5e3e30a30132f95dafe49a7a499153e0fee7816a0fbf98                                                                                                                                                                                0.0s
 => => naming to docker.io/library/datetime-api-go:latest                                                                                                                                                                                                                   0.0s

View build details: docker-desktop://dashboard/build/desktop-linux/desktop-linux/m9kgl1afr8z080e9ydg47d8nz

What's next:
    View a summary of image vulnerabilities and recommendations → docker scout quickview
✓ API-Go imajı oluşturuldu
🔨 Web-Go imajı build ediliyor...
[+] Building 0.3s (8/8) FINISHED                                                                                                                                                                                                                            docker:desktop-linux
 => [internal] load build definition from Dockerfile                                                                                                                                                                                                                        0.0s
 => => transferring dockerfile: 191B                                                                                                                                                                                                                                        0.0s
 => [internal] load metadata for docker.io/library/nginx:alpine                                                                                                                                                                                                             0.2s
 => [internal] load .dockerignore                                                                                                                                                                                                                                           0.0s
 => => transferring context: 2B                                                                                                                                                                                                                                             0.0s
 => [1/3] FROM docker.io/library/nginx:alpine@sha256:61e01287e546aac28a3f56839c136b31f590273f3b41187a36f46f6a03bbfe22                                                                                                                                                       0.0s
 => [internal] load build context                                                                                                                                                                                                                                           0.0s
 => => transferring context: 63B                                                                                                                                                                                                                                            0.0s
 => CACHED [2/3] COPY index.html /usr/share/nginx/html/                                                                                                                                                                                                                     0.0s
 => CACHED [3/3] COPY nginx.conf /etc/nginx/conf.d/default.conf                                                                                                                                                                                                             0.0s
 => exporting to image                                                                                                                                                                                                                                                      0.0s
 => => exporting layers                                                                                                                                                                                                                                                     0.0s
 => => writing image sha256:064bb63a27b659ddc55d82f9a3e9c772e40861990fd90e0988d33535e17dadc5                                                                                                                                                                                0.0s
 => => naming to docker.io/library/datetime-web-go:latest                                                                                                                                                                                                                   0.0s

View build details: docker-desktop://dashboard/build/desktop-linux/desktop-linux/uzdo72a2ke5vi1xlsblg6ksvs

What's next:
    View a summary of image vulnerabilities and recommendations → docker scout quickview
✓ Web-Go imajı oluşturuldu
✓ Tüm imajlar oluşturuldu
📦 İmajlar Kind cluster'a yükleniyor...
Image: "datetime-api-csharp:latest" with ID "sha256:f7dfdc10ef2de0f11a79ab3d09d434d439a69d4d5fb3de6f1ece236ec2527ce6" not yet present on node "kind-control-plane", loading...
Image: "datetime-api-csharp:latest" with ID "sha256:f7dfdc10ef2de0f11a79ab3d09d434d439a69d4d5fb3de6f1ece236ec2527ce6" not yet present on node "kind-worker2", loading...
Image: "datetime-api-csharp:latest" with ID "sha256:f7dfdc10ef2de0f11a79ab3d09d434d439a69d4d5fb3de6f1ece236ec2527ce6" not yet present on node "kind-worker", loading...
Image: "datetime-api-csharp:latest" with ID "sha256:f7dfdc10ef2de0f11a79ab3d09d434d439a69d4d5fb3de6f1ece236ec2527ce6" not yet present on node "kind-control-plane3", loading...
Image: "datetime-api-csharp:latest" with ID "sha256:f7dfdc10ef2de0f11a79ab3d09d434d439a69d4d5fb3de6f1ece236ec2527ce6" not yet present on node "kind-control-plane2", loading...
Image: "datetime-api-csharp:latest" with ID "sha256:f7dfdc10ef2de0f11a79ab3d09d434d439a69d4d5fb3de6f1ece236ec2527ce6" not yet present on node "kind-worker3", loading...
Image: "datetime-web-csharp:latest" with ID "sha256:5aade1f4711aabf20ab6cdd107d9cd940945296c28b78e922fe6043882d4df38" not yet present on node "kind-control-plane", loading...
Image: "datetime-web-csharp:latest" with ID "sha256:5aade1f4711aabf20ab6cdd107d9cd940945296c28b78e922fe6043882d4df38" not yet present on node "kind-worker2", loading...
Image: "datetime-web-csharp:latest" with ID "sha256:5aade1f4711aabf20ab6cdd107d9cd940945296c28b78e922fe6043882d4df38" not yet present on node "kind-worker", loading...
Image: "datetime-web-csharp:latest" with ID "sha256:5aade1f4711aabf20ab6cdd107d9cd940945296c28b78e922fe6043882d4df38" not yet present on node "kind-control-plane3", loading...
Image: "datetime-web-csharp:latest" with ID "sha256:5aade1f4711aabf20ab6cdd107d9cd940945296c28b78e922fe6043882d4df38" not yet present on node "kind-control-plane2", loading...
Image: "datetime-web-csharp:latest" with ID "sha256:5aade1f4711aabf20ab6cdd107d9cd940945296c28b78e922fe6043882d4df38" not yet present on node "kind-worker3", loading...
Image: "datetime-api-go:latest" with ID "sha256:e9f917ea634a5b192c5e3e30a30132f95dafe49a7a499153e0fee7816a0fbf98" not yet present on node "kind-control-plane", loading...
Image: "datetime-api-go:latest" with ID "sha256:e9f917ea634a5b192c5e3e30a30132f95dafe49a7a499153e0fee7816a0fbf98" not yet present on node "kind-worker2", loading...
Image: "datetime-api-go:latest" with ID "sha256:e9f917ea634a5b192c5e3e30a30132f95dafe49a7a499153e0fee7816a0fbf98" not yet present on node "kind-worker", loading...
Image: "datetime-api-go:latest" with ID "sha256:e9f917ea634a5b192c5e3e30a30132f95dafe49a7a499153e0fee7816a0fbf98" not yet present on node "kind-control-plane3", loading...
Image: "datetime-api-go:latest" with ID "sha256:e9f917ea634a5b192c5e3e30a30132f95dafe49a7a499153e0fee7816a0fbf98" not yet present on node "kind-control-plane2", loading...
Image: "datetime-api-go:latest" with ID "sha256:e9f917ea634a5b192c5e3e30a30132f95dafe49a7a499153e0fee7816a0fbf98" not yet present on node "kind-worker3", loading...
Image: "datetime-web-go:latest" with ID "sha256:064bb63a27b659ddc55d82f9a3e9c772e40861990fd90e0988d33535e17dadc5" not yet present on node "kind-control-plane", loading...
Image: "datetime-web-go:latest" with ID "sha256:064bb63a27b659ddc55d82f9a3e9c772e40861990fd90e0988d33535e17dadc5" not yet present on node "kind-worker2", loading...
Image: "datetime-web-go:latest" with ID "sha256:064bb63a27b659ddc55d82f9a3e9c772e40861990fd90e0988d33535e17dadc5" not yet present on node "kind-worker", loading...
Image: "datetime-web-go:latest" with ID "sha256:064bb63a27b659ddc55d82f9a3e9c772e40861990fd90e0988d33535e17dadc5" not yet present on node "kind-control-plane3", loading...
Image: "datetime-web-go:latest" with ID "sha256:064bb63a27b659ddc55d82f9a3e9c772e40861990fd90e0988d33535e17dadc5" not yet present on node "kind-control-plane2", loading...
Image: "datetime-web-go:latest" with ID "sha256:064bb63a27b659ddc55d82f9a3e9c772e40861990fd90e0988d33535e17dadc5" not yet present on node "kind-worker3", loading...
✓ İmajlar yüklendi
📦 Kubernetes kaynakları uygulanıyor...
deployment.apps/datetime-api-csharp created
service/datetime-api-csharp-service created
✓ API deployment uygulandı
deployment.apps/datetime-web-csharp created
service/datetime-web-csharp-service created
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

⏱️  Toplam Süre: 3 dakika 0 saniye

📊 Durum Bilgisi:
NAME                                   READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
datetime-api-csharp-5b755f6575-dxw62   1/1     Running   0          10s   10.244.3.2   kind-worker3   <none>           <none>
datetime-api-csharp-5b755f6575-qlzld   1/1     Running   0          10s   10.244.5.3   kind-worker    <none>           <none>
datetime-api-go-69d7d7c5c-fpv6n        1/1     Running   0          10s   10.244.5.2   kind-worker    <none>           <none>
datetime-api-go-69d7d7c5c-n5dsn        1/1     Running   0          10s   10.244.4.3   kind-worker2   <none>           <none>
datetime-api-go-69d7d7c5c-wf68m        1/1     Running   0          10s   10.244.3.4   kind-worker3   <none>           <none>
datetime-web-csharp-78cb6c4558-254t4   1/1     Running   0          10s   10.244.4.2   kind-worker2   <none>           <none>
datetime-web-csharp-78cb6c4558-5trt2   1/1     Running   0          10s   10.244.3.3   kind-worker3   <none>           <none>
datetime-web-go-5c776fd996-bk46z       1/1     Running   0          10s   10.244.4.4   kind-worker2   <none>           <none>
datetime-web-go-5c776fd996-fwnhx       1/1     Running   0          10s   10.244.5.4   kind-worker    <none>           <none>

NAME                          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
datetime-api-csharp-service   ClusterIP   10.96.203.160   <none>        80/TCP    10s
datetime-api-go-service       ClusterIP   10.96.55.216    <none>        80/TCP    10s
datetime-web-csharp-service   ClusterIP   10.96.244.141   <none>        80/TCP    10s
datetime-web-go-service       ClusterIP   10.96.83.147    <none>        80/TCP    10s
kubernetes                    ClusterIP   10.96.0.1       <none>        443/TCP   2m47s

NAME               CLASS   HOSTS                                                        ADDRESS   PORTS   AGE
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

**Deployment Süresi:** M1-Max (32 GB)

- İlk deployment: ~5 dakika
- Cached build ile: ~3 dakika ✅

**Oluşturulan Kaynaklar:**

- ✅ Multi-node Kubernetes cluster (3 control-planes + 3 workers - HA setup)
- ✅ NGINX Ingress Controller (worker node'larda, 2 replica)
- ✅ 2x datetime-api pods (worker node'larda)
- ✅ 2x datetime-web pods (worker node'larda)
- ✅ Services ve Ingress yapılandırması

</details>

## ⚡ TL;DR (Çok Hızlı Başlangıç)

```bash
# 1. Proje dizinini oluşturun ve dosyaları yerleştirin
mkdir -p datetime-k8s/{api-csharp,web-csharp,k8s}

# 2. Tüm dosyaları ilgili klasörlere kopyalayın:
#    - Makefile -> datetime-k8s/
#    - api-csharp/* -> datetime-k8s/api-csharp/
#    - web-csharp/* -> datetime-k8s/web-csharp/
#    - k8s/* -> datetime-k8s/k8s/
#    - *.yaml -> datetime-k8s/

# 3. Proje dizinine girin
cd datetime-k8s

# 4. Dizin yapısını kontrol edin (opsiyonel)
make setup

# 5. Tek komutla deploy edin!
make deploy

# 6. Doğrulayın
make verify

# 7. Tarayıcıda açın
open http://web-csharp.local
```

**Hepsi bu kadar!** 🎉 Uygulama çalışır durumda.

---

## 📁 Proje Yapısı

```
datetime-k8s/
├── api-csharp/                        # .NET 9 API (C#)
│   ├── Program.cs                     # .NET 9 Minimal API
│   ├── DateTimeApi.csproj             # Proje dosyası
│   └── Dockerfile.api                 # API Docker image
├── web-csharp/                        # Nginx Web App (C# API için)
│   ├── index.html                     # Web UI (Vanilla JS)
│   ├── nginx.conf                     # Nginx yapılandırması
│   └── Dockerfile.web                 # Web Docker image
├── api-go/                            # Go API
│   ├── main.go                        # Go HTTP server
│   ├── handlers/                      # HTTP handlers
│   ├── models/                        # Data models
│   ├── utils/                         # Utility functions
│   ├── go.mod                         # Go module
│   ├── Dockerfile                     # API-Go Docker image
│   └── README.md                      # API-Go documentation
├── web-go/                            # Nginx Web App (Go API için)
│   ├── index.html                     # Web UI (Vanilla JS)
│   ├── nginx.conf                     # Nginx yapılandırması
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
│   ├── ARCHITECTURE.md                # 📘 Sistem mimarisi genel bakış
│   ├── ARCHITECTURE_C4.en.md          # 📘 C4 model architecture diagrams
│   ├── ARCHITECTURE_C4.md             # 📘 C4 model mimari diyagramları
│   ├── architecture-diagram.md        # 📘 Architecture diagram documentation
│   ├── c4-diagrams.md                 # 📘 C4 diagram generation guide
│   ├── CHANGES_SUMMARY.en.md          # 📄 Summary of changes
│   ├── CHANGES_SUMMARY.md             # 📄 Değişikliklerin özeti
│   ├── DEBUGGING_KUBERNETES.en.md     # 🔍 Kubernetes debugging guide
│   ├── DEBUGGING_KUBERNETES.md        # 🔍 Kubernetes debugging rehberi
│   ├── DOCKER_OPTIMIZATION.en.md      # 🐳 Docker image optimization guide (277 MB → 33.9 MB)
│   ├── DOCKER_OPTIMIZATION.md         # 🐳 Docker image optimizasyon rehberi (277 MB → 33.9 MB)
│   ├── HAPROXY_LOADBALANCER.en.md     # 📘 HAProxy load balancer setup
│   ├── HAPROXY_LOADBALANCER.md        # 📘 HAProxy load balancer kurulumu
│   ├── HAPROXY_NGINX_ARCHITECTURE.en.md # 📘 HAProxy vs NGINX architecture
│   ├── HAPROXY_NGINX_ARCHITECTURE.md  # 📘 HAProxy vs NGINX mimarisi
│   ├── INGRESS_CONTROLLER_FIX.en.md   # 📘 Ingress fix methods
│   ├── INGRESS_CONTROLLER_FIX.md      # 📘 Ingress düzeltme yöntemleri
│   ├── INGRESS_ROUTING.en.md          # 📘 Ingress routing explanation
│   ├── INGRESS_ROUTING.md             # 📘 Ingress routing açıklaması
│   ├── INGRESS_SETUP.en.md            # 📘 Ingress setup guide
│   ├── INGRESS_SETUP.md               # 📘 Ingress kurulum rehberi
│   ├── INGRESS-WORKER-NODE-MIGRATION.en.md # 📘 Ingress worker node migration
│   ├── INGRESS-WORKER-NODE-MIGRATION.md # 📘 Ingress worker node taşıma
│   ├── LOAD_BALANCING.en.md           # 📘 Load balancing strategies
│   ├── LOAD_BALANCING.md              # 📘 Yük dengeleme stratejileri
│   ├── MACOS_NETWORK_FIX.en.md        # 📘 macOS network troubleshooting
│   ├── MACOS_NETWORK_FIX.md           # 📘 macOS network sorun giderme
│   ├── PROJECT_SUMMARY.en.md          # 📘 Summary of components and key points
│   ├── PROJECT_SUMMARY.md             # 📘 Bileşenlerin özeti
│   ├── QUICK_START.en.md              # 📘 Quick start guide
│   ├── QUICK_START.md                 # 📘 Hızlı başlangıç rehberi
│   ├── SERVICE_TO_SERVICE_COMMUNICATION.en.md # 📘 Service-to-service calls
│   ├── SERVICE_TO_SERVICE_COMMUNICATION.md # 📘 Servisler arası iletişim
│   ├── WORKER_NODES.en.md             # 📘 Multi-node cluster guide
│   └── WORKER_NODES.md                # 📘 Çok node cluster rehberi
├── Makefile                           # 🎯 Ana otomasyon (ÖNERİLEN!)
├── CONTRIBUTING.md                    # 📖 Nasıl katkıda bulunurum?
└── README.md                          # 📖 Ana dokümantasyon
```

### 📄 Yapılandırma Dosyası

| Dosya                | İşlevi                                                                | Otomatik Oluşturulur mu?                               |
| -------------------- | --------------------------------------------------------------------- | ------------------------------------------------------ |
| **kind-config.yaml** | Kind cluster yapılandırması (3 control-planes + 3 workers - HA setup) | ✅ Evet (`make create-cluster` veya `make deploy` ile) |

**Not**: Daha fazla bilgi için [WORKER_NODES](docs/WORKER_NODES.md) dosyasına bakın.

### 🎯 Hızlı Referans

**Makefile Komutları** (make help ile tüm liste):

- Deployment: `make deploy`, `make redeploy`, `make clean-all`
- Monitoring: `make status`, `make show-nodes`, `make logs-api`, `make verify`
- Debugging: `make fix-ingress`, `make fix-webhooks`, `make test`
- Scaling: `make scale-api REPLICAS=3`, `make restart-api`
- Build: `make build-all`, `make quick-update`

## 🚀 Hızlı Başlangıç

### Ön Gereksinimler

- Docker
- Kind (Kubernetes in Docker)
- kubectl

### Kurulum Komutları

```bash
# 1. Kind'ı yükleyin (eğer yoksa)
# macOS
brew install kind

# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# 2. kubectl'i yükleyin (eğer yoksa)
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# 3. Projeyi klonlayın veya dosyaları oluşturun
mkdir -p datetime-k8s/{api-csharp,web-csharp,k8s}
cd datetime-k8s
```

## 🎯 Deployment

```bash
# Tüm komutları görmek için
make help

# Tek komutla tam deployment
make deploy

# Deployment'ı doğrula
make verify

# Durum bilgisi
make status
```

#### Makefile Ana Komutları

| Komut            | Açıklama                       |
| ---------------- | ------------------------------ |
| `make help`      | Tüm komutları listeler         |
| `make deploy`    | **Tam deployment (ANA KOMUT)** |
| `make verify`    | Deployment'ı doğrular          |
| `make test`      | Endpoint'leri test eder        |
| `make status`    | Cluster durumunu gösterir      |
| `make logs-api`  | API loglarını izler            |
| `make logs-web`  | Web loglarını izler            |
| `make clean`     | K8s kaynaklarını siler         |
| `make clean-all` | Her şeyi siler (cluster dahil) |
| `make redeploy`  | Tamamen yeniden deploy eder    |

#### Makefile İleri Seviye Komutlar

| Komut                       | Açıklama                          |
| --------------------------- | --------------------------------- |
| `make build-api`            | Sadece API imajını build eder     |
| `make build-web`            | Sadece Web imajını build eder     |
| `make build-all`            | Tüm imajları build eder           |
| `make create-cluster`       | Kind cluster oluşturur            |
| `make install-ingress`      | NGINX Ingress kurar               |
| `make fix-ingress`          | hostNetwork düzeltir              |
| `make fix-webhooks`         | Webhook'ları temizler             |
| `make scale-api REPLICAS=3` | API'yi 3 replica'ya ölçeklendirir |
| `make scale-web REPLICAS=3` | Web'i 3 replica'ya ölçeklendirir  |
| `make restart-api`          | API'yi yeniden başlatır           |
| `make restart-web`          | Web'i yeniden başlatır            |
| `make quick-update`         | Sadece imajları günceller         |

## 🌐 Erişim

### C# Uygulamaları

- **Web Uygulaması**: http://web-csharp.local
- **API Endpoint**: http://api-csharp.local/api/datetime
- **Health Check**: http://api-csharp.local/health

### Go Uygulamaları

- **Web-Go Uygulaması**: http://web-go.local
- **API-Go Health**: http://api-go.local/health
- **API-Go Endpoints**:
  - Timezone Converter: http://api-go.local/api/timezone/convert
  - Time Calculator: http://api-go.local/api/time/calculate
  - World Clock: http://api-go.local/api/worldclock
  - Countdown: http://api-go.local/api/countdown
  - Business Days: http://api-go.local/api/businessdays

### 📊 Monitoring ve Debug

```bash
# Logları görüntüleme
make logs              # Tüm loglar (son 50 satır)
make logs-api          # API loglarını izle (real-time)
make logs-web          # Web loglarını izle (real-time)

# Durum kontrolü
make status            # Genel durum
make verify            # Detaylı doğrulama

# Test
make test              # Endpoint testleri
```

#### kubectl ile (Manuel)

```bash
# Pod'ları Görüntüleme
kubectl get pods
kubectl get pods -o wide
kubectl get pods -w  # watch mode

# Logları İnceleme
kubectl logs -l app=datetime-api-csharp -f
kubectl logs -l app=datetime-web-csharp -f
kubectl logs <pod-name> -f

# Service'leri Kontrol Etme
kubectl get services
kubectl describe service datetime-api-service
kubectl describe service datetime-web-service

# Ingress Durumu
kubectl get ingress
kubectl describe ingress datetime-ingress
```

## 🧪 Test Komutları

```bash
# Otomatik endpoint testleri
make test

# Manuel testler
curl http://api-csharp.local/api/datetime
curl http://api-csharp.local/health
curl http://web-csharp.local
```

### Manuel Testler

```bash
# API test
curl http://api-csharp.local/api/datetime
curl http://api-csharp.local/health

# Web test
curl http://web-csharp.local

# Detaylı test
curl -v http://api-csharp.local/api/datetime

# JSON formatında
curl -s http://api-csharp.local/api/datetime | jq .
```

## 🔧 Scaling

```bash
# API'yi scale et
make scale-api REPLICAS=3

# Web'i scale et
make scale-web REPLICAS=5

# Deployment'ları yeniden başlat
make restart-api
make restart-web

# Durum kontrol
make status
```

### kubectl ile (Manuel)

```bash
# API'yi scale et
kubectl scale deployment datetime-api-csharp --replicas=3

# Web'i scale et
kubectl scale deployment datetime-web-csharp --replicas=3

# Durum kontrol
kubectl get pods -l app=datetime-api
```

## 🗑️ Temizleme

```bash
# Sadece Kubernetes kaynaklarını sil (cluster kalır)
make clean

# Cluster'ı da sil
make clean-cluster

# Her şeyi sil
make clean-all

# Temizle ve yeniden deploy et
make redeploy
```

### Shell Script / Manuel

```bash
# Kaynakları sil
kubectl delete -f k8s/api-csharp-deployment.yaml
kubectl delete -f k8s/web-csharp-deployment.yaml
kubectl delete -f k8s/ingress.yaml

# Kind cluster'ı sil
kind delete cluster

# /etc/hosts temizle (manuel)
sudo nano /etc/hosts
# api-csharp.local ve web-csharp.local satırlarını silin
```

## 🔧 Sorun Giderme

```bash
# Tüm sistemi doğrula
make verify

# Sadece ingress sorununu düzelt
make fix-ingress

# Sadece webhook sorununu düzelt
make fix-webhooks

# Deployment'ları yeniden başlat
make restart-api
make restart-web

# Logları kontrol et
make logs-api
make logs-web

# Tamamen yeniden deploy
make redeploy
```

### Kind Cluster'ı Yeniden Oluşturma

```bash
# Makefile ile
make clean-cluster
make create-cluster
```

### Mac'te Ingress hostNetwork Sorunu

Mac'te Kind kullanırken NGINX Ingress Controller bazen cloud ortamları için yapılandırılır ve `hostNetwork: true` ayarı yapılmaz. Bu durumda:

```bash
# Makefile ile (Önerilen)
make fix-ingress

# Manuel kontrol
kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.template.spec.hostNetwork}'

# Manuel düzeltme
kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '{"spec":{"template":{"spec":{"hostNetwork":true}}}}'
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx
```

### Mac'te Problematic Admission Webhooks Sorunu

NGINX Ingress Controller'da ValidatingWebhookConfiguration Mac/Kind ortamında "connection refused" veya "context deadline exceeded" hatalarına neden olabilir. Bu webhook'lar Kind cluster'da gereksizdir:

```bash
# Makefile ile (Önerilen)
make fix-webhooks

# Manuel temizleme
kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission
kubectl delete jobs -n ingress-nginx ingress-nginx-admission-create ingress-nginx-admission-patch

# Webhook'ların silindiğini doğrula
kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io | grep ingress
```

**Not:** `make deploy` bu sorunu otomatik olarak düzeltir.

### Pod'lar başlamıyor

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Ingress çalışmıyor

```bash
kubectl get ingress
kubectl describe ingress datetime-ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Ingress Controller pod'unu kontrol et
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx <ingress-controller-pod-name>
```

### CORS hataları

Ingress'te CORS annotations kontrol edin:

```yaml
nginx.ingress.kubernetes.io/enable-cors: "true"
nginx.ingress.kubernetes.io/cors-allow-origin: "*"
```

### DNS çözümlenmiyor

/etc/hosts dosyasını kontrol edin:

```bash
cat /etc/hosts | grep local
```

## 📝 Notlar

- **Image Pull Policy**: `imagePullPolicy: Never` Kind için ayarlanmıştır
- **Replicas**: Her servis için 2 replica varsayılan olarak çalışır
- **Multi-Node Cluster**: Varsayılan olarak 3 control-planes + 3 worker nodes yapılandırması kullanılır (HA setup)
  - Control-plane: Kubernetes yönetim bileşenleri ve Ingress Controller
  - Worker nodes: Uygulama pod'ları (datetime-api, datetime-web)
  - Detaylı bilgi için: `WORKER_NODES.md`
- **Mac Optimizasyonu**: `make deploy` otomatik olarak Mac/Kind sorunlarını düzeltir:
  - hostNetwork ayarını true yapar
  - Problematic admission webhook'ları temizler

## 🎓 Kullanım Kılavuzu

#### Makefile 🎯

**Avantajlar:**

- ✅ Tek tek işlemler yapılabilir (`make build-api`, `make scale-api`)
- ✅ Hata yönetimi daha iyi
- ✅ İleri seviye özellikler (scale, restart, quick-update)
- ✅ Her komut bağımsız çalışır
- ✅ Renklendirme ve daha iyi output

**Kullanım:**

```bash
make deploy      # İlk kurulum
make verify      # Kontrol
make logs-api    # Log izleme
make scale-api REPLICAS=3  # Scaling
```

### Senaryolar

**Senaryo 1: İlk Kurulum**

```bash
# Önce proje dizinine girin!
cd datetime-k8s

# Makefile (Önerilen)
make setup    # Dosyaların yerinde olup olmadığını kontrol et
make deploy   # Deploy et
make verify   # Doğrula
```

**Senaryo 2: Kod Değişikliği**

```bash
# Proje dizininde olduğunuzdan emin olun
cd datetime-k8s

# Makefile (Hızlı)
make quick-update
```

**Senaryo 3: Sorun Giderme**

```bash
# Proje dizininde olduğunuzdan emin olun
cd datetime-k8s

# Makefile
make verify          # Problemi tespit et
make fix-ingress     # veya make fix-webhooks
make logs-api        # Logları kontrol et
```

**Senaryo 4: Tamamen Yeniden Başlat**

```bash
# Proje dizininde olduğunuzdan emin olun
cd datetime-k8s

# Makefile (En Hızlı)
make redeploy
```

## 📚 Dokümantasyon

### Mimari

- **🎯 C4 Model Diyagramlar**: [ARCHITECTURE_C4](docs/ARCHITECTURE_C4.md) - Endüstri standardı C4 Model ile mimari (Context, Container, Component, Deployment)
- **🏗️ Detaylı Teknik Diyagramlar**: [ARCHITECTURE](docs/ARCHITECTURE.md) - Circuit breaker, rate limiting, request flow diyagramları
- **📐 Mimari Diyagram Dokümantasyonu**: [Architecture Diagram](docs/architecture-diagram.md) - Mimari diyagramların oluşturulması ve bakımı
- **🎨 C4 Diyagram Oluşturma Rehberi**: [C4 Diagrams](docs/c4-diagrams.md) - C4 model diyagramlarını oluşturma ve yönetme

### Geliştirme

- **🚀 Hızlı Başlangıç**: [QUICK_START](docs/QUICK_START.md) - Projeyi hızlıca başlatma rehberi
- **🔗 Servisler Arası İletişim**: [SERVICE_TO_SERVICE_COMMUNICATION](docs/SERVICE_TO_SERVICE_COMMUNICATION.md) - Servisler arası iletişim, resiliency ve rate limiting
- **📋 Proje Özeti**: [PROJECT_SUMMARY](docs/PROJECT_SUMMARY.md) - Proje bileşenlerinin özeti ve önemli noktalar

### Deployment ve Stratejiler

- **🎯 Deployment Stratejileri**: [DEPLOYMENT_STRATEGIES](docs/DEPLOYMENT_STRATEGIES.md) - Rolling Update, Canary, Blue-Green deployment karşılaştırması ve öneriler
- **📝 Değişiklik Özeti**: [CHANGES_SUMMARY](docs/CHANGES_SUMMARY.md) - Proje değişikliklerinin özeti

### Performance & Optimization

- **🐳 Docker Image Optimizasyonu**: [DOCKER_OPTIMIZATION](docs/DOCKER_OPTIMIZATION.md) - .NET Docker image optimizasyon rehberi (277 MB → 33.9 MB, %87.8 boyut azalması)

### Sorun Giderme & Yapılandırma

- **🔍 Kubernetes Debugging**: [DEBUGGING_KUBERNETES](docs/DEBUGGING_KUBERNETES.md) - Kubernetes sorun giderme ve debugging rehberi (CrashLoopBackOff, JSON serialization, globalization hataları)
- **🌐 Ingress Routing**: [INGRESS_ROUTING](docs/INGRESS_ROUTING.md) - Ingress routing açıklaması ve yapılandırması
- **📦 Ingress Kurulumu**: [INGRESS_SETUP](docs/INGRESS_SETUP.md) - NGINX Ingress Controller kurulum rehberi
- **🔨 Ingress Controller Düzeltme**: [INGRESS_CONTROLLER_FIX](docs/INGRESS_CONTROLLER_FIX.md) - Ingress sorunlarını düzeltme yöntemleri
- **🔄 Ingress Controller Migration**: [INGRESS_WORKER_NODE_MIGRATION](docs/INGRESS-WORKER-NODE-MIGRATION.md) - Ingress controller'ı worker node'lara taşıma, deployment optimizasyonu ve troubleshooting rehberi
- **⚡ macOS Network Fix**: [MACOS_NETWORK_FIX](docs/MACOS_NETWORK_FIX.md) - 5 saniye gecikme sorunu çözümü
- **👥 Multi-node Cluster**: [WORKER_NODES](docs/WORKER_NODES.md) - Çok node cluster kurulum ve yönetim rehberi

### Load Balancing

- **⚖️ Yük Dengeleme Stratejileri**: [LOAD_BALANCING](docs/LOAD_BALANCING.md) - Kubernetes load balancing stratejileri ve best practices
- **🔀 HAProxy Load Balancer**: [HAPROXY_LOADBALANCER](docs/HAPROXY_LOADBALANCER.md) - HAProxy load balancer kurulumu ve yapılandırması
- **🔄 HAProxy vs NGINX Mimarisi**: [HAPROXY_NGINX_ARCHITECTURE](docs/HAPROXY_NGINX_ARCHITECTURE.md) - HAProxy ve NGINX mimarisi karşılaştırması

## 🤝 Katkı

Katkılarınızı bekliyoruz! Lütfen detaylar için [CONTRIBUTING](CONTRIBUTING.md) dosyasına bakın.

## 📄 Lisans

Bu proje MIT Lisansı ile lisanslanmıştır - detaylar için [LICENSE](LICENSE) dosyasına bakın.

## 🙏 Teşekkürler

- Kubernetes topluluğu
- Kind projesi
- NGINX Ingress Controller ekibi

---

**Proje Durumu**: ✅ Üretime hazır
**Platform**: Kubernetes (Kind)
**Test Durumu**: ✅ Tüm testler başarılı
**Dokümantasyon**: ✅ Kapsamlı

**Mutlu Kodlamalar! 🚀**

**Prepared by:** Claude (Anthropic)
**Date:** 2025-10-28
**Version:** 1.1
**Project:** DateTime Kubernetes Polyglot Microservices