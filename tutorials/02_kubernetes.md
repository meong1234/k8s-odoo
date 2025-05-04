# Kubernetes Workshop: From Container to Cloud Native

## 1. Why Kubernetes? The Challenge of Container Orchestration

As organizations adopt containers, they quickly face new challenges:

- Managing hundreds or thousands of containers manually is impossible
- Ensuring high availability and fault tolerance is complex
- Scaling containers up and down based on demand requires automation
- Networking between containers needs consistent management
- Storage management for stateful applications is tricky
- Rolling updates and rollbacks must be handled gracefully

Kubernetes solves these problems by providing **container orchestration**.

## 2. What is Kubernetes? A Simple Explanation

**Kubernetes** (K8s) is an open-source platform for automating the deployment, scaling, and operations of containerized applications.

> 🖼️ **Analogy**: If Docker is like a shipping container, Kubernetes is like the entire shipping logistics system—coordinating which containers go where, ensuring they arrive safely, replacing damaged ones, and scaling operations based on demand.

### Origins of Kubernetes

- Developed by Google, based on their internal system called Borg
- The name "Kubernetes" comes from Greek, meaning "helmsman" or "pilot"
- Donated to the Cloud Native Computing Foundation (CNCF) in 2014
- Now maintained by a large open-source community

## 3. Kubernetes Architecture: The Big Picture

Kubernetes has a distributed architecture with various components working together:

### Control Plane Components (Master Node)

- **API Server**: The front-end interface for Kubernetes
- **etcd**: A distributed key-value store for all cluster data
- **Scheduler**: Places containers on appropriate nodes
- **Controller Manager**: Ensures the desired state matches the actual state
- **Cloud Controller Manager**: Interfaces with cloud provider APIs

### Node Components (Worker Node)

- **Kubelet**: Ensures containers are running in a pod
- **Container Runtime**: Software responsible for running containers (e.g., Docker)
- **Kube-proxy**: Handles network communication to and from pods

![Kubernetes Architecture](https://d33wubrfki0l68.cloudfront.net/2475489eaf20163ec0f54ddc1d92aa8d4c87c96b/e7c81/images/docs/components-of-kubernetes.svg)

## 4. Setting Up Your First Kubernetes Cluster

Let's get our hands dirty with some practical examples:

### Local Development Options

#### Minikube
Perfect for beginners and local development:
(Note: For Windows/Linux installation, please refer to the [official Minikube documentation](https://minikube.sigs.k8s.io/docs/start/))

```bash
# Install Minikube (macOS example)
brew install minikube

# Start a cluster
minikube start

# Access dashboard
minikube dashboard
```

#### Kind (Kubernetes IN Docker)
Another lightweight option:
(Note: For Windows/Linux installation, please refer to the [official Kind documentation](https://kind.sigs.k8s.io/docs/user/quick-start/#installation))

```bash
# Install Kind (macOS example)
brew install kind

# Create a cluster
kind create cluster --name my-cluster

# Verify installation
kubectl get nodes
```

### Installing kubectl

kubectl is the command-line tool for interacting with Kubernetes:

```bash
# For macOS
brew install kubectl

# For Ubuntu
sudo apt-get update && sudo apt-get install -y kubectl

# Verify installation
kubectl version --client
```

## 5. Basic Kubernetes Components

### Pods

#### What is a Pod?
The smallest deployable unit in Kubernetes—a group of one or more containers that share storage and network resources. Pods are ephemeral by nature, which means they can be created, destroyed, and recreated as needed.

```
            POD
    +---------------------+
    |   +-------------+   |
    |   | Container 1 |   |
    |   +-------------+   |
    |                     |
    |   +-------------+   |     Shared:
    |   | Container 2 |   |     - Network namespace
    |   +-------------+   |     - Storage volumes
    |                     |     - IPC namespace
    |   +-------------+   |
    |   | Container 3 |   |
    |   +-------------+   |
    +---------------------+
             |
             |
    +---------------------+
    |    Pod IP Address   |
    +---------------------+
```

#### Key Characteristics of Pods:
- Contains one or more containers
- Shares a network namespace (containers can communicate via localhost)
- Has a unique IP address within the cluster
- Is ephemeral (not designed to survive scheduling failures or node crashes)

#### Hands-on: Creating a Simple Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-first-pod
spec:
  containers:
  - name: nginx
    image: nginx:1.19
    ports:
    - containerPort: 80
```

### Services

#### What is a Service?
Services provide a consistent way to access your pods, acting as an abstraction layer that defines a logical set of pods and a policy to access them. Since pods are ephemeral, services allow clients to reliably discover and connect to containers running in the pods.

```
                   Service: my-service
                   ClusterIP: 10.0.0.1
                          +
                          |
                          v
    +------------------------------------------+
    |                                          |
    |  +----------+    +----------+           |
    |  |          |    |          |           |
    |  |  Pod 1   |    |  Pod 2   |           |
    |  |app=myapp |    |app=myapp |           |
    |  |          |    |          |           |
    |  +----------+    +----------+           |
    |                                          |
    +------------------------------------------+
                   Service Selector:
                     app: myapp
```

#### Types of Services:
- **ClusterIP**: Exposes the service internally within the cluster (default)
- **NodePort**: Exposes the service on each Node's IP at a static port
- **LoadBalancer**: Exposes the service externally using a cloud provider's load balancer
- **ExternalName**: Maps the service to a DNS name

#### Hands-on: Creating a Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### ConfigMaps

#### What is a ConfigMap?
ConfigMaps allow you to decouple configuration from container images, making your applications more portable. They store non-confidential data in key-value pairs that can be consumed by pods as environment variables, command-line arguments, or configuration files.

#### When to Use ConfigMaps:
- Application configuration
- Setting environment variables
- Populating configuration files

#### Hands-on: Working with ConfigMaps

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_host: "db.example.com"
  database_port: "5432"
  config.json: |
    {
      "environment": "development",
      "debug": true
    }
```

### Secrets

#### What is a Secret?
Secrets are similar to ConfigMaps but designed to hold sensitive information such as passwords, OAuth tokens, and SSH keys. They help prevent exposing confidential data in your application stack.

#### Best Practices for Secrets:
- Use Kubernetes Secrets for short-lived credentials
- Consider external secret management for production (HashiCorp Vault, AWS Secrets Manager)
- Enable encryption at rest for your secrets

#### Hands-on: Creating and Using Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  username: YWRtaW4=  # base64 encoded "admin"
  password: cGFzc3dvcmQxMjM=  # base64 encoded "password123"
```

## 6. Kubernetes Controllers

### ReplicaSets

#### What is a ReplicaSet?
ReplicaSets ensure that a specified number of pod replicas are running at any given time. They provide self-healing capabilities by automatically creating new pods when existing ones fail, get deleted, or are terminated.

#### Key Features:
- Maintains a stable set of replica pods
- Ensures the specified number of pods are running
- Replaces pods that are deleted or terminated

#### Hands-on: Creating a ReplicaSet

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
```

### Deployments

#### What is a Deployment?
Deployments provide declarative updates for ReplicaSets and Pods. They allow you to describe an application's lifecycle, such as which images to use, the number of pods, and how to update them.

```
  DEPLOYMENT
  +----------------------------------+
  |                                  |
  |  REPLICASET                      |
  |  +----------------------------+  |
  |  |                            |  |
  |  |  POD          POD          |  |
  |  |  +------+     +------+     |  |
  |  |  |      |     |      |     |  |
  |  |  |      |     |      |     |  |
  |  |  +------+     +------+     |  |
  |  |                            |  |
  |  |  POD          POD          |  |
  |  |  +------+     +------+     |  |
  |  |  |      |     |      |     |  |
  |  |  |      |     |      |     |  |
  |  |  +------+     +------+     |  |
  |  |                            |  |
  |  +----------------------------+  |
  |                                  |
  +----------------------------------+
```

#### Key Benefits of Deployments:
- Manages ReplicaSets for you
- Provides rolling updates and rollbacks
- Maintains deployment history
- Pauses and resumes deployments

#### Hands-on: Working with Deployments

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
        ports:
        - containerPort: 80
```

### StatefulSets

#### What is a StatefulSet?
StatefulSets are specialized workload controllers designed for stateful applications. Unlike Deployments, StatefulSets provide guarantees about the ordering and uniqueness of Pods.

#### When to Use StatefulSets:
- Database clusters (MySQL, PostgreSQL, MongoDB)
- Applications requiring stable, unique network identifiers
- Applications requiring persistent storage
- Applications requiring ordered, graceful deployment and scaling

#### Hands-on: Creating a StatefulSet

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx"
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```

## 7. Health Checks and Self-Healing

### Readiness Probes

#### What is a Readiness Probe?
Readiness probes determine when a container is ready to start accepting traffic. A pod is considered ready when all of its containers are ready. Services only send traffic to pods that are ready.

#### When to Use Readiness Probes:
- Applications that need time to load configuration or data
- Services that depend on other services
- Containers that need initialization time

#### Types of Readiness Probes:
- HTTP GET requests
- TCP socket checks
- Exec commands

#### Hands-on: Configuring Readiness Probes

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
  - name: web-app
    image: my-web-app:1.0
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
```

### Liveness Probes

#### What is a Liveness Probe?
Liveness probes determine if a container is running properly. If the liveness probe fails, Kubernetes will restart the container to try to fix the issue.

#### When to Use Liveness Probes:
- Applications that might crash but not terminate
- Applications that could enter a deadlock state
- Long-running applications that need to recover from temporary issues

#### Hands-on: Configuring Liveness Probes

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
  - name: web-app
    image: my-web-app:1.0
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 3
      periodSeconds: 3
```

### Combining Probes for Robust Applications

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: robust-app
spec:
  containers:
  - name: app
    image: my-app:1.0
    ports:
    - containerPort: 8080
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 5
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 15
      periodSeconds: 10
```

## 8. Storage in Kubernetes

### Volumes

#### What is a Volume?
A volume is a directory accessible to all containers in a pod. Kubernetes supports many types of volumes, allowing data to survive container restarts within a pod.

#### Types of Volumes:
- **emptyDir**: Temporary storage for a pod (deleted when pod is removed)
- **hostPath**: Mounts a file or directory from the host node's filesystem
- **configMap/secret**: Mounts a ConfigMap or Secret as a volume
- **cloud provider specific**: EBS, Azure Disk, GCE Persistent Disk

#### Hands-on: Using an emptyDir Volume

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cache-pod
spec:
  containers:
  - name: cache-container
    image: nginx:1.19
    volumeMounts:
    - mountPath: /cache
      name: cache-volume
  volumes:
  - name: cache-volume
    emptyDir: {}
```

### Persistent Volumes (PV)

#### What is a Persistent Volume?
A Persistent Volume is a piece of storage in the cluster that has been provisioned by an administrator or dynamically provisioned using Storage Classes. PVs have a lifecycle independent of any pod that uses them.

#### Key Concepts:
- Cluster resource managed by administrators
- Available to pods regardless of their lifecycle
- Supports various storage backends
- Can be provisioned statically or dynamically

#### Hands-on: Creating a Persistent Volume

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: block-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard # This can be a generic name or a specific one
  # hostPath is suitable for single-node clusters like Minikube or Kind for development.
  # It is NOT recommended for production or multi-node clusters as data is tied to a specific node.
  hostPath:
    path: /data/my-app-data # Ensure this path exists on your node or is DirectoryOrCreate
    type: DirectoryOrCreate
```

### Persistent Volume Claims (PVC)

#### What is a Persistent Volume Claim?
A Persistent Volume Claim is a request for storage by a user. It is similar to a pod in that pods consume node resources and PVCs consume PV resources.

```
  Admin Creates                User Creates              User Creates
  +-------------+              +-------------+            +-------------+
  | Persistent  |  bound to    | Persistent  | used by    |             |
  | Volume (PV) |<------------>| Volume      |<---------->|     Pod     |
  |             |              | Claim (PVC) |            |             |
  +-------------+              +-------------+            +-------------+
        ^                             ^                         |
        |                             |                         |
        |                             |                         v
  +--------------------------------------------------+  +----------------+
  |                                                  |  |                |
  |               Storage Backend                    |  | Container      |
  |     (Cloud Disk, NFS, Local Storage, etc.)       |  | Volume Mount   |
  |                                                  |  |                |
  +--------------------------------------------------+  +----------------+
```

#### Key Concepts:

#### Hands-on: Creating and Using a PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-data-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mysql-pod
spec:
  containers:
  - name: mysql
    image: mysql:5.7
    env:
    - name: MYSQL_ROOT_PASSWORD
      value: "password"
    volumeMounts:
    - mountPath: "/var/lib/mysql"
      name: mysql-data
  volumes:
  - name: mysql-data
    persistentVolumeClaim:
      claimName: mysql-data-claim
```

### Storage Classes

#### What is a Storage Class?
Storage Classes help administrators describe the "classes" of storage they offer. They enable dynamic volume provisioning, allowing PVCs to automatically create PVs based on the requested storage class.

#### Key Benefits:
- Dynamic provisioning of volumes
- Different quality of service levels (SSD, HDD)
- Reclaim policies for released volumes
- Volume expansion capabilities

#### Hands-on: Creating a Storage Class

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
# The provisioner depends on your Kubernetes environment.
# For AWS: kubernetes.io/aws-ebs
# For GCE: kubernetes.io/gce-pd
# For Azure: kubernetes.io/azure-disk
# For local KinD clusters, local-path-provisioner is often used by default (storageclass: standard).
# This example uses AWS EBS.
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2 # Cloud provider-specific parameters
  fsType: ext4
reclaimPolicy: Retain # Or Delete
allowVolumeExpansion: true
```

## 9. Namespaces and Resource Management

### What are Namespaces?
Namespaces provide a mechanism for isolating groups of resources within a cluster. They are particularly useful in environments where multiple teams or projects share a Kubernetes cluster, allowing you to divide cluster resources between multiple users.

```
                        Kubernetes Cluster
  +------------------------------------------------------------------+
  |                                                                  |
  |  Namespace: dev                   Namespace: prod                |
  |  +-------------------------+      +-------------------------+    |
  |  |                         |      |                         |    |
  |  | +------+  +----------+  |      | +------+  +----------+  |    |
  |  | | Pods |  | Services |  |      | | Pods |  | Services |  |    |
  |  | +------+  +----------+  |      | +------+  +----------+  |    |
  |  |                         |      |                         |    |
  |  | +------+  +----------+  |      | +------+  +----------+  |    |
  |  | | Conf |  | Secrets  |  |      | | Conf |  | Secrets  |  |    |
  |  | | Maps |  |          |  |      | | Maps |  |          |  |    |
  |  | +------+  +----------+  |      | +------+  +----------+  |    |
  |  +-------------------------+      +-------------------------+    |
  |                                                                  |
  +------------------------------------------------------------------+
```

### When to Use Namespaces:
- Multi-tenant environments where multiple teams use the same cluster
- Staging and production environments on the same cluster
- Resource organization and isolation
- Access control for different teams

### Resource Management

#### Resource Requests and Limits
Kubernetes allows you to specify how much CPU and memory each container needs (requests) and the maximum it can use (limits).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
  - name: resource-demo-container
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

#### Workshop Exercise: Observe Resource Utilization
1. Apply the above pod configuration
2. Check resource usage: `kubectl top pod resource-demo`
3. Try creating a pod that exceeds your cluster's resources

### Hands-on: Working with Namespaces

```bash
# Create a namespace
kubectl create namespace development

# Deploy to a specific namespace
kubectl apply -f deployment.yaml --namespace=development

# List resources in a specific namespace
kubectl get pods --namespace=development

# Set your default namespace
kubectl config set-context --current --namespace=development
```

## 10. Kubernetes Networking

### Network Policies

#### What are Network Policies?
Network Policies specify how groups of pods are allowed to communicate with each other and with external network endpoints.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### Service Discovery

Kubernetes provides built-in service discovery using DNS. Each service gets a DNS entry in the format: `<service-name>.<namespace>.svc.cluster.local`

#### Workshop Exercise: Service Discovery
1. Create two deployments in the same namespace
2. Create services for both deployments
3. From one pod, connect to the other service using its DNS name

## 11. Troubleshooting Kubernetes

### Common Issues and How to Diagnose Them

#### Pod Issues
- **Pending status**: Usually indicates resource constraints or scheduling issues
- **CrashLoopBackOff**: Container is crashing repeatedly, check logs
- **ImagePullBackOff**: Unable to pull the container image, check image name and registry credentials

#### Service Issues
- **Endpoints not populated**: Check pod labels match service selector
- **Cannot access service**: Check network policies, service type

#### Cluster Issues
- **Node NotReady**: Check node conditions and kubelet status
- **API server unavailable**: Check control plane components

### Troubleshooting Commands

```bash
# Pod troubleshooting
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl logs <pod-name> -c <container-name>  # For multi-container pods
kubectl exec -it <pod-name> -- /bin/sh

# Node troubleshooting
kubectl describe node <node-name>
kubectl get events

# Service troubleshooting
kubectl describe service <service-name>
kubectl get endpoints <service-name>
```

## 12. Next Steps on Your Kubernetes Journey

Congratulations on getting started with Kubernetes! Here's what to explore next:

- **GitOps** with tools like ArgoCD or Flux
- **Service Mesh** with Istio or Linkerd
- **Observability** with Prometheus, Grafana, and Jaeger
- **Security** with tools like OPA, Falco, and Kyverno
- **CI/CD** integration with Jenkins, GitHub Actions, or GitLab CI

### Useful Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
- [CNCF Landscape](https://landscape.cncf.io/)
- [Kubernetes Playground](https://www.katacoda.com/courses/kubernetes/playground)

Remember, Kubernetes is vast - focus on understanding the core concepts first before diving deeper into specific areas!
