# Architecture Diagram

## Service-to-Service Communication Architecture

```mermaid
graph TB
    subgraph "Kubernetes Cluster (Kind)"
        subgraph "Ingress Layer"
            Ingress[NGINX Ingress Controller<br/>Round Robin Load Balancing]
        end

        subgraph "C# Microservice (.NET 9)"
            CSharpAPI1[C# API Pod 1]
            CSharpAPI2[C# API Pod 2]
            CSharpAPI3[C# API Pod 3]

            CSharpAPI1 --> |Circuit Breaker| GoClient1[Go API Client]
            CSharpAPI2 --> |Circuit Breaker| GoClient2[Go API Client]
            CSharpAPI3 --> |Circuit Breaker| GoClient3[Go API Client]

            GoClient1 -.-> |Retry: 3 attempts<br/>Exponential Backoff| RateLimit1[Rate Limiter<br/>20 req/sec]
            GoClient2 -.-> |Retry: 3 attempts<br/>Exponential Backoff| RateLimit2[Rate Limiter<br/>20 req/sec]
            GoClient3 -.-> |Retry: 3 attempts<br/>Exponential Backoff| RateLimit6[Rate Limiter<br/>20 req/sec]
        end

        subgraph "Go Microservice (Go 1.25)"
            GoAPI1[Go API Pod 1]
            GoAPI2[Go API Pod 2]
            GoAPI3[Go API Pod 3]

            GoAPI1 --> |Circuit Breaker| CSharpClient1[C# API Client]
            GoAPI2 --> |Circuit Breaker| CSharpClient2[C# API Client]
            GoAPI3 --> |Circuit Breaker| CSharpClient3[C# API Client]

            CSharpClient1 -.-> |Retry: 3 attempts<br/>100ms, 200ms, 400ms| RateLimit3[Rate Limiter<br/>30 req/sec]
            CSharpClient2 -.-> |Retry: 3 attempts<br/>100ms, 200ms, 400ms| RateLimit4[Rate Limiter<br/>30 req/sec]
            CSharpClient3 -.-> |Retry: 3 attempts<br/>100ms, 200ms, 400ms| RateLimit5[Rate Limiter<br/>30 req/sec]
        end

        subgraph "Service Discovery"
            DNS[Kubernetes DNS<br/>CoreDNS]
        end

        RateLimit1 --> |Service Name| DNS
        RateLimit2 --> |Service Name| DNS
        RateLimit3 --> |Service Name| DNS
        RateLimit4 --> |Service Name| DNS
        RateLimit5 --> |Service Name| DNS
        RateLimit6 --> |Service Name| DNS

        DNS --> |datetime-api-go-service| GoAPI1
        DNS --> |datetime-api-go-service| GoAPI2
        DNS --> |datetime-api-go-service| GoAPI3

        DNS --> |datetime-api-csharp-service| CSharpAPI1
        DNS --> |datetime-api-csharp-service| CSharpAPI2
        DNS --> |datetime-api-csharp-service| CSharpAPI3
    end

    Client[Web-CSharp Client] --> |http://api-csharp.local| Ingress
    Client2[Web-Go Client] --> |http://api-go.local| Ingress

    Ingress --> CSharpAPI1
    Ingress --> CSharpAPI2
    Ingress --> CSharpAPI3
    Ingress --> GoAPI1
    Ingress --> GoAPI2
    Ingress --> GoAPI3

    style CSharpAPI1 fill:#512BD4,color:#fff
    style CSharpAPI2 fill:#512BD4,color:#fff
    style CSharpAPI3 fill:#512BD4,color:#fff
    style GoAPI1 fill:#00ADD8,color:#fff
    style GoAPI2 fill:#00ADD8,color:#fff
    style GoAPI3 fill:#00ADD8,color:#fff
    style Ingress fill:#326CE5,color:#fff
    style DNS fill:#FF6B6B,color:#fff
```

## Resiliency Features

```mermaid
stateDiagram-v2
    [*] --> Closed: Normal Operation
    Closed --> Open: 50% Failure Rate<br/>(5 failures in 30s)
    Open --> HalfOpen: After 30s
    HalfOpen --> Closed: Success
    HalfOpen --> Open: Failure

    note right of Closed
        ✅ Requests passing through
        ✅ Retry on failure (3x)
        ✅ Rate limiting active
    end note

    note right of Open
        ❌ Requests rejected immediately
        ⏱️ Wait 30 seconds
        🛡️ Protecting failed service
    end note

    note right of HalfOpen
        🧪 Testing with 3 requests
        ⚖️ Evaluating recovery
    end note
```

## Rate Limiting: Token Bucket Algorithm

```mermaid
graph LR
    subgraph "Token Bucket"
        Bucket[Bucket<br/>Capacity: 100 tokens]
        Refill[Refill Rate<br/>100 tokens/sec]
    end

    Request1[Request 1] --> Check1{Token<br/>Available?}
    Check1 -->|Yes| Take1[Take 1 token]
    Check1 -->|No| Reject1[429 Too Many<br/>Requests]

    Take1 --> Process[Process Request]

    Refill --> Bucket

    style Bucket fill:#4CAF50,color:#fff
    style Reject1 fill:#F44336,color:#fff
    style Process fill:#2196F3,color:#fff
```

## Request Flow Example

```mermaid
sequenceDiagram
    participant Client
    participant Ingress
    participant CSharpAPI as C# API (.NET 9)
    participant RateLimiter as Rate Limiter
    participant CircuitBreaker as Circuit Breaker
    participant DNS as Kubernetes DNS
    participant GoAPI as Go API (Go 1.25)

    Client->>Ingress: GET /api/go-time
    Ingress->>CSharpAPI: Forward request

    CSharpAPI->>RateLimiter: Check rate limit (20 req/sec)
    RateLimiter-->>CSharpAPI: ✅ Allowed

    CSharpAPI->>CircuitBreaker: Check circuit state
    CircuitBreaker-->>CSharpAPI: ✅ Closed (healthy)

    CSharpAPI->>DNS: Resolve datetime-api-go-service
    DNS-->>CSharpAPI: 10.96.87.242 → Pod IP

    CSharpAPI->>GoAPI: GET /api/worldclock?city=Istanbul

    alt Success
        GoAPI-->>CSharpAPI: 200 OK + Data
        CSharpAPI-->>Ingress: 200 OK (wrapped response)
        Ingress-->>Client: 200 OK + JSON
    else Failure (1st attempt)
        GoAPI--xCSharpAPI: Timeout / Error
        Note over CSharpAPI: Retry after 100ms
        CSharpAPI->>GoAPI: GET /api/worldclock (retry 2)
        GoAPI-->>CSharpAPI: 200 OK + Data
        CSharpAPI-->>Ingress: 200 OK
        Ingress-->>Client: 200 OK + JSON
    else Circuit Opens
        CircuitBreaker-->>CSharpAPI: ❌ Open (too many failures)
        CSharpAPI-->>Ingress: 503 Service Unavailable
        Ingress-->>Client: 503 + Error message
        Note over CircuitBreaker: Wait 30 seconds<br/>Then try half-open
    end
```

## Technology Stack

```mermaid
mindmap
  root((DateTime K8s))
    Microservices
      C# API
        .NET 9
        Minimal API
        Built-in Resiliency
      Go API
        Go 1.25
        net/http
        gobreaker
    Kubernetes
      Kind Cluster - HA Setup
        3 Control Plane Nodes
        3 Worker Nodes
        etcd Quorum (3-node)
      HAProxy Load Balancer
        Port 80/443
        Stats :8404
      NGINX Ingress
        3 Replicas
        hostNetwork true
      Service Discovery
        CoreDNS
    Resiliency
      Circuit Breaker
        Closed
        Open
        Half-Open
      Retry Policy
        Exponential Backoff
        Jitter
      Rate Limiting
        Token Bucket
        Per-Service Limits
      Timeout
        10s per request
        30s total
```

---

## How to View

### GitHub
Upload `architecture-diagram.png` to repository settings → Social preview

### README
Add this to README.md:
```markdown
## Architecture
![Architecture](docs/architecture-diagram.png)
```

### Mermaid Live Editor
1. Copy any diagram above
2. Go to https://mermaid.live
3. Paste and edit
4. Export as PNG/SVG
