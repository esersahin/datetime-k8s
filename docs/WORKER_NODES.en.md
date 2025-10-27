<div align="center">

### 🌐 Read in Other Languages

| 🇬🇧 [English](WORKER_NODES.en.md) | 🇹🇷 [Türkçe](WORKER_NODES.md) |
| :------------------------------: | :--------------------------: |

</div>

---

# Guide to Adding Worker Nodes to Kubernetes Cluster

This document will teach you how to create a multi-node cluster by adding 2 worker nodes to your Kind cluster.

## 📋 Table of Contents

1. [Current State](#-current-state)
2. [Target State](#-target-state)
3. [kind-config.yaml Changes](#-kind-configyaml-changes)
4. [Makefile Changes](#-makefile-changes)
5. [Post-Deployment Checks](#-post-deployment-checks)
6. [Pod Scheduling and Node Affinity](#-pod-scheduling-and-node-affinity)

---

## 🔍 Current State

Currently your cluster is running with **only 1 control-plane node**:

```yaml
nodes:
  - role: control-plane
```

In this structure:

- ✅ All Kubernetes control plane components running (API Server, Scheduler, Controller Manager)
- ⚠️ Pods running on control-plane node
- ⚠️ Not a production-like environment
- ⚠️ No high availability

## 🎯 Target State

**1 Control-Plane + 2 Worker Node** structure:

```yaml
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

In this structure:

- ✅ Control plane operations on separate node
- ✅ Application pods on worker nodes
- ✅ Production-like environment
- ✅ Load balancing and scalability
- ✅ Ability to test node failure scenarios

---

## 📝 kind-config.yaml Changes

### ❌ Old `kind-config.yaml`

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

### ✅ New `kind-config.yaml` (Multi-Node)

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

### 🔑 Key Points

1. **Control-Plane Node**:

   - `ingress-ready=true` label only on control-plane
   - Port mappings only on control-plane
   - Ingress controller will run here

2. **Worker Nodes**:
   - Custom labels can be added (`worker-group`)
   - Application pods will run here
   - Each node can be labeled differently (for node affinity)

---

## 🔧 Makefile Changes

### Updated `create-cluster` Target

The `create-cluster` target in `Makefile` has been updated with an important improvement:

**Important Feature**: Now `kind-config.yaml` is **automatically created** if it doesn't exist!

```makefile
create-cluster: ## Create Kind cluster (multi-node: 1 control-plane + 2 workers)
	@echo "$(YELLOW)🚀 Checking Kind cluster...$(NC)"
	@if ! kind get clusters | grep -q "$(CLUSTER_NAME)"; then \
		echo "$(YELLOW)Creating Kind cluster (1 control-plane + 2 workers)...$(NC)"; \
		if [ ! -f "kind-config.yaml" ]; then \
			echo "$(YELLOW)kind-config.yaml not found, creating...$(NC)"; \
			# Create kind-config.yaml using printf
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
			echo "$(GREEN)✓ kind-config.yaml created$(NC)"; \
		else \
			echo "$(GREEN)✓ kind-config.yaml exists, using it$(NC)"; \
		fi; \
		# Always create cluster using kind-config.yaml
		kind create cluster --config=kind-config.yaml; \
		echo "$(GREEN)✓ Multi-node Kind cluster created$(NC)"; \
		echo ""; \
		echo "$(BLUE)Cluster Nodes:$(NC)"; \
		kubectl get nodes -o wide; \
	else \
		echo "$(GREEN)✓ Kind cluster already exists$(NC)"; \
		echo "$(BLUE)Existing nodes:$(NC)"; \
		kubectl get nodes; \
	fi
```

### 🎯 Flow Logic

1. **Check if cluster exists**

   - If yes: Show existing nodes
   - If no: Continue

2. **Check if kind-config.yaml exists**

   - If yes: Use existing file
   - If no: Auto-create using `printf`

3. **Create cluster**

   - Always use `kind create cluster --config=kind-config.yaml`
   - Not using inline config, always using file

4. **Show nodes**
   - List created nodes

### 🔑 Advantages

- ✅ **Automatic**: File is auto-created if missing
- ✅ **Consistent**: Same file always used
- ✅ **Customizable**: User can manually edit `kind-config.yaml` if desired
- ✅ **Version Control**: `kind-config.yaml` can be added to git
- ✅ **Reproducible**: Same configuration used every time

### New Added `show-nodes` Target

```makefile
show-nodes: ## Show cluster nodes in detail
	@echo "$(BLUE)📊 Cluster Nodes$(NC)"
	@echo "===================="
	@kubectl get nodes -o wide
	@echo ""
	@echo "$(BLUE)Node Details:$(NC)"
	@echo ""
	@for node in $$(kubectl get nodes -o name); do \
		echo "$(YELLOW)$$node:$(NC)"; \
		kubectl describe $$node | grep -A 5 "Labels:"; \
		echo ""; \
	done
```

### Updated `status` Target

```makefile
status: ## Show cluster status
	@echo "$(BLUE)📊 Cluster Status$(NC)"
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


## 🔍 Post-Deployment Checks

### 1. Check Nodes

```bash
# Using Makefile
make show-nodes

# or using kubectl
kubectl get nodes

# Detailed info
kubectl get nodes -o wide

# Expected output:
NAME                 STATUS   ROLES           AGE   VERSION
kind-control-plane   Ready    control-plane   2m    v1.27.3
kind-worker          Ready    <none>          2m    v1.27.3
kind-worker2         Ready    <none>          2m    v1.27.3
```

### 2. Check Pod Distribution

```bash
# Show which node pods are running on
kubectl get pods -o wide

# Using Makefile
make status
```

**Example Output:**

```
NAME                           READY   STATUS    NODE
datetime-api-5d8f7b9c8-abc12   1/1     Running   kind-worker
datetime-api-5d8f7b9c8-def34   1/1     Running   kind-worker2
datetime-web-7c9d4b8f5-ghi56   1/1     Running   kind-worker
datetime-web-7c9d4b8f5-jkl78   1/1     Running   kind-worker2
```

### 3. Check Node Labels

```bash
# Show labels of all nodes
kubectl get nodes --show-labels

# Show labels of specific node
kubectl describe node kind-worker | grep Labels -A 10
```

---

## 📦 Pod Scheduling and Node Affinity

### Current Deployments

Your current deployments don't contain any node affinity, so pods will be automatically distributed to worker nodes.

### Optional: Assign Pods to Specific Nodes

If you want to run specific pods on specific nodes:

#### Add Node Affinity to api-csharp-deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: datetime-api
spec:
  replicas: 2
  template:
    spec:
      # Node Affinity - API pods only run on worker-group-1
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

#### Add Node Affinity to web-csharp-deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: datetime-web
spec:
  replicas: 2
  template:
    spec:
      # Node Affinity - Web pods only run on worker-group-2
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

To guarantee same pods run on different nodes:

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

## 🧪 Test Scenarios

### Test 1: Auto-Create kind-config.yaml

```bash
# Delete kind-config.yaml (if exists)
rm kind-config.yaml

# Create cluster
make create-cluster

# Expected output:
# ℹ kind-config.yaml not found, creating...
# ✓ kind-config.yaml created
# ✓ Multi-node Kind cluster created

# Verify file was created
ls -la kind-config.yaml
cat kind-config.yaml

# Check nodes
kubectl get nodes
# Expected: kind-control-plane, kind-worker, kind-worker2
```

### Test 2: Test Pod Distribution

```bash
# Increase replica count
make scale-api REPLICAS=4
make scale-web REPLICAS=4

# Check distribution
kubectl get pods -o wide

# How many pods on each node?
kubectl get pods -o wide | awk '{print $7}' | sort | uniq -c

# Expected output example:
#   1 NODE
#   2 kind-worker
#   2 kind-worker2
#   2 kind-control-plane (only ingress controller)
```

### Test 3: Node Failure Simulation

```bash
# Drain a worker node
kubectl drain kind-worker --ignore-daemonsets --delete-emptydir-data

# Watch pods move to other node
kubectl get pods -o wide -w

# Expected: Pods on kind-worker will move to kind-worker2

# Reactivate node
kubectl uncordon kind-worker

# Check if pods rebalanced
kubectl get pods -o wide
```

### Test 4: Node Resource Monitoring

```bash
# Node resource usage (requires metrics-server)
kubectl top nodes

# If metrics-server not installed
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Disable TLS for metrics-server (for Kind)
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Wait a few minutes and try again
kubectl top nodes
kubectl top pods

# General status using Makefile
make status
```

### Test 5: Multi-Node Cluster Features

```bash
# 1. Check node labels
kubectl get nodes --show-labels

# 2. Check each node's role
kubectl get nodes -o custom-columns=NAME:.metadata.name,ROLE:.metadata.labels."kubernetes\.io/role",STATUS:.status.conditions[-1].type

# 3. Only system pods on control-plane?
kubectl get pods -n kube-system -o wide | grep control-plane

# 4. Application pods on worker nodes?
kubectl get pods -o wide | grep -E "kind-worker|kind-worker2"

# 5. Detailed report
make show-nodes
```

---

## 📊 Comparison Table

| Feature                   | Single Node    | Multi-Node (1+2) |
| ------------------------- | -------------- | ---------------- |
| **High Availability**     | ❌ No          | ✅ Yes           |
| **Load Balancing**        | ❌ No          | ✅ Automatic     |
| **Resource Isolation**    | ❌ Limited     | ✅ Good          |
| **Production-like**       | ❌ No          | ✅ Yes           |
| **Testing Capabilities**  | ⚠️ Basic       | ✅ Advanced      |
| **Node Failure Handling** | ❌ Can't test  | ✅ Can test      |
| **Startup Time**          | ✅ Fast (~30s) | ⚠️ Medium (~60s) |
| **Resource Usage**        | ✅ Low         | ⚠️ Medium        |

---

## 🚀 Deployment Commands

### Scenario 1: First Deployment (NO kind-config.yaml)

```bash
# Go to project directory
cd datetime-k8s

# Deploy - kind-config.yaml will be auto-created
make deploy

# What happened?
# 1. kind-config.yaml was auto-created
# 2. Multi-node cluster created (1+2)
# 3. All services deployed

# Check created file
cat kind-config.yaml

# Check nodes
make show-nodes
```

### Scenario 2: First Deployment (WITH kind-config.yaml)

```bash
# If kind-config.yaml already exists
cd datetime-k8s

# Deploy - existing file will be used
make deploy

# What happened?
# 1. Existing kind-config.yaml was used
# 2. Cluster created
# 3. Services deployed
```

### Scenario 3: Custom Worker Node Count

```bash
# Manually edit kind-config.yaml
nano kind-config.yaml

# Add 3rd worker
# - role: worker
#   labels:
#     worker-group: group-3

# Delete old cluster
make clean-cluster

# Create new cluster
make create-cluster

# Check nodes
make show-nodes

# Expected: 1 control-plane + 3 workers
```

### Scenario 4: Update Existing Cluster

⚠️ **WARNING**: Adding nodes to Kind cluster is not supported! You need to delete and recreate the cluster.

```bash
# In project directory
cd datetime-k8s

# Full redeploy
make redeploy

# What happened?
# 1. Existing cluster deleted (clean-all)
# 2. kind-config.yaml checked/created
# 3. New multi-node cluster created
# 4. All services redeployed

# Verify nodes
kubectl get nodes
```

---

## 📝 Summary

### Changes Made

1. ✅ `kind-config.yaml` - Added 2 worker nodes
2. ✅ `Makefile` - Updated `create-cluster` target
   - **New Feature**: Auto-creates `kind-config.yaml` if missing
   - File creation using `printf`
3. ✅ `Makefile` - Added `show-nodes` target
4. ✅ `Makefile` - Updated `status` target

### Quick Reference Table

| Command                    | Description               | kind-config.yaml Status    |
| -------------------------- | ------------------------- | -------------------------- |
| `make create-cluster`      | Create cluster            | Auto-created if missing    |
| `make deploy`              | Full deployment           | Auto-created if missing    |
| `make show-nodes`          | Show nodes in detail      | -                          |
| `make status`              | General status (node+pod) | -                          |
| `make clean-cluster`       | Delete cluster            | kind-config.yaml preserved |
| `make redeploy`            | Delete and recreate       | Existing or newly created  |
| `kubectl get nodes`        | Node list                 | -                          |
| `kubectl get pods -o wide` | Pod placement             | -                          |

### Usage Flow Diagram

```
┌──────────────────────────────────────┐
│  make deploy or make create-cluster  │
└─────────────────┬────────────────────┘
                  │
                  ▼
       ┌──────────────────────┐
       │ Does kind-config.yaml│
       │ exist?               │
       └──────┬──────┬────────┘
              │      │
        NO    │      │ YES
              │      │
              ▼      ▼
    ┌──────────┐  ┌──────────────┐
    │ Auto     │  │ Use existing │
    │ Create   │  │ file         │
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

### Usage

```bash
# 1. Delete existing cluster
make clean-all

# 2. Deploy new multi-node cluster
make deploy

# 3. Check nodes
make show-nodes

# 4. Check pod distribution
make status

# 5. Test
make verify
make test
```

### Expected Result

- 1 Control-Plane Node (kind-control-plane)
- 2 Worker Nodes (kind-worker, kind-worker2)
- Pods distributed evenly on worker nodes
- Ingress Controller running on control-plane
- All services working properly

---

## 🔗 Additional Resources

- [Kind Multi-Node Clusters](https://kind.sigs.k8s.io/docs/user/quick-start/#creating-a-cluster)
- [Kubernetes Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Pod Anti-Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)

---

**Note**: These changes are fully optimized for local development. Production environments may require different configurations.
