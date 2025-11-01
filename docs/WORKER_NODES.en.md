<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](WORKER_NODES.en.md) | 🇹🇷 [Türkçe](WORKER_NODES.md) |
| :------------------------------: | :--------------------------: |

</div>

---

# High Availability Kubernetes Cluster Working Guide

This documentation explains the **High Availability (HA)** Kubernetes cluster setup and management with 3 control-plane + 3 worker node architecture.

## 📋 Table of Contents

1. [Cluster Architecture](#-cluster-architecture)
2. [kind-config.yaml Structure](#-kind-configyaml-structure)
3. [Creating Cluster](#-creating-cluster)
4. [Node Management](#-node-management)
5. [Deployment Configuration](#-deployment-configuration)
6. [Pod Distribution Strategies](#-pod-distribution-strategies)
7. [Monitoring and Debugging](#-monitoring-and-debugging)
8. [Troubleshooting](#-troubleshooting)

---

## 🏗️ Cluster Architecture

### Current Structure

The project uses **High Availability (HA)** configuration:

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

### Advantages

✅ **High Availability (HA)**

- 3 control-plane nodes: Resilient to API server failures
- Etcd cluster: Consensus-based data replication
- Cluster continues to work if any control-plane goes down

✅ **Workload Distribution**

- 3 worker nodes: Pods distributed evenly
- Easy scaling
- Resource isolation

✅ **Production-Ready**

- HA setup similar to production environments
- Failure scenarios can be tested
- Load balancing strategies can be tested

---

## 📄 kind-config.yaml Structure

### Full Configuration

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  # Control Plane Node 1 - First control plane for HA setup
  - role: control-plane

  # Control Plane Node 2 - Second control plane for HA setup
  - role: control-plane

  # Control Plane Node 3 - Third control plane for HA setup
  - role: control-plane

  # Worker Node 1 - Ingress controller will run here
  # No port mapping - Access through HAProxy
  - role: worker
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true,worker-group=group-1"

  # Worker Node 2 - Second worker for high availability
  # No port mapping - Access through HAProxy
  - role: worker
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true,worker-group=group-2"

  # Worker Node 3 - Third worker for high availability
  # No port mapping - Access through HAProxy
  - role: worker
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true,worker-group=group-3"
```

### Important Notes

⚠️ **Manual Creation Required**

- `k8s/kind-config.yaml` file must exist **manually** in repository
- Makefile `create-cluster` command does NOT auto-create this file
- If file doesn't exist, cluster creation will fail with ERROR

🏷️ **Node Labels**

- `ingress-ready=true`: NGINX Ingress Controller can run on these nodes
- `worker-group=group-X`: Can be used for pod affinity/anti-affinity

🚫 **No Port Mapping**

- Port mapping removed from worker nodes
- Access through HAProxy external load balancer

---

## 🚀 Creating Cluster

### Step 1: File Check

```bash
# Check if kind-config.yaml exists
ls -la k8s/kind-config.yaml
```

**Expected output:**

```
-rw-r--r-- 1 user staff 1234 Oct 28 10:00 k8s/kind-config.yaml
```

### Step 2: Create Cluster

```bash
make create-cluster
```

**Output:**

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

### Step 3: Check Node Status

```bash
make show-nodes
```

**Output:**

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

## 🎛️ Node Management

### Viewing Node Information

```bash
# List all nodes
kubectl get nodes

# Detailed information
kubectl get nodes -o wide

# Show node labels
kubectl get nodes --show-labels
```

### Checking Node Labels

```bash
# Show all worker node labels
kubectl get nodes -l '!node-role.kubernetes.io/control-plane' --show-labels

# Expected output:
NAME           STATUS   ROLES    AGE   VERSION   LABELS
kind-worker    Ready    <none>   13m   v1.34.0   beta.kubernetes.io/arch=arm64,beta.kubernetes.io/os=linux,ingress-ready=true,kubernetes.io/arch=arm64,kubernetes.io/hostname=kind-worker,kubernetes.io/os=linux,worker-group=group-1
kind-worker2   Ready    <none>   13m   v1.34.0   beta.kubernetes.io/arch=arm64,beta.kubernetes.io/os=linux,ingress-ready=true,kubernetes.io/arch=arm64,kubernetes.io/hostname=kind-worker2,kubernetes.io/os=linux,worker-group=group-2
kind-worker3   Ready    <none>   13m   v1.34.0   beta.kubernetes.io/arch=arm64,beta.kubernetes.io/os=linux,ingress-ready=true,kubernetes.io/arch=arm64,kubernetes.io/hostname=kind-worker3,kubernetes.io/os=linux,worker-group=group-3
```

### Viewing Node Capacity

```bash
# Show resources of each node
kubectl describe nodes

# Short summary
kubectl top nodes  # (requires metrics-server)
```

---

## 📦 Deployment Configuration

### C# API Deployment

**File:** `k8s/api-csharp-deployment.yaml`

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
      maxUnavailable: 1 # At most 1 pod can be down at the same time
      maxSurge: 1 # +1 extra pod can run during update
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

### Service Configuration

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
  # Best choice for stateless API
  sessionAffinity: None
```

**Features:**

- ✅ 3 replicas (High Availability)
- ✅ RollingUpdate (Zero-downtime deployments)
- ✅ Resource limits (Memory: 256Mi, CPU: 200m)
- ✅ Health probes (Liveness & Readiness)
- ✅ Service-to-service communication
- ✅ Round-robin load balancing

---

## 📊 Pod Distribution Strategies

### Automatic Distribution (Default)

Kubernetes scheduler automatically distributes pods evenly:

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

### Checking Pod Placement

```bash
# Show pods with their nodes
kubectl get pods -o wide

# Expected output:
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

### Node Affinity (Optional)

To direct specific pods to specific worker groups:

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

### Pod Anti-Affinity (For HA)

Distribute pods of the same application to different nodes:

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

## 🔍 Monitoring and Debugging

### Cluster Status

```bash
# General status
make status

# Output:
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

### Pod Logs

```bash
# RECOMMENDED: Live log follow using Makefile
make logs-api     # Follow API logs (Ctrl+C to exit)
make logs-web     # Follow Web logs (Ctrl+C to exit)

# Follow all API pods logs using label selector
kubectl logs -l app=datetime-api-csharp -f --prefix

# Show logs of a specific pod
# First, find the pod name:
kubectl get pods
# Then show the logs:
kubectl logs datetime-api-csharp-555f77dd8d-5q9zr

# Live log follow for a specific pod
kubectl logs -f datetime-api-csharp-555f77dd8d-5q9zr

# Show last 50 lines of logs
kubectl logs datetime-api-csharp-555f77dd8d-5q9zr --tail=50
```

### Service Endpoints

```bash
# Which pods is the service forwarding to?
kubectl get endpoints datetime-api-csharp-service
kubectl get endpoints datetime-web-csharp-service

# Output:
NAME                          ENDPOINTS                                         AGE
datetime-api-csharp-service   10.244.3.2:5000,10.244.4.2:5000,10.244.5.2:5000   15m
datetime-web-csharp-service   10.244.3.3:80,10.244.4.3:80,10.244.5.3:80         15m
```

### Resource Usage

```bash
# Pod resource usage
kubectl top pods # (requires metrics-server)

# Node resource usage
kubectl top nodes #(requires metrics-server)
```

---

## 🔧 Troubleshooting

### Problem 1: kind-config.yaml Not Found

**Error:**

```
❌ ERROR: k8s/kind-config.yaml not found!
This file is required for worker node configuration.
```

**Solution:**

```bash
# Make sure the file exists
ls k8s/kind-config.yaml

# If not, create or pull from repository
git pull origin main
```

### Problem 2: Pods in Pending State

**Check:**

```bash
kubectl describe pod <pod-name>
```

**Possible reasons:**

- Insufficient resources
- Node selector mismatch
- Image pull errors

**Solution:**

```bash
# Check node capacity
kubectl describe nodes

# Check pod events
kubectl get events --sort-by='.lastTimestamp'
```

### Problem 3: Service Endpoints Empty

**Check:**

```bash
kubectl get endpoints <service-name>
```

**Solution:**

```bash
# Do pod labels match service selector?
kubectl get pods --show-labels
kubectl describe service <service-name>

# Are pods Ready?
kubectl get pods
kubectl wait --for=condition=ready pod -l app=datetime-api-csharp
```

### Problem 4: Control-Plane Nodes NotReady

**Check:**

```bash
kubectl get nodes
kubectl describe node kind-control-plane
```

**Solution:**

```bash
# Recreate cluster
make clean-all
make deploy
```

---

## 📚 Resources

### Official Documentation

- [Kind Multi-Node Clusters](https://kind.sigs.k8s.io/docs/user/quick-start/#creating-a-cluster)
- [Kubernetes High Availability](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/)
- [Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Pod Anti-Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)

### Project Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture details
- [HAPROXY_NGINX_ARCHITECTURE.md](HAPROXY_NGINX_ARCHITECTURE.md) - Load balancer structure
- [INGRESS_ROUTING.md](INGRESS_ROUTING.md) - Ingress routing details

---

## 🎯 Quick Commands

```bash
# Create cluster
make create-cluster

# Show cluster status
make status

# Show nodes
make show-nodes

# Show pod distribution
kubectl get pods -o wide

# Show service endpoints
kubectl get endpoints

# Clean all resources
make clean-all

# Redeploy
make redeploy
```

---

**Note**: This configuration is optimized for local development. Production environments may require additional security, monitoring, and networking configurations.

---

**Last Updated:** 2025-10-31
**Version:** 2.1
**Project:** DateTime Kubernetes Polyglot Microservices
