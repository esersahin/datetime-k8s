<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](INGRESS_ROUTING.en.md) | 🇹🇷 [Türkçe](INGRESS_ROUTING.md) |
| :---------------------------------: | :-----------------------------: |

</div>

---

# Ingress Routing: Multi-Layer Routing with HA Architecture

## 📋 Table of Contents

1. [Architecture Overview](#-architecture-overview)
2. [Traffic Flow (Multi-Layer)](#-traffic-flow-multi-layer)
3. [How It Works?](#-how-it-works)
4. [Technical Details](#-technical-details)
5. [Load Balancing Layers](#-load-balancing-layers)
6. [Test and Verification](#-test-and-verification)
7. [Troubleshooting](#-troubleshooting)
8. [Summary](#-summary)

---

This document explains the multi-layer routing mechanism in High Availability (HA) architecture:
- **Layer 1**: HAProxy → 3 Ingress Controllers (on worker nodes)
- **Layer 2**: Ingress Controllers → Kubernetes Services
- **Layer 3**: Services → Application Pods

## 🏗️ Architecture Overview

### HA Cluster Structure

```
┌─────────────────────────────────────────────────────────┐
│         3 Control Plane Nodes (HA - Management)         │
│  • Kubernetes API Server, etcd, Scheduler               │
│  • Ingress Controller DOES NOT run here                 │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│            3 Worker Nodes (HA - Workload)               │
│  • Ingress Controller (3 replicas)                      │
│  • Application Pods                                     │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
               ┌─────────────────┐
               │   HAProxy LB    │
               │  localhost:80   │
               │  localhost:443  │
               └─────────────────┘
```

## 🔄 Traffic Flow (Multi-Layer)

### Layer 1: HAProxy → Ingress Controllers

```
┌──────────────────────────────────────────────────────────┐
│          🌐 Browser/Client                               │
│     http://api-csharp.local/api/datetime                 │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│          🔀 HAProxy Load Balancer                        │
│          Docker Container (localhost:80/443)             │
│                                                          │
│  Backend: k8s_workers                                    │
│    - kind-worker:80     (weight 1)                       │
│    - kind-worker2:80    (weight 1)                       │
│    - kind-worker3:80    (weight 1)                       │
│  Algorithm: roundrobin                                   │
└────────┬─────────┬──────────┬──────────────────────────┘
         │         │          │
         │         │          │
         ▼         ▼          ▼
┌────────────┐ ┌────────────┐ ┌────────────┐
│  WORKER-1  │ │  WORKER-2  │ │  WORKER-3  │
│            │ │            │ │            │
│  Ingress   │ │  Ingress   │ │  Ingress   │
│  Replica 1 │ │  Replica 2 │ │  Replica 3 │
│  :80/443   │ │  :80/443   │ │  :80/443   │
└─────┬──────┘ └─────┬──────┘ └─────┬──────┘
      └──────────────┴──────────────┘
                     │
```

### Layer 2: Ingress → Services

```
         ┌───────────────────────────────┐
         │  NGINX Ingress Controller     │
         │  (Selected replica)           │
         │                               │
         │  Rules:                       │
         │  • api-csharp.local → Service │
         │  • web-csharp.local → Service │
         └───────────┬───────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
┌───────────────────┐   ┌───────────────────┐
│ datetime-api-     │   │ datetime-web-     │
│ csharp-service    │   │ csharp-service    │
│ ClusterIP:80      │   │ ClusterIP:80      │
│ Selector:         │   │ Selector:         │
│   app=datetime-   │   │   app=datetime-   │
│   api-csharp      │   │   web-csharp      │
└─────────┬─────────┘   └─────────┬─────────┘
          │                       │
```

### Layer 3: Services → Application Pods

```
          │                       │
     ┌────┴────┐             ┌────┴────┐
     │         │             │         │
     ▼         ▼             ▼         ▼
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│Worker-1 │ │Worker-2 │ │Worker-1 │ │Worker-2 │
│         │ │         │ │         │ │         │
│ API-Pod │ │ API-Pod │ │ Web-Pod │ │ Web-Pod │
│ :5000   │ │ :5000   │ │ :80     │ │ :80     │
└─────────┘ └─────────┘ └─────────┘ └─────────┘
```

## 🎯 How It Works?

### 1. HAProxy Load Balancer (First Layer)

HAProxy is the traffic entry point and distributes to 3 worker nodes:

```yaml
# haproxy/haproxy.cfg
backend k8s_workers
    mode http
    balance roundrobin
    option httpchk GET /healthz
    server worker1 172.18.0.4:80 check weight 1
    server worker2 172.18.0.5:80 check weight 1
    server worker3 172.18.0.6:80 check weight 1
```

**Features:**
- ✅ Round-robin load balancing
- ✅ Health check (/healthz endpoint)
- ✅ Automatic failover (unhealthy node bypass)
- ✅ Localhost:80/443 exposure

### 2. Ingress Controller (On Worker Nodes - 3 Replicas)

One Ingress Controller replica runs on each worker node:

```yaml
# k8s/ingress-nginx-deployment.yaml
spec:
  replicas: 3  # 3 replicas for HA
  template:
    spec:
      hostNetwork: true  # Listen on worker node's 80/443 ports
      nodeSelector:
        ingress-ready: "true"  # Run on worker nodes
```

```yaml
# kind-config.yaml (Worker nodes)
nodes:
  - role: worker
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    # NO extraPortMappings - HAProxy is used
```

**Why On Worker Nodes?**
- ✅ Control-plane stays clean (management only)
- ✅ HA: 3 replicas, fault tolerance
- ✅ Scalability: Add/remove worker nodes
- ✅ Production best practice

### 3. Ingress Rules (Layer 2)

Ingress Controller routes to Services based on host header:

```yaml
# k8s/ingress.yaml
rules:
  - host: api-csharp.local
    http:
      paths:
        - path: /
          backend:
            service:
              name: datetime-api-csharp-service
  - host: web-csharp.local
    http:
      paths:
        - path: /
          backend:
            service:
              name: datetime-web-csharp-service
```

### 4. Service Discovery (Layer 3)

Services find pods using **label selector**:

```yaml
# datetime-api-csharp-service
spec:
  type: ClusterIP
  selector:
    app: datetime-api-csharp # Finds ALL pods with this label
  ports:
    - port: 80
      targetPort: 5000
```

Service automatically finds all pods with this label **regardless of which node they're on**.

### 5. Load Balancing

Service **automatically** distributes traffic to pods:

- Round-robin (default)
- Session affinity (sticky sessions)
- Based on health checks

## 🔍 Technical Details

### Multi-Layer Architecture

There are 3 load balancing layers in the system:

```
┌─────────────────────────────────────────────────┐
│ Layer 1: HAProxy (External LB)                  │
│  • localhost:80 → 3 worker nodes                │
│  • Health check, failover                       │
│  • Round-robin distribution                     │
└─────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│ Layer 2: Ingress Controllers (3 replicas)       │
│  • Worker-1, Worker-2, Worker-3                 │
│  • Host-based routing (api-csharp.local, etc.)  │
│  • SSL termination                              │
└─────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│ Layer 3: Kubernetes Services (ClusterIP)        │
│  • Label selector → Pod discovery                │
│  • kube-proxy → iptables rules                  │
│  • Round-robin to pods                          │
└─────────────────────────────────────────────────┘
```

### Node Architecture

```
Control-Plane Nodes (3):
├── Kubernetes Control Components
│   ├── API Server
│   ├── etcd
│   ├── Scheduler
│   └── Controller Manager
└── kube-proxy (network rules)

Worker Node 1-3:
├── Ingress Controller Pod (hostNetwork=true)
│   └── NGINX listening on :80/:443
├── Application Pods
│   ├── datetime-api-csharp (10.244.x.2)
│   └── datetime-web-csharp (10.244.x.3)
└── kube-proxy (network rules)

HAProxy Container (Docker):
└── Load balances to all 3 workers
```

### ClusterIP Service

```yaml
type: ClusterIP # Accessible from within cluster
```

Service gets a **virtual IP**:

- `datetime-api-csharp-service`: 10.96.xxx.xxx:80
- This IP is in front of all pod IPs
- kube-proxy routes this IP to pod IPs

### Network Flow (Multi-Layer)

```
1. Request arrives: http://api-csharp.local/api/datetime

2. HAProxy (Layer 1):
   - Frontend localhost:80 captures request
   - Backend k8s_workers selected
   - Round-robin: worker2 selected (172.18.0.5:80)
   - Health check: ✓ worker2 healthy
   - Request forward → worker2:80

3. Ingress Controller (Layer 2 - On Worker2):
   - NGINX listening on :80 via hostNetwork
   - Check host header: api-csharp.local ✓
   - Ingress rule match: datetime-api-csharp-service
   - Forward to Service IP: 10.96.xxx.xxx:80

4. kube-proxy (Layer 3 - on every node):
   - Intercepts Service IP: 10.96.xxx.xxx:80
   - Endpoint list (via label selector):
     * 10.244.1.2:5000 (worker1)
     * 10.244.2.2:5000 (worker2)
   - Round-robin/iptables: 10.244.1.2:5000 selected

5. Application Pod (Worker1):
   - datetime-api-csharp pod receives request
   - /api/datetime endpoint processed
   - Response: {"time": "2025-01-15T10:30:00"}

6. Response Flow (reverse):
   - Pod → Service → Ingress Controller (worker2)
   → HAProxy → Client
```

### Example: 10 Request Flow

```bash
curl http://api-csharp.local/api/datetime  # 10 times

# HAProxy distribution (Layer 1):
Request 1  → Worker1 Ingress → Service → Pod A  # Worker1
Request 2  → Worker2 Ingress → Service → Pod B  # Worker2
Request 3  → Worker3 Ingress → Service → Pod A  # Worker3
Request 4  → Worker1 Ingress → Service → Pod B  # Worker1
Request 5  → Worker2 Ingress → Service → Pod A  # Worker2
...

# Each request can go to different Ingress replica and different pod
# Two-layer load balancing: HAProxy + K8s Service
```

## 📊 Load Balancing Layers

### Layer 1: HAProxy Load Balancing

```cfg
# haproxy/haproxy.cfg
backend k8s_workers
    mode http
    balance roundrobin  # Round-robin algorithm
    option httpchk GET /healthz  # Health check
    http-check expect status 200

    server worker1 172.18.0.4:80 check weight 1  # Equal weight
    server worker2 172.18.0.5:80 check weight 1
    server worker3 172.18.0.6:80 check weight 1
```

**Features:**
- ✅ Round-robin: Each worker gets equal traffic
- ✅ Health check: Unhealthy worker bypassed
- ✅ Automatic failover: System continues if worker down

### Layer 2: Ingress Annotations

```yaml
# k8s/ingress.yaml
annotations:
  nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
  nginx.ingress.kubernetes.io/load-balance: "round_robin"
  nginx.ingress.kubernetes.io/upstream-hash-by: "$request_uri"  # Optional
```

**Strategies:**
- `round_robin`: Distribute to pods in order (default)
- `ip_hash`: Same client IP to same pod
- `least_conn`: Least connected pod

### Layer 3: Service Session Affinity

```yaml
# k8s/datetime-api-csharp-service.yaml (optional)
sessionAffinity: ClientIP  # Sticky session
sessionAffinityConfig:
  clientIP:
    timeoutSeconds: 300  # Same pod for 5 minutes
```

**Use Cases:**
- ✅ Session affinity needed: E-commerce cart, login sessions
- ❌ Stateless API: Session affinity NOT NEEDED (better load balancing)

## 🧪 Test and Verification

### 1. HA Cluster Status

```bash
# Check all nodes
kubectl get nodes

# Expected:
# NAME                  STATUS   ROLES           AGE   VERSION
# kind-control-plane    Ready    control-plane   10m   v1.31.0
# kind-control-plane2   Ready    control-plane   10m   v1.31.0
# kind-control-plane3   Ready    control-plane   10m   v1.31.0
# kind-worker           Ready    <none>          10m   v1.31.0
# kind-worker2          Ready    <none>          10m   v1.31.0
# kind-worker3          Ready    <none>          10m   v1.31.0
```

### 2. Ingress Controller Replicas (On Worker Nodes)

```bash
# Where are Ingress Controller pods? (3 replicas)
kubectl get pods -n ingress-nginx -o wide

# Expected:
# NAME                                     READY   STATUS    NODE
# ingress-nginx-controller-xxx             1/1     Running   kind-worker
# ingress-nginx-controller-yyy             1/1     Running   kind-worker2
# ingress-nginx-controller-zzz             1/1     Running   kind-worker3

# Is replica count correct?
kubectl get deployment -n ingress-nginx ingress-nginx-controller
# READY: 3/3
```

### 3. HAProxy Status

```bash
# Is HAProxy running?
docker ps | grep haproxy

# OUTPUT:
# <container-id>  haproxy:2.8  ...  0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp

# HAProxy stats (optional)
curl http://localhost:8404/stats
# Worker health status can be seen
```

### 4. Application Pod Locations

```bash
# Where are application pods?
kubectl get pods -o wide

# Expected:
# NAME                           NODE
# datetime-api-csharp-xxx        kind-worker or kind-worker2
# datetime-web-csharp-xxx        kind-worker or kind-worker2
```

### 5. Service Endpoints

```bash
# Which pods is Service routing to?
kubectl get endpoints datetime-api-csharp-service
kubectl get endpoints datetime-web-csharp-service

# Output:
# NAME                             ENDPOINTS
# datetime-api-csharp-service      10.244.1.2:5000,10.244.2.2:5000
# datetime-web-csharp-service      10.244.1.3:80,10.244.2.3:80
```

### 6. Multi-Layer Traffic Test

```bash
# Test via HAProxy (Layer 1 + 2 + 3)
for i in {1..10}; do
  curl -s http://api-csharp.local/api/datetime | jq .time
done

# On each request:
# - HAProxy selects different worker (Layer 1)
# - Selected worker's Ingress handles it (Layer 2)
# - Service selects different pod (Layer 3)

# Check HAProxy stats
curl http://localhost:8404/stats | grep k8s_workers -A 10
```

### 7. HA Failover Test

```bash
# Simulate Worker1 failure (delete Ingress replica)
kubectl delete pod -n ingress-nginx <worker1-ingress-pod>

# Test - HAProxy automatically routes to worker2/worker3
curl http://api-csharp.local/api/datetime
# Success! ✅ Zero downtime

# Pod automatically recreated
kubectl get pods -n ingress-nginx -o wide
```

## 🔧 Troubleshooting

### Issue 1: "503 Service Temporarily Unavailable"

```bash
# Are pods ready?
kubectl get pods

# Do Service endpoints exist?
kubectl get endpoints datetime-api-csharp-service

# Solution: Wait for pods to be Ready
kubectl wait --for=condition=ready pod -l app=datetime-api-csharp
```

### Issue 2: Ingress Running on Control-Plane ❌ WRONG!

```bash
# Check
kubectl get pods -n ingress-nginx -o wide

# If on control-plane, INCORRECT! Should be on worker nodes
# NAME                                     NODE
# ingress-nginx-controller-xxx            kind-control-plane  ❌ WRONG!

# Solution: Fix deployment
kubectl delete deployment -n ingress-nginx ingress-nginx-controller
kubectl apply -f k8s/ingress-nginx-deployment.yaml

# Or recreate cluster
make clean-all
make deploy
```

### Issue 3: HAProxy Access Not Working

```bash
# Is HAProxy running?
docker ps | grep haproxy

# Check HAProxy logs
docker logs <haproxy-container-id>

# Are worker nodes reachable?
docker exec <haproxy-container-id> ping -c 1 kind-worker

# Solution: Restart HAProxy
cd haproxy
docker-compose down
docker-compose up -d
```

### Issue 4: Only 1-2 Ingress Replicas Running

```bash
# Check replica count
kubectl get deployment -n ingress-nginx ingress-nginx-controller
# READY: 2/3  ❌ Should be 3!

# Check worker node labels
kubectl get nodes --show-labels | grep ingress-ready

# Solution: Add missing label
kubectl label node kind-worker3 ingress-ready=true --overwrite
kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller
```

### Issue 5: Traffic Only Going to One Worker

```bash
# Check HAProxy config
cat haproxy/haproxy.cfg | grep -A 10 "backend k8s_workers"

# Is balance algorithm roundrobin?
# Are server lines correct?

# Check HAProxy stats
curl http://localhost:8404/stats | grep k8s_workers -A 10

# Solution: Fix HAProxy config and reload
cd haproxy
docker-compose down
docker-compose up -d
```

## 📝 Summary

### Multi-Layer Architecture

| Layer | Component                 | Location                  | Role                               | Replicas |
| ----- | ------------------------- | ------------------------- | ---------------------------------- | -------- |
| **1** | **HAProxy**               | Docker container          | External LB, failover, localhost   | 1        |
| **2** | **Ingress Controllers**   | Worker nodes (3)          | Host-based routing, SSL            | 3        |
| **3** | **Services**              | Virtual IP (cluster-wide) | Pod discovery, load balancing      | N/A      |
| **4** | **Application Pods**      | Worker nodes              | Application logic                  | 2+       |
| **-** | **kube-proxy**            | Every node                | iptables rules, network routing    | 6        |
| **-** | **Control Plane**         | 3 control-plane nodes     | Kubernetes management (API, etcd)  | 3        |

### Why This Structure Is Ideal?

#### HA & Fault Tolerance
- ✅ **3 Control Plane**: etcd quorum, API server HA
- ✅ **3 Ingress Replicas**: System continues if one worker crashes
- ✅ **HAProxy Failover**: Unhealthy worker automatically bypassed
- ✅ **Multiple App Pods**: Service-level load balancing

#### Separation of Concerns
- ✅ **Control-Plane**: Only Kubernetes management (API, scheduler, etcd)
- ✅ **Worker Nodes**: Workload (Ingress + application pods)
- ✅ **HAProxy**: External load balancing (outside Kubernetes)

#### Scalability & Performance
- ✅ **Horizontal Scaling**: Add worker node → automatic Ingress replica
- ✅ **Multi-Layer LB**: HAProxy + Ingress + Service = optimal distribution
- ✅ **Zero Downtime**: RollingUpdate for seamless deployment

#### Production-Ready
- ✅ **Best Practice**: Industry-standard HA architecture
- ✅ **Observable**: HAProxy stats, Ingress metrics, pod logs
- ✅ **Maintainable**: Declarative YAML, version-controlled

---

**Conclusion**: With 3-layer HA architecture, we achieve a **production-grade** system. HAProxy (Layer 1), Ingress Controllers (Layer 2), and Kubernetes Services (Layer 3) work together to provide **high availability, fault tolerance, and optimal load balancing**.
