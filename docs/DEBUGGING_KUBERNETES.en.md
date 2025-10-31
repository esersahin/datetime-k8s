# Kubernetes C# API Debugging Guide

## Problem

The C# API service was constantly crashing in Kubernetes (`CrashLoopBackOff`), and after fixes, it was returning 500 Internal Server Error. However, errors were not visible in pod logs.

## Encountered Errors

### 1. DateTimeApi.dll Not Found

**Symptom:**
```bash
$ kubectl get pods -l app=datetime-api-csharp
NAME                                   READY   STATUS             RESTARTS        AGE
datetime-api-csharp-555f77dd8d-9wzlf   0/1     CrashLoopBackOff   5 (2m47s ago)   5m46s
```

**Error Message:**
```
The command could not be loaded, possibly because:
  * You intended to execute a .NET application:
      The application 'DateTimeApi.dll' does not exist.
  * You intended to execute a .NET SDK command:
      No .NET SDKs were found.
```

**Root Cause:**
The Dockerfile uses `PublishSingleFile=true` parameter but ENTRYPOINT is still set to `dotnet DateTimeApi.dll`. When PublishSingleFile is used, a single executable is created, not a DLL.

**Solution:**
```dockerfile
# Dockerfile.api - Before
ENTRYPOINT ["dotnet", "DateTimeApi.dll"]

# Dockerfile.api - After
ENTRYPOINT ["./DateTimeApi"]
```

### 2. JSON Source Generator Error

**Symptom:**
Pods are running but the `/health` endpoint returns errors.

**Error Message:**
```
System.NotSupportedException: JsonTypeInfo metadata for type '<>f__AnonymousType1`4[...]'
was not provided by TypeInfoResolver of type '[RateLimitJsonContext, WorldClockJsonContext]'.
If using source generation, ensure that all root types passed to the serializer have been
annotated with 'JsonSerializableAttribute'.
```

**Root Cause:**
When using source generation, anonymous types cannot be serialized. All types must be defined beforehand.

**Solution:**
Convert anonymous types to named records:

```csharp
// Before - Anonymous type
return Results.Ok(new
{
    status = "healthy",
    pod = podName,
    node = nodeName,
    service = "datetime-api-csharp"
});

// After - Named record
return Results.Ok(new HealthResponse(
    "healthy",
    podName,
    nodeName,
    "datetime-api-csharp"
));

// Record definition
public record HealthResponse(string Status, string Pod, string Node, string Service);

// Add to JsonSerializerContext
[JsonSerializable(typeof(HealthResponse))]
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
public partial class RateLimitJsonContext : JsonSerializerContext
{
}
```

### 3. CultureNotFoundException - Globalization Error

**Symptom:**
API is running, no errors in pod logs, but `/api/datetime` endpoint returns 500 error.

**Debugging Steps:**

#### 1. Check Pods
```bash
$ kubectl get pods -l app=datetime-api-csharp
NAME                                   READY   STATUS    RESTARTS   AGE
datetime-api-csharp-555f77dd8d-2vpbr   1/1     Running   0          7m33s
datetime-api-csharp-555f77dd8d-2z697   1/1     Running   0          7m33s
datetime-api-csharp-555f77dd8d-vkvq9   1/1     Running   0          7m33s
```

#### 2. Inspect All Pod Logs
```bash
$ kubectl logs -l app=datetime-api-csharp --tail=20 --prefix=true
[pod/datetime-api-csharp-555f77dd8d-2vpbr/api] info: Request finished HTTP/1.1 GET /health - 200
[pod/datetime-api-csharp-555f77dd8d-2z697/api] info: Request finished HTTP/1.1 GET /health - 200
```

**Result:** Only `/health` requests are visible, `/api/datetime` requests are not appearing.

#### 3. Port Forward Directly to Pod
```bash
$ kubectl port-forward datetime-api-csharp-555f77dd8d-2vpbr 5001:5000 &
Forwarding from 127.0.0.1:5001 -> 5000
Forwarding from [::1]:5001 -> 5000
```

#### 4. Start Live Log Monitoring
```bash
$ kubectl logs -f datetime-api-csharp-555f77dd8d-2vpbr --tail=0 &
```

#### 5. Send Test Request
```bash
$ curl -i http://localhost:5001/api/datetime
HTTP/1.1 500 Internal Server Error
Content-Length: 0
Date: Tue, 28 Oct 2025 18:51:59 GMT
Server: Kestrel
```

#### 6. Catch Error in Live Log
```
info: Microsoft.AspNetCore.Hosting.Diagnostics[1]
      Request starting HTTP/1.1 GET http://localhost:5001/api/datetime - - -
info: Microsoft.AspNetCore.Routing.EndpointMiddleware[0]
      Executing endpoint 'HTTP: GET /api/datetime'
info: Microsoft.AspNetCore.Routing.EndpointMiddleware[1]
      Executed endpoint 'HTTP: GET /api/datetime'
fail: Microsoft.AspNetCore.Server.Kestrel[13]
      Connection id "0HNGMA6SKFR8J", Request id "0HNGMA6SKFR8J:00000001": An unhandled exception was thrown by the application.
      System.Globalization.CultureNotFoundException: Only the invariant culture is supported in globalization-invariant mode.
      See https://aka.ms/GlobalizationInvariantMode for more information. (Parameter 'name')
      tr-TR is an invalid culture identifier.
         at System.Globalization.CultureInfo..ctor(String name, Boolean useUserOverride)
         at System.Globalization.CultureInfo..ctor(String name)
         at Program.<>c.<<Main>$>b__0_6() in /src/Program.cs:line 120
```

**Root Cause:**
When building with `PublishTrimmed=true` parameter, globalization support is removed. Usage of `tr-TR` culture fails.

**Solution:**
Remove culture usage:

```csharp
// Before - tr-TR culture usage
now.ToString("dddd", new System.Globalization.CultureInfo("tr-TR"))

// After - Invariant culture (English)
now.ToString("dddd")
```

## Debugging Techniques and Commands

### 1. Check Pod Status
```bash
# List all pods
kubectl get pods -l app=datetime-api-csharp

# With detailed info
kubectl get pods -l app=datetime-api-csharp -o wide
```

### 2. Log Inspection Commands
```bash
# Show last 30 lines of a specific pod
kubectl logs <POD_NAME> --tail=30

# Show logs from all pods (with pod name prefix)
kubectl logs -l app=datetime-api-csharp --tail=20 --prefix=true

# Check startup logs
kubectl logs <POD_NAME> | head -50

# Follow live logs
kubectl logs -f <POD_NAME> --tail=0
```

### 3. Debugging with Port Forward
```bash
# Forward a specific pod's port to local
kubectl port-forward <POD_NAME> 5001:5000

# Run in background
kubectl port-forward <POD_NAME> 5001:5000 &

# Send test requests
curl -i http://localhost:5001/api/datetime
curl -v http://localhost:5001/health
```

### 4. Service and Ingress Checks
```bash
# Check service configuration
kubectl get service <SERVICE_NAME> -o yaml

# Check ingress configuration
kubectl get ingress -o yaml

# Show ingress rules for a specific host
kubectl get ingress -o yaml | grep -A 10 "host: api-csharp.local"
```

### 5. Connect to Container
```bash
# Open shell inside container (if available)
kubectl exec -it <POD_NAME> -- /bin/sh
kubectl exec -it <POD_NAME> -- /bin/bash

# Execute single command
kubectl exec <POD_NAME> -- curl http://localhost:5000/health
```

### 6. Image and Deployment Checks
```bash
# Check image tag in deployment
kubectl get deployment <DEPLOYMENT_NAME> -o jsonpath='{.spec.template.spec.containers[0].image}'

# Restart deployment
kubectl rollout restart deployment <DEPLOYMENT_NAME>

# Monitor rollout status
kubectl rollout status deployment <DEPLOYMENT_NAME>
```

## Debugging Best Practices

### 1. Port Forward Debugging Workflow
```bash
# Terminal 1: Follow live logs
kubectl logs -f <POD_NAME>

# Terminal 2: Port forward and test
kubectl port-forward <POD_NAME> 5001:5000
curl http://localhost:5001/api/endpoint
```

With this approach, you can see the error in logs immediately when you send a request.

### 2. Multi-Replica Debugging
When you have multiple pods:
1. Connect to a specific pod with port forward
2. Monitor that pod's logs
3. Ensure the request definitely goes to that pod
4. Catch the error

### 3. Background Process Management
```bash
# Start background process
kubectl port-forward <POD_NAME> 5001:5000 &

# List processes
jobs

# Terminate process
kill %1  # or with specific process ID: kill <PID>
```

## Docker and Kubernetes Workflow

### 1. Local Development with Docker Desktop
```bash
# Build image
docker build -f Dockerfile.api -t datetime-api-csharp:latest .

# Docker Desktop's Kubernetes uses local images directly
# NO need to push to registry

# Restart deployment
kubectl rollout restart deployment datetime-api-csharp

# Monitor status
kubectl rollout status deployment datetime-api-csharp
```

### 2. Image Cache Management
```bash
# List all datetime images
docker images | grep -i datetime

# Remove specific image
docker rmi <IMAGE_NAME>:<TAG>

# Clean up unused images
docker image prune
```

## Summary

This debugging process taught us:

1. Using **Port Forward** allows you to connect directly to a specific pod and test it
2. **Live log monitoring** (`kubectl logs -f`) helps you catch errors instantly
3. Things to watch out for when using **PublishTrimmed and PublishSingleFile**:
   - Set ENTRYPOINT correctly
   - Check globalization support
   - Write code compatible with source generation
4. **Load balancing** can route requests to different pods, so port-forwarding to a specific pod for testing is crucial

## Advanced Debugging Commands

### 1. Pod Events and Detailed Information
```bash
# Detailed information about pod (events, conditions, resources)
kubectl describe pod <POD_NAME>

# Show recent events sorted by time
kubectl get events --sort-by='.lastTimestamp'

# Events for specific pod
kubectl get events --field-selector involvedObject.name=<POD_NAME>

# Events in all namespaces
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

### 2. Endpoint and Service Discovery Checks
```bash
# Check if service is correctly connected to pods
kubectl get endpoints

# Endpoints for specific service
kubectl get endpoints <SERVICE_NAME>

# Test service DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup datetime-api-csharp-service

# Test service connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- curl http://datetime-api-csharp-service/health
```

### 3. Resource Usage Monitoring
```bash
# CPU and Memory usage of pods
kubectl top pods

# All pods detailed
kubectl top pods --all-namespaces

# Node resource usage
kubectl top nodes

# Specific pod resource usage
kubectl top pod <POD_NAME> --containers
```

### 4. Multiple Container Debugging
```bash
# List all containers in pod
kubectl get pod <POD_NAME> -o jsonpath='{.spec.containers[*].name}'

# Get logs from specific container
kubectl logs <POD_NAME> -c <CONTAINER_NAME>

# Init container logs
kubectl logs <POD_NAME> -c <INIT_CONTAINER_NAME>

# Exec into specific container
kubectl exec -it <POD_NAME> -c <CONTAINER_NAME> -- /bin/sh
```

### 5. Crash Debugging
```bash
# Show logs from previous crashed container
kubectl logs <POD_NAME> --previous

# Details of crashed pod
kubectl describe pod <POD_NAME> | grep -A 10 "Last State"

# Find pods with high restart count
kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'
```

## Common Kubernetes Issues and Solutions

### 1. ImagePullBackOff
**Symptom:**
```bash
$ kubectl get pods
NAME                    READY   STATUS             RESTARTS   AGE
my-app-xxx              0/1     ImagePullBackOff   0          2m
```

**Debugging:**
```bash
# Check pod details
kubectl describe pod <POD_NAME>

# Check image pull policy
kubectl get pod <POD_NAME> -o jsonpath='{.spec.containers[0].imagePullPolicy}'

# Check image name
kubectl get pod <POD_NAME> -o jsonpath='{.spec.containers[0].image}'
```

**Solutions:**
- For local development with Docker Desktop, use `imagePullPolicy: Never` or `imagePullPolicy: IfNotPresent`
- Ensure image name is correct
- For private registry, define `imagePullSecrets`

### 2. CrashLoopBackOff
**Symptom:**
```bash
$ kubectl get pods
NAME                    READY   STATUS              RESTARTS   AGE
my-app-xxx              0/1     CrashLoopBackOff    5          3m
```

**Debugging:**
```bash
# Inspect previous crash logs
kubectl logs <POD_NAME> --previous

# Check pod events
kubectl describe pod <POD_NAME>

# Check startup probe/liveness probe settings
kubectl get pod <POD_NAME> -o yaml | grep -A 10 "livenessProbe"
```

**Solutions:**
- Check application logs (connection strings, environment variables)
- If startup time is insufficient, increase `initialDelaySeconds`
- Increase resource limits if insufficient

### 3. OOMKilled (Out of Memory)
**Symptom:**
```bash
$ kubectl describe pod <POD_NAME>
...
Last State:     Terminated
  Reason:       OOMKilled
  Exit Code:    137
```

**Debugging:**
```bash
# Monitor memory usage
kubectl top pod <POD_NAME>

# Check memory limits
kubectl get pod <POD_NAME> -o jsonpath='{.spec.containers[0].resources.limits.memory}'

# Search for OOMKilled in pod events
kubectl get events | grep OOMKilled
```

**Solutions:**
```yaml
# Increase memory limits in deployment
resources:
  requests:
    memory: "256Mi"
  limits:
    memory: "512Mi"  # Increased
```

### 4. Pending Pods
**Symptom:**
```bash
$ kubectl get pods
NAME                    READY   STATUS    RESTARTS   AGE
my-app-xxx              0/1     Pending   0          5m
```

**Debugging:**
```bash
# Learn why it's pending
kubectl describe pod <POD_NAME>

# Check node capacity
kubectl describe nodes

# PVC (Persistent Volume Claim) issues
kubectl get pvc
```

**Common Reasons:**
- Insufficient node resources (CPU, Memory)
- PVC cannot be mounted
- Node selector/affinity mismatch

### 5. Service Discovery / DNS Issues
**Symptom:**
Inter-pod communication not working.

**Debugging:**
```bash
# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Service DNS test
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <SERVICE_NAME>

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Service endpoints check
kubectl get endpoints <SERVICE_NAME>
```

**Solutions:**
- Ensure service selector matches pod labels
- Verify service ports are correct
- Confirm CoreDNS pods are running

## Health Checks and Probes

### Liveness, Readiness and Startup Probes

```yaml
# Deployment example
apiVersion: apps/v1
kind: Deployment
metadata:
  name: datetime-api-csharp
spec:
  template:
    spec:
      containers:
      - name: api
        image: datetime-api-csharp:latest
        ports:
        - containerPort: 5000

        # Startup Probe - During container startup
        startupProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 0
          periodSeconds: 5
          failureThreshold: 30  # 30 * 5 = 150 seconds startup time

        # Liveness Probe - Is container healthy?
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3

        # Readiness Probe - Can it receive traffic?
        readinessProbe:
          httpGet:
            path: /ready
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2

        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
```

**Probe Debugging:**
```bash
# Probe failure events
kubectl get events | grep -i probe

# Pod conditions
kubectl get pod <POD_NAME> -o jsonpath='{.status.conditions[*]}'

# Readiness status
kubectl get pod <POD_NAME> -o jsonpath='{.status.containerStatuses[0].ready}'
```

## Network Debugging

### 1. Network Connectivity Testing
```bash
# Start network debugging pod
kubectl run netshoot --rm -it --image=nicolaka/netshoot -- /bin/bash

# Inside pod:
# DNS test
nslookup kubernetes.default
dig datetime-api-csharp-service.default.svc.cluster.local

# HTTP connectivity
curl http://datetime-api-csharp-service/health
curl -v http://datetime-api-csharp-service.default.svc.cluster.local/health

# TCP connectivity
nc -zv datetime-api-csharp-service 80

# Trace route
traceroute datetime-api-csharp-service
```

### 2. Network Policy Debugging
```bash
# List network policies
kubectl get networkpolicies

# Policy details
kubectl describe networkpolicy <POLICY_NAME>

# Find which network policies affect the pod
kubectl get networkpolicy -o yaml | grep -B 10 "app: datetime-api-csharp"
```

### 3. Ingress Debugging
```bash
# Ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Ingress resource details
kubectl describe ingress <INGRESS_NAME>

# Backend service health
kubectl get ingress <INGRESS_NAME> -o jsonpath='{.status.loadBalancer.ingress[0]}'

# Test ingress routing
curl -H "Host: api-csharp.local" http://<INGRESS_IP>/api/datetime
```

## Performance and Profiling

### 1. .NET Diagnostics Tools
```bash
# Install dotnet-tools in container (for development)
kubectl exec -it <POD_NAME> -- dotnet tool install -g dotnet-dump
kubectl exec -it <POD_NAME> -- dotnet tool install -g dotnet-trace
kubectl exec -it <POD_NAME> -- dotnet tool install -g dotnet-counters

# Collect memory dump
kubectl exec <POD_NAME> -- dotnet-dump collect -p 1 -o /tmp/dump

# Copy dump to local
kubectl cp <POD_NAME>:/tmp/dump ./dump

# Collect CPU trace
kubectl exec <POD_NAME> -- dotnet-trace collect -p 1 --duration 00:00:30 -o /tmp/trace.nettrace

# Monitor live metrics
kubectl exec <POD_NAME> -- dotnet-counters monitor -p 1
```

### 2. Application Performance Monitoring
```bash
# Test request latency
time curl http://api-csharp.local/api/datetime

# Load testing (hey tool)
kubectl run hey --rm -it --image=williamyeh/hey:latest -- \
  -z 30s -c 10 http://datetime-api-csharp-service/api/datetime

# Concurrent requests test
kubectl run hey --rm -it --image=williamyeh/hey:latest -- \
  -n 1000 -c 50 http://datetime-api-csharp-service/api/datetime
```

## Alternative Debugging Tools

### 1. Stern - Multi-pod Log Tailing
```bash
# Stern installation (macOS)
brew install stern

# Tail logs from all datetime-api-csharp pods
stern datetime-api-csharp

# Only error logs
stern datetime-api-csharp --since 5m | grep -i error

# Specific container
stern datetime-api-csharp -c api

# Namespace based
stern -n default datetime-api-csharp
```

### 2. K9s - Interactive Kubernetes CLI
```bash
# K9s installation (macOS)
brew install k9s

# Start K9s
k9s

# Shortcuts:
# :pods          -> List pods
# :svc           -> List services
# :deploy        -> List deployments
# l              -> Logs
# d              -> Describe
# e              -> Edit
# Ctrl+d         -> Delete
# /              -> Filter
```

### 3. Kubectx and Kubens
```bash
# Installation (macOS)
brew install kubectx

# Switch context (switch cluster)
kubectx
kubectx docker-desktop

# Switch namespace
kubens
kubens default
```

## Deployment Rollback and Recovery

### 1. Deployment History
```bash
# Show deployment history
kubectl rollout history deployment/<DEPLOYMENT_NAME>

# Details of specific revision
kubectl rollout history deployment/<DEPLOYMENT_NAME> --revision=2

# Current revision
kubectl get deployment <DEPLOYMENT_NAME> -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}'
```

### 2. Rollback Operations
```bash
# Rollback to previous version
kubectl rollout undo deployment/<DEPLOYMENT_NAME>

# Rollback to specific revision
kubectl rollout undo deployment/<DEPLOYMENT_NAME> --to-revision=2

# Monitor rollout status
kubectl rollout status deployment/<DEPLOYMENT_NAME>

# Pause rollout (while making changes)
kubectl rollout pause deployment/<DEPLOYMENT_NAME>

# Resume rollout
kubectl rollout resume deployment/<DEPLOYMENT_NAME>
```

### 3. Blue-Green Deployment Debugging
```bash
# Deploy new version (blue)
kubectl apply -f deployment-v2.yaml

# Route service to new version
kubectl patch service <SERVICE_NAME> -p '{"spec":{"selector":{"version":"v2"}}}'

# Delete old version
kubectl delete deployment <OLD_DEPLOYMENT_NAME>

# Rollback if issues
kubectl patch service <SERVICE_NAME> -p '{"spec":{"selector":{"version":"v1"}}}'
```

## Docker Build Optimization

### 1. Build Cache Strategy
```dockerfile
# Good - Layer caching optimized
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# 1. First copy only project file (changes less often)
COPY DateTimeApi.csproj .
RUN dotnet restore

# 2. Then copy code files (changes often)
COPY Program.cs .
RUN dotnet publish -c Release -o /app/publish

# Bad - Restore runs on every change
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY . .  # All files copied
RUN dotnet restore && dotnet publish
```

### 2. .dockerignore Usage
```
# .dockerignore
bin/
obj/
*.md
.git/
.gitignore
Dockerfile*
.vs/
.vscode/
*.user
*.suo
```

### 3. Multi-stage Build Best Practices
```dockerfile
# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish -c Release -o /app/publish

# Stage 2: Runtime (minimal image)
FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS runtime
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "DateTimeApi.dll"]
```

## Local Development Workflow

### 1. Skaffold with Hot Reload
```yaml
# skaffold.yaml
apiVersion: skaffold/v2beta29
kind: Config
metadata:
  name: datetime-api
build:
  artifacts:
  - image: datetime-api-csharp
    docker:
      dockerfile: Dockerfile.api
deploy:
  kubectl:
    manifests:
    - k8s/api-csharp-deployment.yaml
```

```bash
# Development mode (hot reload)
skaffold dev

# Build and deploy once
skaffold run

# Debug mode
skaffold debug
```

### 2. Telepresence - Local Code, Remote Cluster
```bash
# Telepresence installation
brew install telepresence

# Connect to cluster
telepresence connect

# Inject local service to cluster
telepresence intercept datetime-api-csharp --port 5000:5000

# Now local code receives cluster traffic
dotnet run

# Disconnect
telepresence leave datetime-api-csharp
telepresence quit
```

### 3. Tilt Development
```python
# Tiltfile
docker_build('datetime-api-csharp', '.',
  dockerfile='Dockerfile.api',
  live_update=[
    sync('./Program.cs', '/src/Program.cs'),
    run('dotnet build', trigger=['./Program.cs'])
  ]
)

k8s_yaml('k8s/api-csharp-deployment.yaml')
k8s_resource('datetime-api-csharp', port_forwards=5000)
```

```bash
# Start Tilt
tilt up

# Open Web UI
# http://localhost:10350
```

## Security Debugging

### 1. RBAC Permissions
```bash
# Check current user permissions
kubectl auth can-i --list

# Check permission for specific action
kubectl auth can-i create pods
kubectl auth can-i delete deployments

# Check service account permissions
kubectl auth can-i --list --as=system:serviceaccount:default:my-service-account

# List roles and rolebindings
kubectl get roles,rolebindings
kubectl get clusterroles,clusterrolebindings
```

### 2. Security Context Issues
```bash
# Check pod security context
kubectl get pod <POD_NAME> -o jsonpath='{.spec.securityContext}'

# Container security context
kubectl get pod <POD_NAME> -o jsonpath='{.spec.containers[0].securityContext}'

# Running as non-root user?
kubectl get pod <POD_NAME> -o jsonpath='{.spec.containers[0].securityContext.runAsNonRoot}'
```

### 3. Secrets Debugging
```bash
# List secrets
kubectl get secrets

# Secret details (base64 encoded)
kubectl get secret <SECRET_NAME> -o yaml

# Decode secret
kubectl get secret <SECRET_NAME> -o jsonpath='{.data.password}' | base64 -d

# Check if pod has mounted secret
kubectl get pod <POD_NAME> -o jsonpath='{.spec.volumes[*].secret}'
```

## Real-world Debugging Scenarios

### Scenario 1: Intermittent 500 Errors
**Problem:** API sometimes returns 500 errors, sometimes works.

**Debugging Steps:**
```bash
# 1. Monitor all pod logs in parallel
stern datetime-api-csharp

# 2. Note error time and use correlation ID
kubectl logs <POD_NAME> | grep <CORRELATION_ID>

# 3. Check resource utilization
kubectl top pods
watch -n 1 'kubectl top pods | grep datetime-api-csharp'

# 4. Test network latency
kubectl run netshoot --rm -it --image=nicolaka/netshoot -- \
  bash -c 'for i in {1..100}; do time curl -s http://datetime-api-csharp-service/api/datetime; done'
```

### Scenario 2: Memory Leak Detection
**Problem:** Pods consume more memory over time.

**Debugging Steps:**
```bash
# 1. Monitor memory trend
watch -n 5 'kubectl top pod <POD_NAME>'

# 2. Collect memory dump
kubectl exec <POD_NAME> -- dotnet-dump collect -p 1 -o /tmp/dump1.dmp
# 30 minutes later
kubectl exec <POD_NAME> -- dotnet-dump collect -p 1 -o /tmp/dump2.dmp

# 3. Copy dumps locally and analyze
kubectl cp <POD_NAME>:/tmp/dump1.dmp ./dump1.dmp
kubectl cp <POD_NAME>:/tmp/dump2.dmp ./dump2.dmp

# 4. Analyze with dotnet-dump
dotnet-dump analyze dump1.dmp
> dumpheap -stat
> gcroot <OBJECT_ADDRESS>
```

### Scenario 3: Slow API Response
**Problem:** API response times are too long.

**Debugging Steps:**
```bash
# 1. Request timing
time curl -w "\nTotal time: %{time_total}s\n" http://api-csharp.local/api/datetime

# 2. Trace collection
kubectl exec <POD_NAME> -- dotnet-trace collect -p 1 --duration 00:00:30

# 3. Check database connection pool
kubectl logs <POD_NAME> | grep -i "connection"

# 4. Check rate limiting
kubectl logs <POD_NAME> | grep -i "rate limit"

# 5. Dependency health check
kubectl exec <POD_NAME> -- curl http://datetime-api-go-service/health
```

### Scenario 4: Connection Pool Exhaustion
**Problem:** "No connection available" errors.

**Debugging:**
```bash
# Check HttpClient configuration
kubectl exec <POD_NAME> -- env | grep HTTP

# Monitor active connections
kubectl exec <POD_NAME> -- netstat -an | grep ESTABLISHED | wc -l

# Concurrent request test
kubectl run hey --rm -it --image=williamyeh/hey:latest -- \
  -c 100 -n 1000 http://datetime-api-csharp-service/api/go-time
```

## Monitoring and Alerting

### Prometheus and Grafana Integration
```yaml
# ServiceMonitor for Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: datetime-api-csharp
spec:
  selector:
    matchLabels:
      app: datetime-api-csharp
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

```bash
# Test metrics endpoint
curl http://datetime-api-csharp-service/metrics

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# http://localhost:9090/targets

# Grafana dashboard
kubectl port-forward -n monitoring svc/grafana 3000:3000
# http://localhost:3000
```

## Cheat Sheet - Quick Reference

```bash
# POD DEBUGGING
kubectl get pods -o wide
kubectl describe pod <POD>
kubectl logs <POD> --previous
kubectl logs -f <POD>
kubectl exec -it <POD> -- /bin/sh
kubectl top pod <POD>

# DEPLOYMENT DEBUGGING
kubectl rollout status deployment/<DEPLOY>
kubectl rollout history deployment/<DEPLOY>
kubectl rollout undo deployment/<DEPLOY>
kubectl get deployment <DEPLOY> -o yaml

# SERVICE DEBUGGING
kubectl get svc
kubectl get endpoints <SVC>
kubectl describe svc <SVC>

# NETWORK DEBUGGING
kubectl run netshoot --rm -it --image=nicolaka/netshoot
kubectl run busybox --rm -it --image=busybox -- nslookup <SVC>

# EVENTS and TROUBLESHOOTING
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --field-selector involvedObject.name=<POD>

# PORT FORWARD
kubectl port-forward <POD> 8080:80
kubectl port-forward svc/<SVC> 8080:80

# LOGS
kubectl logs <POD> --tail=100
kubectl logs -l app=myapp --prefix=true
stern <APP>

# RESOURCE MONITORING
kubectl top nodes
kubectl top pods --all-namespaces

# ROLLBACK
kubectl rollout undo deployment/<DEPLOY>
kubectl rollout undo deployment/<DEPLOY> --to-revision=2
```

## Related Links

- [.NET Globalization Invariant Mode](https://aka.ms/GlobalizationInvariantMode)
- [System.Text.Json Source Generation](https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/source-generation)
- [Kubernetes Debugging Documentation](https://kubernetes.io/docs/tasks/debug/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [.NET Diagnostics Tools](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/)
- [Stern - Multi Pod Log Tailing](https://github.com/stern/stern)
- [K9s - Kubernetes CLI](https://k9scli.io/)
- [Telepresence - Local Development](https://www.telepresence.io/)

---

**Last Updated:** 2025-10-31
**Version:** 2.1
**Project:** DateTime Kubernetes Polyglot Microservices
