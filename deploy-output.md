# DateTime Kubernetes Deployment Çıktısı

Bu dosya `make deploy` komutunun çalışma çıktısını içermektedir.

**Çalıştırılan Komut:** `make deploy`
**Tarih:** 2025-10-05
**Dizin:** `/Users/esersahin/Projects/esersahin/repos/csharp-projects/datetime-k8s`

## Deployment Çıktısı

```bash
🚀 Kind cluster kontrol ediliyor...
No kind clusters found.
Kind cluster oluşturuluyor (1 control-plane + 2 workers)...
✓ kind-config.yaml mevcut, kullanılıyor
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.34.0) 🖼
 ✓ Preparing nodes 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Have a question, bug, or feature request? Let us know! https://kind.sigs.k8s.io/#community 🙂
✓ Multi-node Kind cluster oluşturuldu

Cluster Node'ları:
NAME                 STATUS     ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION     CONTAINER-RUNTIME
kind-control-plane   NotReady   control-plane   15s   v1.34.0   172.20.0.2    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker          NotReady   <none>          0s    v1.34.0   172.20.0.3    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker2         NotReady   <none>          0s    v1.34.0   172.20.0.4    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
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
pod/ingress-nginx-controller-7884c64dd8-jgxd9 condition met
✓ NGINX Ingress Controller kuruldu
🔧 Ingress yapılandırması kontrol ediliyor...
hostNetwork ayarı düzeltiliyor...
deployment.apps/ingress-nginx-controller patched (no change)
deployment "ingress-nginx-controller" successfully rolled out
pod/ingress-nginx-controller-7884c64dd8-jgxd9 condition met
✓ hostNetwork ayarı düzeltildi
🔧 Ingress Controller control-plane'e taşınıyor...
Ingress Controller URRENT_NODE'da, control-plane'e taşınıyor...
deployment.apps/ingress-nginx-controller patched (no change)
deployment "ingress-nginx-controller" successfully rolled out
pod/ingress-nginx-controller-7884c64dd8-jgxd9 condition met
✓ Ingress Controller control-plane'e taşındı

Ingress Controller Durumu:
NAME                                        READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
ingress-nginx-controller-7884c64dd8-jgxd9   1/1     Running   0          54s   172.20.0.2   kind-control-plane   <none>           <none>
🧹 Admission webhook'ları temizleniyor...
✓ Webhook'lar temizlendi
🔨 API imajı build ediliyor...
[+] Building 0.0s (15/15) FINISHED                                                                                                                                                                                                                                                                  docker:desktop-linux
 => [internal] load build definition from Dockerfile.api                                                                                                                                                                                                                                                            0.0s
 => => transferring dockerfile: 1.13kB                                                                                                                                                                                                                                                                              0.0s
 => [internal] load metadata for mcr.microsoft.com/dotnet/aspnet:9.0                                                                                                                                                                                                                                                0.0s
 => [internal] load metadata for mcr.microsoft.com/dotnet/sdk:9.0                                                                                                                                                                                                                                                   0.0s
 => [internal] load .dockerignore                                                                                                                                                                                                                                                                                   0.0s
 => => transferring context: 2B                                                                                                                                                                                                                                                                                     0.0s
 => [build 1/6] FROM mcr.microsoft.com/dotnet/sdk:9.0                                                                                                                                                                                                                                                               0.0s
 => [stage-1 1/3] FROM mcr.microsoft.com/dotnet/aspnet:9.0                                                                                                                                                                                                                                                          0.0s
 => [internal] load build context                                                                                                                                                                                                                                                                                   0.0s
 => => transferring context: 70B                                                                                                                                                                                                                                                                                    0.0s
 => CACHED [stage-1 2/3] WORKDIR /app                                                                                                                                                                                                                                                                               0.0s
 => CACHED [build 2/6] WORKDIR /src                                                                                                                                                                                                                                                                                 0.0s
 => CACHED [build 3/6] COPY DateTimeApi.csproj .                                                                                                                                                                                                                                                                    0.0s
 => CACHED [build 4/6] RUN dotnet restore                                                                                                                                                                                                                                                                           0.0s
 => CACHED [build 5/6] COPY Program.cs .                                                                                                                                                                                                                                                                            0.0s
 => CACHED [build 6/6] RUN dotnet publish -c Release -o /app/publish                                                                                                                                                                                                                                                0.0s
 => CACHED [stage-1 3/3] COPY --from=build /app/publish .                                                                                                                                                                                                                                                           0.0s
 => exporting to image                                                                                                                                                                                                                                                                                              0.0s
 => => exporting layers                                                                                                                                                                                                                                                                                             0.0s
 => => writing image sha256:9a58bc6a1467909a0fe413973a70b251647a4ad7397af5c3d4632a3ec274d01d                                                                                                                                                                                                                        0.0s
 => => naming to docker.io/library/datetime-api:latest                                                                                                                                                                                                                                                              0.0s

View build details: docker-desktop://dashboard/build/desktop-linux/desktop-linux/zg8nk1byti8x7i3feznlo9cag

What's next:
    View a summary of image vulnerabilities and recommendations → docker scout quickview
✓ API imajı oluşturuldu
🔨 Web imajı build ediliyor...
[+] Building 1.2s (9/9) FINISHED                                                                                                                                                                                                                                                                    docker:desktop-linux
 => [internal] load build definition from Dockerfile.web                                                                                                                                                                                                                                                            0.0s
 => => transferring dockerfile: 197B                                                                                                                                                                                                                                                                                0.0s
 => [internal] load metadata for docker.io/library/nginx:alpine                                                                                                                                                                                                                                                     1.1s
 => [auth] library/nginx:pull token for registry-1.docker.io                                                                                                                                                                                                                                                        0.0s
 => [internal] load .dockerignore                                                                                                                                                                                                                                                                                   0.0s
 => => transferring context: 2B                                                                                                                                                                                                                                                                                     0.0s
 => [1/3] FROM docker.io/library/nginx:alpine@sha256:42a516af16b852e33b7682d5ef8acbd5d13fe08fecadc7ed98605ba5e3b26ab8                                                                                                                                                                                               0.0s
 => [internal] load build context                                                                                                                                                                                                                                                                                   0.0s
 => => transferring context: 62B                                                                                                                                                                                                                                                                                    0.0s
 => CACHED [2/3] COPY index.html /usr/share/nginx/html/                                                                                                                                                                                                                                                             0.0s
 => CACHED [3/3] COPY nginx.conf /etc/nginx/conf.d/default.conf                                                                                                                                                                                                                                                     0.0s
 => exporting to image                                                                                                                                                                                                                                                                                              0.0s
 => => exporting layers                                                                                                                                                                                                                                                                                             0.0s
 => => writing image sha256:935c8c5e5c9cf3f075d982c482ebad333d028574884ee2459522893c96d1a3f0                                                                                                                                                                                                                        0.0s
 => => naming to docker.io/library/datetime-web:latest                                                                                                                                                                                                                                                              0.0s

View build details: docker-desktop://dashboard/build/desktop-linux/desktop-linux/ua4vm1xzml47pewcsnx4qjekt

What's next:
    View a summary of image vulnerabilities and recommendations → docker scout quickview
✓ Web imajı oluşturuldu
✓ Tüm imajlar oluşturuldu
📦 İmajlar Kind cluster'a yükleniyor...
Image: "datetime-api:latest" with ID "sha256:9a58bc6a1467909a0fe413973a70b251647a4ad7397af5c3d4632a3ec274d01d" not yet present on node "kind-worker", loading...
Image: "datetime-api:latest" with ID "sha256:9a58bc6a1467909a0fe413973a70b251647a4ad7397af5c3d4632a3ec274d01d" not yet present on node "kind-worker2", loading...
Image: "datetime-api:latest" with ID "sha256:9a58bc6a1467909a0fe413973a70b251647a4ad7397af5c3d4632a3ec274d01d" not yet present on node "kind-control-plane", loading...
Image: "datetime-web:latest" with ID "sha256:935c8c5e5c9cf3f075d982c482ebad333d028574884ee2459522893c96d1a3f0" not yet present on node "kind-worker", loading...
Image: "datetime-web:latest" with ID "sha256:935c8c5e5c9cf3f075d982c482ebad333d028574884ee2459522893c96d1a3f0" not yet present on node "kind-worker2", loading...
Image: "datetime-web:latest" with ID "sha256:935c8c5e5c9cf3f075d982c482ebad333d028574884ee2459522893c96d1a3f0" not yet present on node "kind-control-plane", loading...
✓ İmajlar yüklendi
📦 Kubernetes kaynakları uygulanıyor...
deployment.apps/datetime-api created
service/datetime-api-service created
✓ API deployment uygulandı
deployment.apps/datetime-web created
service/datetime-web-service created
✓ Web deployment uygulandı
ingress.networking.k8s.io/datetime-ingress created
✓ Ingress uygulandı

⏳ Deployment'ların hazır olması bekleniyor...
deployment.apps/datetime-api condition met
deployment.apps/datetime-web condition met
✓ Tüm deployment'lar hazır
📝 /etc/hosts dosyası güncelleniyor...
✓ /etc/hosts zaten güncel

======================================
🎉 Deployment tamamlandı! 🎉
======================================

📊 Durum Bilgisi:
NAME                            READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
datetime-api-7c496c6d89-7sgdt   1/1     Running   0          9s    10.244.1.2   kind-worker2   <none>           <none>
datetime-api-7c496c6d89-sg8q9   1/1     Running   0          9s    10.244.2.2   kind-worker    <none>           <none>
datetime-web-567d9789cd-x8nqf   1/1     Running   0          9s    10.244.1.3   kind-worker2   <none>           <none>
datetime-web-567d9789cd-z4kvw   1/1     Running   0          9s    10.244.2.3   kind-worker    <none>           <none>

NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
datetime-api-service   ClusterIP   10.96.173.141   <none>        80/TCP    9s
datetime-web-service   ClusterIP   10.96.189.101   <none>        80/TCP    9s
kubernetes             ClusterIP   10.96.0.1       <none>        443/TCP   92s

NAME               CLASS   HOSTS                 ADDRESS   PORTS   AGE
datetime-ingress   nginx   api.local,web.local             80      9s

======================================
🌐 Uygulamaya Erişim:
======================================
  Web Uygulaması: http://web.local
  API: http://api.local/api/datetime

```

## Özet

✅ **Başarılı Deployment!** Tüm adımlar sorunsuz tamamlandı:

1. **Kind Cluster:** 3-node cluster oluşturuldu (1 control-plane + 2 workers)
2. **NGINX Ingress:** Özel ingress-nginx-deployment.yaml ile kuruldu ve optimize edildi
3. **Docker Images:** API ve Web imajları build edildi ve tüm node'lara yüklendi
4. **Kubernetes Resources:** Deployment, Service ve Ingress kaynakları uygulandı
5. **Load Balancing:** Her servis için 2 replica worker node'larda çalışıyor
6. **Network:** /etc/hosts dosyası güncellendi

### Çalışan Podlar

- `datetime-api`: 2 replica (kind-worker ve kind-worker2'de)
- `datetime-web`: 2 replica (kind-worker ve kind-worker2'de)
- `ingress-nginx-controller`: 1 replica (kind-control-plane'de)

### Cluster Yapısı

- **Control Plane:** kind-control-plane (172.20.0.2) - Ingress Controller burada
- **Worker Node 1:** kind-worker (172.20.0.3) - Uygulama podları
- **Worker Node 2:** kind-worker2 (172.20.0.4) - Uygulama podları

### Erişim Adresleri

- **Web Uygulaması:** http://web.local
- **API Endpoint:** http://api.local/api/datetime
