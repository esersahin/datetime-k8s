<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](LOAD_BALANCING.en.md) | 🇹🇷 [Türkçe](LOAD_BALANCING.md) |
|:---:|:---:|

</div>

---

# Load Balancing Configuration

## 📋 Table of Contents

1. [Load Balancing Strategies](#-load-balancing-strategies)
2. [Recommendations for Our Project](#-recommendations-for-our-project)
3. [Changing Configuration](#-changing-configuration)
4. [Testing](#-testing)
5. [Comparison](#-comparison)
6. [Recommendation for Our Project](#-recommendation-for-our-project)
7. [Summary](#-summary)

---

This document explains different load balancing strategies you can use in ingress.yaml.

## 🔀 Load Balancing Strategies

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
Request 1 → Pod A
Request 2 → Pod B
Request 3 → Pod A
Request 4 → Pod B
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
→ New request goes to Pod B
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

### Current Configuration

```yaml
# ingress.yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$binary_remote_addr"
```

This uses **IP Hash** strategy.

### Scenario 1: Stateless API (Recommended)

If your API is completely stateless (no sessions):

```yaml
# ingress.yaml - Round Robin
metadata:
  annotations:
    # Remove this line or set to round_robin
    # nginx.ingress.kubernetes.io/upstream-hash-by: "$binary_remote_addr"
    nginx.ingress.kubernetes.io/load-balance: "round_robin"
```

**Advantages**:

- ✅ Better load distribution
- ✅ Automatic distribution if pod goes down
- ✅ Simple and predictable

### Scenario 2: Session-Based Application

If you have user sessions:

```yaml
# ingress.yaml - IP Hash + Service Session Affinity
metadata:
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$binary_remote_addr"
```

AND in Service:

```yaml
# api-deployment.yaml & web-deployment.yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 300
```

**Advantages**:

- ✅ Session consistency
- ✅ High cache hit rate
- ✅ Consistent user experience

### Scenario 3: WebSocket Usage

If you have WebSocket connections:

```yaml
# ingress.yaml - Least Connections
metadata:
  annotations:
    nginx.ingress.kubernetes.io/load-balance: "least_conn"
    # For WebSocket
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

### Test 1: Round Robin

```bash
# Set round robin
make set-lb-roundrobin  # or kubectl patch

# Send 10 requests
for i in {1..10}; do
  curl -s http://api.local/api/datetime | jq -r '.time'
done

# Check pod logs - both pods should show logs
kubectl logs -l app=datetime-api --tail=5
```

### Test 2: IP Hash (Sticky)

```bash
# Set IP hash
make set-lb-iphash

# 10 requests from same client
for i in {1..10}; do
  curl -s http://api.local/api/datetime | jq -r '.time'
done

# Only 1 pod should show logs (same IP → same pod)
kubectl logs -l app=datetime-api --tail=5
```

### Test 3: Test from Different IPs

```bash
# Set IP hash
make set-lb-iphash

# From different source IPs (Docker containers)
for i in {1..5}; do
  docker run --rm --network kind curlimages/curl:latest \
    curl -s http://api.local/api/datetime
done

# Each container has different IP, can go to different pods
```

---

## 📊 Comparison

| Strategy        | Advantage           | Disadvantage         | Use Case      |
| --------------- | ------------------- | -------------------- | ------------- |
| **Round Robin** | Equal distribution  | No session retention | Stateless API |
| **IP Hash**     | Session consistency | Uneven distribution  | Stateful app  |
| **Least Conn**  | Dynamic load        | Complex              | WebSocket     |
| **Custom Hash** | Flexible            | Complex              | Special needs |

---

## 🎯 Recommendation for Our Project

### DateTime API & Web Application

**Status**: Completely stateless (no sessions, just returns datetime)

**Recommended Configuration**:

```yaml
# ingress.yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    # Round robin (default) - best load distribution
    nginx.ingress.kubernetes.io/load-balance: "round_robin"
```

```yaml
# REMOVE session affinity from Services
# api-deployment.yaml & web-deployment.yaml
spec:
  # Remove these lines:
  # sessionAffinity: ClientIP
  # sessionAffinityConfig: ...
```

**Why**:

- ✅ Each pod gets equal load
- ✅ No issues if a pod restarts
- ✅ Easy to scale
- ✅ Simple and predictable

---

## 📝 Summary

**Current configuration**: IP Hash (sticky sessions)
**Ideal for DateTime project**: Round Robin (stateless)

**To change**:

```bash
# Edit ingress.yaml
nano k8s/ingress.yaml

# Remove nginx.ingress.kubernetes.io/upstream-hash-by line
# Or add round_robin

# Apply
kubectl apply -f k8s/ingress.yaml

# Or using Makefile
make set-lb-roundrobin
```
