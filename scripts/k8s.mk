# Kubernetes support targets

.PHONY: kind-create kind-delete kind-status kind-load-image k8s-help

# Configuration variables
KIND_IMAGE        := kindest/node:v1.33.0
KIND_CLUSTER      := starter-cluster
WAIT_TIMEOUT      := 120s

# Registry settings (exported for other makefiles)
export REG_NAME          := kind-registry
export REG_LOCALHOST_PORT := 5050
export REG_CLUSTER_PORT  := 5000

# Help for Kubernetes commands
k8s-help:
	@echo "Kubernetes (KIND) Commands:"
	@echo "--------------------------"
	@echo "  kind-create         - Create a Kubernetes cluster using KIND with integrated registry"
	@echo "  kind-delete         - Delete the Kubernetes cluster"
	@echo "  kind-status         - Check status of the KIND cluster"
	@echo "  kind-load-image     - Load a Docker image into KIND (requires IMAGE=name:tag)"
	@echo ""

# Create a Kubernetes cluster using KIND with integrated registry
kind-create:
	@echo "==> Setting up local registry container '$(REG_NAME)'"
	@REG_PORT_MAPPING="$$(docker inspect -f '{{range \$$p, \$$conf := .NetworkSettings.Ports}}{{if eq \$$p "5000/tcp"}}{{(index \$$conf 0).HostPort}}{{end}}{{end}}' $(REG_NAME) 2>/dev/null || echo '')"; \
	if [ "$$(docker ps -a -q -f name=^/$(REG_NAME)$$)" = "" ]; then \
		echo "  - Creating Docker registry on localhost:$(REG_LOCALHOST_PORT)"; \
		docker run -d --restart=always -p "127.0.0.1:$(REG_LOCALHOST_PORT):$(REG_CLUSTER_PORT)" \
			--name "$(REG_NAME)" registry:2; \
	elif [ "$$REG_PORT_MAPPING" != "$(REG_LOCALHOST_PORT)" ]; then \
		echo "  - Recreating registry container with correct port mapping"; \
		docker rm -f "$(REG_NAME)" > /dev/null 2>&1 || true; \
		docker run -d --restart=always -p "127.0.0.1:$(REG_LOCALHOST_PORT):$(REG_CLUSTER_PORT)" \
			--name "$(REG_NAME)" registry:2; \
	elif [ "$$(docker inspect -f '{{.State.Running}}' $(REG_NAME) 2>/dev/null || echo false)" != "true" ]; then \
		echo "  - Starting existing Docker registry container"; \
		docker start "$(REG_NAME)"; \
	else \
		echo "  - Registry container already running"; \
	fi
	
	@echo "==> Creating Kubernetes cluster '$(KIND_CLUSTER)' with image $(KIND_IMAGE)"
	@rm -f /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "kind: Cluster" > /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "apiVersion: kind.x-k8s.io/v1alpha4" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "containerdConfigPatches:" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "  - |-" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "    [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"localhost:$(REG_LOCALHOST_PORT)\"]" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "      endpoint = [\"http://$(REG_NAME):$(REG_CLUSTER_PORT)\"]" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "nodes:" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "  - role: control-plane" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "    image: $(KIND_IMAGE)" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "    kubeadmConfigPatches:" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "      - |" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "        kind: InitConfiguration" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "        nodeRegistration:" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "          kubeletExtraArgs:" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "            node-labels: \"ingress-ready=true\"" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "  - role: worker" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@echo "    image: $(KIND_IMAGE)" >> /tmp/kind-config-$(KIND_CLUSTER).yaml
	@kind create cluster --name $(KIND_CLUSTER) --wait 5m --config=/tmp/kind-config-$(KIND_CLUSTER).yaml
	@rm -f /tmp/kind-config-$(KIND_CLUSTER).yaml

	@echo "==> Connecting registry to cluster network"
	@if [ "$$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "$(REG_NAME)")" = "null" ]; then \
		echo "  - Connecting registry to kind network"; \
		docker network connect "kind" "$(REG_NAME)" || echo "Warning: Could not connect registry to network"; \
	else \
		echo "  - Registry already connected to kind network"; \
	fi

	@echo "==> Registering registry with cluster"
	@rm -f /tmp/registry-cm-$(KIND_CLUSTER).yaml
	@echo "apiVersion: v1" > /tmp/registry-cm-$(KIND_CLUSTER).yaml
	@echo "kind: ConfigMap" >> /tmp/registry-cm-$(KIND_CLUSTER).yaml
	@echo "metadata:" >> /tmp/registry-cm-$(KIND_CLUSTER).yaml
	@echo "  name: local-registry-hosting" >> /tmp/registry-cm-$(KIND_CLUSTER).yaml
	@echo "  namespace: kube-public" >> /tmp/registry-cm-$(KIND_CLUSTER).yaml
	@echo "data:" >> /tmp/registry-cm-$(KIND_CLUSTER).yaml
	@echo "  localRegistryHosting.v1: |" >> /tmp/registry-cm-$(KIND_CLUSTER).yaml
	@echo "    host: \"localhost:$(REG_LOCALHOST_PORT)\"" >> /tmp/registry-cm-$(KIND_CLUSTER).yaml
	@echo "    hostFromContainerRuntime: \"$(REG_NAME):$(REG_CLUSTER_PORT)\"" >> /tmp/registry-cm-$(KIND_CLUSTER).yaml
	@echo "    hostFromClusterNetwork: \"$(REG_NAME):$(REG_CLUSTER_PORT)\"" >> /tmp/registry-cm-$(KIND_CLUSTER).yaml
	@echo "    help: \"https://kind.sigs.k8s.io/docs/user/local-registry/\"" >> /tmp/registry-cm-$(KIND_CLUSTER).yaml
	@kubectl apply --server-side -f /tmp/registry-cm-$(KIND_CLUSTER).yaml
	@rm -f /tmp/registry-cm-$(KIND_CLUSTER).yaml

	@echo "==> Creating registry service for DNS resolution"
	@rm -f /tmp/registry-svc-$(KIND_CLUSTER).yaml
	@echo "apiVersion: v1" > /tmp/registry-svc-$(KIND_CLUSTER).yaml
	@echo "kind: Service" >> /tmp/registry-svc-$(KIND_CLUSTER).yaml
	@echo "metadata:" >> /tmp/registry-svc-$(KIND_CLUSTER).yaml
	@echo "  name: $(REG_NAME)" >> /tmp/registry-svc-$(KIND_CLUSTER).yaml
	@echo "  namespace: default" >> /tmp/registry-svc-$(KIND_CLUSTER).yaml
	@echo "spec:" >> /tmp/registry-svc-$(KIND_CLUSTER).yaml
	@echo "  type: ExternalName" >> /tmp/registry-svc-$(KIND_CLUSTER).yaml
	@echo "  externalName: $(REG_NAME)" >> /tmp/registry-svc-$(KIND_CLUSTER).yaml
	@echo "  ports:" >> /tmp/registry-svc-$(KIND_CLUSTER).yaml
	@echo "  - name: registry" >> /tmp/registry-svc-$(KIND_CLUSTER).yaml
	@echo "    port: $(REG_CLUSTER_PORT)" >> /tmp/registry-svc-$(KIND_CLUSTER).yaml
	@kubectl apply -f /tmp/registry-svc-$(KIND_CLUSTER).yaml
	@rm -f /tmp/registry-svc-$(KIND_CLUSTER).yaml

	@echo "==> Waiting for local-path-provisioner to be available"
	@kubectl wait --timeout=$(WAIT_TIMEOUT) --namespace=local-path-storage \
		--for=condition=Available deployment/local-path-provisioner
	@echo "==> Cluster is ready!"

# Delete the Kubernetes cluster
kind-delete:
	@echo "==> Deleting Kubernetes cluster '$(KIND_CLUSTER)'"
	@kind delete cluster --name $(KIND_CLUSTER)

# Check status of the KIND cluster
kind-status:
	@echo "==> Available clusters:"
	@kind get clusters
	@echo "==> Cluster info for '$(KIND_CLUSTER)':"
	@kubectl cluster-info --context kind-$(KIND_CLUSTER) 2>/dev/null || echo "Cluster not running"
	@echo "==> Registry status:"
	@docker inspect -f '{{.State.Status}}' "$(REG_NAME)" 2>/dev/null || echo "Registry not found"
	
# Load a Docker image into the KIND cluster
kind-load-image:
	@if [ -z "$(IMAGE)" ]; then \
		echo "Error: IMAGE is required"; \
		echo "Usage: make kind-load-image IMAGE=your-image:tag"; \
		exit 1; \
	fi
	@echo "==> Loading image '$(IMAGE)' into cluster '$(KIND_CLUSTER)'"
	@kind load docker-image $(IMAGE) --name $(KIND_CLUSTER)