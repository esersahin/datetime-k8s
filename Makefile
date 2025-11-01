.PHONY: help setup build-api build-web build-all load-images create-cluster \
        install-ingress fix-ingress fix-webhooks deploy-k8s deploy verify clean \
        clean-cluster clean-all logs logs-api logs-web test status show-nodes \
        scale-api scale-web restart-api restart-web redeploy quick-update update-hosts

# Renkler
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Değişkenler
API_IMAGE := datetime-api-csharp:latest
WEB_IMAGE := datetime-web-csharp:latest
API_GO_IMAGE := datetime-api-go:latest
WEB_GO_IMAGE := datetime-web-go:latest
CLUSTER_NAME := kind
NAMESPACE := default

help: ## Tüm komutları gösterir
	@echo "$(BLUE)DateTime Kubernetes Makefile$(NC)"
	@echo "=============================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Hızlı Başlangıç:$(NC)"
	@echo "  make deploy        # Tüm sistemi deploy et"
	@echo "  make verify        # Sistemi doğrula"
	@echo "  make logs-api      # API loglarını izle"
	@echo "  make clean-all     # Her şeyi temizle"

setup: ## Proje dizin yapısını kontrol eder ve gerekirse oluşturur
	@echo "$(YELLOW)📁 Proje dizin yapısı kontrol ediliyor...$(NC)"
	@mkdir -p api-csharp web-csharp k8s
	@echo "$(GREEN)✓ Dizinler hazır$(NC)"
	@echo ""
	@echo "$(BLUE)Dosya yerleşimi kontrolü:$(NC)"
	@echo ""
	@if [ ! -d "api-csharp" ] || [ -z "$$(ls -A api-csharp 2>/dev/null)" ]; then \
		echo "$(YELLOW)⚠ api-csharp/ dizini boş - Şu dosyaları ekleyin:$(NC)"; \
		echo "  - Program.cs"; \
		echo "  - DateTimeApi.csproj"; \
		echo "  - Dockerfile.api"; \
	else \
		echo "$(GREEN)✓ api-csharp/ dizini dolu$(NC)"; \
	fi
	@if [ ! -d "web-csharp" ] || [ -z "$$(ls -A web-csharp 2>/dev/null)" ]; then \
		echo "$(YELLOW)⚠ web-csharp/ dizini boş - Şu dosyaları ekleyin:$(NC)"; \
		echo "  - index.html"; \
		echo "  - nginx.conf"; \
		echo "  - Dockerfile.web"; \
	else \
		echo "$(GREEN)✓ web-csharp/ dizini dolu$(NC)"; \
	fi
	@if [ ! -d "k8s" ] || [ -z "$$(ls -A k8s 2>/dev/null)" ]; then \
		echo "$(YELLOW)⚠ k8s/ dizini boş - Şu dosyaları ekleyin:$(NC)"; \
		echo "  - api-csharp-deployment.yaml"; \
		echo "  - web-csharp-deployment.yaml"; \
		echo "  - ingress.yaml"; \
	else \
		echo "$(GREEN)✓ k8s/ dizini dolu$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)Hazır olduğunuzda 'make deploy' komutunu çalıştırın!$(NC)"

build-api: ## API Docker imajını build eder
	@echo "$(YELLOW)🔨 API imajı build ediliyor...$(NC)"
	@cd api-csharp && docker build -t $(API_IMAGE) -f Dockerfile.api .
	@echo "$(GREEN)✓ API imajı oluşturuldu$(NC)"

build-web: ## Web Docker imajını build eder
	@echo "$(YELLOW)🔨 Web imajı build ediliyor...$(NC)"
	@cd web-csharp && docker build -t $(WEB_IMAGE) -f Dockerfile.web .
	@echo "$(GREEN)✓ Web imajı oluşturuldu$(NC)"

build-api-go: ## API-Go Docker imajını build eder
	@echo "$(YELLOW)🔨 API-Go imajı build ediliyor...$(NC)"
	@cd api-go && docker build -t $(API_GO_IMAGE) .
	@echo "$(GREEN)✓ API-Go imajı oluşturuldu$(NC)"

build-web-go: ## Web-Go Docker imajını build eder
	@echo "$(YELLOW)🔨 Web-Go imajı build ediliyor...$(NC)"
	@cd web-go && docker build -t $(WEB_GO_IMAGE) .
	@echo "$(GREEN)✓ Web-Go imajı oluşturuldu$(NC)"

build-all: build-api build-web build-api-go build-web-go ## Tüm Docker imajlarını build eder
	@echo "$(GREEN)✓ Tüm imajlar oluşturuldu$(NC)"

load-images: build-all ## İmajları Kind cluster'a yükler
	@echo "$(YELLOW)📦 İmajlar Kind cluster'a yükleniyor...$(NC)"
	@kind load docker-image $(API_IMAGE) --name $(CLUSTER_NAME)
	@kind load docker-image $(WEB_IMAGE) --name $(CLUSTER_NAME)
	@kind load docker-image $(API_GO_IMAGE) --name $(CLUSTER_NAME)
	@kind load docker-image $(WEB_GO_IMAGE) --name $(CLUSTER_NAME)
	@echo "$(GREEN)✓ İmajlar yüklendi$(NC)"

create-cluster: ## Kind cluster oluşturur (multi-node: 3 control-planes + 3 workers HA setup)
	@echo "$(YELLOW)🚀 Kind cluster kontrol ediliyor...$(NC)"
	@if ! kind get clusters | grep -q "$(CLUSTER_NAME)"; then \
		echo "$(YELLOW)Kind cluster oluşturuluyor (3 control-planes + 3 workers - HA setup)...$(NC)"; \
		if [ ! -f "k8s/kind-config.yaml" ]; then \
			echo "$(RED)❌ HATA: k8s/kind-config.yaml bulunamadı!$(NC)"; \
			echo "$(YELLOW)Bu dosya worker node yapılandırması için gereklidir.$(NC)"; \
			exit 1; \
		else \
			echo "$(GREEN)✓ k8s/kind-config.yaml mevcut, kullanılıyor$(NC)"; \
		fi; \
		kind create cluster --config=k8s/kind-config.yaml; \
		echo "$(GREEN)✓ Multi-node Kind cluster oluşturuldu$(NC)"; \
		echo ""; \
		echo "$(BLUE)Cluster Node'ları:$(NC)"; \
		kubectl get nodes -o wide; \
	else \
		echo "$(GREEN)✓ Kind cluster zaten mevcut$(NC)"; \
		echo "$(BLUE)Mevcut node'lar:$(NC)"; \
		kubectl get nodes; \
	fi

install-ingress: create-cluster ## NGINX Ingress Controller kurar (Kind optimized)
	@echo "$(YELLOW)📥 NGINX Ingress Controller kontrol ediliyor...$(NC)"
	@if ! kubectl get namespace ingress-nginx &> /dev/null; then \
		echo "$(YELLOW)NGINX Ingress Controller kuruluyor (Kind için optimize edilmiş)...$(NC)"; \
		if [ -f "k8s/ingress-nginx-deployment.yaml" ]; then \
			echo "$(YELLOW)Özel ingress-nginx-deployment.yaml kullanılıyor...$(NC)"; \
			kubectl apply -f k8s/ingress-nginx-deployment.yaml; \
		else \
			echo "$(YELLOW)Kind'ın varsayılan manifest'i kullanılıyor...$(NC)"; \
			kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml; \
		fi; \
		sleep 10; \
		kubectl wait --namespace ingress-nginx \
			--for=condition=ready pod \
			--selector=app.kubernetes.io/component=controller \
			--timeout=180s 2>/dev/null || true; \
		echo "$(GREEN)✓ NGINX Ingress Controller kuruldu$(NC)"; \
	else \
		echo "$(GREEN)✓ NGINX Ingress Controller zaten mevcut$(NC)"; \
	fi

fix-ingress: ## Ingress hostNetwork ayarını düzeltir (Mac için)
	@echo "$(YELLOW)🔧 Ingress yapılandırması kontrol ediliyor...$(NC)"
	@if kubectl get deployment -n ingress-nginx ingress-nginx-controller &> /dev/null; then \
		CURRENT_HOST_NETWORK=$(kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.template.spec.hostNetwork}'); \
		if [ "$CURRENT_HOST_NETWORK" != "true" ]; then \
			echo "$(YELLOW)hostNetwork ayarı düzeltiliyor...$(NC)"; \
			kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
				-p '{"spec":{"template":{"spec":{"hostNetwork":true}}}}'; \
			kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout=180s; \
			kubectl wait --namespace ingress-nginx \
				--for=condition=ready pod \
				--selector=app.kubernetes.io/component=controller \
				--timeout=180s 2>/dev/null || true; \
			echo "$(GREEN)✓ hostNetwork ayarı düzeltildi$(NC)"; \
		else \
			echo "$(GREEN)✓ hostNetwork ayarı zaten doğru$(NC)"; \
		fi; \
		echo ""; \
		echo "$(BLUE)Ingress Controller Durumu:$(NC)"; \
		kubectl get pods -n ingress-nginx -o wide; \
	fi

fix-webhooks: ## Problematic admission webhooks'u temizler (Mac için)
	@echo "$(YELLOW)🧹 Admission webhook'ları temizleniyor...$(NC)"
	@kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission 2>/dev/null || true
	@kubectl delete jobs -n ingress-nginx ingress-nginx-admission-create ingress-nginx-admission-patch 2>/dev/null || true
	@echo "$(GREEN)✓ Webhook'lar temizlendi$(NC)"

deploy-k8s: ## Kubernetes kaynaklarını deploy eder
	@echo "$(YELLOW)📦 Kubernetes kaynakları uygulanıyor...$(NC)"
	@kubectl apply -f k8s/api-csharp-deployment.yaml
	@echo "$(GREEN)✓ API deployment uygulandı$(NC)"
	@kubectl apply -f k8s/web-csharp-deployment.yaml
	@echo "$(GREEN)✓ Web deployment uygulandı$(NC)"
	@kubectl apply -f k8s/api-go-deployment.yaml 2>/dev/null && echo "$(GREEN)✓ API-Go deployment uygulandı$(NC)" || true
	@kubectl apply -f k8s/web-go-deployment.yaml 2>/dev/null && echo "$(GREEN)✓ Web-Go deployment uygulandı$(NC)" || true
	@kubectl apply -f k8s/ingress.yaml
	@echo "$(GREEN)✓ Ingress uygulandı$(NC)"
	@echo ""
	@echo "$(YELLOW)⏳ Deployment'ların hazır olması bekleniyor...$(NC)"
	@kubectl wait --for=condition=available --timeout=120s deployment/datetime-api-csharp 2>/dev/null || true
	@kubectl wait --for=condition=available --timeout=120s deployment/datetime-web-csharp 2>/dev/null || true
	@kubectl wait --for=condition=available --timeout=120s deployment/datetime-api-go 2>/dev/null || true
	@kubectl wait --for=condition=available --timeout=120s deployment/datetime-web-go 2>/dev/null || true
	@echo "$(GREEN)✓ Tüm deployment'lar hazır$(NC)"

update-hosts: ## /etc/hosts dosyasını günceller
	@echo "$(YELLOW)📝 /etc/hosts dosyası güncelleniyor...$(NC)"
	@if ! grep -q "api-csharp.local" /etc/hosts; then \
		echo "127.0.0.1 api-csharp.local web-csharp.local api-go.local web-go.local" | sudo tee -a /etc/hosts > /dev/null; \
		echo "::1 api-csharp.local web-csharp.local api-go.local web-go.local" | sudo tee -a /etc/hosts > /dev/null; \
		echo "$(GREEN)✓ /etc/hosts güncellendi (IPv4 ve IPv6)$(NC)"; \
	else \
		if ! grep -q "api-go.local" /etc/hosts; then \
			sudo sed -i '' 's/api-csharp.local web-csharp.local/api-csharp.local web-csharp.local api-go.local web-go.local/' /etc/hosts; \
			echo "$(GREEN)✓ /etc/hosts güncellendi (api-go.local ve web-go.local eklendi)$(NC)"; \
		fi; \
		if ! grep -q "::1.*api-csharp.local" /etc/hosts; then \
			echo "::1 api-csharp.local web-csharp.local api-go.local web-go.local" | sudo tee -a /etc/hosts > /dev/null; \
			echo "$(GREEN)✓ IPv6 entries eklendi (5 saniye gecikme düzeltildi!)$(NC)"; \
		else \
			echo "$(GREEN)✓ /etc/hosts zaten güncel$(NC)"; \
		fi \
	fi

deploy: ## Tüm deployment sürecini çalıştırır (ANA KOMUT)
	@echo "$(BLUE)⏱️  Deployment başlatılıyor...$(NC)"
	@START_TIME=$$(date +%s); \
	$(MAKE) create-cluster install-ingress fix-ingress fix-webhooks load-images deploy-k8s install-haproxy update-hosts; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	MINUTES=$$((DURATION / 60)); \
	SECONDS=$$((DURATION % 60)); \
	echo ""; \
	echo "$(GREEN)======================================$(NC)"; \
	echo "$(GREEN)🎉 Deployment tamamlandı! 🎉$(NC)"; \
	echo "$(GREEN)======================================$(NC)"; \
	echo ""; \
	echo "$(YELLOW)⏱️  Toplam Süre: $${MINUTES} dakika $${SECONDS} saniye$(NC)"; \
	echo ""; \
	echo "$(BLUE)📊 Durum Bilgisi:$(NC)"; \
	kubectl get pods -o wide; \
	echo ""; \
	kubectl get services; \
	echo ""; \
	kubectl get ingress; \
	echo ""; \
	echo "$(GREEN)======================================$(NC)"; \
	echo "$(BLUE)🌐 Uygulamaya Erişim:$(NC)"; \
	echo "$(GREEN)======================================$(NC)"; \
	echo "  $(YELLOW)C# Uygulamaları:$(NC)"; \
	echo "    Web: http://web-csharp.local"; \
	echo "    API: http://api-csharp.local/api/datetime"; \
	echo ""; \
	echo "  $(YELLOW)Go Uygulamaları:$(NC)"; \
	echo "    Web-Go: http://web-go.local"; \
	echo "    API-Go: http://api-go.local/health"; \
	echo ""

verify: ## Deployment'ı doğrular ve test eder
	@echo "$(BLUE)🔍 Deployment Doğrulama$(NC)"
	@echo "========================"
	@echo ""
	@PASS=0; FAIL=0; \
	echo "$(BLUE)1. Kind Cluster$(NC)"; \
	if kind get clusters | grep -q "$(CLUSTER_NAME)"; then \
		echo "$(GREEN)✓ Kind cluster mevcut$(NC)"; \
		PASS=$$((PASS + 1)); \
	else \
		echo "$(RED)✗ Kind cluster mevcut değil$(NC)"; \
		FAIL=$$((FAIL + 1)); \
	fi; \
	echo ""; \
	echo "$(BLUE)2. NGINX Ingress Controller$(NC)"; \
	if kubectl get namespace ingress-nginx &> /dev/null; then \
		echo "$(GREEN)✓ Ingress namespace mevcut$(NC)"; \
		PASS=$$((PASS + 1)); \
	else \
		echo "$(RED)✗ Ingress namespace mevcut değil$(NC)"; \
		FAIL=$$((FAIL + 1)); \
	fi; \
	HOST_NETWORK=$$(kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.template.spec.hostNetwork}' 2>/dev/null); \
	if [ "$$HOST_NETWORK" = "true" ]; then \
		echo "$(GREEN)✓ hostNetwork: true (Doğru)$(NC)"; \
		PASS=$$((PASS + 1)); \
	else \
		echo "$(YELLOW)⚠ hostNetwork: $$HOST_NETWORK (Mac için 'true' olmalı)$(NC)"; \
		FAIL=$$((FAIL + 1)); \
	fi; \
	if kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission &> /dev/null; then \
		echo "$(YELLOW)⚠ ValidatingWebhook mevcut (Mac/Kind'da sorun çıkarabilir)$(NC)"; \
		FAIL=$$((FAIL + 1)); \
	else \
		echo "$(GREEN)✓ ValidatingWebhook yok (İdeal)$(NC)"; \
		PASS=$$((PASS + 1)); \
	fi; \
	echo ""; \
	echo "$(BLUE)3. Deployments$(NC)"; \
	if kubectl get deployment datetime-api-csharp &> /dev/null; then \
		echo "$(GREEN)✓ API deployment mevcut$(NC)"; \
		PASS=$$((PASS + 1)); \
	else \
		echo "$(RED)✗ API deployment mevcut değil$(NC)"; \
		FAIL=$$((FAIL + 1)); \
	fi; \
	if kubectl get deployment datetime-web-csharp &> /dev/null; then \
		echo "$(GREEN)✓ Web deployment mevcut$(NC)"; \
		PASS=$$((PASS + 1)); \
	else \
		echo "$(RED)✗ Web deployment mevcut değil$(NC)"; \
		FAIL=$$((FAIL + 1)); \
	fi; \
	echo ""; \
	echo "$(BLUE)4. Endpoint Testleri$(NC)"; \
	if curl -s -f http://api-csharp.local/health &> /dev/null; then \
		echo "$(GREEN)✓ API health endpoint erişilebilir$(NC)"; \
		PASS=$$((PASS + 1)); \
	else \
		echo "$(RED)✗ API health endpoint erişilemiyor$(NC)"; \
		FAIL=$$((FAIL + 1)); \
	fi; \
	if curl -s -f http://api-csharp.local/api/datetime &> /dev/null; then \
		echo "$(GREEN)✓ API datetime endpoint erişilebilir$(NC)"; \
		PASS=$$((PASS + 1)); \
	else \
		echo "$(RED)✗ API datetime endpoint erişilemiyor$(NC)"; \
		FAIL=$$((FAIL + 1)); \
	fi; \
	if curl -s -f http://web-csharp.local &> /dev/null; then \
		echo "$(GREEN)✓ Web uygulaması erişilebilir$(NC)"; \
		PASS=$$((PASS + 1)); \
	else \
		echo "$(RED)✗ Web uygulaması erişilemiyor$(NC)"; \
		FAIL=$$((FAIL + 1)); \
	fi; \
	echo ""; \
	TOTAL=$$((PASS + FAIL)); \
	PERCENTAGE=$$((PASS * 100 / TOTAL)); \
	echo "$(BLUE)ÖZET$(NC)"; \
	echo "Toplam: $$TOTAL | $(GREEN)Başarılı: $$PASS$(NC) | $(RED)Başarısız: $$FAIL$(NC) | Oran: $$PERCENTAGE%"; \
	if [ $$FAIL -eq 0 ]; then \
		echo ""; \
		echo "$(GREEN)🎉 TÜM TESTLER BAŞARILI! 🎉$(NC)"; \
	fi

logs: ## Tüm pod loglarını gösterir
	@echo "$(YELLOW)API Logs:$(NC)"
	@kubectl logs -l app=datetime-api-csharp --tail=50 --prefix
	@echo ""
	@echo "$(YELLOW)Web Logs:$(NC)"
	@kubectl logs -l app=datetime-web-csharp --tail=50 --prefix

logs-api: ## API loglarını takip eder
	@echo "$(YELLOW)📋 API logları izleniyor... (Ctrl+C ile çıkış)$(NC)"
	@kubectl logs -l app=datetime-api-csharp -f

logs-web: ## Web loglarını takip eder
	@echo "$(YELLOW)📋 Web logları izleniyor... (Ctrl+C ile çıkış)$(NC)"
	@kubectl logs -l app=datetime-web-csharp -f

test: ## API ve Web endpoint'lerini test eder
	@echo "$(BLUE)🧪 Endpoint Testleri$(NC)"
	@echo "===================="
	@echo ""
	@echo "$(YELLOW)C# Uygulamaları:$(NC)"
	@echo "----------------"
	@echo "$(YELLOW)C# API Health:$(NC)"
	@curl -s http://api-csharp.local/health | jq . 2>/dev/null || curl -s http://api-csharp.local/health
	@echo ""
	@echo "$(YELLOW)C# API DateTime:$(NC)"
	@curl -s http://api-csharp.local/api/datetime | jq . 2>/dev/null || curl -s http://api-csharp.local/api/datetime
	@echo ""
	@echo "$(YELLOW)C# Web (ilk 200 karakter):$(NC)"
	@curl -s http://web-csharp.local | head -c 200
	@echo "..."
	@echo ""
	@echo "$(YELLOW)Go Uygulamaları:$(NC)"
	@echo "----------------"
	@echo "$(YELLOW)Go API Health:$(NC)"
	@curl -s http://api-go.local/health | jq . 2>/dev/null || curl -s http://api-go.local/health
	@echo ""
	@echo "$(YELLOW)Go Web (ilk 200 karakter):$(NC)"
	@curl -s http://web-go.local | head -c 200
	@echo "..."

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

show-nodes: ## Cluster node'larını detaylı gösterir
	@echo "$(BLUE)📊 Cluster Node'ları$(NC)"
	@echo "===================="
	@kubectl get nodes -o wide
	@echo ""
	@echo "$(BLUE)Node Detayları:$(NC)"
	@echo ""
	@for node in $(kubectl get nodes -o name); do \
		echo "$(YELLOW)$node:$(NC)"; \
		kubectl describe $node | grep -E "Name:|Labels:|Taints:|Conditions:" | head -20; \
		echo ""; \
	done

scale-api: ## API replica sayısını artırır (make scale-api REPLICAS=3)
	@REPLICAS=$${REPLICAS:-3}; \
	echo "$(YELLOW)📈 API $$REPLICAS replica'ya ölçeklendiriliyor...$(NC)"; \
	kubectl scale deployment datetime-api-csharp --replicas=$$REPLICAS; \
	echo "$(GREEN)✓ API ölçeklendirildi$(NC)"

scale-web: ## Web replica sayısını artırır (make scale-web REPLICAS=3)
	@REPLICAS=$${REPLICAS:-3}; \
	echo "$(YELLOW)📈 Web $$REPLICAS replica'ya ölçeklendiriliyor...$(NC)"; \
	kubectl scale deployment datetime-web-csharp --replicas=$$REPLICAS; \
	echo "$(GREEN)✓ Web ölçeklendirildi$(NC)"

restart-api: ## API deployment'ını yeniden başlatır
	@echo "$(YELLOW)🔄 API yeniden başlatılıyor...$(NC)"
	@kubectl rollout restart deployment datetime-api-csharp
	@echo "$(GREEN)✓ API yeniden başlatıldı$(NC)"

restart-web: ## Web deployment'ını yeniden başlatır
	@echo "$(YELLOW)🔄 Web yeniden başlatılıyor...$(NC)"
	@kubectl rollout restart deployment datetime-web-csharp
	@echo "$(GREEN)✓ Web yeniden başlatıldı$(NC)"

clean: ## Kubernetes kaynaklarını siler (cluster'ı silmez)
	@echo "$(YELLOW)🧹 Kubernetes kaynakları temizleniyor...$(NC)"
	@kubectl delete -f k8s/ingress.yaml 2>/dev/null || true
	@kubectl delete -f k8s/web-csharp-deployment.yaml 2>/dev/null || true
	@kubectl delete -f k8s/api-csharp-deployment.yaml 2>/dev/null || true
	@echo "$(GREEN)✓ Kubernetes kaynakları temizlendi$(NC)"

clean-cluster: ## Kind cluster'ı siler
	@echo "$(YELLOW)🗑️  Kind cluster siliniyor...$(NC)"
	@kind delete cluster --name $(CLUSTER_NAME)
	@echo "$(GREEN)✓ Cluster silindi$(NC)"

clean-all: clean clean-cluster remove-haproxy ## Her şeyi temizler (cluster + kaynaklar + HAProxy)
	@echo "$(GREEN)✓ Tüm kaynaklar temizlendi$(NC)"
	@echo ""
	@echo "$(YELLOW)⚠️  /etc/hosts dosyasını manuel temizlemeyi unutmayın:$(NC)"
	@echo "  sudo nano /etc/hosts"
	@echo "  # api-csharp.local ve web-csharp.local satırlarını silin"

redeploy: clean-all deploy ## Tam yeniden deployment (clean + deploy)

quick-update: build-all load-images ## Sadece imajları günceller (cluster'ı değiştirmez)
	@echo "$(YELLOW)🔄 Deployment'lar yeniden başlatılıyor...$(NC)"
	@kubectl rollout restart deployment datetime-api-csharp
	@kubectl rollout restart deployment datetime-web-csharp
	@kubectl rollout restart deployment datetime-api-go 2>/dev/null || true
	@kubectl rollout restart deployment datetime-web-go 2>/dev/null || true
	@kubectl rollout status deployment datetime-api-csharp
	@kubectl rollout status deployment datetime-web-csharp
	@kubectl rollout status deployment datetime-api-go 2>/dev/null || true
	@kubectl rollout status deployment datetime-web-go 2>/dev/null || true
	@echo "$(GREEN)✓ Güncelleme tamamlandı$(NC)"
install-haproxy: ## HAProxy load balancer kurar (Port 80 için HA)
	@echo "$(YELLOW)⚖️  HAProxy load balancer kontrol ediliyor...$(NC)"
	@if docker ps --format '{{.Names}}' | grep -q "^kind-http-lb$$"; then \
		echo "$(GREEN)✓ HAProxy zaten çalışıyor$(NC)"; \
	else \
		echo "$(YELLOW)HAProxy load balancer başlatılıyor...$(NC)"; \
		if [ ! -f "k8s/haproxy-lb.cfg" ]; then \
			echo "$(RED)❌ HATA: k8s/haproxy-lb.cfg bulunamadı!$(NC)"; \
			exit 1; \
		fi; \
		docker run -d \
			--name kind-http-lb \
			--network kind \
			-p 80:80 \
			-p 443:443 \
			-p 8404:8404 \
			-v $(PWD)/k8s/haproxy-lb.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
			haproxy:2.8-alpine > /dev/null 2>&1; \
		sleep 2; \
		echo "$(GREEN)✓ HAProxy load balancer başlatıldı$(NC)"; \
		echo ""; \
		echo "$(BLUE)HAProxy Bilgisi:$(NC)"; \
		echo "  Port 80  : HTTP Traffic (HA Load Balancing)"; \
		echo "  Port 443 : HTTPS Traffic (HA Load Balancing)"; \
		echo "  Port 8404: HAProxy Stats (http://localhost:8404)"; \
	fi

remove-haproxy: ## HAProxy load balancer'ı kaldırır
	@echo "$(YELLOW)🗑️  HAProxy load balancer kaldırılıyor...$(NC)"
	@docker rm -f kind-http-lb 2>/dev/null || true
	@echo "$(GREEN)✓ HAProxy kaldırıldı$(NC)"
