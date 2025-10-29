# Kubernetes'te C# API Debugging Rehberi

## Sorun

C# API servisi Kubernetes üzerinde sürekli crash oluyordu (`CrashLoopBackOff`) ve daha sonra düzeltmelerden sonra 500 Internal Server Error hatası veriyordu. Ancak hatalar pod loglarında görünmüyordu.

## Karşılaşılan Hatalar

### 1. DateTimeApi.dll Bulunamadı

**Belirti:**
```bash
$ kubectl get pods -l app=datetime-api-csharp
NAME                                   READY   STATUS             RESTARTS        AGE
datetime-api-csharp-555f77dd8d-9wzlf   0/1     CrashLoopBackOff   5 (2m47s ago)   5m46s
```

**Hata Mesajı:**
```
The command could not be loaded, possibly because:
  * You intended to execute a .NET application:
      The application 'DateTimeApi.dll' does not exist.
  * You intended to execute a .NET SDK command:
      No .NET SDKs were found.
```

**Kök Neden:**
Dockerfile'da `PublishSingleFile=true` parametresi kullanılmış ancak ENTRYPOINT hala `dotnet DateTimeApi.dll` olarak ayarlanmış. PublishSingleFile kullanıldığında tek bir executable oluşturulur, DLL değil.

**Çözüm:**
```dockerfile
# Dockerfile.api - Önceki hali
ENTRYPOINT ["dotnet", "DateTimeApi.dll"]

# Dockerfile.api - Düzeltilmiş hali
ENTRYPOINT ["./DateTimeApi"]
```

### 2. JSON Source Generator Hatası

**Belirti:**
Pod'lar çalışıyor ancak `/health` endpoint'i hata veriyor.

**Hata Mesajı:**
```
System.NotSupportedException: JsonTypeInfo metadata for type '<>f__AnonymousType1`4[...]'
was not provided by TypeInfoResolver of type '[RateLimitJsonContext, WorldClockJsonContext]'.
If using source generation, ensure that all root types passed to the serializer have been
annotated with 'JsonSerializableAttribute'.
```

**Kök Neden:**
Source generation kullanılırken anonymous type'lar serialize edilemez. Tüm tiplerin önceden tanımlanması gerekiyor.

**Çözüm:**
Anonymous type'ları named record'lara çevirdik:

```csharp
// Önceki hali - Anonymous type
return Results.Ok(new
{
    status = "healthy",
    pod = podName,
    node = nodeName,
    service = "datetime-api-csharp"
});

// Düzeltilmiş hali - Named record
return Results.Ok(new HealthResponse(
    "healthy",
    podName,
    nodeName,
    "datetime-api-csharp"
));

// Record tanımı
public record HealthResponse(string Status, string Pod, string Node, string Service);

// JsonSerializerContext'e ekleme
[JsonSerializable(typeof(HealthResponse))]
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
public partial class RateLimitJsonContext : JsonSerializerContext
{
}
```

### 3. CultureNotFoundException - Globalization Hatası

**Belirti:**
API çalışıyor, pod loglarında hata yok, ancak `/api/datetime` endpoint'i 500 hatası veriyor.

**Debugging Adımları:**

#### 1. Pod'ları Kontrol Et
```bash
$ kubectl get pods -l app=datetime-api-csharp
NAME                                   READY   STATUS    RESTARTS   AGE
datetime-api-csharp-555f77dd8d-2vpbr   1/1     Running   0          7m33s
datetime-api-csharp-555f77dd8d-2z697   1/1     Running   0          7m33s
datetime-api-csharp-555f77dd8d-vkvq9   1/1     Running   0          7m33s
```

#### 2. Tüm Pod'ların Loglarını İncele
```bash
$ kubectl logs -l app=datetime-api-csharp --tail=20 --prefix=true
[pod/datetime-api-csharp-555f77dd8d-2vpbr/api] info: Request finished HTTP/1.1 GET /health - 200
[pod/datetime-api-csharp-555f77dd8d-2z697/api] info: Request finished HTTP/1.1 GET /health - 200
```

**Sonuç:** Sadece `/health` istekleri var, `/api/datetime` istekleri görünmüyor.

#### 3. Port Forward ile Direkt Pod'a Bağlan
```bash
$ kubectl port-forward datetime-api-csharp-555f77dd8d-2vpbr 5001:5000 &
Forwarding from 127.0.0.1:5001 -> 5000
Forwarding from [::1]:5001 -> 5000
```

#### 4. Canlı Log İzlemeyi Başlat
```bash
$ kubectl logs -f datetime-api-csharp-555f77dd8d-2vpbr --tail=0 &
```

#### 5. Test İsteği Gönder
```bash
$ curl -i http://localhost:5001/api/datetime
HTTP/1.1 500 Internal Server Error
Content-Length: 0
Date: Tue, 28 Oct 2025 18:51:59 GMT
Server: Kestrel
```

#### 6. Canlı Log'da Hatayı Yakala
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

**Kök Neden:**
`PublishTrimmed=true` parametresi ile build edildiğinde globalization desteği kaldırılmış. `tr-TR` culture kullanımı başarısız oluyor.

**Çözüm:**
Culture kullanımını kaldırdık:

```csharp
// Önceki hali - tr-TR culture kullanımı
now.ToString("dddd", new System.Globalization.CultureInfo("tr-TR"))

// Düzeltilmiş hali - Invariant culture (İngilizce)
now.ToString("dddd")
```

## Debugging Teknikleri ve Komutlar

### 1. Pod Durumunu Kontrol Etme
```bash
# Tüm pod'ları listele
kubectl get pods -l app=datetime-api-csharp

# Detaylı bilgi ile
kubectl get pods -l app=datetime-api-csharp -o wide
```

### 2. Log İnceleme Komutları
```bash
# Belirli bir pod'un son 30 satırını göster
kubectl logs <POD_NAME> --tail=30

# Tüm pod'ların loglarını göster (hangi pod'dan geldiğini belirt)
kubectl logs -l app=datetime-api-csharp --tail=20 --prefix=true

# Başlangıç loglarını kontrol et
kubectl logs <POD_NAME> | head -50

# Canlı log izleme
kubectl logs -f <POD_NAME> --tail=0
```

### 3. Port Forward ile Debugging
```bash
# Belirli bir pod'un portunu local'e forward et
kubectl port-forward <POD_NAME> 5001:5000

# Background'da çalıştır
kubectl port-forward <POD_NAME> 5001:5000 &

# Test isteği gönder
curl -i http://localhost:5001/api/datetime
curl -v http://localhost:5001/health
```

### 4. Service ve Ingress Kontrolleri
```bash
# Service yapılandırmasını kontrol et
kubectl get service <SERVICE_NAME> -o yaml

# Ingress yapılandırmasını kontrol et
kubectl get ingress -o yaml

# Belirli bir host için ingress kurallarını göster
kubectl get ingress -o yaml | grep -A 10 "host: api-csharp.local"
```

### 5. Container İçine Bağlanma
```bash
# Container içinde shell açma (eğer mevcut ise)
kubectl exec -it <POD_NAME> -- /bin/sh
kubectl exec -it <POD_NAME> -- /bin/bash

# Tek komut çalıştırma
kubectl exec <POD_NAME> -- curl http://localhost:5000/health
```

### 6. Image ve Deployment Kontrolleri
```bash
# Deployment'daki image tag'ini kontrol et
kubectl get deployment <DEPLOYMENT_NAME> -o jsonpath='{.spec.template.spec.containers[0].image}'

# Deployment'ı restart et
kubectl rollout restart deployment <DEPLOYMENT_NAME>

# Rollout durumunu izle
kubectl rollout status deployment <DEPLOYMENT_NAME>
```

## En İyi Debugging Uygulamaları

### 1. Port Forward Debugging Workflow
```bash
# Terminal 1: Canlı log izle
kubectl logs -f <POD_NAME>

# Terminal 2: Port forward yap ve test et
kubectl port-forward <POD_NAME> 5001:5000
curl http://localhost:5001/api/endpoint
```

Bu yaklaşımla isteği gönderdiğinizde hatayı anında logda görebilirsiniz.

### 2. Çoklu Replica Debugging
Birden fazla pod varsa:
1. Port forward ile belirli bir pod'a bağlanın
2. O pod'un loglarını izleyin
3. İsteğin kesinlikle o pod'a gittiğini garanti edin
4. Hatayı yakalayın

### 3. Background Process Yönetimi
```bash
# Background process başlat
kubectl port-forward <POD_NAME> 5001:5000 &

# Process'leri listele
jobs

# Process'i sonlandır
kill %1  # veya belirli process ID ile: kill <PID>
```

## Docker ve Kubernetes İş Akışı

### 1. Docker Desktop ile Local Geliştirme
```bash
# Image build et
docker build -f Dockerfile.api -t datetime-api-csharp:latest .

# Docker Desktop'ın Kubernetes'i local image'ları direkt kullanır
# Registry'e push etmeye gerek YOK

# Deployment'ı restart et
kubectl rollout restart deployment datetime-api-csharp

# Durumu izle
kubectl rollout status deployment datetime-api-csharp
```

### 2. Image Cache Yönetimi
```bash
# Tüm datetime image'larını listele
docker images | grep -i datetime

# Belirli bir image'ı sil
docker rmi <IMAGE_NAME>:<TAG>

# Kullanılmayan image'ları temizle
docker image prune
```

## Özet

Bu debugging süreci şunları öğretti:

1. **Port Forward** kullanarak belirli bir pod'a direkt bağlanıp test edebilirsiniz
2. **Canlı log izleme** (`kubectl logs -f`) hatayı anında yakalamanızı sağlar
3. **PublishTrimmed ve PublishSingleFile** kullanırken dikkat edilmesi gerekenler:
   - ENTRYPOINT'i doğru ayarlamak
   - Globalization desteğini kontrol etmek
   - Source generation ile uyumlu kod yazmak
4. **Load balancing** nedeniyle birden fazla pod varsa, port-forward ile belirli bir pod'u test etmek çok önemli

## İleri Seviye Debugging Komutları

### 1. Pod Events ve Detaylı Bilgi
```bash
# Pod hakkında detaylı bilgi (events, conditions, resources)
kubectl describe pod <POD_NAME>

# Son olayları zaman sırasına göre göster
kubectl get events --sort-by='.lastTimestamp'

# Belirli bir pod için events
kubectl get events --field-selector involvedObject.name=<POD_NAME>

# Tüm namespace'lerdeki events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

### 2. Endpoint ve Service Discovery Kontrolleri
```bash
# Service'in pod'lara doğru bağlanıp bağlanmadığını kontrol et
kubectl get endpoints

# Belirli bir service için endpoints
kubectl get endpoints <SERVICE_NAME>

# Service DNS çözümlemesini test et
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup datetime-api-csharp-service

# Service connectivity test
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- curl http://datetime-api-csharp-service/health
```

### 3. Resource Usage Monitoring
```bash
# Pod'ların CPU ve Memory kullanımı
kubectl top pods

# Tüm pod'lar için detaylı
kubectl top pods --all-namespaces

# Node'ların resource kullanımı
kubectl top nodes

# Belirli bir pod'un resource kullanımı
kubectl top pod <POD_NAME> --containers
```

### 4. Multiple Container Debugging
```bash
# Pod içindeki tüm container'ları listele
kubectl get pod <POD_NAME> -o jsonpath='{.spec.containers[*].name}'

# Belirli bir container'ın loglarını al
kubectl logs <POD_NAME> -c <CONTAINER_NAME>

# Init container logları
kubectl logs <POD_NAME> -c <INIT_CONTAINER_NAME>

# Belirli container'a exec ile bağlan
kubectl exec -it <POD_NAME> -c <CONTAINER_NAME> -- /bin/sh
```

### 5. Crash Debugging
```bash
# Önceki crash'deki container loglarını göster
kubectl logs <POD_NAME> --previous

# Crash loop olan pod'un detayları
kubectl describe pod <POD_NAME> | grep -A 10 "Last State"

# Restart count'u yüksek pod'ları bul
kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'
```

## Yaygın Kubernetes Sorunları ve Çözümleri

### 1. ImagePullBackOff
**Belirti:**
```bash
$ kubectl get pods
NAME                    READY   STATUS             RESTARTS   AGE
my-app-xxx              0/1     ImagePullBackOff   0          2m
```

**Debugging:**
```bash
# Pod detaylarına bak
kubectl describe pod <POD_NAME>

# Image pull policy kontrol et
kubectl get pod <POD_NAME> -o jsonpath='{.spec.containers[0].imagePullPolicy}'

# Image adını kontrol et
kubectl get pod <POD_NAME> -o jsonpath='{.spec.containers[0].image}'
```

**Çözümler:**
- Docker Desktop ile local development yapıyorsanız `imagePullPolicy: Never` veya `imagePullPolicy: IfNotPresent` kullanın
- Image adının doğru olduğundan emin olun
- Private registry için `imagePullSecrets` tanımlayın

### 2. CrashLoopBackOff
**Belirti:**
```bash
$ kubectl get pods
NAME                    READY   STATUS              RESTARTS   AGE
my-app-xxx              0/1     CrashLoopBackOff    5          3m
```

**Debugging:**
```bash
# Önceki crash'in loglarını incele
kubectl logs <POD_NAME> --previous

# Pod events'leri kontrol et
kubectl describe pod <POD_NAME>

# Startup probe/liveness probe ayarlarını kontrol et
kubectl get pod <POD_NAME> -o yaml | grep -A 10 "livenessProbe"
```

**Çözümler:**
- Application loglarını kontrol edin (connection strings, environment variables)
- Startup time yetersizse `initialDelaySeconds` arttırın
- Resource limits yetersizse arttırın

### 3. OOMKilled (Out of Memory)
**Belirti:**
```bash
$ kubectl describe pod <POD_NAME>
...
Last State:     Terminated
  Reason:       OOMKilled
  Exit Code:    137
```

**Debugging:**
```bash
# Memory kullanımını izle
kubectl top pod <POD_NAME>

# Memory limits kontrolü
kubectl get pod <POD_NAME> -o jsonpath='{.spec.containers[0].resources.limits.memory}'

# Pod events'de OOMKilled mesajı ara
kubectl get events | grep OOMKilled
```

**Çözümler:**
```yaml
# Deployment'da memory limits arttır
resources:
  requests:
    memory: "256Mi"
  limits:
    memory: "512Mi"  # Arttırıldı
```

### 4. Pending Pods
**Belirti:**
```bash
$ kubectl get pods
NAME                    READY   STATUS    RESTARTS   AGE
my-app-xxx              0/1     Pending   0          5m
```

**Debugging:**
```bash
# Neden pending olduğunu öğren
kubectl describe pod <POD_NAME>

# Node'ların kapasitesini kontrol et
kubectl describe nodes

# PVC (Persistent Volume Claim) sorunları
kubectl get pvc
```

**Yaygın Nedenler:**
- Yetersiz node resources (CPU, Memory)
- PVC mount edilemiyor
- Node selector/affinity uyuşmazlığı

### 5. Service Discovery / DNS Sorunları
**Belirti:**
Pod'lar arası iletişim çalışmıyor.

**Debugging:**
```bash
# DNS çözümlemesi test et
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Service DNS test
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <SERVICE_NAME>

# CoreDNS loglarını kontrol et
kubectl logs -n kube-system -l k8s-app=kube-dns

# Service endpoints kontrolü
kubectl get endpoints <SERVICE_NAME>
```

**Çözümler:**
- Service selector'ın pod label'ları ile eşleştiğinden emin olun
- Service port'larının doğru olduğunu kontrol edin
- CoreDNS pod'larının çalıştığını doğrulayın

## Health Checks ve Probes

### Liveness, Readiness ve Startup Probes

```yaml
# Deployment örneği
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

        # Startup Probe - Container başlarken
        startupProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 0
          periodSeconds: 5
          failureThreshold: 30  # 30 * 5 = 150 saniye startup süresi

        # Liveness Probe - Container sağlıklı mı?
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3

        # Readiness Probe - Traffic alabilir mi?
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

# Readiness durumu
kubectl get pod <POD_NAME> -o jsonpath='{.status.containerStatuses[0].ready}'
```

## Network Debugging

### 1. Network Connectivity Testing
```bash
# Network debugging pod'u başlat
kubectl run netshoot --rm -it --image=nicolaka/netshoot -- /bin/bash

# Pod içinden:
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
# Network policies listele
kubectl get networkpolicies

# Belirli bir policy'nin detayları
kubectl describe networkpolicy <POLICY_NAME>

# Pod'un hangi network policy'lerden etkilendiğini bul
kubectl get networkpolicy -o yaml | grep -B 10 "app: datetime-api-csharp"
```

### 3. Ingress Debugging
```bash
# Ingress controller logları
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Ingress resource detayları
kubectl describe ingress <INGRESS_NAME>

# Backend service health
kubectl get ingress <INGRESS_NAME> -o jsonpath='{.status.loadBalancer.ingress[0]}'

# Test ingress routing
curl -H "Host: api-csharp.local" http://<INGRESS_IP>/api/datetime
```

## Performance ve Profiling

### 1. .NET Diagnostics Tools
```bash
# Container içine dotnet-tools kur (geliştirme ortamı için)
kubectl exec -it <POD_NAME> -- dotnet tool install -g dotnet-dump
kubectl exec -it <POD_NAME> -- dotnet tool install -g dotnet-trace
kubectl exec -it <POD_NAME> -- dotnet tool install -g dotnet-counters

# Memory dump al
kubectl exec <POD_NAME> -- dotnet-dump collect -p 1 -o /tmp/dump

# Dump'ı local'e kopyala
kubectl cp <POD_NAME>:/tmp/dump ./dump

# CPU trace al
kubectl exec <POD_NAME> -- dotnet-trace collect -p 1 --duration 00:00:30 -o /tmp/trace.nettrace

# Live metrics izle
kubectl exec <POD_NAME> -- dotnet-counters monitor -p 1
```

### 2. Application Performance Monitoring
```bash
# Request latency test
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
# Stern kurulumu (macOS)
brew install stern

# Tüm datetime-api-csharp pod'larının loglarını izle
stern datetime-api-csharp

# Sadece hata logları
stern datetime-api-csharp --since 5m | grep -i error

# Belirli container
stern datetime-api-csharp -c api

# Namespace bazlı
stern -n default datetime-api-csharp
```

### 2. K9s - Interactive Kubernetes CLI
```bash
# K9s kurulumu (macOS)
brew install k9s

# K9s başlat
k9s

# Kısayollar:
# :pods          -> Pod'ları listele
# :svc           -> Service'leri listele
# :deploy        -> Deployment'ları listele
# l              -> Logs
# d              -> Describe
# e              -> Edit
# Ctrl+d         -> Delete
# /              -> Filter
```

### 3. Kubectx ve Kubens
```bash
# Kurulum (macOS)
brew install kubectx

# Context değiştir (cluster değiştir)
kubectx
kubectx docker-desktop

# Namespace değiştir
kubens
kubens default
```

## Deployment Rollback ve Recovery

### 1. Deployment History
```bash
# Deployment geçmişini göster
kubectl rollout history deployment/<DEPLOYMENT_NAME>

# Belirli bir revision'ın detayları
kubectl rollout history deployment/<DEPLOYMENT_NAME> --revision=2

# Aktif revision
kubectl get deployment <DEPLOYMENT_NAME> -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}'
```

### 2. Rollback İşlemleri
```bash
# Önceki versiyona geri dön
kubectl rollout undo deployment/<DEPLOYMENT_NAME>

# Belirli bir revision'a dön
kubectl rollout undo deployment/<DEPLOYMENT_NAME> --to-revision=2

# Rollout durumunu izle
kubectl rollout status deployment/<DEPLOYMENT_NAME>

# Rollout'u duraklat (değişiklik yaparken)
kubectl rollout pause deployment/<DEPLOYMENT_NAME>

# Rollout'u devam ettir
kubectl rollout resume deployment/<DEPLOYMENT_NAME>
```

### 3. Blue-Green Deployment Debugging
```bash
# Yeni version deploy et (blue)
kubectl apply -f deployment-v2.yaml

# Service'i yeni versiyona yönlendir
kubectl patch service <SERVICE_NAME> -p '{"spec":{"selector":{"version":"v2"}}}'

# Eski versiyonu sil
kubectl delete deployment <OLD_DEPLOYMENT_NAME>

# Sorun olursa eski versiyona dön
kubectl patch service <SERVICE_NAME> -p '{"spec":{"selector":{"version":"v1"}}}'
```

## Docker Build Optimization

### 1. Build Cache Stratejisi
```dockerfile
# İyi - Layer caching optimize edilmiş
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# 1. Önce sadece proje dosyası kopyala (az değişir)
COPY DateTimeApi.csproj .
RUN dotnet restore

# 2. Sonra kod dosyalarını kopyala (sık değişir)
COPY Program.cs .
RUN dotnet publish -c Release -o /app/publish

# Kötü - Her değişiklikte restore yapılır
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY . .  # Tüm dosyalar kopyalanıyor
RUN dotnet restore && dotnet publish
```

### 2. .dockerignore Kullanımı
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

### 1. Skaffold ile Hot Reload
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

# Sadece bir kez build ve deploy
skaffold run

# Debug mode
skaffold debug
```

### 2. Telepresence - Local Code, Remote Cluster
```bash
# Telepresence kurulumu
brew install telepresence

# Cluster'a bağlan
telepresence connect

# Local servisi cluster'a inject et
telepresence intercept datetime-api-csharp --port 5000:5000

# Artık local'de çalışan kod cluster'daki traffic alacak
dotnet run

# Bağlantıyı kes
telepresence leave datetime-api-csharp
telepresence quit
```

### 3. Tilt ile Development
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
# Tilt başlat
tilt up

# Web UI aç
# http://localhost:10350
```

## Security Debugging

### 1. RBAC Permissions
```bash
# Mevcut kullanıcının yetkilerini kontrol et
kubectl auth can-i --list

# Belirli bir işlem için yetki kontrolü
kubectl auth can-i create pods
kubectl auth can-i delete deployments

# Service account yetkilerini kontrol et
kubectl auth can-i --list --as=system:serviceaccount:default:my-service-account

# Role ve RoleBinding'leri listele
kubectl get roles,rolebindings
kubectl get clusterroles,clusterrolebindings
```

### 2. Security Context Issues
```bash
# Pod'un security context'ini kontrol et
kubectl get pod <POD_NAME> -o jsonpath='{.spec.securityContext}'

# Container security context
kubectl get pod <POD_NAME> -o jsonpath='{.spec.containers[0].securityContext}'

# Non-root user olarak çalışıyor mu?
kubectl get pod <POD_NAME> -o jsonpath='{.spec.containers[0].securityContext.runAsNonRoot}'
```

### 3. Secrets Debugging
```bash
# Secret'ları listele
kubectl get secrets

# Secret detayları (base64 encoded)
kubectl get secret <SECRET_NAME> -o yaml

# Secret'ı decode et
kubectl get secret <SECRET_NAME> -o jsonpath='{.data.password}' | base64 -d

# Pod'un secret mount edip etmediğini kontrol et
kubectl get pod <POD_NAME> -o jsonpath='{.spec.volumes[*].secret}'
```

## Gerçek Dünya Debugging Senaryoları

### Senaryo 1: Aralıklı 500 Hataları
**Problem:** Bazen API 500 hatası veriyor, bazen çalışıyor.

**Debugging Adımları:**
```bash
# 1. Tüm pod'ların loglarını paralel izle
stern datetime-api-csharp

# 2. Hata zamanını not et ve correlation ID kullan
kubectl logs <POD_NAME> | grep <CORRELATION_ID>

# 3. Resource utilization kontrol et
kubectl top pods
watch -n 1 'kubectl top pods | grep datetime-api-csharp'

# 4. Network latency test et
kubectl run netshoot --rm -it --image=nicolaka/netshoot -- \
  bash -c 'for i in {1..100}; do time curl -s http://datetime-api-csharp-service/api/datetime; done'
```

### Senaryo 2: Memory Leak Detection
**Problem:** Pod'lar zamanla daha fazla memory kullanıyor.

**Debugging Adımları:**
```bash
# 1. Memory trend izle
watch -n 5 'kubectl top pod <POD_NAME>'

# 2. Memory dump al
kubectl exec <POD_NAME> -- dotnet-dump collect -p 1 -o /tmp/dump1.dmp
# 30 dakika sonra tekrar
kubectl exec <POD_NAME> -- dotnet-dump collect -p 1 -o /tmp/dump2.dmp

# 3. Dump'ları local'e kopyala ve analiz et
kubectl cp <POD_NAME>:/tmp/dump1.dmp ./dump1.dmp
kubectl cp <POD_NAME>:/tmp/dump2.dmp ./dump2.dmp

# 4. dotnet-dump ile analiz
dotnet-dump analyze dump1.dmp
> dumpheap -stat
> gcroot <OBJECT_ADDRESS>
```

### Senaryo 3: Slow API Response
**Problem:** API response süreleri çok uzun.

**Debugging Adımları:**
```bash
# 1. Request timing
time curl -w "\nTotal time: %{time_total}s\n" http://api-csharp.local/api/datetime

# 2. Trace collection
kubectl exec <POD_NAME> -- dotnet-trace collect -p 1 --duration 00:00:30

# 3. Database connection pool kontrol
kubectl logs <POD_NAME> | grep -i "connection"

# 4. Rate limiting kontrol
kubectl logs <POD_NAME> | grep -i "rate limit"

# 5. Dependency health check
kubectl exec <POD_NAME> -- curl http://datetime-api-go-service/health
```

### Senaryo 4: Connection Pool Exhaustion
**Problem:** "No connection available" hataları.

**Debugging:**
```bash
# HttpClient configuration kontrol
kubectl exec <POD_NAME> -- env | grep HTTP

# Active connections monitoring
kubectl exec <POD_NAME> -- netstat -an | grep ESTABLISHED | wc -l

# Concurrent request test
kubectl run hey --rm -it --image=williamyeh/hey:latest -- \
  -c 100 -n 1000 http://datetime-api-csharp-service/api/go-time
```

## Monitoring ve Alerting

### Prometheus ve Grafana Integration
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
# Metrics endpoint test
curl http://datetime-api-csharp-service/metrics

# Prometheus targets kontrol
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# http://localhost:9090/targets

# Grafana dashboard
kubectl port-forward -n monitoring svc/grafana 3000:3000
# http://localhost:3000
```

## Cheat Sheet - Hızlı Referans

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

# EVENTS ve TROUBLESHOOTING
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

## İlgili Bağlantılar

- [.NET Globalization Invariant Mode](https://aka.ms/GlobalizationInvariantMode)
- [System.Text.Json Source Generation](https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/source-generation)
- [Kubernetes Debugging Documentation](https://kubernetes.io/docs/tasks/debug/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [.NET Diagnostics Tools](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/)
- [Stern - Multi Pod Log Tailing](https://github.com/stern/stern)
- [K9s - Kubernetes CLI](https://k9scli.io/)
- [Telepresence - Local Development](https://www.telepresence.io/)
