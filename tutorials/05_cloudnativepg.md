# CloudNative PostgreSQL Workshop: Managing PostgreSQL on Kubernetes

## 1. Why CloudNative PostgreSQL? The Challenge of Database Management on Kubernetes

Running stateful applications like databases in Kubernetes presents unique challenges:

- Traditional database management requires specialized knowledge and operations
- Achieving high availability and disaster recovery is complex
- Implementing proper backup and restore mechanisms is crucial but difficult
- Scaling databases requires careful planning and execution
- Security and access management need special attention
- Performance tuning is essential but can be challenging in containerized environments

**CloudNative PostgreSQL** solves these problems by providing a Kubernetes operator specifically designed for PostgreSQL databases.

## 2. What is CloudNative PostgreSQL? A Simple Explanation

CloudNative PostgreSQL is a Kubernetes operator that automates the deployment and management of PostgreSQL clusters on Kubernetes.

> 🖼️ **Analogy**: If Kubernetes is the operating system for your cloud infrastructure and PostgreSQL is your database engine, CloudNative PostgreSQL is like having a dedicated database administrator working 24/7 to ensure your PostgreSQL databases are properly deployed, configured, maintained, and scaled.

```
                 +------------------+
                 |                  |
                 |   Kubernetes     |
                 |                  |
                 +---------+--------+
                           |
              +------------+-------------+
              |                          |
              v                          v
  +------------------------+   +----------------------+
  |                        |   |                      |
  |  CloudNative PG        |   |  Your Applications   |
  |  Operator              |   |                      |
  |                        |   |                      |
  +------+---------+-------+   +----------------------+
         |         |
         |         |
  +------v---+ +---v------+
  |          | |          |
  |  Postgres| |  Postgres|
  |  Primary | |  Replica |
  |          | |          |
  +----------+ +----------+
```

### Origins of CloudNative PostgreSQL

- Developed by EDB (EnterpriseDB), a major contributor to the PostgreSQL project
- First released in 2021
- Open-source project under the Apache 2.0 license
- Designed specifically for Kubernetes environments
- Built on the experience of running PostgreSQL in production for many years

## 3. CloudNative PostgreSQL Architecture: The Big Picture

CloudNative PostgreSQL implements a controller pattern to continuously monitor and manage PostgreSQL clusters:

### Core Components

- **PostgreSQL Operator**: The central controller that manages PostgreSQL clusters
- **Custom Resource Definitions (CRDs)**: Define PostgreSQL-specific resources in Kubernetes
- **PostgreSQL Instances**: The actual database pods running PostgreSQL
- **Monitoring and Metrics**: Integration with Prometheus and other monitoring tools

```
  +---------------------------------+
  |                                 |
  |  CloudNative PG Operator        |
  |                                 |
  +---------------------------------+
               |
               | watches & manages
               |
               v
  +---------------------------------+
  |                                 |
  |  Cluster Custom Resource        |
  |                                 |
  +---------------------------------+
               |
               | defines
               |
               v
  +-------------+------------+------------+
  |             |            |            |
  |  Primary    |  Replica 1 |  Replica 2 |
  |  Instance   |  Instance  |  Instance  |
  |             |            |            |
  +-------------+------------+------------+
        |             |             |
        +-------------+-------------+
               |
               v
  +----------------------------------+
  |                                  |
  |  Persistent Volume Claims        |
  |  (Storage)                       |
  |                                  |
  +----------------------------------+
```

### PostgreSQL Cluster Topology

CloudNative PostgreSQL supports various cluster topologies:

- **Primary-Replica**: One primary (read-write) and multiple replicas (read-only)
- **Synchronous Replication**: Ensures data durability across multiple nodes
- **Asynchronous Replication**: Provides scalability for read operations

### Backup and Recovery

- **Consistent Backups**: Uses PostgreSQL's native mechanisms for consistent backups
- **Point-in-Time Recovery (PITR)**: Restore to any point within the retention period
- **Volume Snapshots**: Integration with CSI volume snapshots
- **Backup Storage**: Multiple options including S3-compatible object stores

## 4. Setting Up CloudNative PostgreSQL

### Prerequisites

- Kubernetes cluster (v1.19+)
- Kubernetes storage class that supports persistent volumes
- Helm (v3+) or kubectl for installation

### Installation Options

#### Using Helm

```bash
# Add the CloudNativePG Helm repository
helm repo add cnpg https://cloudnative-pg.github.io/charts

# Update your local chart repository cache
helm repo update

# Install CloudNative PostgreSQL Operator
helm install cnpg cnpg/cloudnative-pg --namespace cnpg-system --create-namespace
```

#### Using kubectl

```bash
# Install the latest release directly from GitHub
kubectl apply -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.19/releases/cnpg-1.19.0.yaml
```

### Verifying Installation

```bash
# Check if the operator is running
kubectl get pods -n cnpg-system

# Verify the CRDs are installed
kubectl get crds | grep postgresql
```

## 5. Creating Your First PostgreSQL Cluster

Let's create a simple PostgreSQL cluster to understand the basics:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-cluster-example
spec:
  instances: 3
  primaryUpdateStrategy: unsupervised

  # PostgreSQL configuration
  postgresql:
    parameters:
      shared_buffers: 256MB
      max_connections: 100
      
  # Resource requirements
  resources:
    requests:
      memory: 512Mi
      cpu: 0.5
    limits:
      memory: 1Gi
      cpu: 1.0
      
  # Storage configuration
  storage:
    size: 1Gi
    storageClass: standard
```

Apply this manifest to create your first cluster:

```bash
kubectl apply -f postgres-cluster.yaml
```

### Monitoring Cluster Creation

```bash
# Watch the cluster being created
kubectl get clusters -w

# Check the pods that are created
kubectl get pods -l cnpg.io/cluster=pg-cluster-example

# View detailed cluster information
kubectl describe cluster pg-cluster-example
```

### Understanding the PostgreSQL Cluster Resources

When you create a PostgreSQL cluster with CloudNative PostgreSQL, several Kubernetes resources are created:

```
PostgreSQL Cluster Custom Resource
              |
              v
+-------------+------------+--------------+
|             |            |              |
| StatefulSet | Services   | ConfigMaps   |
|             |            |              |
+-------------+------------+--------------+
|             |            |              |
| Secrets     | PVCs       | ServiceAccts |
|             |            |              |
+-------------+------------+--------------+
```

## 6. Connecting to Your PostgreSQL Cluster

CloudNative PostgreSQL creates several services for different connection purposes:

- **`<cluster-name>-rw`**: For read/write connections (routes to primary)
- **`<cluster-name>-ro`**: For read-only connections (load balances across replicas)
- **`<cluster-name>-r`**: For read-only connections to a specific replica

### Getting Connection Information

```bash
# Get service details
kubectl get svc -l cnpg.io/cluster=pg-cluster-example

# Get the superuser password
kubectl get secret pg-cluster-example-superuser -o jsonpath="{.data.password}" | base64 -d
```

### Connecting from Inside the Cluster

From another pod in the same namespace:

```bash
# Using the superuser credentials
psql "host=pg-cluster-example-rw port=5432 dbname=postgres user=postgres password=<superuser-password>"

# Using read-only endpoint for queries
psql "host=pg-cluster-example-ro port=5432 dbname=postgres user=postgres password=<superuser-password>"
```

### Connecting from Outside the Cluster

You can expose your PostgreSQL cluster using:

1. **Ingress** (not typically recommended for databases)
2. **LoadBalancer Service**
3. **NodePort Service**
4. **Port Forwarding** (development only)

Example of port forwarding for development:

```bash
# Forward local port 5432 to the read-write service
kubectl port-forward svc/pg-cluster-example-rw 5432:5432
```

Then connect using your PostgreSQL client:

```bash
psql "host=localhost port=5432 dbname=postgres user=postgres password=<superuser-password>"
```

## 7. High Availability and Failover

One of the key benefits of CloudNative PostgreSQL is built-in high availability.

### Understanding Failover Process

```
                      Failure Detection
                            |
                            v
+-----------------+    +---------+    +-------------------+
|                 |    |         |    |                   |
| Primary Failure |---→| Operator|---→| Promote Replica   |
|                 |    |         |    | to Primary        |
+-----------------+    +---------+    +-------------------+
                                              |
                                              v
                            +-------------------------------+
                            |                               |
                            | Update Services to Point      |
                            | to New Primary                |
                            |                               |
                            +-------------------------------+
```

### Testing Failover

You can simulate a failover by deleting the current primary pod:

```bash
# Identify the current primary
kubectl get pods -l cnpg.io/cluster=pg-cluster-example,cnpg.io/instanceRole=primary

# Delete the primary pod to trigger failover
kubectl delete pod pg-cluster-example-1

# Watch the promotion of a new primary
kubectl get pods -l cnpg.io/cluster=pg-cluster-example -w
```

The operator will:
1. Detect the primary failure
2. Promote the most suitable replica to primary
3. Reconfigure the cluster to use the new primary
4. Update the services to point to the new primary

## 8. Scaling Your PostgreSQL Cluster

CloudNative PostgreSQL makes it easy to scale your cluster horizontally (more replicas) or vertically (more resources).

### Horizontal Scaling

To add more replicas to your cluster, simply update the `instances` field in your cluster specification:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-cluster-example
spec:
  instances: 5  # Increased from 3 to 5
  # ... rest of configuration remains the same
```

Apply the updated configuration:

```bash
kubectl apply -f postgres-cluster.yaml
```

### Vertical Scaling

To increase resources for your PostgreSQL instances:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-cluster-example
spec:
  # ... other configuration remains the same
  resources:
    requests:
      memory: 1Gi    # Increased from 512Mi
      cpu: 1.0       # Increased from 0.5
    limits:
      memory: 2Gi    # Increased from 1Gi
      cpu: 2.0       # Increased from 1.0
```

Apply the updated configuration:

```bash
kubectl apply -f postgres-cluster.yaml
```

### Storage Scaling

You can also increase the storage size:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-cluster-example
spec:
  # ... other configuration remains the same
  storage:
    size: 2Gi  # Increased from 1Gi
    storageClass: standard
```

Note: Storage scaling requires that your storage class supports volume expansion.

## 9. Backup and Disaster Recovery

CloudNative PostgreSQL provides robust backup and recovery capabilities.

### Setting Up Scheduled Backups

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-cluster-example
spec:
  # ... other configuration remains the same
  backup:
    barmanObjectStore:
      destinationPath: "s3://my-bucket/pg-backups/"
      endpointURL: "https://s3.amazonaws.com"
      s3Credentials:
        accessKeyId:
          name: s3-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: s3-creds
          key: ACCESS_SECRET_KEY
      wal:
        compression: gzip
        maxParallel: 8
      data:
        compression: gzip
        immediateCheckpoint: true
        jobs: 4
    retentionPolicy: "30d"
    schedule: "0 0 * * *"  # Daily at midnight
```

### Creating a Manual Backup

```bash
# Create a backup
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: pg-cluster-example-manual-backup
spec:
  cluster:
    name: pg-cluster-example
EOF
```

### Restoring from a Backup

To restore a database from a backup, you create a new cluster with restore configuration:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-cluster-restored
spec:
  instances: 3
  # ... other configuration remains the same
  storage:
    size: 1Gi
    storageClass: standard
  bootstrap:
    recovery:
      backup:
        name: pg-cluster-example-manual-backup  # Reference to the backup resource
```

### Point-in-Time Recovery

CloudNative PostgreSQL also supports point-in-time recovery:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-cluster-pitr
spec:
  instances: 3
  # ... other configuration remains the same
  bootstrap:
    recovery:
      backup:
        name: pg-cluster-example-manual-backup
      recoveryTarget:
        targetTime: "2023-05-15 15:30:00.00000+00"  # Recover to this point in time
```

## 10. Monitoring and Observability

CloudNative PostgreSQL integrates with Prometheus and Grafana for monitoring.

### Metrics Endpoints

CloudNative PostgreSQL exposes metrics in Prometheus format on port 9187 of each PostgreSQL pod.

### Setting Up Monitoring

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-cluster-example
spec:
  # ... other configuration remains the same
  monitoring:
    enablePodMonitor: true  # Requires Prometheus Operator
```

### Key Metrics to Monitor

- **PostgreSQL Metrics**: Connection count, transaction rate, cache hit ratio
- **System Metrics**: CPU, memory, disk usage, network
- **Replication Metrics**: Replication lag, WAL generation rate
- **Operator Metrics**: Reconciliation time, error count

### Grafana Dashboards

CloudNative PostgreSQL provides pre-built Grafana dashboards that you can import:

```bash
# Get the Grafana dashboard configuration
curl -O https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/docs/src/samples/monitoring/grafana-dashboard.json

# Import this JSON into your Grafana instance
```

## 11. Advanced Configuration

CloudNative PostgreSQL provides many advanced configuration options for production use.

### Customizing PostgreSQL Configuration

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-cluster-example
spec:
  # ... other configuration remains the same
  postgresql:
    parameters:
      shared_buffers: 256MB
      work_mem: 8MB
      maintenance_work_mem: 64MB
      max_connections: 100
      max_parallel_workers: 8
      max_worker_processes: 8
      wal_buffers: 16MB
      random_page_cost: 1.1
```

### Implementing TLS

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-cluster-example
spec:
  # ... other configuration remains the same
  certificates:
    serverTLSSecret:
      name: pg-server-tls
    clientCASecret:
      name: pg-ca
    replicationTLSSecret:
      name: pg-replication-tls
  # Require SSL connections
  postgresql:
    parameters:
      ssl: "on"
      ssl_cert_file: "/tls/server.crt"
      ssl_key_file: "/tls/server.key"
      ssl_ca_file: "/tls/ca.crt"
```

### Setting Up Synchronous Replication

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-cluster-example
spec:
  instances: 3
  # ... other configuration remains the same
  minSyncReplicas: 1
  maxSyncReplicas: 2
  postgresql:
    parameters:
      synchronous_commit: "on"
```

### Database Initialization

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-cluster-example
spec:
  # ... other configuration remains the same
  bootstrap:
    initdb:
      database: appdb
      owner: appuser
      secret:
        name: appuser-secret
      postInitSQL:
        - CREATE EXTENSION pg_stat_statements;
        - CREATE SCHEMA app;
```

## 12. Troubleshooting CloudNative PostgreSQL

Common issues and how to solve them:

### Checking Operator Logs

```bash
# View operator logs
kubectl logs -n cnpg-system deployment/cnpg-controller-manager
```

### Debugging Cluster Issues

```bash
# View cluster status
kubectl describe cluster pg-cluster-example

# Check PostgreSQL instance logs
kubectl logs pg-cluster-example-1

# Access PostgreSQL directly to run diagnostics
kubectl exec -it pg-cluster-example-1 -- psql -U postgres
```

### Common Issues

1. **Cluster doesn't start**:
   - Check PVC provisioning
   - Verify resource constraints
   - Look for errors in operator logs

2. **Replication issues**:
   - Check network connectivity
   - Verify WAL archiving is working
   - Examine PostgreSQL logs for replication errors

3. **Backup failures**:
   - Verify S3 credentials and permissions
   - Check available storage
   - Look for errors in backup logs

## 13. Next Steps with CloudNative PostgreSQL

Now that you understand the basics, explore these advanced topics:

- **Multi-cluster Deployments**: Set up disaster recovery across regions
- **Integration with CI/CD Pipelines**: Automate database schema changes
- **Advanced PostgreSQL Features**: Enable extensions and add-ons
- **Performance Tuning**: Optimize for specific workloads
- **Security Hardening**: Implement defense in depth

### Useful Resources

- [CloudNative PostgreSQL Documentation](https://cloudnative-pg.io/documentation/)
- [GitHub Repository](https://github.com/cloudnative-pg/cloudnative-pg)
- [Community Slack](https://kubernetes.slack.com/) - #cnpg channel
- [EDB Website](https://www.enterprisedb.com/products/cloudnative-postgresql-kubernetes-ha-clusters-k8s-containers)

CloudNative PostgreSQL brings the power and reliability of PostgreSQL to Kubernetes in a truly cloud-native way. By handling the complex aspects of database management, it allows you to focus on your applications while providing the robustness and features that PostgreSQL is known for.