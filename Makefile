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
API_IMAGE := datetime-api:latest
WEB_IMAGE := datetime-web:latest
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
	@mkdir -p api web k8s
	@echo "$(GREEN)✓ Dizinler hazır$(NC)"
	@echo ""
	@echo "$(BLUE)Dosya yerleşimi kontrolü:$(NC)"
	@echo ""
	@if [ ! -d "api" ] || [ -z "$(ls -A api 2>/dev/null)" ]; then \
		echo "$(YELLOW)⚠ api/ dizini boş - Şu dosyaları ekleyin:$(NC)"; \
		echo "  - Program.cs"; \
		echo "  - DateTimeApi.csproj"; \
		echo "  - Dockerfile.api"; \
	else \
		echo "$(GREEN)✓ api/ dizini dolu$(NC)"; \
	fi
	@if [ ! -d "web" ] || [ -z "$(ls -A web 2>/dev/null)" ]; then \
		echo "$(YELLOW)⚠ web/ dizini boş - Şu dosyaları ekleyin:$(NC)"; \
		echo "  - index.html"; \
		echo "  - nginx.conf"; \
		echo "  - Dockerfile.web"; \
	else \
		echo "$(GREEN)✓ web/ dizini dolu$(NC)"; \
	fi
	@if [ ! -d "k8s" ] || [ -z "$(ls -A k8s 2>/dev/null)" ]; then \
		echo "$(YELLOW)⚠ k8s/ dizini boş - Şu dosyaları ekleyin:$(NC)"; \
		echo "  - api-deployment.yaml"; \
		echo "  - web-deployment.yaml"; \
		echo "  - ingress.yaml"; \
	else \
		echo "$(GREEN)✓ k8s/ dizini dolu$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)Hazır olduğunuzda 'make deploy' komutunu çalıştırın!$(NC)"

build-api: ## API Docker imajını build eder
	@echo "$(YELLOW)🔨 API imajı build ediliyor...$(NC)"
	@cd api && docker build -t $(API_IMAGE) -f Dockerfile.api .
	@echo "$(GREEN)✓ API imajı oluşturuldu$(NC)"

build-web: ## Web Docker imajını build eder
	@echo "$(YELLOW)🔨 Web imajı build ediliyor...$(NC)"
	@cd web && docker build -t $(WEB_IMAGE) -f Dockerfile.web .
	@echo "$(GREEN)✓ Web imajı oluşturuldu$(NC)"

build-all: build-api build-web ## Tüm Docker imajlarını build eder
	@echo "$(GREEN)✓ Tüm imajlar oluşturuldu$(NC)"

load-images: build-all ## İmajları Kind cluster'a yükler
	@echo "$(YELLOW)📦 İmajlar Kind cluster'a yükleniyor...$(NC)"
	@kind load docker-image $(API_IMAGE) --name $(CLUSTER_NAME)
	@kind load docker-image $(WEB_IMAGE) --name $(CLUSTER_NAME)
	@echo "$(GREEN)✓ İmajlar yüklendi$(NC)"

create-cluster: ## Kind cluster oluşturur (multi-node: 1 control-plane + 2 workers)
	@echo "$(YELLOW)🚀 Kind cluster kontrol ediliyor...$(NC)"
	@if ! kind get clusters | grep -q "$(CLUSTER_NAME)"; then \
		echo "$(YELLOW)Kind cluster oluşturuluyor (1 control-plane + 2 workers)...$(NC)"; \
		if [ ! -f "kind-config.yaml" ]; then \
			echo "$(YELLOW)kind-config.yaml bulunamadı, oluşturuluyor...$(NC)"; \
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
		sleep 5; \
		kubectl wait --namespace ingress-nginx \
			--for=condition=ready pod \
			--selector=app.kubernetes.io/component=controller \
			--timeout=90s 2>/dev/null || true; \
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
			kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout=90s; \
			kubectl wait --namespace ingress-nginx \
				--for=condition=ready pod \
				--selector=app.kubernetes.io/component=controller \
				--timeout=90s 2>/dev/null || true; \
			echo "$(GREEN)✓ hostNetwork ayarı düzeltildi$(NC)"; \
		else \
			echo "$(GREEN)✓ hostNetwork ayarı zaten doğru$(NC)"; \
		fi; \
		echo "$(YELLOW)🔧 Ingress Controller control-plane kontrolü yapılıyor...$(NC)"; \
		CURRENT_NODE=$$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].spec.nodeName}'); \
		if [ "$$CURRENT_NODE" != "kind-control-plane" ]; then \
			echo "$(YELLOW)Ingress Controller $$CURRENT_NODE'da, control-plane'e taşınıyor...$(NC)"; \
			kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"}}}}}'; \
			kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout=90s; \
			kubectl wait --namespace ingress-nginx \
				--for=condition=ready pod \
				--selector=app.kubernetes.io/component=controller \
				--timeout=90s 2>/dev/null || true; \
			echo "$(GREEN)✓ Ingress Controller control-plane'e taşındı$(NC)"; \
		else \
			echo "$(GREEN)✓ Ingress Controller zaten control-plane'de$(NC)"; \
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
	@kubectl apply -f k8s/api-deployment.yaml
	@echo "$(GREEN)✓ API deployment uygulandı$(NC)"
	@kubectl apply -f k8s/web-deployment.yaml
	@echo "$(GREEN)✓ Web deployment uygulandı$(NC)"
	@kubectl apply -f k8s/ingress.yaml
	@echo "$(GREEN)✓ Ingress uygulandı$(NC)"
	@echo ""
	@echo "$(YELLOW)⏳ Deployment'ların hazır olması bekleniyor...$(NC)"
	@kubectl wait --for=condition=available --timeout=120s deployment/datetime-api 2>/dev/null || true
	@kubectl wait --for=condition=available --timeout=120s deployment/datetime-web 2>/dev/null || true
	@echo "$(GREEN)✓ Tüm deployment'lar hazır$(NC)"

update-hosts: ## /etc/hosts dosyasını günceller
	@echo "$(YELLOW)📝 /etc/hosts dosyası güncelleniyor...$(NC)"
	@if ! grep -q "api.local" /etc/hosts; then \
		echo "127.0.0.1 api.local web.local" | sudo tee -a /etc/hosts > /dev/null; \
		echo "$(GREEN)✓ /etc/hosts güncellendi$(NC)"; \
	else \
		echo "$(GREEN)✓ /etc/hosts zaten güncel$(NC)"; \
	fi

deploy: create-cluster install-ingress fix-ingress fix-webhooks load-images deploy-k8s update-hosts ## Tüm deployment sürecini çalıştırır (ANA KOMUT)
	@echo ""
	@echo "$(GREEN)======================================$(NC)"
	@echo "$(GREEN)🎉 Deployment tamamlandı! 🎉$(NC)"
	@echo "$(GREEN)======================================$(NC)"
	@echo ""
	@echo "$(BLUE)📊 Durum Bilgisi:$(NC)"
	@kubectl get pods -o wide
	@echo ""
	@kubectl get services
	@echo ""
	@kubectl get ingress
	@echo ""
	@echo "$(GREEN)======================================$(NC)"
	@echo "$(BLUE)🌐 Uygulamaya Erişim:$(NC)"
	@echo "$(GREEN)======================================$(NC)"
	@echo "  Web Uygulaması: http://web.local"
	@echo "  API: http://api.local/api/datetime"
	@echo ""

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
	if kubectl get deployment datetime-api &> /dev/null; then \
		echo "$(GREEN)✓ API deployment mevcut$(NC)"; \
		PASS=$$((PASS + 1)); \
	else \
		echo "$(RED)✗ API deployment mevcut değil$(NC)"; \
		FAIL=$$((FAIL + 1)); \
	fi; \
	if kubectl get deployment datetime-web &> /dev/null; then \
		echo "$(GREEN)✓ Web deployment mevcut$(NC)"; \
		PASS=$$((PASS + 1)); \
	else \
		echo "$(RED)✗ Web deployment mevcut değil$(NC)"; \
		FAIL=$$((FAIL + 1)); \
	fi; \
	echo ""; \
	echo "$(BLUE)4. Endpoint Testleri$(NC)"; \
	if curl -s -f http://api.local/health &> /dev/null; then \
		echo "$(GREEN)✓ API health endpoint erişilebilir$(NC)"; \
		PASS=$$((PASS + 1)); \
	else \
		echo "$(RED)✗ API health endpoint erişilemiyor$(NC)"; \
		FAIL=$$((FAIL + 1)); \
	fi; \
	if curl -s -f http://api.local/api/datetime &> /dev/null; then \
		echo "$(GREEN)✓ API datetime endpoint erişilebilir$(NC)"; \
		PASS=$$((PASS + 1)); \
	else \
		echo "$(RED)✗ API datetime endpoint erişilemiyor$(NC)"; \
		FAIL=$$((FAIL + 1)); \
	fi; \
	if curl -s -f http://web.local &> /dev/null; then \
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
	@kubectl logs -l app=datetime-api --tail=50 --prefix
	@echo ""
	@echo "$(YELLOW)Web Logs:$(NC)"
	@kubectl logs -l app=datetime-web --tail=50 --prefix

logs-api: ## API loglarını takip eder
	@echo "$(YELLOW)📋 API logları izleniyor... (Ctrl+C ile çıkış)$(NC)"
	@kubectl logs -l app=datetime-api -f

logs-web: ## Web loglarını takip eder
	@echo "$(YELLOW)📋 Web logları izleniyor... (Ctrl+C ile çıkış)$(NC)"
	@kubectl logs -l app=datetime-web -f

test: ## API ve Web endpoint'lerini test eder
	@echo "$(BLUE)🧪 Endpoint Testleri$(NC)"
	@echo "===================="
	@echo ""
	@echo "$(YELLOW)API Health:$(NC)"
	@curl -s http://api.local/health | jq . 2>/dev/null || curl -s http://api.local/health
	@echo ""
	@echo "$(YELLOW)API DateTime:$(NC)"
	@curl -s http://api.local/api/datetime | jq . 2>/dev/null || curl -s http://api.local/api/datetime
	@echo ""
	@echo "$(YELLOW)Web (ilk 200 karakter):$(NC)"
	@curl -s http://web.local | head -c 200
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
	kubectl scale deployment datetime-api --replicas=$$REPLICAS; \
	echo "$(GREEN)✓ API ölçeklendirildi$(NC)"

scale-web: ## Web replica sayısını artırır (make scale-web REPLICAS=3)
	@REPLICAS=$${REPLICAS:-3}; \
	echo "$(YELLOW)📈 Web $$REPLICAS replica'ya ölçeklendiriliyor...$(NC)"; \
	kubectl scale deployment datetime-web --replicas=$$REPLICAS; \
	echo "$(GREEN)✓ Web ölçeklendirildi$(NC)"

restart-api: ## API deployment'ını yeniden başlatır
	@echo "$(YELLOW)🔄 API yeniden başlatılıyor...$(NC)"
	@kubectl rollout restart deployment datetime-api
	@echo "$(GREEN)✓ API yeniden başlatıldı$(NC)"

restart-web: ## Web deployment'ını yeniden başlatır
	@echo "$(YELLOW)🔄 Web yeniden başlatılıyor...$(NC)"
	@kubectl rollout restart deployment datetime-web
	@echo "$(GREEN)✓ Web yeniden başlatıldı$(NC)"

clean: ## Kubernetes kaynaklarını siler (cluster'ı silmez)
	@echo "$(YELLOW)🧹 Kubernetes kaynakları temizleniyor...$(NC)"
	@kubectl delete -f k8s/ingress.yaml 2>/dev/null || true
	@kubectl delete -f k8s/web-deployment.yaml 2>/dev/null || true
	@kubectl delete -f k8s/api-deployment.yaml 2>/dev/null || true
	@echo "$(GREEN)✓ Kubernetes kaynakları temizlendi$(NC)"

clean-cluster: ## Kind cluster'ı siler
	@echo "$(YELLOW)🗑️  Kind cluster siliniyor...$(NC)"
	@kind delete cluster --name $(CLUSTER_NAME)
	@echo "$(GREEN)✓ Cluster silindi$(NC)"

clean-all: clean clean-cluster ## Her şeyi temizler (cluster + kaynaklar)
	@echo "$(GREEN)✓ Tüm kaynaklar temizlendi$(NC)"
	@echo ""
	@echo "$(YELLOW)⚠️  /etc/hosts dosyasını manuel temizlemeyi unutmayın:$(NC)"
	@echo "  sudo nano /etc/hosts"
	@echo "  # api.local ve web.local satırlarını silin"

redeploy: clean-all deploy ## Tam yeniden deployment (clean + deploy)

quick-update: build-all load-images ## Sadece imajları günceller (cluster'ı değiştirmez)
	@echo "$(YELLOW)🔄 Deployment'lar yeniden başlatılıyor...$(NC)"
	@kubectl rollout restart deployment datetime-api
	@kubectl rollout restart deployment datetime-web
	@kubectl rollout status deployment datetime-api
	@kubectl rollout status deployment datetime-web
	@echo "$(GREEN)✓ Güncelleme tamamlandı$(NC)"