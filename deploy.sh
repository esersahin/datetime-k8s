#!/bin/bash

set -e

# Başlangıç zamanını kaydet
START_TIME=$(date +%s)

echo "🚀 DateTime Kubernetes Deployment Script"
echo "========================================"

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonksiyonlar
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

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
    kubectl get nodes
fi

# 2. NGINX Ingress Controller kurulumu
print_info "NGINX Ingress Controller kontrol ediliyor..."
if ! kubectl get namespace ingress-nginx &> /dev/null; then
    print_info "NGINX Ingress Controller kuruluyor (Kind/Mac optimized)..."
    
    # Kind için özel manifest indir ve düzenle
    curl -s https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml | \
    kubectl apply -f -
    
    print_info "Ingress Controller hazır olması bekleniyor..."
    sleep 5  # Webhook için bekleme süresi
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=90s 2>/dev/null || true
    
    print_success "NGINX Ingress Controller kuruldu"
else
    print_success "NGINX Ingress Controller zaten mevcut"
fi

# 2.1. NGINX Ingress Controller'ın hostNetwork ayarını kontrol et ve düzelt
print_info "NGINX Ingress Controller yapılandırması kontrol ediliyor..."
if kubectl get deployment -n ingress-nginx ingress-nginx-controller &> /dev/null; then
    CURRENT_HOST_NETWORK=$(kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.template.spec.hostNetwork}')
    if [ "$CURRENT_HOST_NETWORK" != "true" ]; then
        print_info "hostNetwork ayarı düzeltiliyor..."
        kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '{"spec":{"template":{"spec":{"hostNetwork":true}}}}'

        print_info "NGINX Ingress Controller yeniden başlatılması bekleniyor..."
        kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout=90s
        kubectl wait --namespace ingress-nginx \
          --for=condition=ready pod \
          --selector=app.kubernetes.io/component=controller \
          --timeout=90s 2>/dev/null || true
        print_success "hostNetwork ayarı düzeltildi ve controller yeniden başlatıldı"
    else
        print_success "hostNetwork ayarı zaten doğru yapılandırılmış"
    fi

    # Control-plane yerleşimi kontrolü
    print_info "Ingress Controller control-plane kontrolü yapılıyor..."
    CURRENT_NODE=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].spec.nodeName}')
    if [ "$CURRENT_NODE" != "kind-control-plane" ]; then
        print_info "Ingress Controller $CURRENT_NODE'da, control-plane'e taşınıyor..."
        kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"}}}}}'

        kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout=90s
        kubectl wait --namespace ingress-nginx \
          --for=condition=ready pod \
          --selector=app.kubernetes.io/component=controller \
          --timeout=90s 2>/dev/null || true
        print_success "Ingress Controller control-plane'e taşındı"
    else
        print_success "Ingress Controller zaten control-plane'de"
    fi

    echo ""
    print_info "Ingress Controller Durumu:"
    kubectl get pods -n ingress-nginx -o wide
fi

# 2.2. Problematic admission webhooks'u devre dışı bırak (Mac/Kind için)
print_info "Admission webhook'ları kontrol ediliyor..."
if kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission &> /dev/null; then
    print_info "Validating webhook devre dışı bırakılıyor (Mac/Kind için gerekli)..."
    kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission 2>/dev/null || true
    print_success "Validating webhook silindi"
fi

# Admission webhook job'ları da temizle
print_info "Webhook job'ları temizleniyor..."
kubectl delete jobs -n ingress-nginx ingress-nginx-admission-create ingress-nginx-admission-patch 2>/dev/null || true
print_success "Webhook yapılandırması temizlendi"

# 3. Docker imajlarını build et
print_info "Docker imajları oluşturuluyor..."

# API için
print_info "API imajı build ediliyor..."
cd api
docker build -t datetime-api:latest -f Dockerfile.api .
cd ..
print_success "API imajı oluşturuldu"

# Web için
print_info "Web imajı build ediliyor..."
cd web
docker build -t datetime-web:latest -f Dockerfile.web .
cd ..
print_success "Web imajı oluşturuldu"

# API-Go için
print_info "API-Go imajı build ediliyor..."
cd api-go
docker build -t datetime-api-go:latest .
cd ..
print_success "API-Go imajı oluşturuldu"

# Web-Go için
print_info "Web-Go imajı build ediliyor..."
cd web-go
docker build -t datetime-web-go:latest .
cd ..
print_success "Web-Go imajı oluşturuldu"

# 4. İmajları Kind'a yükle
print_info "İmajlar Kind cluster'a yükleniyor..."
kind load docker-image datetime-api:latest
kind load docker-image datetime-web:latest
kind load docker-image datetime-api-go:latest
kind load docker-image datetime-web-go:latest
print_success "İmajlar yüklendi"

# 5. Kubernetes kaynaklarını uygula
print_info "Kubernetes kaynakları uygulanıyor..."

kubectl apply -f k8s/api-deployment.yaml
print_success "API deployment uygulandı"

kubectl apply -f k8s/web-deployment.yaml
print_success "Web deployment uygulandı"

if [ -f "k8s/api-go-deployment.yaml" ]; then
    kubectl apply -f k8s/api-go-deployment.yaml
    print_success "API-Go deployment uygulandı"
fi

if [ -f "k8s/web-go-deployment.yaml" ]; then
    kubectl apply -f k8s/web-go-deployment.yaml
    print_success "Web-Go deployment uygulandı"
fi

kubectl apply -f k8s/ingress.yaml
print_success "Ingress uygulandı"

# 6. Deployment'ların hazır olmasını bekle
print_info "Deployment'lar hazır olması bekleniyor..."
kubectl wait --for=condition=available --timeout=120s deployment/datetime-api
kubectl wait --for=condition=available --timeout=120s deployment/datetime-web
kubectl wait --for=condition=available --timeout=120s deployment/datetime-api-go 2>/dev/null || true
kubectl wait --for=condition=available --timeout=120s deployment/datetime-web-go 2>/dev/null || true
print_success "Tüm deployment'lar hazır"

# 7. /etc/hosts dosyasını güncelle
print_info "Host dosyası güncelleniyor..."
if ! grep -q "api.local" /etc/hosts; then
    echo "127.0.0.1 api.local web.local api-go.local web-go.local" | sudo tee -a /etc/hosts
    echo "::1 api.local web.local api-go.local web-go.local" | sudo tee -a /etc/hosts
    print_success "Host dosyası güncellendi (IPv4 ve IPv6)"
else
    if ! grep -q "api-go.local" /etc/hosts; then
        sudo sed -i '' 's/api.local web.local/api.local web.local api-go.local web-go.local/' /etc/hosts
        print_success "Host dosyası güncellendi (api-go.local ve web-go.local eklendi)"
    fi
    if ! grep -q "::1.*api.local" /etc/hosts; then
        echo "::1 api.local web.local api-go.local web-go.local" | sudo tee -a /etc/hosts
        print_success "IPv6 entries eklendi (5 saniye gecikme düzeltildi!)"
    else
        print_success "Host kayıtları zaten mevcut"
    fi
fi

# 8. Süre hesaplama
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# 9. Durum bilgisi
echo ""
echo "========================================"
print_success "Deployment tamamlandı! 🎉"
echo "========================================"
echo ""
echo -e "${YELLOW}⏱️  Toplam Süre: ${MINUTES} dakika ${SECONDS} saniye${NC}"
echo ""
echo "📊 Durum Bilgisi:"
echo ""
kubectl get pods -o wide
echo ""
kubectl get services
echo ""
kubectl get ingress
echo ""
echo "========================================"
echo "🌐 Uygulamaya Erişim:"
echo "========================================"
echo -e "  ${YELLOW}C# Uygulamaları:${NC}"
echo "    Web: http://web.local"
echo "    API: http://api.local/api/datetime"
echo ""
echo -e "  ${YELLOW}Go Uygulamaları:${NC}"
echo "    Web-Go: http://web-go.local"
echo "    API-Go: http://api-go.local/health"
echo ""
echo "========================================"
echo "📝 Yararlı Komutlar:"
echo "========================================"
echo "  Logları görüntüle:"
echo "    kubectl logs -l app=datetime-api -f"
echo "    kubectl logs -l app=datetime-web -f"
echo ""
echo "  Pod'ları izle:"
echo "    kubectl get pods -w"
echo ""
echo "  Servisleri test et:"
echo "    curl http://api.local/api/datetime"
echo "    curl http://web.local"
echo ""
echo "  Temizle:"
echo "    kubectl delete -f k8s/api-deployment.yaml"
echo "    kubectl delete -f k8s/web-deployment.yaml"
echo "    kubectl delete -f k8s/ingress.yaml"
echo "    kind delete cluster"
echo ""
print_success "İyi çalışmalar! 🚀"