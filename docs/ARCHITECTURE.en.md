<div align="center">

### 🌐 Read in Other Languages

| 🇹🇷 [Türkçe](ARCHITECTURE.md) | 🇬🇧 [English](ARCHITECTURE.en.md) |
| :--------------------: | :------------------------: |

</div>

---

# Architecture Diagrams

This page visually explains the architectural structure of the DateTime Kubernetes project.

## 📋 Table of Contents

1. [Overall Architecture](#-overall-architecture)
2. [Circuit Breaker States](#-circuit-breaker-states)
3. [Rate Limiting - Token Bucket](#-rate-limiting---token-bucket)
4. [Request Flow](#-request-flow)
5. [Technology Stack](#-technology-stack)

---

## 🏗️ Overall Architecture

This diagram shows how C# and Go microservices run in the Kubernetes cluster and communicate with each other.

![Architecture Overview](diagrams/architecture-overview.png)

### Features:

- **2 C# API Pods (.NET 9)** - Running on worker nodes
- **3 Go API Pods (Go 1.25)** - Distributed across worker nodes
- **NGINX Ingress** - Round Robin load balancing
- **Kubernetes DNS** - CoreDNS for service discovery
- **Circuit Breaker** - Failure protection in each service
- **Rate Limiting** - Per-service rate limiting
- **Retry Policy** - Auto-retry with exponential backoff

---

## 🔄 Circuit Breaker States

The circuit breaker has 3 states: Closed (Normal), Open (Failed), Half-Open (Testing).

![Circuit Breaker States](diagrams/circuit-breaker-states.png)

### State Transitions:

**Closed → Open:**
- Condition: 50% failure rate within 30 seconds (minimum 5 requests)
- Example: 5 out of 10 requests fail

**Open → Half-Open:**
- Condition: After waiting 30 seconds
- Purpose: Test if service has recovered

**Half-Open → Closed:**
- Condition: Test requests succeed
- Maximum 3 test requests

**Half-Open → Open:**
- Condition: Test requests fail
- Wait another 30 seconds

### Example Scenario:

```
1. Normal operation → Closed
2. Go API crashes → 5 failures
3. Circuit opens → Open (30s)
4. After 30 seconds → Half-Open
5a. Test succeeds → Closed ✅
5b. Test fails → Open (30s more) ❌
```

---

## ⏱️ Rate Limiting - Token Bucket

Limits requests per second using the token bucket algorithm.

![Rate Limiting Token Bucket](diagrams/rate-limiting-token-bucket.png)

### Algorithm:

1. **Bucket:**
   - Capacity: 100 tokens
   - Initially full

2. **Refill:**
   - 100 tokens added every second
   - Maximum capacity: 100

3. **On Request:**
   - Check if token available
   - If yes: Take 1 token, process request
   - If no: 429 Too Many Requests

### Example:

```
[Start] Bucket: 100/100
[Request 1-100] Bucket: 0/100 → All processed
[Request 101] Bucket: 0/100 → 429 Error
[1 second later] Bucket: 100/100 → 100 tokens added
```

### Per-Service Limits:

**C# API:**
- Global: 100 req/sec
- Go API calls: 20 req/sec

**Go API:**
- Global: 150 req/sec
- C# API calls: 30 req/sec

**Why different?**
- Go is more performant → Handles more load
- Service isolation → One service can't overwhelm another

---

## 🔀 Request Flow

Shows step-by-step how a client request progresses through the system.

![Request Flow Sequence](diagrams/request-flow-sequence.png)

### Normal Flow (Success):

1. Client → `GET http://api.local/api/go-time`
2. Ingress → Route to C# API
3. C# API → Check rate limiter (20 req/sec)
4. Rate Limiter → ✅ Allow
5. C# API → Check circuit breaker
6. Circuit Breaker → ✅ Closed (healthy)
7. C# API → Query DNS: `datetime-api-go-service`
8. DNS → `10.96.87.242` (Service IP)
9. C# API → Call Go API
10. Go API → Return response
11. C# API → Create wrapper response
12. Client → Receive JSON

### Retry Scenario:

1. C# API → Call Go API (1st attempt)
2. Go API → Timeout / Error
3. C# API → Wait 100ms
4. C# API → Call Go API (2nd attempt)
5. Go API → ✅ Successful response
6. Client → Receive JSON

**Total time:** ~100-200ms (with 1 retry)

### Circuit Open Scenario:

1. C# API → Check circuit breaker
2. Circuit Breaker → ❌ Open (too many failures)
3. C# API → Don't send request, return error immediately
4. Client → 503 Service Unavailable

**Total time:** ~1-5ms (very fast, no retry)

**Benefit:** Doesn't add load to failed Go API

---

## 🛠️ Technology Stack

All technologies used in the project and their relationships.

![Technology Stack](diagrams/technology-stack.png)

### Microservices:

**C# API:**
- .NET 9.0
- Minimal API
- Microsoft.Extensions.Http.Resilience (built-in)

**Go API:**
- Go 1.25
- net/http (standard library)
- github.com/sony/gobreaker
- golang.org/x/time/rate

### Kubernetes:

**Cluster:**
- Kind (Kubernetes in Docker)
- 3 Control Plane nodes (HA setup)
- 3 Worker nodes (HA setup)

**Networking:**
- NGINX Ingress Controller
- CoreDNS (Service Discovery)
- ClusterIP Services

### Resiliency Patterns:

**Circuit Breaker:**
- 3-state state machine
- Failure ratio tracking
- Auto-recovery

**Retry Policy:**
- Exponential backoff
- Jitter (randomness)
- Max 3 attempts

**Rate Limiting:**
- Token bucket algorithm
- Per-service quotas
- Burst handling

**Timeout:**
- 10s per request
- 30s total (with retries)

---

## 📊 Usage Scenarios

### Scenario 1: Normal Load

```
Requests: 50 req/sec
Circuit: Closed
Rate Limit: Passing
Result: ✅ All requests successful
```

### Scenario 2: Burst Traffic

```
Requests: 150 req/sec (sudden spike)
First 100: ✅ Pass through token bucket
Next 50: ⏳ Enter queue
Rate Limit: 429 Too Many Requests
```

### Scenario 3: Service Failure

```
Go API: ❌ Down
First 5 requests: Trying with retry → Timeout
Circuit: Goes OPEN
Subsequent requests: Immediately return 503
After 30 seconds: Half-Open → Testing
```

### Scenario 4: Network Issue

```
Request 1: ❌ Network timeout
Retry 1: Wait 100ms → ❌ Timeout
Retry 2: Wait 200ms → ❌ Timeout
Retry 3: Wait 400ms → ❌ Timeout
Circuit: Increments failure counter
Result: 503 Service Unavailable
```

---

## 🎯 Performance Metrics

### Successful Request (Circuit Closed):

```
Rate Limit Check: <1ms
Circuit Check: <1ms
DNS Lookup: ~5ms (or <1ms if cached)
Service Call: 10-50ms
Total: ~15-60ms
```

### Failed Request (Circuit Open):

```
Rate Limit Check: <1ms
Circuit Check: <1ms
Early Return: <1ms
Total: ~2-3ms
```

### Retry Scenario (1 fail, 2 success):

```
1st attempt: 10s timeout
Wait: 100ms
2nd attempt: 20ms success
Total: ~10.12s
```

---

## 📚 Related Documentation

- **Detailed Explanation:** [SERVICE_TO_SERVICE_COMMUNICATION.en.md](SERVICE_TO_SERVICE_COMMUNICATION.en.md)
- **Code Examples:** C# API: `api/Program.cs`, Go API: `api-go/main.go`
- **Test Scenarios:** [SERVICE_TO_SERVICE_COMMUNICATION.en.md#test-scenarios](SERVICE_TO_SERVICE_COMMUNICATION.en.md#-test-scenarios)

---

**Last Updated:** 2025-10-07
**Version:** 1.0
