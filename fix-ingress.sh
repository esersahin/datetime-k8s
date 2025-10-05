#!/bin/bash

set -e

echo "🔧 NGINX Ingress Controller Düzeltme Script'i"
echo "=============================================="

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_header() {
    echo -e "${BLUE}▶ $1${NC}"
}

# 1. NGINX Ingress Controller durumunu kontrol et
print_header "Mevcut durum kontrol ediliyor..."
echo ""

if ! kubectl get namespace ingress-nginx &> /dev/null; then
    print_error "NGINX Ingress Controller kurulu değil!"
    echo ""
    print_info "Önce şu komutu çalıştırın:"
    echo "  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"
    exit 1
fi

# 2. Deployment bilgilerini göster
print_info "Deployment bilgileri:"
echo ""
kubectl get deployment -n ingress-nginx ingress-nginx-controller -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,HOSTNETWORK:.spec.template.spec.hostNetwork

echo ""

# 3. hostNetwork ayarını kontrol et
CURRENT_HOST_NETWORK=$(kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.template.spec.hostNetwork}')

if [ "$CURRENT_HOST_NETWORK" == "true" ]; then
    print_success "hostNetwork zaten 'true' olarak ayarlanmış"
    echo ""
    print_info "Pod bilgileri:"
    kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o wide
    echo ""
    print_success "Her şey doğru yapılandırılmış! ✨"
else
    # 4. hostNetwork ayarını düzelt
    print_info "hostNetwork değeri: $CURRENT_HOST_NETWORK"
    echo ""
    print_info "hostNetwork ayarı 'true' olarak güncelleniyor..."

    kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '{"spec":{"template":{"spec":{"hostNetwork":true}}}}'

    print_success "Patch uygulandı"
    echo ""

    # 5. Rollout durumunu bekle
    print_info "Deployment'ın güncellenmesi bekleniyor..."
    kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout=120s
fi

echo ""
print_info "Pod'ların hazır olması bekleniyor..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo ""
print_success "NGINX Ingress Controller başarıyla güncellendi! ✨"
echo ""

# 6. Son durumu göster
print_header "Güncel durum:"
echo ""
kubectl get deployment -n ingress-nginx ingress-nginx-controller -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,HOSTNETWORK:.spec.template.spec.hostNetwork

echo ""
print_info "Pod bilgileri:"
kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o wide

echo ""
print_header "Service bilgileri:"
kubectl get svc -n ingress-nginx

echo ""
print_success "İşlem tamamlandı! 🎉"
echo ""
print_info "Test etmek için:"
echo "  curl http://api.local/health"
echo "  curl http://api.local/api/datetime"
echo "  curl http://web.local"