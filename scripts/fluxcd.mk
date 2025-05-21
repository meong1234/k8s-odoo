# FluxCD Integration
# Manages FluxCD setup and configuration in the KinD cluster with OCI Registry

# Define KIND cluster name (default: starter-cluster) - must match value in images.mk
KIND_CLUSTER ?= starter-cluster

# Define wait timeout for kubectl operations
WAIT_TIMEOUT ?= 5m

.PHONY: fluxcd-help fluxcd-pull-images fluxcd-load-images fluxcd-install fluxcd-push-artifacts fluxcd-oci-setup fluxcd-setup fluxcd-verify-artifacts

# FluxCD container images
FLUXCD_SOURCE := ghcr.io/fluxcd/source-controller:v1.5.0
FLUXCD_NOTIFICATION := ghcr.io/fluxcd/notification-controller:v1.5.0
FLUXCD_KUSTOMIZE := ghcr.io/fluxcd/kustomize-controller:v1.5.1
FLUXCD_HELM := ghcr.io/fluxcd/helm-controller:v1.2.0
FLUXCD_IMAGES := $(FLUXCD_SOURCE) $(FLUXCD_NOTIFICATION) $(FLUXCD_KUSTOMIZE) $(FLUXCD_HELM)

# FluxCD manifests directory
FLUXCD_MANIFESTS_DIR := $(shell pwd)/fluxcd

# Artifact directories
CLUSTERS_MANIFESTS_DIR := $(shell pwd)/kubernetes/clusters
OPERATORS_MANIFESTS_DIR := $(shell pwd)/kubernetes/operators
INFRA_MANIFESTS_DIR := $(shell pwd)/kubernetes/infra
ERP_MANIFESTS_DIR := $(shell pwd)/kubernetes/erp

# Artifact settings
CLUSTERS_ARTIFACT_NAME := cluster-sync
OPERATORS_ARTIFACT_NAME := operators-sync
INFRA_ARTIFACT_NAME := infra-sync
ERP_ARTIFACT_NAME := erp-sync

# Artifacts to push - each pair is a "directory:name" format
ARTIFACTS_TO_PUSH := $(CLUSTERS_MANIFESTS_DIR):$(CLUSTERS_ARTIFACT_NAME) \
                     $(OPERATORS_MANIFESTS_DIR):$(OPERATORS_ARTIFACT_NAME) \
                     $(INFRA_MANIFESTS_DIR):$(INFRA_ARTIFACT_NAME) \
                     $(ERP_MANIFESTS_DIR):$(ERP_ARTIFACT_NAME)

# OCI Registry settings
REG_NAME ?= kind-registry
REG_LOCALHOST_PORT ?= 5050
REG_CLUSTER_PORT ?= 5000

# OCI artifact settings
OCI_ARTIFACT_NAME := flux-apps-sync
OCI_ARTIFACT_TAG := local

# Registry URLs
OCI_LOCAL_URL := localhost:$(REG_LOCALHOST_PORT)
OCI_CLUSTER_URL := $(REG_NAME):$(REG_CLUSTER_PORT)

# Temporary files
TMP_OCI_SOURCE := /tmp/oci-source-$(KIND_CLUSTER).yaml

# Help for FluxCD commands
fluxcd-help:
	@echo "FluxCD Commands:"
	@echo "---------------"
	@echo "  fluxcd-pull-images    - Pull all FluxCD container images"
	@echo "  fluxcd-load-images    - Load FluxCD images into KinD cluster"
	@echo "  fluxcd-install        - Install FluxCD components in the cluster"
	@echo "  fluxcd-push-artifacts - Push manifests to OCI registry"
	@echo "  fluxcd-oci-setup      - Setup FluxCD with OCI repository"
	@echo "  fluxcd-setup          - Complete FluxCD setup (all steps)"
	@echo ""

# Pull all FluxCD container images
fluxcd-pull-images:
	@echo "==> Pulling FluxCD images..."
	@for img in $(FLUXCD_IMAGES); do \
		echo "  - Pulling $$img"; \
		docker pull $$img; \
	done
	@echo "==> All FluxCD images pulled"

# Load FluxCD images into KinD
fluxcd-load-images: 
	@echo "==> Loading FluxCD images into KinD cluster '$(KIND_CLUSTER)'..."
	@for img in $(FLUXCD_IMAGES); do \
		echo "  - Loading $$img"; \
		kind load docker-image $$img --name $(KIND_CLUSTER); \
	done
	@echo "==> All FluxCD images loaded"

# Install FluxCD components in the cluster
fluxcd-install:
	@echo "==> Installing FluxCD in the cluster..."
	@flux check --pre > /dev/null 2>&1 || { echo "Error: flux CLI not working properly"; exit 1; }
	@flux install --components=source-controller,kustomize-controller,helm-controller,notification-controller
	@echo "==> Waiting for FluxCD controllers to be ready"
	@kubectl -n flux-system wait --timeout=$(WAIT_TIMEOUT) --for=condition=Available deployments --all
	@echo "==> FluxCD installed successfully"

# Push artifacts to OCI registry
fluxcd-push-artifacts:
	@echo "==> Pushing artifacts to OCI registry..."

	@if ! docker ps | grep -q $(REG_NAME); then \
		echo "Error: Registry container '$(REG_NAME)' is not running"; \
		echo "Please run 'make kind-create' first or start the registry manually"; \
		exit 1; \
	fi

	@for artifact in $(ARTIFACTS_TO_PUSH); do \
		ARTIFACT_DIR=$$(echo $$artifact | cut -d: -f1); \
		ARTIFACT_NAME=$$(echo $$artifact | cut -d: -f2); \
		\
		if [ ! -d $$ARTIFACT_DIR ]; then \
			echo "Error: Directory '$$ARTIFACT_DIR' not found, skipping..."; \
			continue; \
		fi; \
		\
		echo "  - Pushing $$ARTIFACT_DIR to OCI registry at $(OCI_LOCAL_URL)/$$ARTIFACT_NAME"; \
		REVISION=$$(date +%s); \
		echo "  - Using revision: $$REVISION and tag: local"; \
		FLUX_OUTPUT=$$(flux push artifact oci://$(OCI_LOCAL_URL)/$$ARTIFACT_NAME:local \
			--path="$$ARTIFACT_DIR" \
			--source="local-development" \
			--revision="$$REVISION" 2>&1) || EXIT_CODE=$$?; \
		\
		if [ -n "$$EXIT_CODE" ] && [ $$EXIT_CODE -ne 0 ]; then \
			echo "$$FLUX_OUTPUT"; \
			exit 1; \
		fi; \
		\
		OCI_URL=$$(echo "$$FLUX_OUTPUT" | grep -o 'oci://.*'); \
		echo "  ✅ Pushed to $$OCI_URL"; \
	done

	@echo "==> Artifact push complete"
	@echo "==> Verifying pushed artifacts..."
	@make fluxcd-verify-artifacts

# Verify pushed artifacts
fluxcd-verify-artifacts:
	@echo "==> Verifying artifacts in registry"
	@for artifact in $(ARTIFACTS_TO_PUSH); do \
		ARTIFACT_NAME=$$(echo $$artifact | cut -d: -f2); \
		echo "  - Checking $$ARTIFACT_NAME in registry at http://$(OCI_LOCAL_URL)/v2/$$ARTIFACT_NAME/tags/list"; \
		TAGS=$$(curl -s "http://$(OCI_LOCAL_URL)/v2/$$ARTIFACT_NAME/tags/list" 2>/dev/null || echo '{"tags":[]}'); \
		if echo "$$TAGS" | grep -q '"local"'; then \
			echo "    ✅ Found $$ARTIFACT_NAME with tag 'local'"; \
		else \
			echo "    ❌ Artifact $$ARTIFACT_NAME with tag 'local' not found in registry!"; \
			echo "       Registry response: $$TAGS"; \
			exit 1; \
		fi; \
	done
	@echo "==> All artifacts verified"

# Create FluxCD resources for OCI repository
fluxcd-oci-setup: fluxcd-verify-artifacts
	@echo "==> Creating FluxCD resources from existing manifests..."
	@kubectl apply -f $(CLUSTERS_MANIFESTS_DIR)/local/flux-system/cluster-source.yaml
	@kubectl apply -f $(CLUSTERS_MANIFESTS_DIR)/local/flux-system/cluster-sync.yaml
	@echo "==> FluxCD OCI resources created successfully"
	@echo "==> Verify status with: kubectl get ocirepositories -n flux-system"

# Complete FluxCD setup (all steps)
fluxcd-setup: fluxcd-pull-images fluxcd-load-images fluxcd-install fluxcd-push-artifacts fluxcd-oci-setup
	@echo "==> FluxCD setup complete"
