# FluxCD Workshop: GitOps for Kubernetes

## 1. Why GitOps? The Challenge of Kubernetes Deployment Management

As organizations scale their Kubernetes deployments, they encounter several challenges:

* Manual deployments create inconsistencies across environments
* Tracking who changed what and when becomes difficult
* Rollbacks and auditing changes requires specialized knowledge
* Drift between intended and actual cluster state occurs frequently
* Managing access control for multiple teams becomes complex
* Ensuring security and compliance across deployments is challenging

**FluxCD solves these problems by implementing GitOps principles for Kubernetes.**

## 2. What is FluxCD? A Simple Explanation

FluxCD is a set of continuous delivery solutions for Kubernetes that uses GitOps principles to manage infrastructure and applications.

> 🖼️ **Analogy**: If Kubernetes is the operating system and Helm is the package manager, FluxCD is like your automated system administrator that continuously ensures everything matches your desired specifications.

### Origins of FluxCD

* Created by Weaveworks, pioneers of the GitOps concept
* Flux v1 released in 2016 as a monolithic operator
* Flux v2 (current version) completely redesigned as a set of specialized controllers
* Donated to the CNCF in 2019
* Achieved CNCF Incubating status in 2021

## 3. GitOps and FluxCD: The Big Picture

### What is GitOps?

GitOps is an operational framework that takes DevOps best practices used for application development such as version control, collaboration, compliance, and CI/CD, and applies them to infrastructure automation.

### Core Principles of GitOps:

* **Declarative**: All system configurations are defined declaratively
* **Versioned and Immutable**: Configuration is stored in Git, providing versioning and immutability
* **Pulled Automatically**: Software agents automatically pull the desired state declaration
* **Continuously Reconciled**: Software agents continuously ensure actual state matches desired state

```
                   +----------------+
      Developer    |                |
      Commits      |  Git Repository|
    +------------>+|                |<--------------+
    |              +----------------+               |
    |                      |                        |
    |                      | Pull                   |
    |                      v                        |
    |              +----------------+               |
    |              |                |      Alert &  |
    |              |   FluxCD       |      Notify   |
    |              |   Controllers  |               |
    |              |                |               |
    |              +----------------+               |
    |                      |                        |
    |                      | Apply                  |
    |                      v                        |
    |              +----------------+               |
    |              |                |               |
    +------------->|   Kubernetes   +---------------+
      Manual        |   Cluster     |  Reconcile
      Changes       |                |
                    +----------------+
```

### FluxCD Architecture

FluxCD follows a modular architecture with multiple controllers, each handling specific aspects of the GitOps workflow:

* **Source Controller**: Manages Git repositories and Helm repositories
* **Kustomize Controller**: Reconciles kustomizations to the cluster
* **Helm Controller**: Reconciles Helm releases against sources
* **Notification Controller**: Handles events and alerts
* **Image Automation Controllers**: Automates image updates in Git repositories

```
  +-------------------+      +-------------------+      +-------------------+
  |                   |      |                   |      |                   |
  |  Source Controller|----->|Kustomize Controller----->|   Notification   |
  |   (Git/Helm/OCI)  |      |                   |      |   Controller     |
  |                   |      |                   |      |                   |
  +-------------------+      +-------------------+      +-------------------+
           |                          ^
           |                          |
           v                          |
  +-------------------+      +-------------------+
  |                   |      |                   |
  |  Helm Controller  |      |Image Automation   |
  |                   |      |  Controller       |
  |                   |      |                   |
  +-------------------+      +-------------------+
```

![FluxCD Architecture](https://fluxcd.io/img/flux-ui-diagram.png)

### Source, Kustomization, and HelmRelease Relationship

Understanding how FluxCD's core resources relate to each other is crucial for effective GitOps:

```
  +------------------+       +--------------------+       +------------------+
  |                  |       |                    |       |                  |
  |  GitRepository   |       |   Kustomization    |       |  HelmRepository  |
  |  (app manifests) +------>|   (customize &     |       |  (chart repo)    |
  |                  |  use  |    deploy)         |       |                  |
  +------------------+       +--------------------+       +------------------+
                                                                  |
                                                                  | use
                                                                  v
                                                         +------------------+
                                                         |                  |
                                                         |   HelmRelease    |
                                                         |   (chart install) |
                                                         |                  |
                                                         +------------------+
```

## 4. Setting Up FluxCD

Let's install FluxCD and start using it:

### Prerequisites

* A Kubernetes cluster
* kubectl installed and configured
* Git repository access (GitHub, GitLab, etc.)

### Installing the Flux CLI

```bash
# For macOS (using Homebrew)
brew install fluxcd/tap/flux

# For Ubuntu/Debian
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify installation
flux --version
```

Bootstrap FluxCD on Your Cluster
```
# Check prerequisites
flux check --pre

# Bootstrap with GitHub (using HTTPS)
flux bootstrap github \
  --owner=YOUR-GITHUB-USERNAME \
  --repository=fleet-infra \
  --branch=main \
  --path=clusters/my-cluster \
  --personal
```

Verifying Installation
```
# Check deployed components
kubectl get pods -n flux-system

# List Flux custom resources
kubectl get crds | grep fluxcd
```

## 5. Core FluxCD Components

### Sources: Where It All Begins

#### What are Sources?

Sources define where FluxCD should pull configuration from, such as Git repositories or Helm chart repositories.

#### Types of Sources

* **GitRepository**: Git repositories containing Kubernetes manifests or Helm charts
* **HelmRepository**: Helm chart repositories
* **Bucket**: S3-compatible buckets containing Kubernetes manifests
* **OCIRepository**: OCI-compatible registries containing artifacts

#### Hands-on: Creating a Git Source

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/stefanprodan/podinfo
  ref:
    branch: master
  timeout: 20s
```

Apply with:
```
kubectl apply -f git-source.yaml
# Or using Flux CLI
flux create source git podinfo \
  --url=https://github.com/stefanprodan/podinfo \
  --branch=master \
  --interval=1m \
  --namespace=flux-system
```

### Kustomizations: Deploying Resources

#### What are Kustomizations?

Kustomizations tell Flux how to deploy resources from a source. They're not the same as Kustomize overlays - in Flux, they represent a deployment target.

#### Hands-on: Creating a Kustomization

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 5m
  path: "./kustomize"
  prune: true
  sourceRef:
    kind: GitRepository
    name: podinfo
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: podinfo
      namespace: default
  timeout: 2m
```

Apply with:
```
kubectl apply -f kustomization.yaml
# Or using Flux CLI
flux create kustomization podinfo \
  --source=GitRepository/podinfo \
  --path="./kustomize" \
  --prune=true \
  --interval=5m \
  --health-check="Deployment/podinfo.default" \
  --timeout=2m \
  --namespace=flux-system
```

### Helm Releases: Managing Helm Charts

#### What are HelmReleases?

HelmReleases define how Flux should deploy and manage Helm charts in your cluster.

#### Hands-on: Creating a HelmRelease

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: bitnami
  namespace: flux-system
spec:
  interval: 1h
  url: https://charts.bitnami.com/bitnami
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: redis
  namespace: flux-system
spec:
  interval: 5m
  chart:
    spec:
      chart: redis
      version: "17.x"
      sourceRef:
        kind: HelmRepository
        name: bitnami
        namespace: flux-system
  values:
    architecture: standalone
    auth:
      enabled: false
  timeout: 5m
```

Apply with:
```
kubectl apply -f helm-release.yaml
# Or using Flux CLI
flux create source helm bitnami \
  --url=https://charts.bitnami.com/bitnami \
  --interval=1h \
  --namespace=flux-system

flux create helmrelease redis \
  --source=HelmRepository/bitnami \
  --chart=redis \
  --chart-version="17.x" \
  --values=values.yaml \
  --namespace=flux-system
```

### Image Automation: Updating Container Images

#### What is Image Automation?

FluxCD can automatically update your Git repository when new container images are available, triggering new deployments.

```
  +--------------------+
  |  Image Registry    |
  |  (new version)     |
  +--------------------+
           |
           | 1. Detect
           v
  +--------------------+        +--------------------+        +-------------+
  |                    |        |                    |        |             |
  | ImageRepository    | -----> | ImagePolicy        | -----> | Image       |
  | (monitors registry)|        | (selects version)  |        | Update      |
  |                    |        |                    |        | Automation  |
  +--------------------+        +--------------------+        +-------------+
                                                                    |
                                                                    | 2. Update
                                                                    v
                                                             +-------------+
                                                             |             |
                                                             | Git Repo    |
                                                             | (manifest)  |
                                                             |             |
                                                             +-------------+
                                                                    |
                                                                    | 3. Triggers
                                                                    v
                                                             +-------------+
                                                             |             |
                                                             | Flux        |
                                                             | Reconcile   |
                                                             |             |
                                                             +-------------+
                                                                    |
                                                                    | 4. Deploy
                                                                    v
                                                             +-------------+
                                                             |             |
                                                             | Kubernetes  |
                                                             | Cluster     |
                                                             |             |
                                                             +-------------+
```

#### Hands-on: Setting Up Image Automation

```yaml
# Image Repository
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: podinfo
  namespace: flux-system
spec:
  image: ghcr.io/stefanprodan/podinfo
  interval: 5m

# Image Policy
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: podinfo
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: 6.0.x

# Image Update Automation
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageUpdateAutomation
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        email: fluxcdbot@users.noreply.github.com
        name: fluxcdbot
      messageTemplate: '{{range .Updated.Images}}{{println .}}{{end}}'
    push:
      branch: main
  update:
    path: ./clusters/my-cluster
    strategy: Setters
```

## 6. Multi-Environment and Team Workflows

### Multi-Environment Management

FluxCD excels at managing multiple environments using several strategies:

#### Directory-Based Environments

```
                       Central GitOps Repository
  +------------------------------------------------------------------+
  |                                                                  |
  |  +----------------------+  +--------------------+  +-----------+ |
  |  |                      |  |                    |  |           | |
  |  | Infrastructure       |  | Apps               |  | Teams     | |
  |  | - CRDs               |  | - Base configs     |  | - Team A  | |
  |  | - Namespaces         |  | - Dev overrides    |  | - Team B  | |
  |  | - RBAC               |  | - Staging overrides|  | - Team C  | |
  |  | - NetworkPolicies    |  | - Prod overrides   |  |           | |
  |  |                      |  |                    |  |           | |
  |  +----------------------+  +--------------------+  +-----------+ |
  |                                                                  |
  +------------------------------------------------------------------+
              |                       |                     |
              v                       v                     v
  +--------------------+  +--------------------+  +-------------------+
  |                    |  |                    |  |                   |
  |  Development       |  |  Staging           |  |  Production       |
  |  Cluster           |  |  Cluster           |  |  Cluster          |
  |                    |  |                    |  |                   |
  +--------------------+  +--------------------+  +-------------------+
```

```
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
```

#### FluxCD Setup for Multi-Environment:

```yaml
# Dev Environment
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps-dev
  namespace: flux-system
spec:
  interval: 5m
  path: "./dev"
  prune: true
  sourceRef:
    kind: GitRepository
    name: my-app-repo

# Production Environment
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps-prod
  namespace: flux-system
spec:
  interval: 10m
  path: "./production"
  prune: true
  sourceRef:
    kind: GitRepository
    name: my-app-repo
  dependsOn:
    - name: apps-dev
```

### Multi-Tenancy with FluxCD

For multi-team setups, FluxCD provides robust isolation:

```yaml
# Team Namespace and RBAC
apiVersion: v1
kind: Namespace
metadata:
  name: team-a
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: team-a
  namespace: team-a
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: team-a-reconciler
  namespace: team-a
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-a-reconciler
  namespace: team-a
subjects:
  - kind: ServiceAccount
    name: team-a
    namespace: team-a
roleRef:
  kind: Role
  name: team-a-reconciler
  apiGroup: rbac.authorization.k8s.io

# Team Kustomization
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: team-a-apps
  namespace: flux-system
spec:
  serviceAccountName: team-a
  interval: 5m
  path: "./teams/team-a"
  prune: true
  sourceRef:
    kind: GitRepository
    name: teams-repo
  targetNamespace: team-a
```

## 7. Advanced FluxCD Techniques

### Dependency Management

FluxCD allows you to define dependencies between resources:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 5m
  path: "./apps"
  prune: true
  sourceRef:
    kind: GitRepository
    name: my-repo
  dependsOn:
    - name: infrastructure  # Only deploy apps after infrastructure is ready
```

### Health Checks and Progressive Delivery

FluxCD can check resource health before considering a deployment successful:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: backend
  namespace: flux-system
spec:
  interval: 5m
  path: "./backend"
  prune: true
  sourceRef:
    kind: GitRepository
    name: my-repo
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: backend
      namespace: default
  timeout: 2m
```

### Secrets Management with SOPS

FluxCD integrates with Mozilla SOPS for secure secrets management:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: secrets
  namespace: flux-system
spec:
  interval: 10m
  path: "./secrets"
  prune: true
  sourceRef:
    kind: GitRepository
    name: my-secrets-repo
  decryption:
    provider: sops
    secretRef:
      name: sops-gpg
```

## 8. FluxCD with Helm Integration

### Managing Helm Charts with FluxCD

FluxCD provides enhanced Helm capabilities:

* Dependency management: Automatically install chart dependencies
* Value overrides: Override values based on environment
* Drift detection: Detect changes and automatically reconcile
* Release history: Track all releases with Git history
* Automated rollbacks: Revert to previous working configurations

#### Complex HelmRelease Example

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: podinfo
  namespace: default
spec:
  interval: 5m
  chart:
    spec:
      chart: podinfo
      version: "6.x"
      sourceRef:
        kind: HelmRepository
        name: podinfo
        namespace: flux-system
      interval: 1m
  values:
    replicaCount: 2
    resources:
      limits:
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 128Mi
  valuesFrom:
    - kind: ConfigMap
      name: podinfo-values
      valuesKey: values.yaml
  upgrade:
    remediation:
      remediateLastFailure: true
  test:
    enable: true
  rollback:
    timeout: 5m
    cleanupOnFail: true
```

#### Using Helm Charts from Git

FluxCD can install Helm charts directly from Git:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: podinfo-charts
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/stefanprodan/podinfo
  ref:
    branch: master
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: podinfo
  namespace: default
spec:
  interval: 5m
  chart:
    spec:
      chart: ./charts/podinfo
      sourceRef:
        kind: GitRepository
        name: podinfo-charts
        namespace: flux-system
      interval: 1m
  values:
    replicaCount: 2
```

## 9. Troubleshooting FluxCD

### Checking Resource Status

```bash
# Check the overall health of Flux
flux check

# Get reconciliation status of sources
flux get sources all

# Get reconciliation status of kustomizations
flux get kustomizations

# Get reconciliation status of helm releases
flux get helmreleases
```

### Debugging Issues

```bash
# Get detailed information about a source
flux get source git podinfo -v

# Trace a specific resource
flux trace kustomization podinfo

# View controller logs
flux logs --all-namespaces

# Suspend reconciliation for debugging
flux suspend kustomization podinfo

# Resume reconciliation
flux resume kustomization podinfo
```

### Common Issues and Solutions

#### Repository Access Issues

```bash
# Check credentials for private repositories
kubectl get secret -n flux-system flux-system -o yaml

# Re-create credentials for repository access
flux create secret git flux-system \
  --url=https://github.com/user/repo \
  --username=username \
  --password=password
```

#### Failed Reconciliation

```bash
# Force reconciliation to debug issues
flux reconcile kustomization podinfo --with-source

# Check events
kubectl get events --sort-by='.lastTimestamp' -n flux-system
```

## 10. FluxCD Best Practices

### Repository Structure

Follow these practices for organizing your GitOps repositories:

```
fleet-infra/
├── clusters/               # Cluster-specific configurations
│   ├── production/
│   └── staging/
├── infrastructure/         # Shared infrastructure components
│   ├── sources/            # External sources (Helm repos, etc.)
│   ├── monitoring/
│   ├── networking/
│   └── storage/
└── apps/                   # Application deployments
    ├── base/               # Base configurations
    ├── production/         # Production overrides
    └── staging/            # Staging overrides
```

### Security Best Practices

* **Use least privilege**: Configure service accounts with minimal permissions
* **Encrypt secrets**: Use SOPS or sealed-secrets for sensitive data
* **Scan for vulnerabilities**: Integrate security scanners in your GitOps pipeline
* **Use signed commits**: Enable commit signing in your Git repositories
* **Implement policy enforcement**: Use tools like Kyverno or OPA Gatekeeper

### Performance Optimization

* **Set appropriate intervals**: Longer intervals for stable resources (infrastructure: 1h), shorter for critical ones (apps: 5m)
* **Use health checks**: Ensure resources are healthy before marking reconciliation as successful
* **Organize by change frequency**: Group resources by how often they change
* **Prune with care**: Enable pruning only when you're confident about your manifests
* **Use dependsOn**: Establish proper dependencies between resources to optimize reconciliation

---

## 11. Next Steps on Your FluxCD Journey

Congratulations on exploring FluxCD! Here's what to explore next:

* **Progressive Delivery**: Implement canary deployments with [Flagger](https://flagger.app/)
* **Notification Systems**: Set up alerts and notifications for reconciliation events
* **Custom Controllers**: Extend FluxCD with custom controllers for specific use cases
* **Multi-cluster Setup**: Manage multiple clusters with FluxCD for enterprise-grade GitOps
* **Compliance and Auditing**: Implement policy enforcement and auditing using OPA or Kyverno

### Useful Resources

* [FluxCD Documentation](https://fluxcd.io/docs/) - Official documentation with guides and references
* [FluxCD GitHub Repository](https://github.com/fluxcd/flux2) - Source code and examples
* [GitOps Toolkit](https://toolkit.fluxcd.io/) - Core components documentation
* [CNCF GitOps Working Group](https://github.com/cncf/tag-app-delivery) - Community standards and practices
* [FluxCD Community](https://fluxcd.io/community/) - Join the community meetings and discussions

### Conclusion

Remember, GitOps with FluxCD is about building confidence in your deployments through automation, versioning, and continuous reconciliation. By following the principles and practices outlined in this guide, you'll be well on your way to implementing a robust GitOps workflow for your Kubernetes environments.

Start small, establish your patterns and practices, and gradually expand your GitOps implementation across your organization. The journey to GitOps maturity is incremental, but the benefits of improved stability, security, and developer productivity make it well worth the effort.

Happy GitOps-ing!

