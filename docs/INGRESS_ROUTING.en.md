<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](INGRESS_ROUTING.en.md) | 🇹🇷 [Türkçe](INGRESS_ROUTING.md) |
| :---------------------------------: | :-----------------------------: |

</div>

---

# Ingress Routing: Control-Plane to Worker Nodes

## 📋 Table of Contents

1. [Traffic Flow](#-traffic-flow)
2. [How It Works?](#-how-it-works)
3. [Technical Details](#-technical-details)
4. [Updated YAML Files](#-updated-yaml-files)
5. [Test and Verification](#-test-and-verification)
6. [Load Balancing Strategies](#-load-balancing-strategies)
7. [Troubleshooting](#-troubleshooting)
8. [Summary](#-summary)

---

This document explains how the Ingress Controller routes traffic to pods on worker nodes while running on the control-plane.

## 🔄 Traffic Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Requests (HTTP/HTTPS)                    │
│              http://api.local, http://web.local             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Kind Cluster (localhost:80)                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│          🎛️  CONTROL-PLANE NODE (kind-control-plane)        │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │     NGINX Ingress Controller Pod                      │  │
│  │  - Host Network: true                                 │  │
│  │  - Port 80/443 listening                              │  │
│  │  - Rules: api.local → datetime-api-service            │  │
│  │           web.local → datetime-web-service            │  │
│  └───────────────────────┬───────────────────────────────┘  │
└──────────────────────────┼──────────────────────────────────┘
                           │
                           ▼
          ┌────────────────┴─────────────────┐
          │                                  │
          ▼                                  ▼
┌──────────────────────┐          ┌──────────────────────┐
│ datetime-api-service │          │ datetime-web-service │
│  Type: ClusterIP     │          │  Type: ClusterIP     │
│  Port: 80            │          │  Port: 80            │
│  Selector:           │          │  Selector:           │
│    app=datetime-api  │          │    app=datetime-web  │
└──────────┬───────────┘          └──────────┬───────────┘
           │                                 │
           │                                 │
   ┌───────┴──────────┐              ┌───────┴──────────┐
   │                  │              │                  │
   ▼                  ▼              ▼                  ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ 💼 WORKER 1 │  │ 💼 WORKER 2 │  │ 💼 WORKER 1 │  │ 💼 WORKER 2 │
│ kind-worker │  │kind-worker2 │  │ kind-worker │  │kind-worker2 │
│             │  │             │  │             │  │             │
│ API Pod 1   │  │ API Pod 2   │  │ Web Pod 1   │  │ Web Pod 2   │
└─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘
```

## 🎯 How It Works?

### 1. Ingress Controller (On Control-Plane)

Ingress Controller runs on control-plane because:

- ✅ Listens on host's 80/443 ports with `hostNetwork: true`
- ✅ Connected to Docker host via `extraPortMappings`
- ✅ `ingress-ready=true` label is on control-plane

```yaml
# kind-config.yaml
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80 # Ingress Controller listens here
        hostPort: 80 # Connected to host
```

### 2. Service Discovery (Kubernetes DNS)

Services find pods using **label selector**:

```yaml
# datetime-api-service
spec:
  selector:
    app: datetime-api # Finds ALL pods with this label
```

Service automatically finds all pods with this label **regardless of which node they're on**.

### 3. Ingress Rules

Ingress routes based on Service names:

```yaml
# ingress.yaml
rules:
  - host: api.local
    http:
      paths:
        - path: /
          backend:
            service:
              name: datetime-api-service # Route to Service
```

### 4. Load Balancing

Service **automatically** distributes traffic to pods:

- Round-robin (default)
- Session affinity (sticky sessions)
- Based on health checks

## 🔍 Technical Details

### Kubernetes Service Mesh

**kube-proxy** runs on every node in Kubernetes:

```
Control-Plane Node:
├── Ingress Controller (Pod)
│   └── Routes traffic to Service
└── kube-proxy
    └── Translates Service to pod IPs on worker nodes

Worker Node 1:
├── datetime-api Pod (10.244.1.2)
├── datetime-web Pod (10.244.1.3)
└── kube-proxy
    └── Manages network rules

Worker Node 2:
├── datetime-api Pod (10.244.2.2)
├── datetime-web Pod (10.244.2.3)
└── kube-proxy
    └── Manages network rules
```

### ClusterIP Service

```yaml
type: ClusterIP # Accessible from within cluster
```

Service gets a **virtual IP**:

- `datetime-api-service`: 10.96.xxx.xxx:80
- This IP is in front of all pod IPs
- kube-proxy routes this IP to pod IPs

### Network Flow

```
1. Request arrives: http://api.local/api/datetime

2. Ingress Controller (control-plane):
   - Check host header: api.local ✓
   - Find Service: datetime-api-service
   - Forward to Service IP: 10.96.xxx.xxx:80

3. kube-proxy (on every node):
   - Intercepts Service IP: 10.96.xxx.xxx:80
   - Lists backend pods:
     * 10.244.1.2:5000 (worker1)
     * 10.244.2.2:5000 (worker2)
   - Round-robin: 10.244.1.2:5000 selected

4. Network routing:
   - Packet sent to worker1
   - API pod responds
   - Response returns to Ingress
   - Sent to client
```

## ✅ Updated YAML Files

### ingress.yaml Changes

```yaml
annotations:
  # Added: Backend protocol
  nginx.ingress.kubernetes.io/backend-protocol: "HTTP"

  # Added: Load balancing strategy
  nginx.ingress.kubernetes.io/load-balance: "round_robin"

  # Removed: rewrite-target (unnecessary)
  # nginx.ingress.kubernetes.io/rewrite-target: /
```

### Service Changes

```yaml
# Added: Session affinity
sessionAffinity: ClientIP
sessionAffinityConfig:
  clientIP:
    timeoutSeconds: 300 # Routes to same pod for 5 minutes
```

**Advantage**: Same client is routed to same pod (sticky session).

## 🧪 Test and Verification

### 1. Ingress Controller Location

```bash
# Where is Ingress Controller running?
kubectl get pods -n ingress-nginx -o wide

# Expected:
# NAME                                     NODE
# ingress-nginx-controller-xxx            kind-control-plane
```

### 2. Application Pod Locations

```bash
# Where are application pods?
kubectl get pods -o wide

# Expected:
# NAME                           NODE
# datetime-api-xxx              kind-worker or kind-worker2
# datetime-web-xxx              kind-worker or kind-worker2
```

### 3. Service Endpoints

```bash
# Which pods is Service routing to?
kubectl get endpoints datetime-api-service
kubectl get endpoints datetime-web-service

# Output:
# NAME                    ENDPOINTS
# datetime-api-service    10.244.1.2:5000,10.244.2.2:5000
# datetime-web-service    10.244.1.3:80,10.244.2.3:80
```

### 4. Traffic Test

```bash
# Send requests to API
for i in {1..10}; do
  curl -s http://api.local/api/datetime | jq .time
done

# Different pods may respond each time (round-robin)
```

### 5. Monitor in Pod Logs

```bash
# Terminal 1: API Pod 1 logs
kubectl logs -f datetime-api-xxx-pod1

# Terminal 2: API Pod 2 logs
kubectl logs -f datetime-api-xxx-pod2

# Terminal 3: Send request
curl http://api.local/api/datetime

# Whichever terminal shows log, that pod responded
```

### 6. Network Debugging

```bash
# Service DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup datetime-api-service

# Direct access to Service (from inside cluster)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://datetime-api-service/api/datetime
```

## 📊 Load Balancing Strategies

### Round Robin (Default)

```yaml
nginx.ingress.kubernetes.io/load-balance: "round_robin"
```

Requests distributed to pods in order:

- Request 1 → Pod 1
- Request 2 → Pod 2
- Request 3 → Pod 1
- Request 4 → Pod 2

### IP Hash

```yaml
nginx.ingress.kubernetes.io/load-balance: "ip_hash"
```

Same client IP always routed to same pod.

### Session Affinity

```yaml
# Service level
sessionAffinity: ClientIP
```

Client IP based sticky session (5 minutes).

## 🔧 Troubleshooting

### Issue 1: "503 Service Temporarily Unavailable"

```bash
# Are pods ready?
kubectl get pods

# Do Service endpoints exist?
kubectl get endpoints datetime-api-service

# Solution: Wait for pods to be Ready
kubectl wait --for=condition=ready pod -l app=datetime-api
```

### Issue 2: Ingress Running on Worker Node

```bash
# Check
kubectl get pods -n ingress-nginx -o wide

# If on worker, kind-config.yaml is wrong
# ingress-ready=true should only be on control-plane

# Solution: Recreate cluster
make clean-cluster
make deploy
```

### Issue 3: Traffic Only Going to One Pod

```bash
# Check load balancing algorithm
kubectl describe ingress datetime-ingress

# Is session affinity off?
kubectl get service datetime-api-service -o yaml | grep sessionAffinity

# Solution: Remove session affinity or lower timeout
```

## 📝 Summary

| Component              | Location                  | Role                     |
| ---------------------- | ------------------------- | ------------------------ |
| **Ingress Controller** | control-plane             | Captures HTTP requests   |
| **Service**            | Virtual IP (cluster-wide) | Finds and routes to pods |
| **Pods**               | worker1, worker2          | Runs the application     |
| **kube-proxy**         | Every node                | Manages network rules    |

### Why This Structure Is Ideal?

✅ **Separation of Concerns**: Control-plane for management, workers for application
✅ **Scalability**: Add/remove worker nodes, Ingress unaffected
✅ **High Availability**: If one worker crashes, other continues
✅ **Load Balancing**: Automatic traffic distribution
✅ **Production-like**: Similar to real clusters

---

**Conclusion**: Although Ingress Controller runs on control-plane, it seamlessly routes traffic to pods on worker nodes thanks to Service and kube-proxy. This is completely normal and correct by Kubernetes design.
