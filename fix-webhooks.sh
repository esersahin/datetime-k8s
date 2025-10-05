#!/bin/bash

set -e

echo "🔧 NGINX Ingress Admission Webhook Düzeltme Script'i"
echo "====================================================="

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 1. Mevcut webhook'ları kontrol et
print_header "Mevcut webhook'lar kontrol ediliyor..."
echo ""

if kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission &> /dev/null; then
    print_info "Validating webhook mevcut:"
    kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission
    echo ""
    
    # Webhook detayları
    print_info "Webhook detayları:"
    kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission -o jsonpath='{.webhooks[*].name}' 2>/dev/null
    echo ""
    echo ""
    
    WEBHOOK_EXISTS=true
else
    print_success "Validating webhook zaten silinmiş"
    WEBHOOK_EXISTS=false
fi

# 2. Webhook job'larını kontrol et
print_header "Webhook job'ları kontrol ediliyor..."
echo ""

JOBS_FOUND=false
if kubectl get jobs -n ingress-nginx ingress-nginx-admission-create &> /dev/null; then
    print_info "admission-create job'ı mevcut"
    JOBS_FOUND=true
fi

if kubectl get jobs -n ingress-nginx ingress-nginx-admission-patch &> /dev/null; then
    print_info "admission-patch job'ı mevcut"
    JOBS_FOUND=true
fi

if [ "$JOBS_FOUND" = false ]; then
    print_success "Webhook job'ları zaten silinmiş"
fi

echo ""

# 3. İlgili pod'ları kontrol et
print_header "Webhook pod'ları kontrol ediliyor..."
echo ""

WEBHOOK_PODS=$(kubectl get pods -n ingress-nginx | grep "admission" | wc -l)
if [ "$WEBHOOK_PODS" -gt 0 ]; then
    print_info "Webhook pod'ları bulundu:"
    kubectl get pods -n ingress-nginx | grep "admission"
    echo ""
else
    print_success "Webhook pod'ları yok"
fi

# 4. Temizlik işlemine başla
if [ "$WEBHOOK_EXISTS" = true ] || [ "$JOBS_FOUND" = true ] || [ "$WEBHOOK_PODS" -gt 0 ]; then
    echo ""
    print_header "Temizlik işlemi başlatılıyor..."
    echo ""
    
    # ValidatingWebhookConfiguration'ı sil
    if [ "$WEBHOOK_EXISTS" = true ]; then
        print_info "ValidatingWebhookConfiguration siliniyor..."
        kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission 2>/dev/null || true
        print_success "ValidatingWebhookConfiguration silindi"
    fi
    
    # Job'ları sil
    if [ "$JOBS_FOUND" = true ]; then
        print_info "Webhook job'ları siliniyor..."
        kubectl delete jobs -n ingress-nginx ingress-nginx-admission-create 2>/dev/null || true
        kubectl delete jobs -n ingress-nginx ingress-nginx-admission-patch 2>/dev/null || true
        print_success "Webhook job'ları silindi"
    fi
    
    # Pod'ları sil (varsa)
    if [ "$WEBHOOK_PODS" -gt 0 ]; then
        print_info "Webhook pod'ları siliniyor..."
        kubectl delete pods -n ingress-nginx -l app.kubernetes.io/component=admission-webhook 2>/dev/null || true
        print_success "Webhook pod'ları silindi"
    fi
    
    # ServiceAccount ve RBAC temizliği (opsiyonel)
    print_info "Webhook ServiceAccount kontrolü..."
    if kubectl get serviceaccount -n ingress-nginx ingress-nginx-admission &> /dev/null; then
        print_info "Webhook ServiceAccount bulundu (silinmiyor, gerekli olabilir)"
    fi
    
    echo ""
    print_success "Temizlik işlemi tamamlandı! ✨"
else
    echo ""
    print_success "Hiçbir webhook bileşeni bulunamadı, temizlik gerekmiyor! ✨"
fi

# 5. Ingress Controller'ı yeniden kontrol et
echo ""
print_header "Ingress Controller durumu kontrol ediliyor..."
echo ""

if kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller &> /dev/null; then
    print_info "Controller pod'ları:"
    kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller
    echo ""
    
    # Controller loglarında webhook hatası var mı kontrol et
    print_info "Controller logları kontrol ediliyor (son 20 satır)..."
    CONTROLLER_POD=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')
    
    if kubectl logs -n ingress-nginx "$CONTROLLER_POD" --tail=20 2>&1 | grep -i "webhook\|admission" > /dev/null; then
        print_info "Loglarda webhook referansları bulundu (normal olabilir)"
    else
        print_success "Loglarda webhook hatası görünmüyor"
    fi
fi

# 6. Sonuç ve öneriler
echo ""
print_header "SONUÇ VE ÖNERİLER"
echo ""

print_success "Webhook bileşenleri temizlendi"
echo ""
print_info "Ingress'lerinizi test edin:"
echo "  kubectl get ingress"
echo "  kubectl describe ingress datetime-ingress"
echo ""
print_info "Endpoint'leri test edin:"
echo "  curl http://api.local/health"
echo "  curl http://api.local/api/datetime"
echo "  curl http://web.local"
echo ""
print_info "Eğer sorun devam ederse:"
echo "  1. Ingress Controller'ı yeniden başlatın:"
echo "     kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller"
echo ""
echo "  2. Tam doğrulama çalıştırın:"
echo "     ./verify-deployment.sh"
echo ""
print_success "İşlem tamamlandı! 🎉"