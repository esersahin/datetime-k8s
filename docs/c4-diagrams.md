# C4 Model Architecture Diagrams

This file contains C4 model diagrams for the DateTime Kubernetes project.

## Level 1: System Context Diagram

Shows the big picture - who uses the system and what external systems it interacts with.

```mermaid
C4Context
    title System Context - DateTime Kubernetes Application

    Person(user, "End User", "Application user accessing via browser")
    Person(developer, "Developer", "Tests APIs and monitors system")

    System_Boundary(k8s, "DateTime K8s System") {
        System(datetime_system, "DateTime Microservices", "Polyglot microservices (CSharp + Go) with resiliency patterns")
    }

    Rel(user, datetime_system, "Views date/time info", "HTTPS/HTTP")
    Rel(developer, datetime_system, "Tests & monitors", "HTTP, kubectl")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="1")
```

## Level 2: Container Diagram

Shows the high-level technology choices and how containers communicate.

```mermaid
C4Container
    title Container Diagram - DateTime Kubernetes Application

    Person(user, "End User", "Browser user")

    System_Boundary(k8s_cluster, "Kubernetes Cluster (Kind)") {
        Container(ingress, "NGINX Ingress", "NGINX", "Routes traffic, load balancing")

        Container_Boundary(csharp_stack, "CSharp Stack (.NET 9)") {
            Container(csharp_web, "Web UI", "Nginx + HTML/JS", "Displays datetime in Turkish")
            Container(csharp_api, "CSharp API", ".NET 9 Minimal API", "REST API with resiliency patterns")
        }

        Container_Boundary(go_stack, "Go Stack (Go 1.25)") {
            Container(go_web, "Web UI Go", "Nginx + HTML/JS", "Displays world clock")
            Container(go_api, "Go API", "Go HTTP Server", "REST API with timezone features")
        }

        ContainerDb(k8s_dns, "CoreDNS", "Kubernetes DNS", "Service discovery")
    }

    Rel(user, ingress, "Accesses", "HTTP :80")
    Rel(ingress, csharp_web, "Routes /web-csharp.local", "HTTP")
    Rel(ingress, csharp_api, "Routes /api-csharp.local", "HTTP")
    Rel(ingress, go_web, "Routes /web-go.local", "HTTP")
    Rel(ingress, go_api, "Routes /api-go.local", "HTTP")

    Rel(csharp_web, csharp_api, "Fetches datetime", "HTTP REST")
    Rel(go_web, go_api, "Fetches world clock", "HTTP REST")
    Rel(csharp_api, go_api, "Service-to-service call", "HTTP + Circuit Breaker")

    Rel(csharp_api, k8s_dns, "Resolves service", "DNS query")
    Rel(go_api, k8s_dns, "Resolves service", "DNS query")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="2")
```

## Level 3: Component Diagram - CSharp API

Shows the internal components of the CSharp API and resiliency patterns.

```mermaid
C4Component
    title Component Diagram - CSharp API (.NET 9)

    Container_Boundary(csharp_api_boundary, "CSharp API Container") {
        Component(endpoints, "API Endpoints", "Minimal API", "REST endpoints (/api/datetime, /health, /api/go-time)")
        Component(resilience_layer, "Resiliency Layer", "Microsoft.Extensions.Http.Resilience", "Manages all resiliency patterns")

        Component(circuit_breaker, "Circuit Breaker", "Built-in Resilience", "3 states: Closed, Open, Half-Open")
        Component(retry_policy, "Retry Policy", "Built-in Resilience", "Exponential backoff with jitter")
        Component(rate_limiter, "Rate Limiter", "Built-in Resilience", "Token bucket (100 req/s global, 20 req/s Go API)")
        Component(timeout, "Timeout Handler", "Built-in Resilience", "10s per request, 30s total")

        Component(http_client, "HTTP Client", "HttpClientFactory", "Calls Go API via DNS")
        Component(datetime_service, "DateTime Service", "CSharp Business Logic", "Turkish datetime formatting")
    }

    Container_Ext(go_api_ext, "Go API", "Go HTTP Server", "External microservice")
    ContainerDb_Ext(k8s_dns_ext, "CoreDNS", "Kubernetes DNS")

    Rel(endpoints, resilience_layer, "Uses", "Dependency Injection")
    Rel(endpoints, datetime_service, "Calls", "Method call")

    Rel(resilience_layer, circuit_breaker, "Contains")
    Rel(resilience_layer, retry_policy, "Contains")
    Rel(resilience_layer, rate_limiter, "Contains")
    Rel(resilience_layer, timeout, "Contains")

    Rel(resilience_layer, http_client, "Wraps", "Resilient HTTP calls")
    Rel(http_client, k8s_dns_ext, "Resolves", "DNS: datetime-api-go-service")
    Rel(http_client, go_api_ext, "Calls", "HTTP with resiliency")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Level 3: Component Diagram - Go API

Shows the internal components of the Go API and resiliency patterns.

```mermaid
C4Component
    title Component Diagram - Go API (Go 1.25)

    Container_Boundary(go_api_boundary, "Go API Container") {
        Component(router, "HTTP Router", "net/http", "Routes: /health, /api/*, /api/worldclock, /api/csharp-datetime")
        Component(handlers, "HTTP Handlers", "handlers package", "Business logic handlers")

        Component(go_circuit_breaker, "Circuit Breaker", "sony/gobreaker", "Failure tracking & protection")
        Component(go_rate_limiter, "Rate Limiter", "golang.org/x/time/rate", "Token bucket (150 req/s global, 30 req/s C# API)")

        Component(timezone_service, "Timezone Service", "Go Business Logic", "Timezone conversion, world clock")
        Component(models, "Data Models", "models package", "Request/Response DTOs")
        Component(utils, "Utilities", "utils package", "Helper functions")
    }

    Container_Ext(csharp_api_ext, "CSharp API", ".NET 9 API", "External microservice")
    ContainerDb_Ext(k8s_dns_ext2, "CoreDNS", "Kubernetes DNS")

    Rel(router, handlers, "Routes to", "Handler functions")
    Rel(handlers, go_circuit_breaker, "Protected by", "Wraps calls")
    Rel(handlers, go_rate_limiter, "Rate limited by", "Token check")
    Rel(handlers, timezone_service, "Calls", "Business logic")
    Rel(handlers, models, "Uses", "Data structures")
    Rel(timezone_service, utils, "Uses", "Helper functions")

    Rel(handlers, k8s_dns_ext2, "Resolves CSharp API", "DNS: datetime-api-csharp-service")
    Rel(handlers, csharp_api_ext, "Calls (optional)", "HTTP with resiliency")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Deployment Diagram (Bonus)

Shows how containers are deployed to Kubernetes infrastructure in HA setup.

```mermaid
C4Deployment
    title Deployment Diagram - HA Kubernetes Kind Cluster (3+3 Setup)

    Deployment_Node(local_machine, "Local Machine", "macOS / Linux") {

        Deployment_Node(haproxy_host, "HAProxy Load Balancer", "Docker Container") {
            Container(haproxy, "HAProxy 2.9", "Load Balancer", "External LB - Port 80/443/8404")
        }

        Deployment_Node(docker, "Docker Desktop", "Docker Engine") {
            Deployment_Node(kind_cluster, "Kind Cluster", "Kubernetes v1.34 - HA Setup") {

                Deployment_Node(control_plane1, "Control Plane 1", "kindest/node:v1.34.0") {
                    Container(k8s_api1, "K8s API Server", "kube-apiserver", "Cluster management")
                    Container(etcd1, "etcd", "etcd v3.5", "Distributed KV Store 1/3")
                }

                Deployment_Node(control_plane2, "Control Plane 2", "kindest/node:v1.34.0") {
                    Container(k8s_api2, "K8s API Server", "kube-apiserver", "Cluster management")
                    Container(etcd2, "etcd", "etcd v3.5", "Distributed KV Store 2/3")
                }

                Deployment_Node(control_plane3, "Control Plane 3", "kindest/node:v1.34.0") {
                    Container(k8s_api3, "K8s API Server", "kube-apiserver", "Cluster management")
                    Container(etcd3, "etcd", "etcd v3.5", "Distributed KV Store 3/3")
                    Container(coredns, "CoreDNS", "DNS Server", "Service discovery")
                }

                Deployment_Node(worker1, "Worker Node 1", "kindest/node:v1.34.0") {
                    Container(ingress_ctrl1, "NGINX Ingress", "NGINX", "Replica 1/3 - hostNetwork:true")
                    Container(csharp_api_pod1, "CSharp API Pod", ".NET 9", "Replica 1/2")
                    Container(go_api_pod1, "Go API Pod", "Go 1.25", "Replica 1/3")
                    Container(csharp_web_pod1, "Web Pod", "Nginx", "Replica 1/2")
                }

                Deployment_Node(worker2, "Worker Node 2", "kindest/node:v1.34.0") {
                    Container(ingress_ctrl2, "NGINX Ingress", "NGINX", "Replica 2/3 - hostNetwork:true")
                    Container(csharp_api_pod2, "CSharp API Pod", ".NET 9", "Replica 2/2")
                    Container(go_api_pod2, "Go API Pod", "Go 1.25", "Replica 2/3")
                    Container(go_web_pod1, "Web-Go Pod", "Nginx", "Replica 1/2")
                }

                Deployment_Node(worker3, "Worker Node 3", "kindest/node:v1.34.0") {
                    Container(ingress_ctrl3, "NGINX Ingress", "NGINX", "Replica 3/3 - hostNetwork:true")
                    Container(go_api_pod3, "Go API Pod", "Go 1.25", "Replica 3/3")
                    Container(csharp_web_pod2, "Web Pod", "Nginx", "Replica 2/2")
                    Container(go_web_pod2, "Web-Go Pod", "Nginx", "Replica 2/2")
                }
            }
        }
    }

    Rel(haproxy, ingress_ctrl1, "Round-robin LB", "HTTP/HTTPS + Health Check")
    Rel(haproxy, ingress_ctrl2, "Round-robin LB", "HTTP/HTTPS + Health Check")
    Rel(haproxy, ingress_ctrl3, "Round-robin LB", "HTTP/HTTPS + Health Check")

    Rel(ingress_ctrl1, csharp_api_pod1, "Routes traffic", "Host: api-csharp.local")
    Rel(ingress_ctrl2, csharp_api_pod2, "Routes traffic", "Host: api-csharp.local")
    Rel(ingress_ctrl1, go_api_pod1, "Routes traffic", "Host: api-go.local")

    Rel(etcd1, etcd2, "Raft consensus", "etcd cluster")
    Rel(etcd2, etcd3, "Raft consensus", "etcd cluster")
    Rel(etcd3, etcd1, "Raft consensus", "etcd cluster")

    Rel(csharp_api_pod1, coredns, "Service discovery", "DNS")
    Rel(csharp_api_pod1, go_api_pod2, "Service call", "HTTP + Circuit Breaker")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## C4 Model Benefits for This Project

### 1. **Standardization**
- Industry-standard notation
- Familiar to architects and developers
- Easy to understand for stakeholders

### 2. **Multiple Abstraction Levels**
- **Level 1 (Context)**: Non-technical stakeholders
- **Level 2 (Container)**: DevOps, architects
- **Level 3 (Component)**: Developers
- **Deployment**: Infrastructure teams

### 3. **Clear Communication**
- Shows **WHO** uses the system (users, developers)
- Shows **WHAT** technology is used (containers)
- Shows **HOW** components interact (relationships)
- Shows **WHERE** it runs (deployment)

### 4. **Documentation Value**
- Self-documenting architecture
- Version controlled with code
- Easy to update as system evolves
- Great for onboarding new team members

---

**Generated with Mermaid C4 diagrams**
**Version:** 1.0
**Last Updated:** 2025-10-07
