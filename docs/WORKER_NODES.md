<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](WORKER_NODES.en.md) | 🇹🇷 [Türkçe](WORKER_NODES.md) |
|:---:|:---:|

</div>

---

﻿# Kubernetes Cluster'a Worker Node Ekleme Rehberi

Bu dokümanda Kind cluster'ınıza 2 worker node ekleyerek multi-node bir cluster oluşturmayı öğreneceksiniz.

## 📋 İçindekiler

1. [Mevcut Durum](#-mevcut-durum)
2. [Hedef Durum](#-hedef-durum)
3. [kind-config.yaml Değişiklikleri](#-kind-configyaml-değişiklikleri)
4. [Makefile Değişiklikleri](#-makefile-değişiklikleri)
5. [deploy.sh Değişiklikleri](#-deploysh-değişiklikleri)
6. [Deployment Sonrası Kontroller](#-deployment-sonrası-kontroller)
7. [Pod Scheduling ve Node Affinity](#-pod-scheduling-ve-node-affinity)

---

## 🔍 Mevcut Durum

Şu anda cluster'ınız **sadece 1 control-plane node** ile çalışıyor:

```yaml
nodes:
  - role: control-plane
```

Bu yapıda:

- ✅ Tüm Kubernetes control plane bileşenleri çalışıyor (API Server, Scheduler, Controller Manager)
- ⚠️ Pod'lar control-plane node'da çalışıyor
- ⚠️ Canlıya benzer bir ortam değil
- ⚠️ High availability yok

## 🎯 Hedef Durum

**1 Control-Plane + 2 Worker Node** yapısı:

```yaml
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

Bu yapıda:

- ✅ Control plane işlemleri ayrı node'da
- ✅ Uygulama pod'ları worker node'larda
- ✅ Production-like ortam
- ✅ Load balancing ve ölçeklenebilirlik
- ✅ Node failure senaryolarını test edebilme

---

## 📝 kind-config.yaml Değişiklikleri

### ❌ Eski `kind-config.yaml`

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
```

### ✅ Yeni `kind-config.yaml` (Multi-Node)

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  # Control Plane Node
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP

  # Worker Node 1
  - role: worker
    labels:
      worker-group: group-1

  # Worker Node 2
  - role: worker
    labels:
      worker-group: group-2
```

### 🔑 Önemli Noktalar

1. **Control-Plane Node**:

   - `ingress-ready=true` label'ı sadece control-plane'de
   - Port mapping'ler sadece control-plane'de
   - Ingress controller burada çalışacak

2. **Worker Node'lar**:
   - Özel label'lar eklenebilir (`worker-group`)
   - Uygulama pod'ları burada çalışacak
   - Her node farklı etiketlenebilir (node affinity için)

---

## 🔧 Makefile Değişiklikleri

### Güncellenen `create-cluster` Target

`Makefile` içindeki `create-cluster` target'ı önemli bir geliştirme ile güncellendi:

**Önemli Özellik**: Artık `kind-config.yaml` dosyası yoksa **otomatik olarak oluşturuluyor**!

```makefile
create-cluster: ## Kind cluster oluşturur (multi-node: 1 control-plane + 2 workers)
	@echo "$(YELLOW)🚀 Kind cluster kontrol ediliyor...$(NC)"
	@if ! kind get clusters | grep -q "$(CLUSTER_NAME)"; then \
		echo "$(YELLOW)Kind cluster oluşturuluyor (1 control-plane + 2 workers)...$(NC)"; \
		if [ ! -f "kind-config.yaml" ]; then \
			echo "$(YELLOW)kind-config.yaml bulunamadı, oluşturuluyor...$(NC)"; \
			# printf kullanarak kind-config.yaml oluştur
			printf 'kind: Cluster\n' > kind-config.yaml; \
			printf 'apiVersion: kind.x-k8s.io/v1alpha4\n' >> kind-config.yaml; \
			printf 'nodes:\n' >> kind-config.yaml; \
			printf '# Control Plane Node\n' >> kind-config.yaml; \
			printf -- '- role: control-plane\n' >> kind-config.yaml; \
			printf '  kubeadmConfigPatches:\n' >> kind-config.yaml; \
			printf '  - |\n' >> kind-config.yaml; \
			printf '    kind: InitConfiguration\n' >> kind-config.yaml; \
			printf '    nodeRegistration:\n' >> kind-config.yaml; \
			printf '      kubeletExtraArgs:\n' >> kind-config.yaml; \
			printf '        node-labels: "ingress-ready=true"\n' >> kind-config.yaml; \
			printf '  extraPortMappings:\n' >> kind-config.yaml; \
			printf '  - containerPort: 80\n' >> kind-config.yaml; \
			printf '    hostPort: 80\n' >> kind-config.yaml; \
			printf '    protocol: TCP\n' >> kind-config.yaml; \
			printf '  - containerPort: 443\n' >> kind-config.yaml; \
			printf '    hostPort: 443\n' >> kind-config.yaml; \
			printf '    protocol: TCP\n' >> kind-config.yaml; \
			printf '\n' >> kind-config.yaml; \
			printf '# Worker Node 1\n' >> kind-config.yaml; \
			printf -- '- role: worker\n' >> kind-config.yaml; \
			printf '  labels:\n' >> kind-config.yaml; \
			printf '    worker-group: group-1\n' >> kind-config.yaml; \
			printf '\n' >> kind-config.yaml; \
			printf '# Worker Node 2\n' >> kind-config.yaml; \
			printf -- '- role: worker\n' >> kind-config.yaml; \
			printf '  labels:\n' >> kind-config.yaml; \
			printf '    worker-group: group-2\n' >> kind-config.yaml; \
			echo "$(GREEN)✓ kind-config.yaml oluşturuldu$(NC)"; \
		else \
			echo "$(GREEN)✓ kind-config.yaml mevcut, kullanılıyor$(NC)"; \
		fi; \
		# Her durumda kind-config.yaml kullanılarak cluster oluştur
		kind create cluster --config=kind-config.yaml; \
		echo "$(GREEN)✓ Multi-node Kind cluster oluşturuldu$(NC)"; \
		echo ""; \
		echo "$(BLUE)Cluster Node'ları:$(NC)"; \
		kubectl get nodes -o wide; \
	else \
		echo "$(GREEN)✓ Kind cluster zaten mevcut$(NC)"; \
		echo "$(BLUE)Mevcut node'lar:$(NC)"; \
		kubectl get nodes; \
	fi
```

### 🎯 Akış Mantığı

1. **Cluster var mı kontrol et**

   - Varsa: Mevcut node'ları göster
   - Yoksa: Devam et

2. **kind-config.yaml var mı kontrol et**

   - Varsa: Mevcut dosyayı kullan
   - Yoksa: `printf` kullanarak otomatik oluştur

3. **Cluster oluştur**

   - Her durumda `kind create cluster --config=kind-config.yaml` kullan
   - Inline config kullanmıyoruz, her zaman dosya kullanıyoruz

4. **Node'ları göster**
   - Oluşturulan node'ları listele

### 🔑 Avantajları

- ✅ **Otomatik**: Dosya yoksa otomatik oluşturuluyor
- ✅ **Tutarlı**: Her zaman aynı dosya kullanılıyor
- ✅ **Özelleştirilebilir**: Kullanıcı isterse `kind-config.yaml`'ı manuel düzenleyebilir
- ✅ **Versiyon Kontrol**: `kind-config.yaml` git'e eklenebilir
- ✅ **Tekrarlanabilir**: Aynı yapılandırma her seferinde kullanılır

### Yeni Eklenen `show-nodes` Target

```makefile
show-nodes: ## Cluster node'larını detaylı gösterir
	@echo "$(BLUE)📊 Cluster Node'ları$(NC)"
	@echo "===================="
	@kubectl get nodes -o wide
	@echo ""
	@echo "$(BLUE)Node Detayları:$(NC)"
	@echo ""
	@for node in $$(kubectl get nodes -o name); do \
		echo "$(YELLOW)$$node:$(NC)"; \
		kubectl describe $$node | grep -A 5 "Labels:"; \
		echo ""; \
	done
```

### Güncellenmiş `status` Target

```makefile
status: ## Cluster durumunu gösterir
	@echo "$(BLUE)📊 Cluster Durumu$(NC)"
	@echo "=================="
	@echo ""
	@echo "$(YELLOW)Nodes:$(NC)"
	@kubectl get nodes -o wide
	@echo ""
	@echo "$(YELLOW)Pods (with Node placement):$(NC)"
	@kubectl get pods -o wide
	@echo ""
	@echo "$(YELLOW)Services:$(NC)"
	@kubectl get services
	@echo ""
	@echo "$(YELLOW)Ingress:$(NC)"
	@kubectl get ingress
```

---

## 🚀 deploy.sh Değişiklikleri

### Güncellenen Cluster Oluşturma Bölümü

```bash
# 1. Kind cluster kontrolü
print_info "Kind cluster kontrol ediliyor..."
if ! kind get clusters | grep -q "kind"; then
    print_info "Kind cluster oluşturuluyor (1 control-plane + 2 workers)..."

    # kind-config.yaml varsa onu kullan, yoksa inline config kullan
    if [ -f "kind-config.yaml" ]; then
        print_info "kind-config.yaml dosyası kullanılıyor..."
        kind create cluster --config=kind-config.yaml
    else
        print_info "Inline config kullanılıyor (multi-node)..."
        cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
  labels:
    worker-group: group-1
- role: worker
  labels:
    worker-group: group-2
EOF
    fi

    print_success "Multi-node Kind cluster oluşturuldu"
    echo ""
    print_info "Cluster node'ları:"
    kubectl get nodes -o wide
else
    print_success "Kind cluster zaten mevcut"
fi
```

---

## 🔍 Deployment Sonrası Kontroller

### 1. Node'ları Kontrol Etme

```bash
# Makefile ile
make show-nodes

# veya kubectl ile
kubectl get nodes

# Detaylı bilgi
kubectl get nodes -o wide

# Beklenen çıktı:
NAME                 STATUS   ROLES           AGE   VERSION
kind-control-plane   Ready    control-plane   2m    v1.27.3
kind-worker          Ready    <none>          2m    v1.27.3
kind-worker2         Ready    <none>          2m    v1.27.3
```

### 2. Pod Dağılımını Kontrol Etme

```bash
# Pod'ların hangi node'da çalıştığını göster
kubectl get pods -o wide

# Makefile ile
make status
```

**Örnek Çıktı:**

```
NAME                           READY   STATUS    NODE
datetime-api-5d8f7b9c8-abc12   1/1     Running   kind-worker
datetime-api-5d8f7b9c8-def34   1/1     Running   kind-worker2
datetime-web-7c9d4b8f5-ghi56   1/1     Running   kind-worker
datetime-web-7c9d4b8f5-jkl78   1/1     Running   kind-worker2
```

### 3. Node Label'larını Kontrol Etme

```bash
# Tüm node'ların label'larını göster
kubectl get nodes --show-labels

# Specific node'un label'larını göster
kubectl describe node kind-worker | grep Labels -A 10
```

---

## 📦 Pod Scheduling ve Node Affinity

### Mevcut Deployment'lar

Şu anki deployment'larınız herhangi bir node affinity içermiyor, bu yüzden pod'lar otomatik olarak worker node'lara dağıtılacak.

### Opsiyonel: Specific Node'a Pod Atama

Eğer belirli pod'ları belirli node'larda çalıştırmak isterseniz:

#### api-deployment.yaml'a Node Affinity Ekleme

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: datetime-api
spec:
  replicas: 2
  template:
    spec:
      # Node Affinity - API pod'ları sadece worker-group-1'de çalışsın
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: worker-group
                    operator: In
                    values:
                      - group-1
      containers:
        - name: api
          image: datetime-api:latest
          # ... rest of config
```

#### web-deployment.yaml'a Node Affinity Ekleme

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: datetime-web
spec:
  replicas: 2
  template:
    spec:
      # Node Affinity - Web pod'ları sadece worker-group-2'de çalışsın
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: worker-group
                    operator: In
                    values:
                      - group-2
      containers:
        - name: web
          image: datetime-web:latest
          # ... rest of config
```

### Pod Anti-Affinity (High Availability)

Aynı pod'ların farklı node'larda çalışmasını garantilemek için:

```yaml
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - datetime-api
              topologyKey: "kubernetes.io/hostname"
```

---

## 🧪 Test Senaryoları

### Test 1: kind-config.yaml Otomatik Oluşturma

```bash
# kind-config.yaml'ı sil (varsa)
rm kind-config.yaml

# Cluster oluştur
make create-cluster

# Beklenen çıktı:
# ℹ kind-config.yaml bulunamadı, oluşturuluyor...
# ✓ kind-config.yaml oluşturuldu
# ✓ Multi-node Kind cluster oluşturuldu

# Dosyanın oluştuğunu doğrula
ls -la kind-config.yaml
cat kind-config.yaml

# Node'ları kontrol et
kubectl get nodes
# Beklenen: kind-control-plane, kind-worker, kind-worker2
```

### Test 2: Pod Dağılımını Test Etme

```bash
# Replica sayısını artır
make scale-api REPLICAS=4
make scale-web REPLICAS=4

# Dağılımı kontrol et
kubectl get pods -o wide

# Her node'da kaç pod var?
kubectl get pods -o wide | awk '{print $7}' | sort | uniq -c

# Beklenen çıktı örneği:
#   1 NODE
#   2 kind-worker
#   2 kind-worker2
#   2 kind-control-plane (sadece ingress controller)
```

### Test 3: Node Failure Simülasyonu

```bash
# Bir worker node'u drain et
kubectl drain kind-worker --ignore-daemonsets --delete-emptydir-data

# Pod'ların diğer node'a taşınmasını izle
kubectl get pods -o wide -w

# Beklenen: kind-worker'daki pod'lar kind-worker2'ye taşınacak

# Node'u tekrar aktif et
kubectl uncordon kind-worker

# Pod'lar tekrar dengelendi mi kontrol et
kubectl get pods -o wide
```

### Test 4: Node Resource Monitoring

```bash
# Node kaynak kullanımı (metrics-server gerekli)
kubectl top nodes

# Eğer metrics-server yoksa kur
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Metrics-server için TLS'i devre dışı bırak (Kind için)
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Birkaç dakika bekle ve tekrar dene
kubectl top nodes
kubectl top pods

# Makefile ile genel durum
make status
```

### Test 5: Multi-Node Cluster Özellikleri

```bash
# 1. Node label'larını kontrol et
kubectl get nodes --show-labels

# 2. Her node'un role'ünü kontrol et
kubectl get nodes -o custom-columns=NAME:.metadata.name,ROLE:.metadata.labels."kubernetes\.io/role",STATUS:.status.conditions[-1].type

# 3. Control-plane'de sadece system pod'ları var mı?
kubectl get pods -n kube-system -o wide | grep control-plane

# 4. Worker node'larda uygulama pod'ları var mı?
kubectl get pods -o wide | grep -E "kind-worker|kind-worker2"

# 5. Detaylı rapor
make show-nodes
```

---

## 📊 Karşılaştırma Tablosu

| Özellik                   | Single Node      | Multi-Node (1+2)   |
| ------------------------- | ---------------- | ------------------ |
| **High Availability**     | ❌ Yok           | ✅ Var             |
| **Load Balancing**        | ❌ Yok           | ✅ Otomatik        |
| **Resource Isolation**    | ❌ Sınırlı       | ✅ İyi             |
| **Production-like**       | ❌ Hayır         | ✅ Evet            |
| **Testing Capabilities**  | ⚠️ Temel         | ✅ Gelişmiş        |
| **Node Failure Handling** | ❌ Test edilemez | ✅ Test edilebilir |
| **Startup Time**          | ✅ Hızlı (~30s)  | ⚠️ Orta (~60s)     |
| **Resource Usage**        | ✅ Düşük         | ⚠️ Orta            |

---

## 🚀 Deployment Komutları

### Senaryo 1: İlk Deployment (kind-config.yaml YOK)

```bash
# Proje dizinine git
cd datetime-k8s

# Deploy et - kind-config.yaml otomatik oluşturulacak
make deploy

# Ne oldu?
# 1. kind-config.yaml otomatik oluşturuldu
# 2. Multi-node cluster oluşturuldu (1+2)
# 3. Tüm servisler deploy edildi

# Oluşan dosyayı kontrol et
cat kind-config.yaml

# Node'ları kontrol et
make show-nodes
```

### Senaryo 2: İlk Deployment (kind-config.yaml VAR)

```bash
# Eğer kind-config.yaml zaten varsa
cd datetime-k8s

# Deploy et - mevcut dosya kullanılacak
make deploy

# Ne oldu?
# 1. Mevcut kind-config.yaml kullanıldı
# 2. Cluster oluşturuldu
# 3. Servisler deploy edildi
```

### Senaryo 3: Özelleştirilmiş Worker Node Sayısı

```bash
# kind-config.yaml'ı manuel düzenle
nano kind-config.yaml

# 3 worker ekle
# - role: worker
#   labels:
#     worker-group: group-3

# Eski cluster'ı sil
make clean-cluster

# Yeni cluster oluştur
make create-cluster

# Node'ları kontrol et
make show-nodes

# Beklenen: 1 control-plane + 3 worker
```

### Senaryo 4: Mevcut Cluster'ı Güncelleme

⚠️ **DİKKAT**: Kind cluster'da node eklemek desteklenmez! Cluster'ı silip yeniden oluşturmanız gerekir.

```bash
# Proje dizininde ol
cd datetime-k8s

# Tam yeniden deployment
make redeploy

# Ne oldu?
# 1. Mevcut cluster silindi (clean-all)
# 2. kind-config.yaml kontrol edildi/oluşturuldu
# 3. Yeni multi-node cluster oluşturuldu
# 4. Tüm servisler yeniden deploy edildi

# Node'ları doğrula
kubectl get nodes
```

---

## 📝 Özet

### Yapılan Değişiklikler

1. ✅ `kind-config.yaml` - 2 worker node eklendi
2. ✅ `Makefile` - `create-cluster` target'ı güncellendi
   - **Yeni Özellik**: `kind-config.yaml` yoksa otomatik oluşturuyor
   - `printf` kullanarak dosya oluşturma
3. ✅ `Makefile` - `show-nodes` target'ı eklendi
4. ✅ `Makefile` - `status` target'ı güncellendi
5. ✅ `deploy.sh` - Multi-node config eklendi

### Hızlı Referans Tablosu

| Komut                      | Açıklama                 | kind-config.yaml Durumu      |
| -------------------------- | ------------------------ | ---------------------------- |
| `make create-cluster`      | Cluster oluştur          | Yoksa otomatik oluşturulur   |
| `make deploy`              | Full deployment          | Yoksa otomatik oluşturulur   |
| `make show-nodes`          | Node'ları detaylı göster | -                            |
| `make status`              | Genel durum (node + pod) | -                            |
| `make clean-cluster`       | Cluster'ı sil            | kind-config.yaml korunur     |
| `make redeploy`            | Sil ve yeniden oluştur   | Mevcut veya yeni oluşturulur |
| `kubectl get nodes`        | Node listesi             | -                            |
| `kubectl get pods -o wide` | Pod yerleşimi            | -                            |

### Kullanım Akış Şeması

```
┌──────────────────────────────────────┐
│  make deploy veya make create-cluster│
└─────────────────┬────────────────────┘
                  │
                  ▼
       ┌──────────────────────┐
       │ kind-config.yaml     │
       │ var mı?              │
       └──────┬──────┬────────┘
              │      │
        HAYIR │      │ EVET
              │      │
              ▼      ▼
    ┌──────────┐  ┌──────────────┐
    │ Otomatik │  │ Mevcut dosya │
    │ Oluştur  │  │ kullan       │
    └────┬─────┘  └──────┬───────┘
         │               │
         └───────┬───────┘
                 │
                 ▼
      ┌──────────────────────────┐
      │ kind create cluster      │
      │ --config=kind-config.yaml│
      └─────────┬────────────────┘
                │
                ▼
    ┌──────────────────────────────┐
    │ 1 Control-Plane              │
    │ 2 Worker Nodes               │
    │ (kind-worker, kind-worker2)  │
    └──────────────────────────────┘
```

### Kullanım

```bash
# 1. Mevcut cluster'ı sil
make clean-all

# 2. Yeni multi-node cluster deploy et
make deploy

# 3. Node'ları kontrol et
make show-nodes

# 4. Pod dağılımını kontrol et
make status

# 5. Test et
make verify
make test
```

### Beklenen Sonuç

- 1 Control-Plane Node (kind-control-plane)
- 2 Worker Node (kind-worker, kind-worker2)
- Pod'lar worker node'larda dengeli dağıtılmış
- Ingress Controller control-plane'de çalışıyor
- Tüm servisler sorunsuz çalışıyor

---

## 🔗 Ek Kaynaklar

- [Kind Multi-Node Clusters](https://kind.sigs.k8s.io/docs/user/quick-start/#creating-a-cluster)
- [Kubernetes Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Pod Anti-Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)

---

**Not**: Bu değişiklikler tamamen local development için optimize edilmiştir. Production ortamları için farklı yapılandırmalar gerekebilir.
