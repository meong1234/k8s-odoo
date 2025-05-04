# Docker Image Management for K8s Odoo Project
# Handles pulling and loading project images into KIND

.PHONY: images-help images-pull-all images-load-all images-manage-all

# Project images
CLOUDNATIVE_PG_IMAGE := ghcr.io/cloudnative-pg/cloudnative-pg:1.25.0

# All project images (add new images here)
PROJECT_IMAGES := $(CLOUDNATIVE_PG_IMAGE)

# Help for image management commands
images-help:
	@echo "Docker Image Management Commands:"
	@echo "--------------------------------"
	@echo "  images-pull-all     - Pull all required Docker images"
	@echo "  images-load-all     - Load all required Docker images into KIND cluster"
	@echo "  images-manage-all   - Pull and load all required Docker images (complete process)"
	@echo ""

# Pull all project images
images-pull-all:
	@echo "==> Pulling project Docker images..."
	@for img in $(PROJECT_IMAGES); do \
		echo "  - Pulling $$img"; \
		docker pull $$img || { echo "Error pulling $$img"; exit 1; }; \
	done
	@echo "==> All project images pulled successfully"

# Load all project images into KIND
images-load-all:
	@echo "==> Loading project Docker images into KIND cluster '$(KIND_CLUSTER)'..."
	@if ! kind get clusters | grep -q $(KIND_CLUSTER); then \
		echo "Error: KIND cluster '$(KIND_CLUSTER)' not found"; \
		echo "Please run 'make kind-create' first"; \
		exit 1; \
	fi
	@for img in $(PROJECT_IMAGES); do \
		echo "  - Loading $$img"; \
		kind load docker-image $$img --name $(KIND_CLUSTER) || { echo "Error loading $$img"; exit 1; }; \
	done
	@echo "==> All project images loaded successfully"

# Pull and load all project images (complete process)
images-manage-all: images-pull-all images-load-all
	@echo "==> Image management complete"
