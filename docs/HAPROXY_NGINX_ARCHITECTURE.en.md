<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](HAPROXY_NGINX_ARCHITECTURE.en.md) | 🇹🇷 [Türkçe](HAPROXY_NGINX_ARCHITECTURE.md) |
| :----------------------------------------------: | :------------------------------------------: |

</div>

---

# HAProxy and NGINX Ingress Architecture

## 📋 Table of Contents

1. [Introduction](#-introduction)
2. [System Components](#-system-components)
3. [Two-Layer Load Balancing Architecture](#-two-layer-load-balancing-architecture)
4. [Detailed Traffic Flow](#-detailed-traffic-flow)
5. [HAProxy vs NGINX Ingress Comparison](#-haproxy-vs-nginx-ingress-comparison)
6. [Why Two Layers?](#-why-two-layers)
7. [Example Scenarios](#-example-scenarios)
8. [Practical Commands and Tests](#-practical-commands-and-tests)
9. [Analogy Explanation](#-analogy-explanation)
10. [Summary](#-summary)

---

## 🎯 Introduction

This document explains in detail the differences between **HAProxy** and **NGINX Ingress Controller** used in the datetime-k8s project, how they work together, and why we use a two-layer architecture.

**Main Question**: "Did we really use HAProxy or did we make NGINX do load balancing?"

**Short Answer**: **Yes, we really use HAProxy!** And together with NGINX Ingress, we created a **two-layer** load balancing structure.

---

## 🏗️ System Components

### 1. HAProxy Container (External Load Balancer)

**Verification Commands**:

```bash
# Check HAProxy container
docker ps --filter name=kind-http-lb --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
```

**Output**:
```
NAMES          IMAGE                PORTS
kind-http-lb   haproxy:2.8-alpine   0.0.0.0:80->80/tcp, [::]:80->80/tcp,
                                    0.0.0.0:443->443/tcp, [::]:443->443/tcp,
                                    0.0.0.0:8404->8404/tcp, [::]:8404->8404/tcp
```

**Check HAProxy Version**:

```bash
docker exec kind-http-lb haproxy -v
```

**Output**:
```
HAProxy version 2.8.16-3a5d368 2025/10/03 - https://haproxy.org/
Status: long-term supported branch - will stop receiving fixes around Q2 2028.
```

**View HAProxy Config File**:

```bash
docker exec kind-http-lb cat /usr/local/etc/haproxy/haproxy.cfg | head -40
```

**Config Content**:
```haproxy
# HAProxy Load Balancer Configuration for Kind Cluster
# Automatically distributes traffic to all worker nodes
# Worker nodes are resolved via DNS (kind-worker, kind-worker2, kind-worker3)

global
    log stdout format raw local0
    maxconn 4096

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 2000ms
    timeout client  50000ms
    timeout server  50000ms

    # For fast failover
    timeout check 1000ms
    retries 2

# HTTP Traffic (port 80)
frontend http_frontend
    bind *:80
    mode http
    default_backend workers_http

# HTTP Load Balancer Backend
backend workers_http
    mode http
    balance roundrobin

    option httpchk GET /healthz
    http-check expect status 200-499

    # Worker nodes - automatically resolved via DNS
    server worker1 kind-worker:80 check inter 2s fall 2 rise 2 resolvers docker resolve-prefer ipv4
    server worker2 kind-worker2:80 check inter 2s fall 2 rise 2 resolvers docker resolve-prefer ipv4
    server worker3 kind-worker3:80 check inter 2s fall 2 rise 2 resolvers docker resolve-prefer ipv4
```

---

### 2. Worker Nodes (Kind Containers)

**Check Worker Nodes**:

```bash
docker ps --filter name=kind-worker --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

**Output**:
```
NAMES          STATUS          PORTS
kind-worker3   Up 15 minutes
kind-worker    Up 15 minutes
kind-worker2   Up 15 minutes
```

**Note**: Worker nodes have **no port mapping**! (extraPortMappings removed)
- Access is provided through HAProxy
- hostNetwork: true allows worker containers to listen on port 80

---

### 3. NGINX Ingress Controller Pods

**Check NGINX Ingress Pods**:

```bash
kubectl get pods -n ingress-nginx -o wide
```

**Output**:
```
NAME                                        READY   STATUS    NODE
ingress-nginx-controller-7f8d89bb7f-brb6k   1/1     Running   kind-worker2
ingress-nginx-controller-7f8d89bb7f-fgb9l   1/1     Running   kind-worker
ingress-nginx-controller-7f8d89bb7f-qdzm4   1/1     Running   kind-worker3
```

**Check hostNetwork Setting**:

```bash
kubectl get pods -n ingress-nginx -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,HOST-NETWORK:.spec.hostNetwork
```

**Output**:
```
NAME                                        NODE           HOST-NETWORK
ingress-nginx-controller-7f8d89bb7f-brb6k   kind-worker2   true
ingress-nginx-controller-7f8d89bb7f-fgb9l   kind-worker    true
ingress-nginx-controller-7f8d89bb7f-qdzm4   kind-worker3   true
```

**hostNetwork: true** → NGINX pods listen on worker container's port 80

---

### 4. Ingress Resources

**Check Ingress Rules**:

```bash
kubectl get ingress -A
```

**Output**:
```
NAMESPACE   NAME               CLASS   HOSTS                                          ADDRESS     PORTS   AGE
default     datetime-ingress   nginx   api.local,api-go.local,web.local,web-go.local  localhost   80      10m
```

**View Ingress Details**:

```bash
kubectl get ingress datetime-ingress -o yaml | grep -A 10 "rules:"
```

**Output**:
```yaml
  rules:
  - host: api.local
    http:
      paths:
      - backend:
          service:
            name: api-service
            port:
              number: 80
  - host: web.local
    http:
      paths:
      - backend:
          service:
            name: web-service
```

---

## 🔄 Two-Layer Load Balancing Architecture

### Layer 1: HAProxy (External Load Balancer)

**Location**: Docker container (inside kind network, but outside Kubernetes)
**Name**: `kind-http-lb`
**Purpose**: Distribute traffic from host to worker nodes

```
┌──────────────────────────────────────────┐
│  MacBook (Host Machine)                  │
│                                          │
│  curl http://api.local/api/datetime      │
│           ↓                              │
│  localhost:80 (HAProxy listening)        │
└──────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────┐
│  HAProxy Container (kind-http-lb)        │
│                                          │
│  Frontend: *:80                          │
│  Backend: workers_http                   │
│    ├─ worker1: kind-worker:80            │
│    ├─ worker2: kind-worker2:80           │
│    └─ worker3: kind-worker3:80           │
│                                          │
│  Algorithm: Round-robin                  │
│  Health Check: GET /healthz (2s)         │
└──────────────────────────────────────────┘
           ↓
     (Round-robin selection)
           ↓
┌─────────┬──────────┬──────────┐
│ Worker1 │ Worker2  │ Worker3  │  ← Kind Containers
│ :80     │ :80      │ :80      │
└─────────┴──────────┴──────────┘
```

**What Does HAProxy Do?**
- ✅ **Selection**: Chooses one of 3 workers (round-robin)
- ✅ **Failover**: If one worker is DOWN, routes to others
- ✅ **Health Check**: Checks `/healthz` endpoint every 2 seconds
- ✅ **DNS-based**: Works even if worker IPs change (kind-worker, kind-worker2, kind-worker3)

---

### Layer 2: NGINX Ingress Controller (Internal Router)

**Location**: Kubernetes pods (1 on each worker node)
**Name**: `ingress-nginx-controller`
**Purpose**: Route traffic to correct Kubernetes Service based on host header

```
Worker Node (example: kind-worker)
┌────────────────────────────────────────────┐
│                                            │
│  Port :80 (via hostNetwork: true)          │
│           ↓                                │
│  ┌──────────────────────────────────────┐  │
│  │ NGINX Ingress Controller POD         │  │
│  │                                      │  │
│  │ Host header check:                   │  │
│  │                                      │  │
│  │ IF Host == "api.local"               │  │
│  │    → api-service:80                  │  │
│  │                                      │  │
│  │ IF Host == "web.local"               │  │
│  │    → web-service:80                  │  │
│  │                                      │  │
│  │ IF Host == "api-go.local"            │  │
│  │    → api-go-service:80               │  │
│  │                                      │  │
│  │ IF Host == "web-go.local"            │  │
│  │    → web-go-service:80               │  │
│  └──────────────────────────────────────┘  │
│           ↓                                │
│  ┌──────────────────────────────────────┐  │
│  │ Kubernetes Services                  │  │
│  │  ├─ api-service                      │  │
│  │  ├─ web-service                      │  │
│  │  ├─ api-go-service                   │  │
│  │  └─ web-go-service                   │  │
│  └──────────────────────────────────────┘  │
│           ↓                                │
│  ┌──────────────────────────────────────┐  │
│  │ Application Pods                     │  │
│  │  ├─ api-deployment-xxx               │  │
│  │  ├─ web-deployment-xxx               │  │
│  │  ├─ api-go-deployment-xxx            │  │
│  │  └─ web-go-deployment-xxx            │  │
│  └──────────────────────────────────────┘  │
│                                            │
└────────────────────────────────────────────┘
```

**What Does NGINX Ingress Do?**
- ✅ **Host-based Routing**: Looks at HTTP Host header (`api.local`, `web.local`, etc.)
- ✅ **Service Mapping**: Routes to correct Kubernetes Service
- ✅ **SSL Termination**: Decrypts HTTPS traffic (for 443)
- ✅ **Path-based Routing**: Different paths can route to different services for same host

---

## 📊 Detailed Traffic Flow

### Complete Request Flow: `curl http://api.local/api/datetime`

```
═══════════════════════════════════════════════════════════════════
          COMPLETE TRAFFIC FLOW EXAMPLE
═══════════════════════════════════════════════════════════════════

Request: curl http://api.local/api/datetime

┌─────────────────────────────────────────────────────────────────┐
│ STEP 1: Client → HAProxy (External Load Balancer)               │
└─────────────────────────────────────────────────────────────────┘

  Client (curl)
    │
    │ DNS: api.local → 127.0.0.1 (via /etc/hosts)
    │
    ↓
  localhost:80
    │
    │ Docker Port Mapping: 0.0.0.0:80 → kind-http-lb:80
    │
    ↓
  HAProxy Container (kind-http-lb)
    │
    │ Task: Select one of 3 workers (round-robin)
    │
    │ Backend Configuration:
    │   server worker1 kind-worker:80 check
    │   server worker2 kind-worker2:80 check  ← Let's say this is selected
    │   server worker3 kind-worker3:80 check
    │
    ↓
  kind-worker2:80 (Docker container)


┌─────────────────────────────────────────────────────────────────┐
│ STEP 2: Worker Node → NGINX Ingress (Internal Router)           │
└─────────────────────────────────────────────────────────────────┘

  kind-worker2 Container
    │
    │ Port :80 open (via hostNetwork: true)
    │
    ↓
  NGINX Ingress Controller Pod
  (running on kind-worker2)
    │
    │ Task: Check HTTP Host header and route
    │
    │ HTTP Headers:
    │   Host: api.local
    │   GET /api/datetime
    │
    │ Ingress Rules Check:
    │   IF Host == "api.local" THEN
    │     backend: api-service:80  ← MATCH!
    │
    ↓
  Kubernetes Service: api-service
    │
    │ Type: ClusterIP
    │ Cluster IP: 10.96.xxx.xxx
    │ Port: 80
    │
    ↓


┌─────────────────────────────────────────────────────────────────┐
│ STEP 3: Service → Application Pod (Pod Load Balancing)          │
└─────────────────────────────────────────────────────────────────┘

  api-service (Kubernetes Service)
    │
    │ Task: Select one of endpoints (kube-proxy)
    │
    │ Endpoints:
    │   - api-deployment-xxx-pod1 (10.244.1.5:8080)
    │   - api-deployment-xxx-pod2 (10.244.2.7:8080) ← Let's say this is selected
    │   - api-deployment-xxx-pod3 (10.244.3.9:8080)
    │
    ↓
  Application Pod: api-deployment-xxx-pod2
    │
    │ Container: ASP.NET Core API
    │ Port: 8080
    │
    │ Controller: DateTimeController
    │   GET /api/datetime
    │
    ↓
  Response:
  {
    "date": "26.10.2025",
    "time": "13:32:36",
    "dayOfWeek": "Sunday",
    "timestamp": "2025-10-26T13:32:36"
  }


┌─────────────────────────────────────────────────────────────────┐
│ STEP 4: Response Path (Same Route Back)                         │
└─────────────────────────────────────────────────────────────────┘

  Application Pod
    ↓
  api-service
    ↓
  NGINX Ingress Controller (kind-worker2)
    ↓
  HAProxy (kind-http-lb)
    ↓
  Client (curl)
```

**Test Command**:

```bash
curl -v http://api.local/api/datetime
```

**Output Analysis**:
```
* Connected to api.local (::1) port 80        ← Connected to HAProxy
> Host: api.local                             ← NGINX Ingress will use this
< HTTP/1.1 200 OK
{"date":"26.10.2025","time":"13:32:36",...}  ← Response from application pod
```

---

## 🔍 HAProxy vs NGINX Ingress Comparison

| **FEATURE**         | **HAProxy**                               | **NGINX Ingress**                      |
| ------------------- | ----------------------------------------- | -------------------------------------- |
| **Location**        | Docker container (outside Kubernetes)     | Kubernetes pod (on each worker)        |
| **Main Task**       | Worker node selection (load balancing)    | Service routing (host-based)           |
| **Routing Criteria**| Round-robin (worker1,2,3)                 | HTTP Host header (api.local, etc.)     |
| **Layer**           | Layer 4/7                                 | Layer 7                                |
| **Health Check**    | GET /healthz (every 2 seconds)            | Kubernetes readinessProbe              |
| **Failover**        | Yes (routes to others if worker DOWN)     | Yes (routes to other pod if pod DOWN)  |
| **SSL Termination** | Yes (for 443)                             | Yes (for 443)                          |
| **Target**          | Worker nodes (kind-worker:80)             | Kubernetes Services (api-service:80)   |
| **Configuration**   | haproxy.cfg                               | Ingress YAML                           |
| **Stats Page**      | Yes (:8404)                               | No                                     |
| **DNS Resolution**  | Yes (Docker DNS: 127.0.0.11)              | Kubernetes CoreDNS                     |
| **Replica Count**   | 1 (Single point, but external)            | 3 (1 on each worker)                   |

---

## 💡 Why Two Layers?

### ❓ QUESTION: Why not just use NGINX Ingress?

### 💡 ANSWER:

#### 1️⃣ Worker Node Failover

**Problem**:
- NGINX Ingress has 1 pod per worker (hostNetwork: true)
- If worker1 crashes, worker1:80 port is unreachable
- Worker nodes have no port mapping (extraPortMappings removed)

**Solution**:
- HAProxy sees worker1 is DOWN
- HAProxy routes to worker2/3
- Service continues without interruption

**Test**:
```bash
# Stop worker1
docker stop kind-worker

# Still working?
curl http://api.local/api/datetime
# ✅ WORKING! (via worker2 and worker3)
```

---

#### 2️⃣ Standard Port Access (80/443)

**Problem**:
- Worker nodes have no port mapping
- Users would need to use ports like `http://localhost:8080`, `http://localhost:8081`

**Solution**:
- HAProxy distributes localhost:80 to all workers
- Users can access without port numbers
- Production-like: `http://api.local` (no port!)

**Comparison**:
```bash
# WITHOUT HAProxy (old method):
curl http://localhost:8080/api/datetime  # worker1
curl http://localhost:8081/api/datetime  # worker2
curl http://localhost:8082/api/datetime  # worker3

# WITH HAProxy (current method):
curl http://api.local/api/datetime       # HAProxy routes ✅
```

---

#### 3️⃣ High Availability (HA)

**Scenario**: 3 workers: worker1, worker2, worker3

```
Normal State:
  ✅ worker1 → UP
  ✅ worker2 → UP
  ✅ worker3 → UP
  ✅ HAProxy → Round-robin (1→2→3→1→2→3...)

Worker1 Crashed:
  ❌ worker1 → DOWN
  ✅ worker2 → UP
  ✅ worker3 → UP
  ✅ HAProxy → Round-robin (2→3→2→3...)
  ✅ Health check: worker1 checked every 2 seconds

Worker1 Back Up:
  ✅ worker1 → UP (after 2 successful health checks)
  ✅ worker2 → UP
  ✅ worker3 → UP
  ✅ HAProxy → Round-robin (1→2→3→1→2→3...)
```

**Check HAProxy Stats**:

```bash
# Stats page
curl -s http://localhost:8404

# Or in browser:
open http://localhost:8404
```

**Stats Output** (when worker1 is DOWN):
```
Backend: workers_http
├─ worker1  ❌ DOWN      (Last check: Connection refused)
├─ worker2  ✅ UP        (L7OK/200 in 1ms)
└─ worker3  ✅ UP        (L7OK/200 in 0ms)

Active Servers: 2/3
```

---

#### 4️⃣ Production-like Setup

**In Real Production Environments**:

```
Cloud Provider (AWS/GCP/Azure)
    ↓
External Load Balancer
  - AWS: Application Load Balancer (ALB)
  - GCP: Google Cloud Load Balancing
  - Azure: Azure Load Balancer
  - On-Premise: HAProxy, F5, NGINX Plus
    ↓
Kubernetes Cluster
    ↓
Ingress Controller (Internal)
  - NGINX Ingress
  - Traefik
  - Istio Gateway
    ↓
Services & Pods
```

**Our Setup**:

```
localhost:80
    ↓
HAProxy (External LB - simulating Cloud LB)
    ↓
Kind Cluster (3 control-plane + 3 worker)
    ↓
NGINX Ingress Controller (Internal Router)
    ↓
Services & Pods
```

**Advantage**: When moving to production, only need to change HAProxy → Cloud LB!

---

## 🎬 Example Scenarios

### Scenario 1: Normal State

```
✅ worker1, worker2, worker3 → All UP
✅ HAProxy doing round-robin
✅ NGINX Ingress running on each worker

Test:
  $ curl http://api.local/api/datetime
  → HAProxy: worker1 selected
  → NGINX (worker1): api.local → api-service
  → api-service: pod-1 selected
  → Response: 200 OK
```

**Command**:
```bash
for i in {1..6}; do
  echo "Request $i:";
  curl -s http://api.local/api/datetime | jq -r '.time';
done
```

**Output** (HAProxy round-robin):
```
Request 1: 13:45:10  ← worker1
Request 2: 13:45:11  ← worker2
Request 3: 13:45:12  ← worker3
Request 4: 13:45:13  ← worker1
Request 5: 13:45:14  ← worker2
Request 6: 13:45:15  ← worker3
```

---

### Scenario 2: Worker1 Crashed

```
❌ worker1 → DOWN
✅ worker2, worker3 → UP
✅ HAProxy skipped worker1, only sending to worker2/3
✅ Service continues to work
```

**Test**:

```bash
# Stop worker1
docker stop kind-worker

# Check HAProxy stats
curl -s http://localhost:8404 | grep -A 2 "workers_http/worker1"
# Output: worker1 DOWN

# Service still working?
curl http://api.local/api/datetime
# ✅ WORKING! (via worker2 or worker3)

# Start worker1 again
docker start kind-worker

# After 4-6 seconds (2 successful health checks)
curl -s http://localhost:8404 | grep -A 2 "workers_http/worker1"
# Output: worker1 UP
```

**HAProxy Logs**:
```bash
docker logs kind-http-lb --tail 20
```

**Example Log**:
```
[WARNING]  Server workers_http/worker1 is DOWN, reason: Layer7 wrong status, code: 502
[INFO]     Server workers_http/worker1 is UP, reason: Layer7 check passed
```

---

### Scenario 3: Worker1 and Worker2 Crashed

```
❌ worker1, worker2 → DOWN
✅ worker3 → UP
✅ HAProxy only sending to worker3
✅ Service continues to work (reduced capacity)
```

**Test**:

```bash
# Stop worker1 and worker2
docker stop kind-worker kind-worker2

# Service still working?
for i in {1..5}; do
  curl -s http://api.local/api/datetime | jq -r '.time';
done
# ✅ WORKING! (only via worker3)

# HAProxy stats
curl -s http://localhost:8404 | grep -E "(worker1|worker2|worker3)" | grep "UP\|DOWN"
# worker1: DOWN
# worker2: DOWN
# worker3: UP
```

---

### Scenario 4: One NGINX Ingress Pod Crashed

```
✅ worker1, worker2, worker3 → All UP
❌ NGINX pod on worker2 crashed
✅ HAProxy will get 502 Bad Gateway when routing to worker2
✅ HAProxy health check marks worker2 as DOWN
✅ HAProxy starts routing to worker1/3
```

**Test**:

```bash
# Delete NGINX pod on worker2
kubectl delete pod -n ingress-nginx -l app.kubernetes.io/component=controller --field-selector spec.nodeName=kind-worker2

# HAProxy health check will fail
# After 2 failed checks, worker2 will be marked DOWN

# HAProxy stats
curl -s http://localhost:8404 | grep "worker2"
# worker2: DOWN (L7: Connection refused or 502)

# Kubernetes will create new pod
kubectl get pods -n ingress-nginx -w

# When new pod is Ready
# After 2 successful checks, worker2 will be marked UP again
```

---

## 🛠️ Practical Commands and Tests

### HAProxy Commands

#### 1. HAProxy Container Status

```bash
docker ps --filter name=kind-http-lb --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

#### 2. HAProxy Stats Page

```bash
# CLI
curl -s http://localhost:8404

# Browser
open http://localhost:8404
```

#### 3. HAProxy Logs

```bash
# Last 50 logs
docker logs kind-http-lb --tail 50

# Follow logs
docker logs kind-http-lb --follow

# Health check logs
docker logs kind-http-lb --follow | grep "health check"
```

#### 4. HAProxy Config Check

```bash
# View config file
docker exec kind-http-lb cat /usr/local/etc/haproxy/haproxy.cfg

# Config syntax check
docker exec kind-http-lb haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
```

#### 5. HAProxy Restart (after config change)

```bash
docker restart kind-http-lb
```

---

### NGINX Ingress Commands

#### 1. NGINX Ingress Pods

```bash
# List pods
kubectl get pods -n ingress-nginx -o wide

# Detailed info
kubectl describe pod -n ingress-nginx -l app.kubernetes.io/component=controller

# Logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
```

#### 2. NGINX Ingress Service

```bash
# Service info
kubectl get svc -n ingress-nginx

# Service endpoints
kubectl get endpoints -n ingress-nginx
```

#### 3. Ingress Resources

```bash
# List all Ingresses
kubectl get ingress -A

# Detailed info
kubectl describe ingress datetime-ingress

# YAML output
kubectl get ingress datetime-ingress -o yaml
```

#### 4. Inspect NGINX Config Inside Pod

```bash
# Exec into NGINX pod
POD_NAME=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n ingress-nginx $POD_NAME -- /bin/bash

# Inside:
nginx -T | grep "server_name api.local"
```

---

### Traffic Test Commands

#### 1. Simple Request Test

```bash
# GET request
curl http://api.local/api/datetime

# JSON output
curl -s http://api.local/api/datetime | jq

# Verbose (show headers)
curl -v http://api.local/api/datetime
```

#### 2. Round-robin Test

```bash
# Send 10 requests and measure timing
for i in {1..10}; do
  echo -n "Request $i: ";
  time curl -s http://api.local/api/datetime > /dev/null;
done
```

#### 3. Load Test

```bash
# Apache Bench (100 requests, 10 concurrent)
ab -n 100 -c 10 http://api.local/api/datetime

# Or hey (https://github.com/rakyll/hey)
hey -n 100 -c 10 http://api.local/api/datetime
```

#### 4. Different Hosts

```bash
# api.local
curl -s http://api.local/api/datetime | jq -r '.time'

# api-go.local
curl -s http://api-go.local/health | jq

# web.local
curl -s http://web.local | grep "<title>"

# web-go.local
curl -s http://web-go.local | grep "<title>"
```

#### 5. Worker Failover Test

```bash
# Terminal 1: Continuous requests
while true; do
  curl -s http://api.local/api/datetime | jq -r '.time';
  sleep 1;
done

# Terminal 2: Stop worker1
docker stop kind-worker

# Terminal 1 should continue without interruption!

# Terminal 2: Start worker1 again
docker start kind-worker

# After 4-6 seconds, worker1 will rejoin the pool
```

---

## 🎓 Analogy Explanation

### Restaurant Analogy

Think of a restaurant:

#### **HAProxy** = Host/Hostess at Restaurant Entrance

- **Task**: Direct customers to available cashiers/tables
- **3 Cashiers**:
  - Cashier 1 (worker1)
  - Cashier 2 (worker2)
  - Cashier 3 (worker3)
- **Algorithm**: Sequential routing (round-robin)
- **Health Check**: Continuously checking if cashiers are open
- **Failover**: If one cashier is closed, direct to another cashier

**Example**:
```
Customer 1: Go to Cashier 1
Customer 2: Go to Cashier 2
Customer 3: Go to Cashier 3
Customer 4: Go to Cashier 1
...

(Cashier 1 closed!)
Customer 5: Go to Cashier 2
Customer 6: Go to Cashier 3
Customer 7: Go to Cashier 2
...
```

---

#### **NGINX Ingress** = Cashier Employee

- **Task**: Route customer's order to correct department
- **Order Types**:
  - Pizza order → Pizza chef (api-service)
  - Burger order → Burger chef (web-service)
  - Drink order → Bar (api-go-service)
  - Dessert order → Pastry (web-go-service)

**Example**:
```
Customer: "I want pizza" (Host: api.local)
Cashier: "Routing to pizza chef" (api-service)

Customer: "I want burger" (Host: web.local)
Cashier: "Routing to burger chef" (web-service)
```

---

### Complete Flow Analogy

```
1. Customer arrives at restaurant entrance
   → curl http://api.local/api/datetime

2. Host directs customer to Cashier 2
   → HAProxy: kind-worker2 selected (round-robin)

3. Customer goes to Cashier 2
   → Request reaches worker2:80

4. Cashier checks order: "You want pizza"
   → NGINX Ingress: Checking Host header (api.local)

5. Cashier says "Routing to pizza chef"
   → NGINX Ingress: Routing to api-service

6. Pizza chef prepares the order
   → api-service → api-deployment pod returns response

7. Pizza reaches customer
   → Response returns to client
```

---

## 📚 Summary

### Layer Structure

```
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 1: HAProxy Load Balancer (L4/L7)                          │
├─────────────────────────────────────────────────────────────────┤
│ • What it does: Worker node selection                           │
│ • Algorithm: Round-robin                                        │
│ • Health Check: GET /healthz (Layer 7)                          │
│ • Failover: Yes (routes to others if worker DOWN)               │
│ • Location: Docker container (outside Kubernetes)               │
│ • Config: k8s/haproxy-lb.cfg                                    │
│ • Stats: http://localhost:8404                                  │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 2: NGINX Ingress Controller (L7)                          │
├─────────────────────────────────────────────────────────────────┤
│ • What it does: Host-based routing (api.local → api-service)    │
│ • Algorithm: Ingress rules (host matching)                      │
│ • SSL Termination: Yes (HTTPS → HTTP)                           │
│ • Location: Kubernetes pod (1 on each worker)                   │
│ • Config: k8s/ingress-nginx-deployment.yaml + Ingress YAML      │
│ • hostNetwork: true (listens on worker container's port 80)     │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 3: Kubernetes Service (kube-proxy) (L4)                   │
├─────────────────────────────────────────────────────────────────┤
│ • What it does: Pod selection                                   │
│ • Algorithm: Round-robin (default)                              │
│ • Location: Kubernetes control plane                            │
│ • Config: Service YAML                                          │
└─────────────────────────────────────────────────────────────────┘
                          ↓
                  Application Pods
```

---

### Answers to Main Questions

#### ❓ Are we using HAProxy?
✅ **Yes!** `kind-http-lb` container runs HAProxy 2.8.

#### ❓ Where is NGINX Ingress?
✅ **As Kubernetes pods!** 1 NGINX Ingress pod runs on each worker node (3 replicas).

#### ❓ How do they work together?
✅ **Two-layer structure:**
   1. HAProxy: Worker selection (External LB)
   2. NGINX: Service routing (Internal Router)

#### ❓ Why two layers?
✅ **4 Main Reasons:**
   1. Worker node failover
   2. Standard port access (80/443)
   3. High availability
   4. Production-like setup

#### ❓ Which one does load balancing?
✅ **Both!**
   - HAProxy: Between worker nodes
   - NGINX Ingress: Routing to Kubernetes Services
   - Kubernetes Service: Between pods

---

### Quick Test Commands

```bash
# 1. Is HAProxy running?
docker ps --filter name=kind-http-lb

# 2. HAProxy stats page
open http://localhost:8404

# 3. NGINX Ingress pods
kubectl get pods -n ingress-nginx -o wide

# 4. Traffic test
curl http://api.local/api/datetime

# 5. Failover test
docker stop kind-worker
curl http://api.local/api/datetime  # Should still work!
docker start kind-worker

# 6. Round-robin test
for i in {1..6}; do curl -s http://api.local/api/datetime | jq -r '.time'; done
```

---

## 🎉 Conclusion

With this architecture:

✅ **Production-like environment**: Like Cloud LB + Kubernetes Ingress
✅ **High Availability**: Worker node fault tolerance
✅ **Easy Access**: No port numbers needed (standard :80/:443)
✅ **Automatic Failover**: HAProxy health checks + DNS-based routing
✅ **Scalability**: Can add as many workers as you want
✅ **Monitoring**: HAProxy stats page (:8404)

---

**Happy Learning! 🚀**

*This document was created to understand the differences between HAProxy and NGINX Ingress Controller and how they work together.*
