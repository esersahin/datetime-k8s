<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](WORKER_NODES.en.md) | 🇹🇷 [Türkçe](WORKER_NODES.md) |
| :------------------------------: | :--------------------------: |

</div>

---

# High Availability Kubernetes Cluster ile Çalışma Rehberi

Bu dokümantasyon, projenin 3 control-plane + 3 worker node yapısındaki **High Availability (HA)** Kubernetes cluster kurulumunu ve yönetimini açıklar.

## 📋 İçindekiler

1. [Cluster Mimarisi](#-cluster-mimarisi)
2. [kind-config.yaml Yapısı](#-kind-configyaml-yapısı)
3. [Cluster Oluşturma](#-cluster-oluşturma)
4. [Node Yönetimi](#-node-yönetimi)
5. [Deployment Yapılandırması](#-deployment-yapılandırması)
6. [Pod Dağılım Stratejileri](#-pod-dağılım-stratejileri)
7. [Monitoring ve Debugging](#-monitoring-ve-debugging)
8. [Troubleshooting](#-troubleshooting)

---

## 🏗️ Cluster Mimarisi

### Mevcut Yapı

Proje **High Availability (HA)** yapılandırması kullanır:

```
┌─────────────────────────────────────────────────────────────────┐
│                    KUBERNETES CLUSTER (HA)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────  CONTROL PLANE  ──────────────────┐    │
│  │                                                         │    │
│  │  ┌───────────────┐  ┌───────────────┐  ┌─────────────┐  │    │
│  │  │ Control Plane │  │ Control Plane │  │Control Plane│  │    │
│  │  │      #1       │  │      #2       │  │     #3      │  │    │
│  │  │ kind-control- │  │ kind-control- │  │kind-control-│  │    │
│  │  │    plane      │  │    plane2     │  │   plane3    │  │    │
│  │  └───────────────┘  └───────────────┘  └─────────────┘  │    │
│  │                                                         │    │
│  │  Kubernetes API Server Load Balanced                    │    │
│  │  Etcd Cluster (Raft Consensus)                          │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ┌──────────────────────  WORKER NODES  ────────────────────┐   │
│  │                                                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │   │
│  │  │  Worker #1  │  │  Worker #2  │  │  Worker #3  │       │   │
│  │  │ kind-worker │  │kind-worker2 │  │kind-worker3 │       │   │
│  │  │             │  │             │  │             │       │   │
│  │  │ group-1     │  │ group-2     │  │ group-3     │       │   │
│  │  │ ingress-    │  │ ingress-    │  │ ingress-    │       │   │
│  │  │  ready      │  │  ready      │  │  ready      │       │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘       │   │
│  │                                                          │   │
│  │  Application Pods (API, Web, etc.)                       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Avantajları

✅ **High Availability (HA)**

- 3 control-plane node: API server hatalarına karşı dayanıklı
- Etcd cluster: Consensus-based data replication
- Herhangi bir control-plane düştüğünde cluster çalışmaya devam eder

✅ **Workload Distribution**

- 3 worker node: Pod'lar dengeli dağıtılır
- Scaling kolaylığı
- Resource isolation

✅ **Production-Ready**

- HA setup production ortamlarına benzer
- Failure scenarios test edilebilir
- Load balancing stratejileri test edilebilir

---

## 📄 kind-config.yaml Yapısı

### Tam Konfigürasyon

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  # Control Plane Node 1 - HA setup için ilk control plane
  - role: control-plane

  # Control Plane Node 2 - HA setup için ikinci control plane
  - role: control-plane

  # Control Plane Node 3 - HA setup için üçüncü control plane
  - role: control-plane

  # Worker Node 1 - Ingress controller burada çalışacak
  # Port mapping yok - HAProxy üzerinden erişilecek
  - role: worker
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true,worker-group=group-1"

  # Worker Node 2 - High availability için ikinci worker
  # Port mapping yok - HAProxy üzerinden erişilecek
  - role: worker
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true,worker-group=group-2"

  # Worker Node 3 - High availability için üçüncü worker
  # Port mapping yok - HAProxy üzerinden erişilecek
  - role: worker
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true,worker-group=group-3"
```

### Önemli Notlar

⚠️ **Manuel Oluşturma Zorunlu**

- `k8s/kind-config.yaml` dosyası repository'de **manuel olarak** bulunmalıdır
- Makefile `create-cluster` komutu bu dosyayı otomatik oluşturmaz
- Dosya yoksa cluster oluşturma HATA verir

🏷️ **Node Labels**

- `ingress-ready=true`: NGINX Ingress Controller bu node'larda çalışabilir
- `worker-group=group-X`: Pod affinity/anti-affinity için kullanılabilir

🚫 **Port Mapping Yok**

- Worker node'larda port mapping kaldırıldı
- Erişim HAProxy external load balancer üzerinden

---

## 🚀 Cluster Oluşturma

### Adım 1: Dosya Kontrolü

```bash
# kind-config.yaml dosyası var mı kontrol et
ls -la k8s/kind-config.yaml
```

**Beklenen çıktı:**

```
-rw-r--r-- 1 user staff 1234 Oct 28 10:00 k8s/kind-config.yaml
```

### Adım 2: Cluster Oluştur

```bash
make create-cluster
```

**Çıktı:**

```
🚀 Kind cluster kontrol ediliyor...
Kind cluster oluşturuluyor (3 control-planes + 3 workers - HA setup)...
✓ k8s/kind-config.yaml mevcut, kullanılıyor

Creating cluster "kind" ...
 • Ensuring node image (kindest/node:v1.34.0) 🖼  ...
 ✓ Ensuring node image (kindest/node:v1.34.0) 🖼
 • Preparing nodes 📦 📦 📦 📦 📦 📦   ...
 ✓ Preparing nodes 📦 📦 📦 📦 📦 📦
 • Configuring the external load balancer ⚖️  ...
 ✓ Configuring the external load balancer ⚖️
 • Writing configuration 📜  ...
 ✓ Writing configuration 📜
 • Starting control-plane 🕹️  ...
 ✓ Starting control-plane 🕹️
 • Installing CNI 🔌  ...
 ✓ Installing CNI 🔌
 • Installing StorageClass 💾  ...
 ✓ Installing StorageClass 💾
 • Joining more control-plane nodes 🎮  ...
 ✓ Joining more control-plane nodes 🎮
 • Joining worker nodes 🚜  ...
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-kind"

✓ Multi-node Kind cluster oluşturuldu

Cluster Node'ları:
NAME                  STATUS   ROLES           AGE   VERSION
kind-control-plane    Ready    control-plane   39s   v1.34.0
kind-control-plane2   Ready    control-plane   34s   v1.34.0
kind-control-plane3   Ready    control-plane   17s   v1.34.0
kind-worker           Ready    <none>          16s   v1.34.0
kind-worker2          Ready    <none>          16s   v1.34.0
kind-worker3          Ready    <none>          16s   v1.34.0
```

### Adım 3: Node Durumunu Kontrol Et

```bash
make show-nodes
```

**Çıktı:**

```
📊 Cluster Node'ları
====================
NAME                  STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION     CONTAINER-RUNTIME
kind-control-plane    Ready    control-plane   14m   v1.34.0   172.20.0.4    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-control-plane2   Ready    control-plane   13m   v1.34.0   172.20.0.7    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-control-plane3   Ready    control-plane   13m   v1.34.0   172.20.0.8    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker           Ready    <none>          13m   v1.34.0   172.20.0.6    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker2          Ready    <none>          13m   v1.34.0   172.20.0.5    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker3          Ready    <none>          13m   v1.34.0   172.20.0.3    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
```

---

## 🎛️ Node Yönetimi

### Node Bilgilerini Görüntüleme

```bash
# Tüm node'ları listele
kubectl get nodes

# Detaylı bilgi
kubectl get nodes -o wide

# Node'ların label'larını göster
kubectl get nodes --show-labels
```

### Node Label'larını Kontrol Etme

```bash
# Tüm worker node label'larını göster
kubectl get nodes -l '!node-role.kubernetes.io/control-plane' --show-labels

# Beklenen çıktı:
NAME           STATUS   ROLES    AGE   VERSION   LABELS
kind-worker    Ready    <none>   13m   v1.34.0   beta.kubernetes.io/arch=arm64,beta.kubernetes.io/os=linux,ingress-ready=true,kubernetes.io/arch=arm64,kubernetes.io/hostname=kind-worker,kubernetes.io/os=linux,worker-group=group-1
kind-worker2   Ready    <none>   13m   v1.34.0   beta.kubernetes.io/arch=arm64,beta.kubernetes.io/os=linux,ingress-ready=true,kubernetes.io/arch=arm64,kubernetes.io/hostname=kind-worker2,kubernetes.io/os=linux,worker-group=group-2
kind-worker3   Ready    <none>   13m   v1.34.0   beta.kubernetes.io/arch=arm64,beta.kubernetes.io/os=linux,ingress-ready=true,kubernetes.io/arch=arm64,kubernetes.io/hostname=kind-worker3,kubernetes.io/os=linux,worker-group=group-3
```

### Node Kapasitesini Görüntüleme

```bash
# Her node'un kaynaklarını göster
kubectl describe nodes

# Kısa özet
kubectl top nodes  # (metrics-server gerekli)
```

---

## 📦 Deployment Yapılandırması

### C# API Deployment

**Dosya:** `k8s/api-csharp-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: datetime-api-csharp
  labels:
    app: datetime-api-csharp
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1 # Aynı anda en fazla 1 pod kapalı olabilir
      maxSurge: 1 # Güncelleme sırasında +1 extra pod çalışabilir
  selector:
    matchLabels:
      app: datetime-api-csharp
  template:
    metadata:
      labels:
        app: datetime-api-csharp
    spec:
      containers:
        - name: api
          image: datetime-api-csharp:latest
          imagePullPolicy: Never
          ports:
            - containerPort: 5000
              name: http
          env:
            - name: DOTNET_gcServer
              value: "1"
            - name: DOTNET_GCHeapHardLimitPercent
              value: "60"
            - name: ASPNETCORE_ENVIRONMENT
              value: "Production"
            - name: TZ
              value: "Europe/Istanbul"
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: GO_API_URL
              value: "http://datetime-api-go-service"
          livenessProbe:
            httpGet:
              path: /health
              port: 5000
            initialDelaySeconds: 10
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 5000
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"
```

### Service Yapılandırması

```yaml
apiVersion: v1
kind: Service
metadata:
  name: datetime-api-csharp-service
  labels:
    app: datetime-api-csharp
  annotations:
    description: "C# API Service - Routes traffic to worker nodes"
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 5000
      protocol: TCP
      name: http
  # IMPORTANT: selector MUST match pod labels
  selector:
    app: datetime-api-csharp
  # Session affinity: None = Round Robin load balancing
  # Stateless API için en iyi seçenek
  sessionAffinity: None
```

**Özellikler:**

- ✅ 3 replica (High Availability)
- ✅ RollingUpdate (Zero-downtime deployments)
- ✅ Resource limits (Memory: 256Mi, CPU: 200m)
- ✅ Health probes (Liveness & Readiness)
- ✅ Service-to-service communication
- ✅ Round-robin load balancing

---

## 📊 Pod Dağılım Stratejileri

### Otomatik Dağılım (Default)

Kubernetes scheduler pod'ları otomatik olarak dengeli dağıtır:

```
Worker Node 1 (kind-worker):
  └─ datetime-api-csharp-xxx-1
  └─ datetime-web-csharp-xxx-1

Worker Node 2 (kind-worker2):
  └─ datetime-api-csharp-xxx-2
  └─ datetime-web-csharp-xxx-2

Worker Node 3 (kind-worker3):
  └─ datetime-api-csharp-xxx-3
  └─ datetime-web-csharp-xxx-3
```

### Pod'ların Yerleşimini Kontrol Etme

```bash
# Pod'ları node ile birlikte göster
kubectl get pods -o wide

# Beklenen çıktı:
NAME                                   READY   STATUS    NODE
NAME                                   READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
datetime-api-csharp-5b755f6575-7cmh9   1/1     Running   0          13m   10.244.5.2   kind-worker3   <none>           <none>
datetime-api-csharp-5b755f6575-bbxvn   1/1     Running   0          13m   10.244.3.2   kind-worker2   <none>           <none>
datetime-api-csharp-5b755f6575-qdb5x   1/1     Running   0          13m   10.244.4.2   kind-worker    <none>           <none>
datetime-api-go-69d7d7c5c-gxfbg        1/1     Running   0          13m   10.244.4.4   kind-worker    <none>           <none>
datetime-api-go-69d7d7c5c-h4p6c        1/1     Running   0          13m   10.244.3.5   kind-worker2   <none>           <none>
datetime-api-go-69d7d7c5c-sdm75        1/1     Running   0          13m   10.244.5.4   kind-worker3   <none>           <none>
datetime-web-csharp-78cb6c4558-4jb4s   1/1     Running   0          13m   10.244.4.3   kind-worker    <none>           <none>
datetime-web-csharp-78cb6c4558-nllpm   1/1     Running   0          13m   10.244.5.3   kind-worker3   <none>           <none>
datetime-web-csharp-78cb6c4558-wxdjf   1/1     Running   0          13m   10.244.3.3   kind-worker2   <none>           <none>
datetime-web-go-5c776fd996-fdlf8       1/1     Running   0          13m   10.244.5.5   kind-worker3   <none>           <none>
datetime-web-go-5c776fd996-knz8p       1/1     Running   0          13m   10.244.3.4   kind-worker2   <none>           <none>
datetime-web-go-5c776fd996-qtdnq       1/1     Running   0          13m   10.244.4.5   kind-worker    <none>           <none>
```

### Node Affinity (Opsiyonel)

Belirli pod'ları belirli worker gruplarına yönlendirmek için:

```yaml
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: worker-group
                    operator: In
                    values:
                      - group-1
                      - group-2
```

### Pod Anti-Affinity (HA için)

Aynı uygulamanın pod'larını farklı node'lara dağıt:

```yaml
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - datetime-api-csharp
              topologyKey: "kubernetes.io/hostname"
```

---

## 🔍 Monitoring ve Debugging

### Cluster Durumu

```bash
# Genel durum
make status

# Çıktı:
📊 Cluster Durumu
==================

Nodes:
NAME                  STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION     CONTAINER-RUNTIME
kind-control-plane    Ready    control-plane   17m   v1.34.0   172.20.0.4    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-control-plane2   Ready    control-plane   16m   v1.34.0   172.20.0.7    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-control-plane3   Ready    control-plane   16m   v1.34.0   172.20.0.8    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker           Ready    <none>          16m   v1.34.0   172.20.0.6    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker2          Ready    <none>          16m   v1.34.0   172.20.0.5    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3
kind-worker3          Ready    <none>          16m   v1.34.0   172.20.0.3    <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit   containerd://2.1.3

Pods (with Node placement):
NAME                                   READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
datetime-api-csharp-5b755f6575-7cmh9   1/1     Running   0          14m   10.244.5.2   kind-worker3   <none>           <none>
datetime-api-csharp-5b755f6575-bbxvn   1/1     Running   0          14m   10.244.3.2   kind-worker2   <none>           <none>
datetime-api-csharp-5b755f6575-qdb5x   1/1     Running   0          14m   10.244.4.2   kind-worker    <none>           <none>
datetime-api-go-69d7d7c5c-gxfbg        1/1     Running   0          14m   10.244.4.4   kind-worker    <none>           <none>
datetime-api-go-69d7d7c5c-h4p6c        1/1     Running   0          14m   10.244.3.5   kind-worker2   <none>           <none>
datetime-api-go-69d7d7c5c-sdm75        1/1     Running   0          14m   10.244.5.4   kind-worker3   <none>           <none>
datetime-web-csharp-78cb6c4558-4jb4s   1/1     Running   0          14m   10.244.4.3   kind-worker    <none>           <none>
datetime-web-csharp-78cb6c4558-nllpm   1/1     Running   0          14m   10.244.5.3   kind-worker3   <none>           <none>
datetime-web-csharp-78cb6c4558-wxdjf   1/1     Running   0          14m   10.244.3.3   kind-worker2   <none>           <none>
datetime-web-go-5c776fd996-fdlf8       1/1     Running   0          14m   10.244.5.5   kind-worker3   <none>           <none>
datetime-web-go-5c776fd996-knz8p       1/1     Running   0          14m   10.244.3.4   kind-worker2   <none>           <none>
datetime-web-go-5c776fd996-qtdnq       1/1     Running   0          14m   10.244.4.5   kind-worker    <none>           <none>

Services:
NAME                          TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
datetime-api-csharp-service   ClusterIP   10.96.199.65   <none>        80/TCP    14m
datetime-api-go-service       ClusterIP   10.96.130.19   <none>        80/TCP    14m
datetime-web-csharp-service   ClusterIP   10.96.96.23    <none>        80/TCP    14m
datetime-web-go-service       ClusterIP   10.96.172.47   <none>        80/TCP    14m
kubernetes                    ClusterIP   10.96.0.1      <none>        443/TCP   16m

Ingress:
NAME               CLASS   HOSTS                                                        ADDRESS     PORTS   AGE
datetime-ingress   nginx   api-csharp.local,api-go.local,web-csharp.local + 1 more...   localhost   80      14m
```

### Pod Logları

```bash
# ÖNERİLEN: Makefile ile canlı log takibi
make logs             # Tüm logları göster (C# + Go)
make logs-api-csharp  # C# API loglarını takip et (Ctrl+C ile çık)
make logs-web-csharp  # C# Web loglarını takip et (Ctrl+C ile çık)
make logs-api-go      # Go API loglarını takip et (Ctrl+C ile çık)
make logs-web-go      # Go Web loglarını takip et (Ctrl+C ile çık)

# Label selector ile tüm C# API pod'larının loglarını takip et
kubectl logs -l app=datetime-api-csharp -f --prefix

# Label selector ile tüm Go API pod'larının loglarını takip et
kubectl logs -l app=datetime-api-go -f --prefix

# Belirli bir pod'un loglarını göster
# Önce pod ismini bul:
kubectl get pods
# Sonra logları göster:
kubectl logs datetime-api-csharp-555f77dd8d-5q9zr

# Belirli bir pod'un canlı log takibi
kubectl logs -f datetime-api-csharp-555f77dd8d-5q9zr

# Son 50 satır log göster
kubectl logs datetime-api-csharp-555f77dd8d-5q9zr --tail=50
```

### Service Endpoints

```bash
# Service hangi pod'lara yönlendiriyor?
kubectl get endpoints datetime-api-csharp-service
kubectl get endpoints datetime-web-csharp-service

# Çıktı:
NAME                          ENDPOINTS                                         AGE
datetime-api-csharp-service   10.244.3.2:5000,10.244.4.2:5000,10.244.5.2:5000   15m
datetime-web-csharp-service   10.244.3.3:80,10.244.4.3:80,10.244.5.3:80         15m
```

### Resource Kullanımı

```bash
# Pod resource kullanımı
kubectl top pods # (metrics-server gerekli)

# Node resource kullanımı
kubectl top nodes #(metrics-server gerekli)
```

---

## 🔧 Troubleshooting

### Problem 1: kind-config.yaml Bulunamadı

**Hata:**

```
❌ HATA: k8s/kind-config.yaml bulunamadı!
Bu dosya worker node yapılandırması için gereklidir.
```

**Çözüm:**

```bash
# Dosyanın var olduğundan emin ol
ls k8s/kind-config.yaml

# Yoksa oluştur veya repository'den al
git pull origin main
```

### Problem 2: Pod'lar Pending Durumda

**Kontrol:**

```bash
kubectl describe pod <pod-name>
```

**Olası nedenler:**

- Insufficient resources
- Node selector mismatch
- Image pull errors

**Çözüm:**

```bash
# Node kapasitesini kontrol et
kubectl describe nodes

# Pod event'lerini kontrol et
kubectl get events --sort-by='.lastTimestamp'
```

### Problem 3: Service Endpoint'leri Boş

**Kontrol:**

```bash
kubectl get endpoints <service-name>
```

**Çözüm:**

```bash
# Pod label'ları service selector ile eşleşiyor mu?
kubectl get pods --show-labels
kubectl describe service <service-name>

# Pod'lar Ready mi?
kubectl get pods
kubectl wait --for=condition=ready pod -l app=datetime-api-csharp
```

### Problem 4: Control-Plane Node'lar NotReady

**Kontrol:**

```bash
kubectl get nodes
kubectl describe node kind-control-plane
```

**Çözüm:**

```bash
# Cluster'ı yeniden oluştur
make clean-all
make deploy
```

---

## 📚 Kaynaklar

### Official Documentation

- [Kind Multi-Node Clusters](https://kind.sigs.k8s.io/docs/user/quick-start/#creating-a-cluster)
- [Kubernetes High Availability](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/)
- [Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Pod Anti-Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)

### Project Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Mimari detayları
- [HAPROXY_NGINX_ARCHITECTURE.md](HAPROXY_NGINX_ARCHITECTURE.md) - Load balancer yapısı
- [INGRESS_ROUTING.md](INGRESS_ROUTING.md) - Ingress routing detayları

---

## 🎯 Hızlı Komutlar

```bash
# Cluster oluştur
make create-cluster

# Cluster durumunu göster
make status

# Node'ları göster
make show-nodes

# Pod dağılımını göster
kubectl get pods -o wide

# Service endpoint'lerini göster
kubectl get endpoints

# Tüm kaynakları temizle
make clean-all

# Yeniden deploy et
make redeploy
```

---

**Not**: Bu yapılandırma local development için optimize edilmiştir. Production ortamları için ek security, monitoring, ve networking konfigürasyonları gerekebilir.

---

**Son Güncelleme:** 2025-10-31
**Versiyon:** 2.1
**Proje:** DateTime Kubernetes Polyglot Microservices
