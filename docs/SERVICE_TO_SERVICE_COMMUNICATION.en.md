# Service-to-Service Communication and Resiliency Implementation

## 📋 Table of Contents

1. [Initial Project State](#-initial-project-state)
2. [Problem: Why Service-to-Service Communication?](#-problem-why-service-to-service-communication)
3. [Terms and Concepts](#-terms-and-concepts)
4. [Design Decisions](#-design-decisions)
5. [C# API Changes (.NET 9)](#-c-api-changes-net-9)
6. [Go API Changes](#-go-api-changes)
7. [Kubernetes Changes](#-kubernetes-changes)
8. [Test Scenarios](#-test-scenarios)
9. [Troubleshooting](#-troubleshooting)
10. [Future Improvements](#-future-improvements)

---

## 🎯 Initial Project State

### Current State (Before Changes)

The project had two DateTime APIs written in different languages:

```
┌─────────────────────┐
│   C# API (.NET 9)   │
│   - /api/datetime   │
│   - /health         │
└─────────────────────┘
         ↑
         │ (Web requests)
         │
    ┌────┴────┐
    │   Web   │
    └─────────┘

┌─────────────────────┐
│   Go API            │
│   - /api/worldclock │
│   - /api/countdown  │
│   - /health         │
└─────────────────────┘
         ↑
         │ (Web-Go requests)
         │
    ┌────┴─────┐
    │  Web-Go  │
    └──────────┘
```

**Problem**: The two APIs were running independently. True "polyglot microservices architecture" requires inter-service communication.

---

## 🔍 Problem: Why Service-to-Service Communication?

### 1. Polyglot Microservices Architecture

**What does it mean?** Microservices written in different programming languages working together.

**Why is it important?**
- Each language used for its strengths (C# → business logic, Go → performance-critical operations)
- Services can leverage each other's capabilities
- Simulates real-world scenarios

### 2. Resiliency Needs

**What does it mean?** System's ability to resist failures and self-heal.

**Why is it needed?**
- If one service crashes, it shouldn't affect others
- Auto-retry on network issues
- System protection under heavy load

---

## 📚 Terms and Concepts

### 1. Circuit Breaker

**What does it do?**
Works like an electrical circuit breaker. If a service keeps failing, it stops sending requests to it.

**Analogy:**
```
Home electrical circuit breaker:
├─ Normal → Electricity flows
├─ Short circuit → Breaker trips (open)
└─ After 5 min → Breaker retries (half-open)
```

**Code Example:**
```csharp
// If 5 failures → wait 30 seconds
CircuitBreaker.FailureRatio = 0.5;        // 50% failure ratio
CircuitBreaker.SamplingDuration = 30s;    // Measure within 30 seconds
CircuitBreaker.BreakDuration = 30s;       // Wait 30 seconds
```

**States:**
- **Closed**: Normal operation, requests pass through
- **Open**: Too many failures, requests rejected
- **Half-Open**: Testing, trying a few requests

### 2. Retry Policy

**What does it do?**
Automatically retries failed requests.

**Exponential Backoff:**
```
1st attempt → Immediate
2nd attempt → Wait 100ms
3rd attempt → Wait 200ms
4th attempt → Wait 400ms
```

**Why Exponential?**
- Reduces server load
- Gives time for temporary issues to resolve
- Prevents network congestion

**Jitter (Randomness):**
```
Without jitter:
All clients → Retry at 100ms → Load spike again

With jitter:
Client 1 → Wait 95ms
Client 2 → Wait 103ms
Client 3 → Wait 98ms
→ Load distributed
```

### 3. Rate Limiting

**What does it do?**
Limits maximum requests per second.

**Token Bucket Algorithm:**

```
Bucket Capacity: 10 tokens
Refill Rate: 5 tokens/second

[Start]
Bucket: 🪙🪙🪙🪙🪙🪙🪙🪙🪙🪙 (10/10)

[Request arrives]
Bucket: 🪙🪙🪙🪙🪙🪙🪙🪙🪙   (9/10)  ✅ Allowed

[10 requests at once]
Bucket: (empty)                    (0/10)

[11th request]
❌ 429 Too Many Requests

[1 second later]
Bucket: 🪙🪙🪙🪙🪙              (5/10)  ✅ 5 tokens added
```

**Why Token Bucket?**
- Allows burst traffic (when bucket is full)
- Stabilizes under sustained load
- Fair resource distribution

**Per-Service Rate Limiting:**
```
C# API Total: 100 req/sec
├─ Calls to Go API: 20 req/sec (special limit)
└─ Other endpoints: 80 req/sec

Why?
→ One service can't overwhelm another
→ Prevents cascading failures
```

### 4. Service Discovery

**What does it do?**
Determines how one service finds another.

**Kubernetes DNS:**
```
C# API → Wants to call Go API
└─ URL: http://datetime-api-go-service
   └─ Kubernetes DNS → Resolves to IP (e.g., 10.96.87.242)
      └─ Load Balancer → Routes to one of 3 pods
```

**Benefits:**
- Code doesn't change if IPs change
- Automatic load balancing
- Service mesh compatible

### 5. Timeout

**What does it do?**
Determines how long to wait for a request.

```
Total Request Timeout: 10s
├─ Send request
├─ If no response within 10 seconds
└─ ❌ Timeout error
```

**Why important?**
- Threads waiting forever consume resources
- Preserves user experience
- Prevents cascading timeouts

### 6. Fallback

**What does it do?**
Defines what to do when primary service fails.

```
C# API → Calls Go API
├─ ✅ Success → Data from Go
└─ ❌ Failure →
   └─ Cached old data
   └─ Default value
   └─ Error message
```

---

## 🎨 Design Decisions

### 1. Why .NET 9 Built-in Resiliency?

**Alternatives:**
- ❌ Polly (3rd party library)
- ✅ Microsoft.Extensions.Http.Resilience (built-in)

**Reasoning:**
```
Built-in Advantages:
├─ Official Microsoft support
├─ Deep .NET integration
├─ Performance optimizations
├─ Fewer dependencies
└─ Long-term support
```

### 2. Why gobreaker (for Go)?

**Alternatives:**
- go-resiliency/circuitbreaker
- sony/gobreaker ✅
- hystrix-go

**Reasoning:**
```
gobreaker Advantages:
├─ Simple API
├─ Active maintenance
├─ Lightweight (minimal dependencies)
├─ Good documentation
└─ Production-proven
```

### 3. Rate Limiting Values

**C# API:**
```
Global: 100 req/sec
Go API Calls: 20 req/sec

Why 20?
→ Prevent overload on Go API
→ Leave quota for other endpoints
→ 20% of 100 → Fair distribution
```

**Go API:**
```
Global: 150 req/sec
C# API Calls: 30 req/sec

Why 150?
→ Go is more performant
→ Can handle more load
→ 50% more than C#
```

### 4. Circuit Breaker Values

**Why 5 failures?**
```
Too low (2 failures) → False alarms
Too high (20 failures) → Late intervention
5 failures → Balanced
```

**Why 30 seconds break?**
```
Too short (5s) → Service can't recover
Too long (5min) → Users wait too long
30s → Server recovery + User experience
```

---

## 🔧 C# API Changes (.NET 9)

### 1. Adding NuGet Package

**File:** `api/DateTimeApi.csproj`

```xml
<ItemGroup>
    <PackageReference Include="Microsoft.Extensions.Http.Resilience" Version="9.0.0" />
</ItemGroup>
```

**Why?**
- .NET 9's resiliency features are in this package
- Circuit breaker, retry, timeout built-in

### 2. HttpClient and Resiliency Configuration

**File:** `api/Program.cs`

```csharp
using System.Threading.RateLimiting;

// HttpClient with Resilience for Go API
var goApiUrl = Environment.GetEnvironmentVariable("GO_API_URL")
    ?? "http://datetime-api-go-service";

builder.Services.AddHttpClient("GoApiClient", client =>
{
    client.BaseAddress = new Uri(goApiUrl);
    client.Timeout = TimeSpan.FromSeconds(30);
})
.AddStandardResilienceHandler(options =>
{
    // Retry policy: 3 attempts with exponential backoff
    options.Retry.MaxRetryAttempts = 3;
    options.Retry.UseJitter = true;

    // Circuit breaker: Open after 5 failures in 30 seconds
    options.CircuitBreaker.FailureRatio = 0.5;
    options.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(30);
    options.CircuitBreaker.MinimumThroughput = 5;
    options.CircuitBreaker.BreakDuration = TimeSpan.FromSeconds(30);

    // Total timeout
    options.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(10);
});
```

**Line-by-Line Explanation:**

1. **`AddHttpClient("GoApiClient")`**
   - Creates named HTTP client
   - Usable via dependency injection
   - Doesn't create new HttpClient per request (performance)

2. **`client.BaseAddress`**
   - Go API's base URL
   - Read from environment variable (overridable in Kubernetes)
   - Default: Service DNS name

3. **`AddStandardResilienceHandler()`**
   - .NET 9's built-in resiliency pipeline
   - Retry + Circuit Breaker + Timeout automatic

4. **`Retry.MaxRetryAttempts = 3`**
   - Retry 3 more times on failure
   - Total: 4 attempts (1 original + 3 retries)

5. **`Retry.UseJitter = true`**
   - Add random delay to each retry
   - Prevents thundering herd problem

6. **`CircuitBreaker.FailureRatio = 0.5`**
   - Open circuit at 50% failure rate
   - Example: 5 out of 10 requests fail → Circuit opens

7. **`CircuitBreaker.SamplingDuration = 30s`**
   - Evaluate requests within 30 seconds
   - Sliding window

8. **`CircuitBreaker.MinimumThroughput = 5`**
   - Need at least 5 requests to evaluate
   - Won't open circuit for 2-3 requests

9. **`CircuitBreaker.BreakDuration = 30s`**
   - Wait 30 seconds when circuit opens
   - Then transition to half-open

10. **`TotalRequestTimeout.Timeout = 10s`**
    - Entire operation (including retries) must complete in 10s
    - ⚠️ **IMPORTANT:** Must be at least 2x SamplingDuration!
    - Otherwise: `OptionsValidationException` error

### 3. Rate Limiting Configuration

**File:** `api/Program.cs`

```csharp
builder.Services.AddRateLimiter(options =>
{
    // Global rate limit: 100 requests per second
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
    {
        return RateLimitPartition.GetTokenBucketLimiter("global", _ =>
            new TokenBucketRateLimiterOptions
            {
                TokenLimit = 100,          // Bucket capacity
                ReplenishmentPeriod = TimeSpan.FromSeconds(1),  // Every 1 second
                TokensPerPeriod = 100,     // Add 100 tokens
                QueueLimit = 10            // Queue up to 10 requests
            });
    });

    // Per-endpoint rate limits
    options.AddPolicy("go-api-calls", context =>
    {
        if (context.Request.Path.StartsWithSegments("/api/go-time"))
        {
            return RateLimitPartition.GetTokenBucketLimiter("go-api-endpoint", _ =>
                new TokenBucketRateLimiterOptions
                {
                    TokenLimit = 20,
                    ReplenishmentPeriod = TimeSpan.FromSeconds(1),
                    TokensPerPeriod = 20,
                    QueueLimit = 5
                });
        }
        return RateLimitPartition.GetNoLimiter("unlimited");
    });

    options.OnRejected = async (context, token) =>
    {
        context.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
        var retryAfterSeconds = context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter)
            ? (double?)retryAfter.TotalSeconds
            : null;

        await context.HttpContext.Response.WriteAsJsonAsync(new
        {
            error = "Rate limit exceeded",
            message = "Too many requests. Please try again later.",
            retryAfter = retryAfterSeconds
        }, cancellationToken: token);
    };
});
```

### 4. New Endpoint: Service-to-Service Communication

**File:** `api/Program.cs`

```csharp
app.MapGet("/api/go-time", async (IHttpClientFactory httpClientFactory) =>
{
    try
    {
        var client = httpClientFactory.CreateClient("GoApiClient");
        var response = await client.GetAsync("/api/worldclock?city=Istanbul");

        if (response.IsSuccessStatusCode)
        {
            var goData = await response.Content.ReadFromJsonAsync<object>();
            return Results.Ok(new
            {
                source = "csharp-api",
                calledService = "go-api",
                endpoint = "/api/worldclock?city=Istanbul",
                data = goData,
                timestamp = DateTime.UtcNow
            });
        }

        return Results.Problem(
            detail: $"Go API returned status code: {response.StatusCode}",
            statusCode: (int)response.StatusCode
        );
    }
    catch (Exception ex)
    {
        return Results.Problem(
            detail: $"Failed to call Go API: {ex.Message}",
            statusCode: StatusCodes.Status503ServiceUnavailable
        );
    }
}).RequireRateLimiting("go-api-calls");
```

---

## 🐹 Go API Changes

### 1. Adding Go Modules

**File:** `api-go/go.mod`

```go
module github.com/esersahin/datetime-api-go

go 1.25.1

require (
	github.com/sony/gobreaker v1.0.0    // Circuit breaker
	golang.org/x/time v0.8.0             // Rate limiter
)
```

### 2. Circuit Breaker Client (for C# API)

**File:** `api-go/client/csharp_client.go`

Key features:
- Circuit breaker with 5 failure threshold
- Retry with exponential backoff (100ms, 200ms, 400ms)
- 10-second timeout per request
- 30-second break duration
- State change logging

### 3. Rate Limiter Middleware

**File:** `api-go/middleware/ratelimit.go`

Features:
- Global rate limiting (150 req/sec)
- Per-endpoint rate limiting (30 req/sec for C# calls)
- Token bucket algorithm
- Thread-safe with sync.RWMutex
- Retry-After header on rejection

---

## ☸️ Kubernetes Changes

### Environment Variables

**File:** `k8s/api-csharp-deployment.yaml`

```yaml
env:
  - name: GO_API_URL
    value: "http://datetime-api-go-service"
```

**File:** `k8s/api-go-deployment.yaml`

```yaml
env:
  - name: CSHARP_API_URL
    value: "http://datetime-api-service"
```

**Why Environment Variables?**
- 12-Factor App compliance
- Not hardcoded in source
- Different per environment (dev/staging/prod)
- Kubernetes DNS service discovery

---

## 🧪 Test Scenarios

### 1. Normal Communication Test

```bash
# C# API → Go API
curl http://api-csharp.local/api/go-time
```

**Expected:**
```json
{
  "source": "csharp-api",
  "calledService": "go-api",
  "endpoint": "/api/worldclock?city=Istanbul",
  "data": [ ... 20 cities ... ],
  "timestamp": "2025-10-06T21:04:10.390258Z"
}
```

### 2. Circuit Breaker Test

```bash
# Scale down Go API
kubectl scale deployment datetime-api-go --replicas=0

# Make requests from C# API
for i in {1..10}; do
  curl http://api-csharp.local/api/go-time
done
```

**Expected Behavior:**
```
Request 1-3: Retrying → 503 Service Unavailable
Request 4-5: Failure ratio reaches 50% → Circuit OPEN
Request 6-10: Circuit open → Immediate 503 (no retry)

After 30 seconds:
Circuit → HALF-OPEN
Request 11: Testing
  → Fails (Go API still down)
  → Circuit OPEN again
```

### 3. Rate Limiting Test

```bash
# 25 requests at once (limit: 20 req/sec)
for i in {1..25}; do
  curl -s http://api-csharp.local/api/go-time -o /dev/null -w "Request $i: %{http_code}\n"
done
```

**Expected:**
```
Request 1-20: 200 OK
Request 21-22: 429 Too Many Requests (queued)
Request 23-25: 429 Too Many Requests (queue full)
```

---

## 🔧 Troubleshooting

### Problem 1: Circuit Breaker Validation Error

**Error:**
```
OptionsValidationException: The sampling duration must be at least
double of timeout interval. Sampling Duration: 10s, Timeout: 10s
```

**Solution:**
```csharp
// WRONG
CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(10);
TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(10);

// CORRECT
CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(30);
TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(10);
```

### Problem 2: Service Discovery Not Working

**Symptom:**
```
Failed to call Go API: dial tcp: lookup datetime-api-go-service:
no such host
```

**Debug:**
```bash
# Check if service exists
kubectl get svc datetime-api-go-service

# Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
nslookup datetime-api-go-service

# Check environment variable
kubectl exec deployment/datetime-api-csharp -- env | grep GO_API_URL
```

---

## 🚀 Future Improvements

### 1. Distributed Tracing
- OpenTelemetry integration
- Jaeger/Zipkin exporter
- Request journey visualization

### 2. Health Check Aggregation
- Services checking each other's health
- Composite health status
- Dependency health reporting

### 3. Metrics & Monitoring
- Prometheus metrics
- Grafana dashboards
- Circuit breaker state tracking
- Rate limit hit counts

### 4. Service Mesh (Istio/Linkerd)
- Move resiliency to sidecar proxies
- Language-agnostic features
- Centralized configuration
- mTLS encryption

---

## 📊 Summary: What We Did and Why

### Before
```
❌ Services running independently
❌ Cascading failures on errors
❌ No rate limiting → DDoS risk
❌ No retry → Temporary errors become permanent
❌ No circuit breaker → Failed service overwhelmed
```

### After
```
✅ C# ↔ Go inter-service communication
✅ Circuit Breaker → Protects failed services
✅ Retry Policy → Handles temporary failures
✅ Rate Limiting → Prevents overload
✅ Timeout → Doesn't waste resources
✅ Service Discovery → IP independent
✅ Monitoring-ready → State visibility
```

### Achievements

**1. Production-Ready:**
- Ready for real-world scenarios
- Netflix/Amazon-style resiliency patterns

**2. Learning:**
- .NET 9 built-in resiliency
- Go circuit breaker patterns
- Kubernetes service mesh basics
- Rate limiting algorithms
- Distributed systems best practices

**3. Extensible:**
- Easy to add new services
- Simple monitoring integration
- Smooth service mesh migration

---

**Prepared by:** Claude (Anthropic)
**Date:** 2025-10-07
**Version:** 1.0
**Project:** DateTime Kubernetes Polyglot Microservices
