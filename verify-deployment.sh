#!/bin/bash

echo "🔍 Deployment Doğrulama Script'i"
echo "=================================="

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
        ((PASS++))
    else
        echo -e "${RED}✗ $1${NC}"
        ((FAIL++))
    fi
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 1. Kind Cluster
print_header "1. Kind Cluster Kontrolü"
kind get clusters | grep -q "kind"
check "Kind cluster mevcut"

# 2. Kubectl bağlantısı
kubectl cluster-info &> /dev/null
check "Kubectl cluster'a bağlı"

# 3. NGINX Ingress Controller
print_header "2. NGINX Ingress Controller"
kubectl get namespace ingress-nginx &> /dev/null
check "Ingress namespace mevcut"

kubectl get deployment -n ingress-nginx ingress-nginx-controller &> /dev/null
check "Ingress controller deployment mevcut"

# Webhook kontrolü
if kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission &> /dev/null; then
    echo -e "${YELLOW}⚠ ValidatingWebhook mevcut (Mac/Kind'da sorun çıkarabilir)${NC}"
    echo -e "${YELLOW}  Silmek için: ./fix-webhooks.sh${NC}"
    ((FAIL++))
else
    echo -e "${GREEN}✓ ValidatingWebhook yok (Mac/Kind için ideal)${NC}"
    ((PASS++))
fi

INGRESS_READY=$(kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.readyReplicas}')
if [ "$INGRESS_READY" -ge 1 ]; then
    echo -e "${GREEN}✓ Ingress controller hazır ($INGRESS_READY replicas)${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ Ingress controller hazır değil${NC}"
    ((FAIL++))
fi

# hostNetwork kontrolü
HOST_NETWORK=$(kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.template.spec.hostNetwork}')
if [ "$HOST_NETWORK" == "true" ]; then
    echo -e "${GREEN}✓ hostNetwork: true (Doğru)${NC}"
    ((PASS++))
else
    echo -e "${YELLOW}⚠ hostNetwork: $HOST_NETWORK (Mac için 'true' olmalı!)${NC}"
    echo -e "${YELLOW}  Düzeltmek için: ./fix-ingress.sh${NC}"
    ((FAIL++))
fi

# 4. API Deployment
print_header "3. DateTime API Kontrolü"
kubectl get deployment datetime-api &> /dev/null
check "API deployment mevcut"

API_READY=$(kubectl get deployment datetime-api -o jsonpath='{.status.readyReplicas}')
API_DESIRED=$(kubectl get deployment datetime-api -o jsonpath='{.spec.replicas}')
if [ "$API_READY" -eq "$API_DESIRED" ]; then
    echo -e "${GREEN}✓ API pod'ları hazır ($API_READY/$API_DESIRED)${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ API pod'ları hazır değil ($API_READY/$API_DESIRED)${NC}"
    ((FAIL++))
fi

kubectl get service datetime-api-service &> /dev/null
check "API service mevcut"

# 5. Web Deployment
print_header "4. DateTime Web Kontrolü"
kubectl get deployment datetime-web &> /dev/null
check "Web deployment mevcut"

WEB_READY=$(kubectl get deployment datetime-web -o jsonpath='{.status.readyReplicas}')
WEB_DESIRED=$(kubectl get deployment datetime-web -o jsonpath='{.spec.replicas}')
if [ "$WEB_READY" -eq "$WEB_DESIRED" ]; then
    echo -e "${GREEN}✓ Web pod'ları hazır ($WEB_READY/$WEB_DESIRED)${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ Web pod'ları hazır değil ($WEB_READY/$WEB_DESIRED)${NC}"
    ((FAIL++))
fi

kubectl get service datetime-web-service &> /dev/null
check "Web service mevcut"

# 6. Ingress
print_header "5. Ingress Kontrolü"
kubectl get ingress datetime-ingress &> /dev/null
check "Ingress mevcut"

# 7. /etc/hosts
print_header "6. DNS Yapılandırması"
if grep -q "api.local" /etc/hosts && grep -q "web.local" /etc/hosts; then
    echo -e "${GREEN}✓ /etc/hosts yapılandırılmış${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ /etc/hosts yapılandırılmamış${NC}"
    echo -e "${YELLOW}  Eklemek için: echo '127.0.0.1 api.local web.local' | sudo tee -a /etc/hosts${NC}"
    ((FAIL++))
fi

# 8. API Endpoint Test
print_header "7. Endpoint Testleri"
if curl -s -f http://api.local/health &> /dev/null; then
    echo -e "${GREEN}✓ API health endpoint erişilebilir${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ API health endpoint erişilemiyor${NC}"
    ((FAIL++))
fi

if curl -s -f http://api.local/api/datetime &> /dev/null; then
    echo -e "${GREEN}✓ API datetime endpoint erişilebilir${NC}"
    ((PASS++))
    
    # JSON response test
    RESPONSE=$(curl -s http://api.local/api/datetime)
    if echo "$RESPONSE" | grep -q "date" && echo "$RESPONSE" | grep -q "time"; then
        echo -e "${GREEN}✓ API valid JSON dönüyor${NC}"
        ((PASS++))
    else
        echo -e "${RED}✗ API invalid JSON dönüyor${NC}"
        ((FAIL++))
    fi
else
    echo -e "${RED}✗ API datetime endpoint erişilemiyor${NC}"
    ((FAIL++))
fi

if curl -s -f http://web.local &> /dev/null; then
    echo -e "${GREEN}✓ Web uygulaması erişilebilir${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ Web uygulaması erişilemiyor${NC}"
    ((FAIL++))
fi

# Özet
print_header "ÖZET"
TOTAL=$((PASS + FAIL))
PERCENTAGE=$((PASS * 100 / TOTAL))

echo ""
echo -e "Toplam Test: $TOTAL"
echo -e "${GREEN}Başarılı: $PASS${NC}"
echo -e "${RED}Başarısız: $FAIL${NC}"
echo -e "Başarı Oranı: ${PERCENTAGE}%"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🎉 TÜM TESTLER BAŞARILI! 🎉${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Uygulamaya erişim:"
    echo "  🌐 Web: http://web.local"
    echo "  🔌 API: http://api.local/api/datetime"
else
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠  BAZI TESTLER BAŞARISIZ  ⚠${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Sorun giderme için:"
    echo "  📋 kubectl get pods --all-namespaces"
    echo "  📋 kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller"
    echo "  🔧 ./fix-ingress.sh"
fi

echo ""
exit $FAIL