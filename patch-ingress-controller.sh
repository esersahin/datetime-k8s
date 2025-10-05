#!/bin/bash

set -e

echo "🔧 Ingress Controller Patch Script"
echo "===================================="

# Renkler
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Kontrol: Ingress Controller var mı?
if ! kubectl get deployment -n ingress-nginx ingress-nginx-controller &> /dev/null; then
    echo "❌ Ingress Controller bulunamadı!"
    echo "Önce şunu çalıştırın: make install-ingress"
    exit 1
fi

print_info "Mevcut durum:"
kubectl get pods -n ingress-nginx -o wide

echo ""
print_info "Ingress Controller'a patch uygulanıyor..."

# Patch uygula
kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type=strategic -p '
{
  "spec": {
    "template": {
      "spec": {
        "hostNetwork": true,
        "nodeSelector": {
          "kubernetes.io/os": "linux",
          "ingress-ready": "true"
        },
        "tolerations": [
          {
            "key": "node-role.kubernetes.io/control-plane",
            "operator": "Exists",
            "effect": "NoSchedule"
          },
          {
            "key": "node-role.kubernetes.io/master",
            "operator": "Exists",
            "effect": "NoSchedule"
          }
        ]
      }
    }
  }
}'

print_success "Patch uygulandı"

echo ""
print_info "Rollout bekleniyor..."
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout=90s

echo ""
print_info "Pod'un hazır olması bekleniyor..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo ""
print_success "İşlem tamamlandı!"
echo ""
print_info "Yeni durum:"
kubectl get pods -n ingress-nginx -o wide

echo ""
echo "Şimdi test edebilirsiniz:"
echo "  curl http://api.local/api/datetime"
echo "  curl http://web.local"