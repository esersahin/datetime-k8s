<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](LOAD_BALANCING.en.md) | 🇹🇷 [Türkçe](LOAD_BALANCING.md) |
|:---:|:---:|

</div>

---

# Load Balancing Configuration

## 📋 Table of Contents

1. [Multi-Layer Load Balancing Architecture](#-multi-layer-load-balancing-architecture)
2. [Load Balancing Strategies](#-load-balancing-strategies)
3. [Recommendations for Our Project](#-recommendations-for-our-project)
4. [Changing Configuration](#-changing-configuration)
5. [Testing](#-testing)
6. [Comparison](#-comparison)
7. [Recommendation for Our Project](#-recommendation-for-our-project)
8. [Summary](#-summary)

---

This document explains the multi-layer load balancing architecture in our project and different load balancing strategies you can use in ingress.yaml.

## 🏗️ Multi-Layer Load Balancing Architecture

Our project has a **4-layer** load balancing structure:

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: HAProxy Load Balancer (Docker Container)          │
│  ↓ Round-robin distribution to 3 worker nodes               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: NGINX Ingress Controllers (3 replicas)            │
│  ↓ Running on worker nodes (kind-worker, worker2, worker3)  │
│  ↓ hostNetwork: true (localhost:80/443)                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: Kubernetes Services (ClusterIP)                   │
│  ↓ 4 services: api-csharp, api-go, web-csharp, web-go       │
│  ↓ Selector-based pod discovery                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 4: Application Pods (13 pods total)                  │
│  ↓ 3 replicas per application × 4 apps                      │
│  ↓ Distributed across 3 worker nodes                        │
└─────────────────────────────────────────────────────────────┘
```

### Traffic Flow (Complete Flow)

```
Client Request (http://api-csharp.local/api/datetime)
         ↓
    localhost:80 (macOS)
         ↓
┌────────────────────────────────────────────────────┐
│ HAProxy Container (Layer 1)                        │
│ - Round-robin to 3 worker nodes                    │
│ - Health checks on port 80                         │
│ - Stats dashboard: localhost:8404                  │
└────────────────────────────────────────────────────┘
         ↓ (randomly picks one)
    ┌────┴────┬────────────┐
    ↓         ↓            ↓
kind-worker  kind-worker2  kind-worker3
    ↓         ↓            ↓
┌────────────────────────────────────────────────────┐
│ NGINX Ingress Controller (Layer 2)                 │
│ - 1 replica per worker node (3 total)              │
│ - hostNetwork: true                                │
│ - Listens on port 80/443                           │
│ - Routes based on Host header                      │
└────────────────────────────────────────────────────┘
         ↓ (matches Host: api-csharp.local)
┌────────────────────────────────────────────────────┐
│ ClusterIP Service (Layer 3)                        │
│ datetime-api-csharp-service:80                     │
│ - selector: app=datetime-api-csharp                │
│ - sessionAffinity: None (Round Robin)              │
└────────────────────────────────────────────────────┘
         ↓ (round-robin to 3 endpoints)
    ┌────┴────┬────────────┐
    ↓         ↓            ↓
┌────────────────────────────────────────────────────┐
│ Application Pods (Layer 4)                         │
│ - datetime-api-csharp-xxxxx-1 (10.244.4.2)         │
│ - datetime-api-csharp-xxxxx-2 (10.244.3.2)         │
│ - datetime-api-csharp-xxxxx-3 (10.244.5.2)         │
└────────────────────────────────────────────────────┘
         ↓
    Response (JSON)
```

### Layer-by-Layer Explanation

#### Layer 1: HAProxy Load Balancer
- **Technology**: HAProxy 2.8+ (Docker container)
- **Task**: Distributes traffic to 3 worker nodes
- **Algorithm**: Round-robin
- **Port Mapping**: 80:80, 443:443, 8404:8404 (stats)
- **Health Check**: Checks port 80 of each worker node
- **Config**: `haproxy.cfg`

```bash
# HAProxy stats
curl http://localhost:8404

# Backend status
docker exec haproxy-lb cat /etc/haproxy/haproxy.cfg
```

#### Layer 2: NGINX Ingress Controller
- **Technology**: NGINX Ingress Controller v1.13.3
- **Placement**: Worker nodes (kind-worker, kind-worker2, kind-worker3)
- **Replicas**: 3 (1 per worker node)
- **hostNetwork**: true (directly listens on ports 80/443)
- **Task**: Routes based on Host header (api-csharp.local, api-go.local, ...)

```bash
# Ingress Controller status
kubectl get pods -n ingress-nginx -o wide
# Expected: 3 pods on worker nodes

# Ingress rules
kubectl get ingress datetime-ingress -o yaml
```

#### Layer 3: Kubernetes Services
- **Technology**: ClusterIP Services
- **Count**: 4 (api-csharp, api-go, web-csharp, web-go)
- **Task**: Pod discovery and load balancing
- **Algorithm**: Round Robin (sessionAffinity: None)
- **Endpoints**: Each service has 3 pod endpoints

```bash
# List services
kubectl get svc

# View endpoints
kubectl get endpoints
# Expected: 3 endpoints per service
```

#### Layer 4: Application Pods
- **Total**: 13 pods (3 per app × 4 apps + 1 spare)
- **Distribution**: Evenly distributed across worker nodes
- **Technology**:
  - C# API (.NET 9) - 32.6 MB
  - Go API (Go 1.21) - ~15 MB
  - C# Web (NGINX + Static HTML)
  - Go Web (NGINX + Static HTML)

```bash
# List pods (with node placement)
kubectl get pods -o wide

# Pods should be distributed across worker nodes
```

---

## 🔀 Load Balancing Strategies

This section applies to **Layer 2 (Ingress)** and **Layer 3 (Service)**.

### 1. Round Robin (Default)

**What it does**: Distributes requests to pods in order.

```yaml
# ingress.yaml
metadata:
  annotations:
    # Default behavior - annotation not required
    # Or to explicitly specify:
    nginx.ingress.kubernetes.io/load-balance: "round_robin"
```

**Use Case**:

- All pods have equal capacity
- Stateless applications
- No sessions or external session store used

**Example Flow**:

```
Request 1 → Pod A (10.244.4.2)
Request 2 → Pod B (10.244.3.2)
Request 3 → Pod C (10.244.5.2)
Request 4 → Pod A (10.244.4.2)
```

### 2. IP Hash (Sticky Sessions - Client IP Based)

**What it does**: Same client IP always routed to same pod.

```yaml
# ingress.yaml
metadata:
  annotations:
    # Client IP based hash
    nginx.ingress.kubernetes.io/upstream-hash-by: "$binary_remote_addr"
```

**Use Case**:

- Session data stored in pod
- WebSocket connections
- User-based cache
- Stateful applications

**Example Flow**:

```
Client 1.2.3.4 → Always Pod A
Client 5.6.7.8 → Always Pod B
Client 9.10.11.12 → Always Pod C
```

### 3. Least Connections

**What it does**: Routes to pod with least active connections.

```yaml
# ingress.yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/load-balance: "least_conn"
```

**Use Case**:

- Long-duration connections (WebSocket, SSE)
- Variable processing times
- Dynamic load distribution

**Example Flow**:

```
Pod A: 5 active connections
Pod B: 2 active connections
Pod C: 8 active connections
→ New request goes to Pod B (least connections)
```

### 4. Custom Hash (Custom Field Based)

**What it does**: Hashes based on specific field in request.

```yaml
# ingress.yaml
metadata:
  annotations:
    # Cookie based
    nginx.ingress.kubernetes.io/upstream-hash-by: "$cookie_user_id"

    # Or header based
    nginx.ingress.kubernetes.io/upstream-hash-by: "$http_x_user_id"

    # Or URI based
    nginx.ingress.kubernetes.io/upstream-hash-by: "$request_uri"
```

**Use Case**:

- Cookie-based sessions
- User ID based routing
- API key based routing

---

## 🎯 Recommendations for Our Project

### Current Configuration (Applied) ✅

Our project has **4 layer load balancing** active:

```yaml
# Layer 1: HAProxy (haproxy.cfg)
backend worker_nodes
    mode http
    balance roundrobin  # Round-robin to 3 workers
    option httpchk GET /healthz
    server worker1 172.20.0.6:80 check
    server worker2 172.20.0.5:80 check
    server worker3 172.20.0.3:80 check
```

```yaml
# Layer 2: Ingress (k8s/ingress.yaml)
metadata:
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/load-balance: "round_robin"  # Round Robin
```

```yaml
# Layer 3: Services (k8s/*-deployment.yaml)
spec:
  sessionAffinity: None  # Round Robin
  # Kubernetes default load balancing
```

```yaml
# Layer 4: Pods
# 3 replicas per application
# Distributed across worker nodes
```

### Scenario 1: Stateless API (✅ Current Configuration)

**Our situation**: All APIs are completely stateless (no sessions)

**Configuration**:
- ✅ HAProxy: Round Robin
- ✅ Ingress: Round Robin
- ✅ Service: Round Robin (sessionAffinity: None)

**Advantages**:
- ✅ Optimal load distribution (across 4 layers)
- ✅ Automatic distribution if pod/node goes down
- ✅ Simple and predictable
- ✅ Easy to scale

### Scenario 2: Session-Based Application

If sessions need to be added in the future:

```yaml
# ingress.yaml - IP Hash + Service Session Affinity
metadata:
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$binary_remote_addr"
```

AND in Service:

```yaml
# *-deployment.yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 300  # 5 minutes
```

**Note**: Session affinity should also be added to HAProxy:

```
# haproxy.cfg
balance source  # IP-based (instead of roundrobin)
```

### Scenario 3: WebSocket Usage

If WebSocket connections are added:

```yaml
# ingress.yaml - Least Connections
metadata:
  annotations:
    nginx.ingress.kubernetes.io/load-balance: "least_conn"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
```

---

## 🔄 Changing Configuration

### Method 1: Edit YAML File

```bash
# Edit ingress.yaml
nano k8s/ingress.yaml

# Apply change
kubectl apply -f k8s/ingress.yaml

# Check Ingress
kubectl describe ingress datetime-ingress
```

### Method 2: kubectl patch

```bash
# Switch to round robin
kubectl patch ingress datetime-ingress -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/load-balance":"round_robin"}}}'

# Switch to IP hash
kubectl patch ingress datetime-ingress -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/upstream-hash-by":"$binary_remote_addr"}}}'

# Switch to least connections
kubectl patch ingress datetime-ingress -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/load-balance":"least_conn"}}}'
```

### Method 3: Add Makefile Targets

We can add new targets to Makefile:

```makefile
# Add to Makefile
set-lb-roundrobin: ## Load balancing: Round Robin
	@echo "$(YELLOW)Setting load balance to round_robin...$(NC)"
	@kubectl patch ingress datetime-ingress -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/load-balance":"round_robin"}}}'
	@echo "$(GREEN)✓ Load balancing set to round_robin$(NC)"

set-lb-iphash: ## Load balancing: IP Hash
	@echo "$(YELLOW)Setting load balance to IP hash...$(NC)"
	@kubectl patch ingress datetime-ingress -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/upstream-hash-by":"$$binary_remote_addr"}}}'
	@echo "$(GREEN)✓ Load balancing set to IP hash$(NC)"

set-lb-leastconn: ## Load balancing: Least Connections
	@echo "$(YELLOW)Setting load balance to least_conn...$(NC)"
	@kubectl patch ingress datetime-ingress -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/load-balance":"least_conn"}}}'
	@echo "$(GREEN)✓ Load balancing set to least_conn$(NC)"

show-lb: ## Show current load balancing config
	@echo "$(BLUE)Current Load Balancing Configuration:$(NC)"
	@kubectl get ingress datetime-ingress -o jsonpath='{.metadata.annotations}' | jq
```

**Usage**:

```bash
make set-lb-roundrobin
make set-lb-iphash
make set-lb-leastconn
make show-lb
```

---

## 🧪 Testing

### Test 1: Multi-Layer Load Balancing

```bash
# Test all layers
for i in {1..12}; do
  echo "Request $i:"
  curl -s http://api-csharp.local/api/datetime | jq -r '.date'
done

# Expected: Equal distribution to all 3 pods (each pod 4 requests)

# Check pod logs
kubectl logs -l app=datetime-api-csharp --tail=20

# HAProxy stats
curl http://localhost:8404/stats
```

### Test 2: HAProxy Backend Health

```bash
# HAProxy backend status
curl -s http://localhost:8404/stats | grep worker

# Expected: 3/3 workers UP
# worker1 (kind-worker): UP
# worker2 (kind-worker2): UP
# worker3 (kind-worker3): UP
```

### Test 3: Ingress Controller Distribution

```bash
# Check Ingress Controller placement on worker nodes
kubectl get pods -n ingress-nginx -o wide

# Expected:
# ingress-nginx-controller-xxxxx  kind-worker   ✅
# ingress-nginx-controller-xxxxx  kind-worker2  ✅
# ingress-nginx-controller-xxxxx  kind-worker3  ✅
```

### Test 4: Round Robin (Layer 3 - Service)

```bash
# Set round robin (already default)
make set-lb-roundrobin

# Send 10 requests
for i in {1..10}; do
  curl -s http://api-csharp.local/api/datetime | jq -r '.time'
done

# Check pod logs - all pods should show logs
kubectl logs -l app=datetime-api-csharp --tail=5
```

### Test 5: IP Hash (Sticky)

```bash
# Set IP hash
make set-lb-iphash

# 10 requests from same client
for i in {1..10}; do
  curl -s http://api-csharp.local/api/datetime | jq -r '.time'
done

# Only 1 pod should show logs (same IP → same pod)
kubectl logs -l app=datetime-api-csharp --tail=5
```

### Test 6: Test from Different IPs

```bash
# Set IP hash
make set-lb-iphash

# From different source IPs (Docker containers)
for i in {1..5}; do
  docker run --rm --network kind curlimages/curl:latest \
    curl -s http://api-csharp.local/api/datetime
done

# Each container has different IP, can go to different pods
```

---

## 📊 Comparison

### Load Balancing Strategies

| Strategy        | Advantage           | Disadvantage         | Use Case      |
| --------------- | ------------------- | -------------------- | ------------- |
| **Round Robin** | Equal distribution  | No session retention | Stateless API |
| **IP Hash**     | Session consistency | Uneven distribution  | Stateful app  |
| **Least Conn**  | Dynamic load        | Complex              | WebSocket     |
| **Custom Hash** | Flexible            | Complex              | Special needs |

### Multi-Layer Architecture Benefits

| Layer | Technology | Task | Redundancy |
| ----- | --------- | ----- | ---------- |
| **Layer 1** | HAProxy | Worker node distribution | Single container (can be HA) |
| **Layer 2** | NGINX Ingress | Host-based routing | 3 replicas (HA) |
| **Layer 3** | ClusterIP Service | Pod discovery | Kubernetes-managed (HA) |
| **Layer 4** | Application Pods | Business logic | 3 replicas per app (HA) |

**Total HA**: 4-layer redundancy

---

## 🎯 Recommendation for Our Project

### DateTime API & Web Application

**Status**: Completely stateless (no sessions, just returns datetime)

**✅ Applied Configuration** (Current):

```yaml
# Layer 1: HAProxy (haproxy.cfg)
backend worker_nodes
    balance roundrobin  # ✅ Round Robin

# Layer 2: Ingress (k8s/ingress.yaml)
metadata:
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/load-balance: "round_robin"  # ✅ Round Robin

# Layer 3: Services (k8s/*-deployment.yaml)
spec:
  sessionAffinity: None  # ✅ Round Robin

# Layer 4: Pods
replicas: 3  # ✅ 3 replicas per application
```

**Why**:

- ✅ Each pod gets equal load (across 4 layers)
- ✅ No issues if a pod/node restarts
- ✅ Automatic failover with HAProxy health checks
- ✅ HA with 3 Ingress Controllers
- ✅ Easy to scale (all layers)
- ✅ Simple and predictable
- ✅ Best choice for stateless APIs

### Architecture Highlights

```
High Availability (HA) at Every Layer:
┌────────────────────────────────────────┐
│ HAProxy: 1 container (can be scaled)  │
├────────────────────────────────────────┤
│ Ingress: 3 replicas (worker nodes)    │
├────────────────────────────────────────┤
│ Services: Kubernetes-managed (HA)     │
├────────────────────────────────────────┤
│ Pods: 3 replicas per app × 4 apps     │
└────────────────────────────────────────┘

Total: 13 application pods + 3 ingress pods
Cluster: 3 control-plane + 3 worker nodes
```

---

## 📝 Summary

### Current Configuration (Current) ✅

**Multi-Layer Load Balancing**:
1. **HAProxy (Layer 1)**: Round-robin → 3 worker nodes
2. **NGINX Ingress (Layer 2)**: Round-robin → Pods (3 replicas on workers)
3. **ClusterIP Service (Layer 3)**: Round-robin → Pods (sessionAffinity: None)
4. **Application Pods (Layer 4)**: 3 replicas per app, distributed

**Result**: Optimal distribution, 4-layer redundancy, production-ready HA

**Ideal for DateTime project**: ✅ Multi-layer Round Robin (stateless)

### To Change

```bash
# Change Layer 2 (Ingress)
nano k8s/ingress.yaml
kubectl apply -f k8s/ingress.yaml

# Change Layer 1 (HAProxy)
nano haproxy.cfg
docker restart haproxy-lb

# Or using Makefile
make set-lb-roundrobin
make set-lb-iphash
make set-lb-leastconn
```

### Monitoring

```bash
# Layer 1: HAProxy stats
curl http://localhost:8404/stats

# Layer 2: Ingress Controller
kubectl get pods -n ingress-nginx -o wide

# Layer 3: Services & Endpoints
kubectl get endpoints

# Layer 4: Pods
kubectl get pods -o wide
```

---

## 🔍 Troubleshooting

### Problem: Uneven load distribution

**Reason**: Incorrect configuration in one layer

**Solution**:
```bash
# Check each layer
# Layer 1
curl http://localhost:8404/stats

# Layer 2
kubectl get ingress datetime-ingress -o yaml

# Layer 3
kubectl get svc -o yaml

# Layer 4
kubectl top pods  # Resource usage
```

### Problem: One worker node DOWN

**Expected**: HAProxy automatically disables that worker

**Verify**:
```bash
# HAProxy backend status
curl http://localhost:8404/stats | grep worker

# Ingress Controller status
kubectl get pods -n ingress-nginx -o wide
```

---

**Last Updated**: 2025-10-29
**Version**: 2.0
**Project**: DateTime Kubernetes Polyglot Microservices with Multi-Layer Load Balancing
