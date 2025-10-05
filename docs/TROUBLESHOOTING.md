<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](TROUBLESHOOTING.en.md) | 🇹🇷 [Türkçe](TROUBLESHOOTING.md) |
| :--------------------------------------: | :----------------------------------: |

</div>

---

# Troubleshooting Guide - DateTime Kubernetes Uygulaması

Bu dokümanda karşılaşılan tüm sorunlar, nedenleri ve çözümleri adım adım açıklanmaktadır.

## 📋 İçindekiler

1. [Endpoint Sorunları](#1-endpoint-sorunları)
2. [Ingress Controller Node Yerleşimi](#2-ingress-controller-node-yerleşimi)
3. [Admission Webhook Sorunları](#3-admission-webhook-sorunları)
4. [Image Pull Sorunları](#4-image-pull-sorunları)
5. [Erişim Sorunları](#5-erişim-sorunları)

---

## 1. Endpoint Sorunları

### 🔴 Sorun

```
Service "default/datetime-api-service" does not have any active Endpoint.
Service "default/datetime-web-service" does not have any active Endpoint.
```

**Belirti**: Ingress Controller loglarında endpoint uyarıları görünüyor.

### 🔍 Analiz

```bash
# Endpoint'leri kontrol et
kubectl get endpoints

# Çıktı:
NAME                   ENDPOINTS   AGE
datetime-api-service   <none>      5m
datetime-web-service   <none>      5m
```

**Neden**: Service'lerdeki `selector` ve `ports` sıralaması yanlış. YAML'da `selector` ports'tan önce gelmeliydi.

### ✅ Çözüm

**api-deployment.yaml ve web-deployment.yaml** dosyalarında Service tanımını düzelttik:

```yaml
# YANLIŞ ❌
spec:
  type: ClusterIP
  selector:           # Önce selector
    app: datetime-api
  ports:              # Sonra ports
  - port: 80
    targetPort: 5000

# DOĞRU ✅
spec:
  type: ClusterIP
  ports:              # Önce ports
  - port: 80
    targetPort: 5000
  selector:           # Sonra selector
    app: datetime-api
```

**Uygulama**:

```bash
kubectl apply -f k8s/api-deployment.yaml
kubectl apply -f k8s/web-deployment.yaml

# Doğrulama
kubectl get endpoints
# ENDPOINTS: 10.244.1.4:5000,10.244.2.2:5000 ✅
```

**Sonuç**: ✅ Endpoint'ler oluştu, Service'ler pod'ları buluyor.

---

## 2. Ingress Controller Node Yerleşimi

### 🔴 Sorun

Ingress Controller **worker node'da** çalışıyor ama **control-plane'de** çalışması gerekiyor.

```bash
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-worker2 ❌
```

**Belirti**: localhost:80/443 üzerinden erişim çalışmıyor.

### 🔍 Analiz

#### Neden Control-Plane'de Çalışmalı?

Kind yapılandırmasında `extraPortMappings` sadece control-plane node'unda:

```yaml
# kind-config.yaml
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80 # ← Sadece control-plane'de!
      - containerPort: 443
        hostPort: 443
```

Worker node'larda bu mapping yok, bu yüzden localhost'tan erişim çalışmıyor.

#### Neden Worker'a Düştü?

Kind'ın NGINX Ingress manifest'inde:

- ✅ `hostNetwork: true` var
- ❌ `nodeSelector: ingress-ready: "true"` YOK!
- ❌ `tolerations` YOK!

**Kubernetes Scheduler Davranışı**:

```
Predicate (Filtreleme):
├─ Control-plane: ✓ (os=linux)
├─ Worker1: ✓ (os=linux)
└─ Worker2: ✓ (os=linux)

Priority (Eşit):
├─ Control-plane: 100 puan
├─ Worker1: 100 puan
└─ Worker2: 100 puan

Seçim: Random! → Worker2 seçildi 🎲
```

### ✅ Çözüm

#### Seçenek 1: Özel Deployment YAML (ÖNERİLEN ⭐)

`k8s/ingress-nginx-deployment.yaml` dosyası oluşturduk:

```yaml
spec:
  template:
    spec:
      hostNetwork: true
      nodeSelector:
        kubernetes.io/os: linux
        ingress-ready: "true" # ← Control-plane'de bu label var!
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
        - key: node-role.kubernetes.io/master
          operator: Exists
          effect: NoSchedule
```

**Kullanım**:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

#### Seçenek 2: Patch (Alternatif)

```bash
# Makefile ile
make fix-ingress

# Veya manuel
kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '
{
  "spec": {
    "template": {
      "spec": {
        "nodeSelector": {
          "ingress-ready": "true"
        }
      }
    }
  }
}'
```

**Doğrulama**:

```bash
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-control-plane ✅
```

**Sonuç**: ✅ Ingress Controller control-plane'de çalışıyor.

---

## 3. Admission Webhook Sorunları

### 🔴 Sorun

Pod başlamıyor:

```bash
kubectl describe pod -n ingress-nginx ingress-nginx-controller-xxx

Events:
  Warning  FailedMount  secret "ingress-nginx-admission" not found
```

**Belirti**: Pod `Pending` durumunda, webhook sertifikası eksik.

### 🔍 Analiz

NGINX Ingress Controller varsayılan olarak **ValidatingWebhook** kullanır:

- Webhook için TLS sertifikası gerekir
- Sertifika bir Job tarafından oluşturulur
- Kind'da bu Job bazen çalışmıyor

**Kind'da Webhook Gereksiz**:

- Local development ortamı
- Ingress validation gerekmez
- Sadece production'da önemli

### ✅ Çözüm

#### Seçenek 1: Webhook'sız Deployment (ÖNERİLEN ⭐)

`k8s/ingress-nginx-deployment.yaml` güncelledik:

```yaml
# Webhook argümanlarını kaldırdık
args:
  - /nginx-ingress-controller
  - --election-id=ingress-nginx-leader
  - --controller-class=k8s.io/ingress-nginx
  # Webhook devre dışı
  # - --validating-webhook=:8443
  # - --validating-webhook-certificate=/usr/local/certificates/cert
  # - --validating-webhook-key=/usr/local/certificates/key

# Volume'u kaldırdık
# volumes:
#   - name: webhook-cert
#     secret:
#       secretName: ingress-nginx-admission

# Port'u kaldırdık
ports:
  - name: http
    containerPort: 80
  - name: https
    containerPort: 443
  # - name: webhook        # ← Kaldırıldı
  #   containerPort: 8443
```

**Uygulama**:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml
```

#### Seçenek 2: Manuel Secret Oluşturma

```bash
# Self-signed sertifika oluştur
kubectl create secret tls ingress-nginx-admission \
  --cert=<(openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj "/CN=ingress-nginx") \
  --key=<(openssl genrsa 2048) \
  -n ingress-nginx

kubectl delete pod -n ingress-nginx -l app.kubernetes.io/component=controller
```

#### Seçenek 3: Webhook'ları Sil

```bash
kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission
```

**Doğrulama**:

```bash
kubectl get pods -n ingress-nginx
# STATUS: Running ✅
```

**Sonuç**: ✅ Webhook'suz Ingress Controller çalışıyor.

---

## 4. Image Pull Sorunları

### 🔴 Sorun

```bash
kubectl get pods -n ingress-nginx
# STATUS: ImagePullBackOff ❌
```

**Belirti**: Container image çekilemiyor.

### 🔍 Analiz

```bash
kubectl describe pod -n ingress-nginx ingress-nginx-controller-xxx

Events:
  Failed to pull image "registry.k8s.io/ingress-nginx/controller:v1.13.3@sha256:c54d7a8..."
  Error: manifest unknown
```

**Neden**:

- SHA256 digest ARM64 platformunda mevcut değil
- M1/M2/M3 Mac (ARM64) kullanıyorsunuz
- Image multi-platform ama digest tek platform için

**Platform Kontrolü**:

```bash
uname -m
# arm64 → ARM Mac ✅
# x86_64 → Intel Mac
```

### ✅ Çözüm

SHA256 digest'i kaldırdık, Docker otomatik platform seçimi yapsın:

```yaml
# YANLIŞ ❌ (SHA digest ile)
image: registry.k8s.io/ingress-nginx/controller:v1.13.3@sha256:c54d7a8ac1c8a04e71091d8a5e6b31f9df9b0a35c7cba73bc87c653ad8ba4b13

# DOĞRU ✅ (Platform-agnostic)
image: registry.k8s.io/ingress-nginx/controller:v1.13.3
```

**k8s/ingress-nginx-deployment.yaml** güncelledik:

```yaml
containers:
  - name: controller
    image: registry.k8s.io/ingress-nginx/controller:v1.13.3
    imagePullPolicy: IfNotPresent
```

**Uygulama**:

```bash
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml

# Image pull'u izle
kubectl get pods -n ingress-nginx -w
```

**Doğrulama**:

```bash
kubectl get pods -n ingress-nginx
# STATUS: Running ✅

kubectl describe pod -n ingress-nginx ingress-nginx-controller-xxx | grep "Image:"
# Image: registry.k8s.io/ingress-nginx/controller:v1.13.3
# Image ID: sha256:... (ARM64 için doğru image)
```

**Sonuç**: ✅ ARM64 image başarıyla çekildi ve pod çalışıyor.

---

## 5. Erişim Sorunları

### 🔴 Sorun

```bash
curl http://api.local/api/datetime
# curl: (7) Failed to connect to api.local port 80: Connection refused
```

**Belirti**: Endpoint'ler var, Ingress Controller çalışıyor ama erişim yok.

### 🔍 Analiz

**Olası Nedenler**:

1. `/etc/hosts` güncel değil
2. Ingress Controller worker node'da
3. hostNetwork false

**Kontrol**:

```bash
# 1. /etc/hosts kontrolü
cat /etc/hosts | grep api.local
# Yoksa sorun bu!

# 2. Ingress Controller node
kubectl get pods -n ingress-nginx -o wide
# NODE: kind-worker2 ise sorun bu!

# 3. hostNetwork
kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o yaml | grep hostNetwork
# false veya yok ise sorun bu!
```

### ✅ Çözüm

#### 1. /etc/hosts Güncelle

```bash
# Ekle
echo "127.0.0.1 api.local web.local" | sudo tee -a /etc/hosts

# Kontrol
grep "api.local\|web.local" /etc/hosts

# Veya Makefile ile
make update-hosts
```

#### 2. Ingress Controller Control-Plane'e Taşı

Yukarıdaki [Bölüm 2](#2-ingress-controller-node-yerleşimi)'ye bakın.

#### 3. hostNetwork Düzelt

```bash
make fix-ingress

# Veya manuel
kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '
{
  "spec": {
    "template": {
      "spec": {
        "hostNetwork": true
      }
    }
  }
}'
```

**Doğrulama**:

```bash
# Test
curl http://api.local/api/datetime

# Beklenen:
{
  "date": "05.10.2025",
  "time": "15:30:45",
  "dayOfWeek": "Pazar",
  "timestamp": "2025-10-05T15:30:45+03:00"
}
```

**Sonuç**: ✅ API ve Web uygulamasına erişim çalışıyor.

---

## 📊 Sorun Giderme Akış Şeması

```
┌─────────────────────────────────────┐
│  Uygulamaya erişilemiyor?           │
└─────────────────┬───────────────────┘
                  │
                  ▼
         ┌─────────────────────┐
         │ Endpoint'ler var mı?│
         └────┬──────────┬─────┘
              │          │
           HAYIR       EVET
              │          │
              ▼          ▼
    ┌──────────────┐  ┌──────────────────────┐
    │ Service YAML │  │ Ingress Controller   │
    │ düzelt       │  │ çalışıyor mu?        │
    │ (selector)   │  └────┬──────────┬──────┘
    └──────────────┘       │          │
                        HAYIR       EVET
                           │          │
                           ▼          ▼
                ┌────────────────┐  ┌──────────────────┐
                │ Pod STATUS?    │  │ Control-plane'de │
                │ - Pending      │  │ mi?              │
                │ - ImagePull... │  └────┬──────┬──────┘
                └────┬───────┬───┘       │      │
                     │       │        HAYIR   EVET
                     ▼       ▼          │      │
            ┌─────────┐ ┌─────────┐     ▼      ▼
            │Webhook  │ │Image    │  ┌────┐ ┌────────┐
            │Secret   │ │SHA256   │  │Fix │ │/etc/   │
            │oluştur  │ │kaldır   │  │    │ │hosts?  │
            └─────────┘ └─────────┘  └────┘ └────────┘
                                        │       │
                                        ▼       ▼
                                    ✅ ÇÖZÜLDÜ
```

---

## 🎯 Hızlı Çözüm Rehberi

### Yeni Kurulum (Önerilen)

```bash
# 1. Temizlik
make clean-all

# 2. Özel Ingress YAML ile deploy
make deploy

# 3. Doğrula
make verify

# 4. Test
curl http://api.local/api/datetime
```

### Mevcut Cluster Sorunları

```bash
# 1. Endpoint yoksa
kubectl apply -f k8s/api-deployment.yaml
kubectl apply -f k8s/web-deployment.yaml

# 2. Ingress sorunluysa
kubectl delete namespace ingress-nginx
kubectl apply -f k8s/ingress-nginx-deployment.yaml

# 3. /etc/hosts
echo "127.0.0.1 api.local web.local" | sudo tee -a /etc/hosts

# 4. Test
curl http://api.local/api/datetime
```

---

## 📋 Checklist: Deployment Doğrulama

Tüm sorunlar çözüldükten sonra:

- [ ] **Node Sayısı**: `kubectl get nodes` → 3 node (1 control + 2 worker)
- [ ] **Endpoint'ler**: `kubectl get endpoints` → Her service 2 endpoint
- [ ] **Ingress Controller**: `kubectl get pods -n ingress-nginx -o wide` → kind-control-plane
- [ ] **Pod Durumu**: `kubectl get pods` → Hepsi Running
- [ ] **hostNetwork**: `kubectl get pod -n ingress-nginx -o yaml | grep hostNetwork` → true
- [ ] **/etc/hosts**: `grep api.local /etc/hosts` → 127.0.0.1 api.local web.local
- [ ] **API Test**: `curl http://api.local/api/datetime` → JSON response
- [ ] **Web Test**: `curl http://web.local` → HTML response
- [ ] **Verify**: `make verify` → Tüm testler başarılı

---

## 🛠️ Kullanışlı Debug Komutları

```bash
# Genel Durum
make status
make show-nodes
make verify

# Ingress Controller
kubectl get pods -n ingress-nginx -o wide
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
kubectl describe pod -n ingress-nginx <pod-name>

# Service & Endpoint
kubectl get endpoints
kubectl describe service datetime-api-service

# Ingress
kubectl describe ingress datetime-ingress

# Pod'lar
kubectl get pods -o wide
kubectl logs <pod-name> -f

# Network Test (Cluster içinden)
kubectl run test --image=curlimages/curl -it --rm -- curl http://datetime-api-service/api/datetime
```

---

## 📚 İlgili Dokümanlar

- **[README](../README.md)**: Genel kullanım ve kurulum
- **[WORKER_NODES](WORKER_NODES.md)**: Multi-node cluster rehberi
- **[INGRESS_ROUTING](INGRESS_ROUTING.md)**: Ingress routing detayları
- **[INGRESS_CONTROLLER_FIX](INGRESS_CONTROLLER_FIX.md)**: Ingress Controller düzeltme yöntemleri
- **[INGRESS_SETUP](INGRESS_SETUP.md)**: Ingress kurulum rehberi
- **[LOAD_BALANCING](LOAD_BALANCING.md)**: Load balancing stratejileri

---

## 🎓 Öğrenilen Dersler

### 1. YAML Sıralaması Önemli

Service tanımında `ports` ve `selector` sıralaması Kubernetes'te önemlidir.

### 2. Kind'da Scheduler Rastgele Seçim Yapabilir

`nodeSelector` olmadan pod'lar rastgele node'lara düşebilir.

### 3. Platform-Specific Image Digest'ler Sorun Çıkarır

ARM64/AMD64 için farklı digest'ler var, multi-platform için digest kullanmayın.

### 4. Webhook'lar Local Development'ta Gereksiz

Kind'da admission webhook'ları devre dışı bırakabilirsiniz.

### 5. hostNetwork + extraPortMappings = localhost Erişim

Kind'da localhost erişimi için bu ikisi birlikte gerekli.

---

## ✅ Final Yapılandırma

### k8s/ingress-nginx-deployment.yaml (Özet)

```yaml
spec:
  template:
    spec:
      # ✅ Host network
      hostNetwork: true

      # ✅ Control-plane'de çalış
      nodeSelector:
        kubernetes.io/os: linux
        ingress-ready: "true"

      # ✅ Control-plane taint'ini tolere et
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          effect: NoSchedule

      containers:
        - name: controller
          # ✅ Platform-agnostic image
          image: registry.k8s.io/ingress-nginx/controller:v1.13.3

          # ✅ Webhook'suz args
          args:
            - /nginx-ingress-controller
            - --ingress-class=nginx
            # Webhook devre dışı

          # ✅ Host ports
          ports:
            - containerPort: 80
              hostPort: 80
            - containerPort: 443
              hostPort: 443
```

---

**Sonuç**: Tüm sorunlar çözüldü, sistem çalışıyor! 🎉
