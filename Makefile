# Kubernetes local Deployment
# Main entry point for all operations

.PHONY: help up down

# Include all makefiles from scripts directory
include scripts/*

# Default target - orchestrates help from all script files
help: k8s-help setup-help fluxcd-help images-help
	@echo "Kubernetes local Deployment"
	@echo "=========================="
	@echo ""
	@echo "High-Level Commands:"
	@echo "-----------------"
	@echo "  up               - Create cluster, load images, and setup FluxCD (complete setup)"
	@echo "  down             - Delete the Kubernetes cluster"
	@echo ""

# High-level command to set up the complete environment
up: kind-create images-manage-all fluxcd-setup
	@echo "==> Environment is now ready!"
	@echo "==> You can access the cluster with: kubectl get pods --all-namespaces"

# High-level command to tear down the environment
down: kind-delete
	@echo "==> Environment has been destroyed"


