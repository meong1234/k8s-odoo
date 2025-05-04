# Helm Workshop: Managing Kubernetes Applications

## 1. Why Helm? The Challenge of Kubernetes Application Deployment

As teams adopt Kubernetes, they quickly encounter new challenges:

- Managing dozens of YAML manifests becomes unwieldy
- Duplicating configuration across environments leads to inconsistencies
- Tracking application versions and history is difficult
- Rollbacks require manual intervention and are error-prone
- Environment-specific configurations demand complex templating solutions
- Sharing applications between teams lacks standardization

Helm solves these problems by providing **package management for Kubernetes**.

## 2. What is Helm? A Simple Explanation

**Helm** is a package manager for Kubernetes that helps you define, install, and upgrade even the most complex Kubernetes applications.

> 🖼️ **Analogy**: If Kubernetes is like an operating system for your cluster, Helm is like apt, yum, or homebrew - it lets you search, install, upgrade and manage applications as packages.

### Origins of Helm

- Originally created by Deis (later acquired by Microsoft)
- Version 1 (Helm Classic) released in 2015
- Helm 2 completely redesigned and donated to the CNCF in 2016
- Helm 3 released in 2019, removing the server-side component (Tiller)
- Now an official CNCF graduated project

## 3. Helm Architecture: The Big Picture

Helm has evolved significantly since its inception. Current architecture includes:

### Core Components

- **Helm CLI**: The command-line client that communicates with the Kubernetes API
- **Charts**: Packages of pre-configured Kubernetes resources
- **Repositories**: Places where charts are stored and shared
- **Releases**: Instances of a chart deployed in a Kubernetes cluster

```
  +----------------+         +-----------------+         +----------------+
  |                |         |                 |         |                |
  |  CHART REPOS   |         |     CHART       |         |    RELEASE     |
  |                |-------->|                 |-------->|                |
  | (where charts  |  pull   | (package with   |  install| (instance of a |
  |  are stored)   |         |  templates)     |         |  chart running |
  |                |         |                 |         |  in cluster)   |
  +----------------+         +-----------------+         +----------------+
                                     ^
                                     |
                                     | customize
                                     |
                             +-----------------+
                             |                 |
                             |     VALUES      |
                             |                 |
                             | (configuration  |
                             |  parameters)    |
                             |                 |
                             +-----------------+
```

### Helm 3 Architecture

Helm 3 simplified the architecture by eliminating Tiller (the server-side component in Helm 2):

- Communicates directly with the Kubernetes API
- Stores release information as Secrets or ConfigMaps in the cluster
- Uses Kubernetes RBAC for access control

![Helm Architecture](https://helm.sh/img/helm-architecture.svg)

## 4. Setting Up Helm

Let's get Helm installed and start working with it:

### Installing Helm

```bash
# For macOS (using Homebrew)
brew install helm

# For Ubuntu/Debian
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

# Verify installation
helm version
```

### Adding Repositories

Helm charts are stored in repositories. Let's add some popular ones:
(Note: The official Helm `stable` repository has been deprecated. You should add specific repositories you need or search on [Artifact Hub](https://artifacthub.io/).)

```bash
# Add Bitnami repository (contains many well-maintained charts)
helm repo add bitnami https://charts.bitnami.com/bitnami

# Example for adding another repository
# helm repo add <alias> <url>

# Update your local repository cache
helm repo update

# List repositories
helm repo list

# Search for charts in added repositories
helm search repo wordpress

# Search for charts on Artifact Hub (requires Helm 3.7.0+)
helm search hub wordpress
```

## 5. Core Helm Concepts

### Charts: The Heart of Helm

#### What is a Chart?
A Helm chart is a package of pre-configured Kubernetes resources. Think of it as a bundle that contains everything needed to run an application in Kubernetes.

#### Structure of a Helm Chart

```
mychart/
  ├── Chart.yaml          # Metadata about the chart
  ├── values.yaml         # Default configuration values
  ├── charts/             # Directory containing dependencies
  ├── templates/          # Directory of templates that generate Kubernetes manifests
  │   ├── deployment.yaml
  │   ├── service.yaml
  │   ├── _helpers.tpl    # Template helpers
  │   └── ...
  └── README.md           # Optional: documentation
```

#### Hands-on: Creating Your First Chart

```bash
# Create a new chart called "my-webapp"
helm create my-webapp

# Look at the chart's structure
ls -la my-webapp/

# Examine the default files
cat my-webapp/Chart.yaml
cat my-webapp/values.yaml
```

### Values and Templates: Customizing Charts

#### What are Values?
Values provide a way to customize charts without modifying their templates. They're defined in the `values.yaml` file and can be overridden at install time.

#### What are Templates?
Templates are Kubernetes manifest files that have been templatized with the Go templating language. They use values to generate the final manifests.

#### Helm Chart Template Rendering Process

```
  VALUES                        TEMPLATES                RENDERED MANIFESTS
  +----------------+            +----------------+       +----------------+
  | replicas: 3    |            | apiVersion: ... |      | apiVersion: ... |
  | image: nginx   |            | kind: Deploy... |      | kind: Deploy... |
  | port: 80       |  --------> | spec:           | ---> | spec:           |
  |                |  Rendered  |   replicas:{{.V | Sent | replicas: 3     |
  |                |    with    |   containers:   |  to  | containers:     |
  |                |  Templates |    - image:{{.V | K8s  |  - image: nginx |
  +----------------+            +----------------+       +----------------+
```

#### Hands-on: Customizing a Chart

```bash
# Look at the default values
cat my-webapp/values.yaml

# Examine one of the templates
cat my-webapp/templates/deployment.yaml
```

Let's modify `values.yaml` to customize our application:

```yaml
# Original values.yaml snippet
image:
  repository: nginx
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: ""
```

```yaml
# Modified values.yaml snippet
image:
  repository: httpd
  pullPolicy: Always
  tag: "2.4"
```

### Releasing Charts: Installation and Management

#### What is a Release?
A release is an instance of a chart running in a Kubernetes cluster. When you install a chart, Helm creates a new release.

#### Hands-on: Installing a Chart

(Note: Helm release names must be unique within a namespace. If you re-run `helm install` with the same release name, it will fail. Use `helm upgrade --install <release-name> ...` for idempotent operations, or `helm uninstall <release-name>` before re-installing.)

```bash
# Install a chart from a repository (e.g., WordPress from Bitnami)
# Ensure you uninstall previous releases if using the same name or use different names.
helm uninstall my-wordpress-release --namespace default # Optional: cleanup previous
helm install my-wordpress-release bitnami/wordpress --namespace default

# Install with custom values
helm uninstall my-wordpress-custom --namespace default # Optional: cleanup previous
helm install my-wordpress-custom bitnami/wordpress --namespace default \
  --set wordpressUsername=admin \
  --set wordpressPassword=password

# Install with a values file
echo 'wordpressUsername: admin
wordpressPassword: password' > custom-values.yaml
helm uninstall my-wordpress-valuesfile --namespace default # Optional: cleanup previous
helm install my-wordpress-valuesfile bitnami/wordpress --namespace default -f custom-values.yaml

# Check the status of a release
helm status my-wordpress-release --namespace default
```

### Release Lifecycle Management

Helm provides robust lifecycle management for your chart releases:

```
  +----------+   install    +----------+   upgrade    +----------+
  |          |------------->|          |------------->|          |
  |   Chart  |              | Release  |              | Release  |
  |          |<-------------|  v1      |<-------------|  v2      |
  +----------+   uninstall  +----------+   rollback   +----------+
                                 |
                                 | list/status/history
                                 v
                            +-----------+
                            |           |
                            | helm CLI  |
                            |           |
                            +-----------+
```

#### Hands-on: Managing Release Lifecycle

## 6. Advanced Helm Techniques

### Chart Dependencies

Helm charts can have dependencies on other charts. These dependencies are defined in the `Chart.yaml` file.

```
       Parent Chart
  +-------------------+
  |                   |
  |    my-webapp      |
  |                   |
  +-------------------+
           |
           |
           v
  +------------------+------------------+------------------+
  |                  |                  |                  |
  | mongodb (dep)    | redis (dep)      | common (lib)     |
  |                  |                  |                  |
  +------------------+------------------+------------------+
  | version: 10.0.0  | version: 12.0.0  | version: 1.0.0   |
  | repo: bitnami    | repo: bitnami    | repo: local      |
  | condition: true  | condition: true  | library: true    |
  +------------------+------------------+------------------+
```

```yaml
dependencies:
  - name: postgresql
    version: 10.3.18
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
```

To manage dependencies:

```bash
# Update chart dependencies
helm dependency update my-chart

# List chart dependencies
helm dependency list my-chart
```

### Chart Hooks

Hooks allow chart developers to intervene at certain points in a release's lifecycle. Common hooks include:

- `pre-install`: Executes before any resources are created
- `post-install`: Executes after all resources are created
- `pre-delete`: Executes before deletion of the release
- `post-delete`: Executes after deletion of the release
- `pre-upgrade`: Executes before upgrade
- `post-upgrade`: Executes after upgrade
- `pre-rollback`: Executes before rollback
- `post-rollback`: Executes after rollback

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ .Release.Name }}-db-init
  annotations:
    "helm.sh/hook": post-install
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
      - name: db-init
        image: postgres:alpine
        command: ["psql", "-c", "CREATE DATABASE app;"]
      restartPolicy: Never
```

### Library Charts

Library charts provide reusable templates that can be shared across multiple charts.

```bash
# Create a library chart
helm create common --starter=library

# Use a library chart in another chart
# In Chart.yaml of the consuming chart:
dependencies:
  - name: common
    version: 0.1.0
    repository: file://../common
```

## 7. Packaging and Sharing Charts

### Creating a Chart Repository

You can create your own chart repository using various methods:

#### Using GitHub Pages

```bash
# Package your chart
helm package my-webapp/ -d repo/

# Generate an index file
helm repo index repo/

# Push to GitHub Pages
git add repo/
git commit -m "Add chart repository"
git push origin main
```

## 8. Helm Best Practices

### Security Best Practices

- **Don't store secrets in values files**: Use external secret management like Kubernetes Secrets, Vault, or Sealed Secrets
- **Use image digest instead of tags**: For production charts, use immutable image references
- **Validate input**: Use schema validation for values
- **Set resource limits**: Always define resource requests and limits

### Chart Design Best Practices

- **Keep charts modular**: Split complex applications into multiple charts
- **Use helpers for common patterns**: Move repeated template logic to _helpers.tpl
- **Document values**: Add comments to values.yaml to explain each option
- **Version your charts**: Follow semantic versioning principles

```yaml
# Example values.yaml with good documentation
# -- Number of replicas to deploy
replicaCount: 1

image:
  # -- Container image repository
  repository: nginx
  # -- Container image pull policy
  pullPolicy: IfNotPresent
  # -- Overrides the image tag whose default is the chart appVersion
  tag: ""

# -- Pod security context
securityContext: {}
```

### Automation Best Practices

- **Automate releases**: Use CI/CD pipelines to manage releases
- **Use Helm Diff**: Preview changes before applying with the helm-diff plugin
- **Maintain a chart repository**: Keep all your organization's charts in a central repository
- **Test charts thoroughly**: Automated testing ensures chart quality

## 9. Next Steps on Your Helm Journey


- [Helm Documentation](https://helm.sh/docs/)
- [Artifact Hub](https://artifacthub.io) for discovering charts
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Chart Testing](https://github.com/helm/chart-testing)
- [Helm Community](https://helm.sh/community/)

Remember, Helm makes Kubernetes applications more manageable, but it's still important to understand the underlying Kubernetes resources!