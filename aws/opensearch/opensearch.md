# Amazon OpenSearch Service

## Overview

Amazon **OpenSearch** Service is AWS’s managed offering for deploying, operating, and scaling OpenSearch clusters. It supports both OpenSearch (open-source fork of Elasticsearch) and legacy Elasticsearch versions up to 7.10.

- **Use cases**: log analytics, full-text search, observability, SIEM, APM, and real-time dashboards.
- **Interfaces**: REST API, OpenSearch Dashboards, SQL/PPL, and legacy Elasticsearch APIs.
- **Deployment modes**: provisioned clusters or serverless collections.

---

## Architecture

### Core Components

| Component | Description |
|----------|-------------|
| **Domain** | Logical container for OpenSearch cluster configuration. Includes engine version, instance types, storage, access policies, endpoints|
| **Nodes** | EC2 instances running OpenSearch engine. Types: `data` (store and query), `master` (cluster coordination), `warm` (infrequent access), `ultrawarm` (S3-backend). |
| **Index** | Logical partition of searchable documents. Each index has `mappings`, `settings`, `shards`. |
| **Shard** | Horizontal partition of an index. Enables parallelism/scalability. `Shard 0` for Sept 1-5 logs. Queries are broadcast to all shards, results merged.|
| **Replica** | Redundant copy of a shard for HA and fault tolerance. |
| **Dashboards** | Visualization layer (OpenSearch Dashboards or Kibana). |

### Deployment Models

- **Provisioned**: You define instance types, instance counts, storage, and zone awareness, manual scaling. 
    - Provides full control over perf tuning and resource allocation. Ideal for predictable workloads. Requires capacity planning and monitoring. (i.e. ECS logs ingested at 500GB/day)
- **Serverless**: Auto-scales compute and storage; ideal for unpredictable workloads.
    - No instance management, autoscaling for compute and storage is based on ingestion and query volume. (pay per GB ingested, stored, queried). No ultrawarm or custom plugins. No Fine-grained access control.

---

## Setup & Configuration

### Domain Creation

```bash
aws opensearch create-domain \
  --domain-name my-search-domain \
  --engine-version OpenSearch_2.9 \
  --cluster-config InstanceType=r6g.large.search,InstanceCount=3 \
  --ebs-options EBSEnabled=true,VolumeType=gp3,VolumeSize=100 \
  --zone-awareness-enabled \
  --region us-east-1
```

### Key Settings

| Setting | Purpose |  Example |
|--------|---------|-----------|
| `InstanceType` | Choose compute class (e.g., `r6g.large.search` for Graviton2). |  `r6g.large.search` for 500GB/day with moderate query load.
| `VolumeType` | `gp3` (gen-purpose), `io1` (high IOPS), or `standard` (magenetic). | gp3 with 1000 IOPS and 500GB for indexing ECS logs|
| `ZoneAwareness` | Enables multi-AZ HA. | 3 AZs in `us-east-1` for fault tolerance.|
| `DedicatedMaster` | Adds dedicated master nodes to manage cluster state. Optional for large clusters. | 3 `c6g.medium.search` master nodes added to 12 node cluster for stabilization of shard allocation.|
| `WarmStorage` | Use UltraWarm for infrequent access. | Logs older than 30 days moved to `ultrawarm1.medium.search` nodes via **Index State Management (ISM)**|

---

## Data Ingestion

### Ingestion Methods

| Method | Description | Example |
|--------|-------------|----------|
| **OpenSearch Ingestion** | Managed pipeline service (Fluent Bit-based). Handles parsing, transformation, delivery to Opensearch | ECS Logs streamed via FireLens to opensearch ingestion, parsing JSON logs and routes to `ecs-app-logs-*` indices, includes CloudWatch Metrics.|
| **Logstash** | Popular open-source ETL tool. Supports filtering, transformations, and routing. ElasticSearch compatible.| Centralized pipeline pulls logs from Kafka, enriches with geo-IP/metadata, indexes them into OpenSearch with custom mappings/field normalizations|
| **Kinesis Firehose** | Real-time streaming ingestion. Buffers, transforms, delivers data to OpenSearch. Supports lambda for inline transformations | CloudWatch logs from multiple accounts streamed via firehose to Opensearch, with lambda functions to convert raw events into structured JSON.|
| **Lambda** | Serverless compute for custom transformation/enrichment/conditional routing before ingestion. Often used with S3, Firehose, or API Gateway. | S3 event triggers Lambda function that reads new log file, parses, extracts field, and bulk indexes into OpenSearch. |
| **Beats/Fluentd** | Lightweight agents for logs and metrics. **Fluentd** is extensible, while **Beats** are specialized (`FileBeat`, `MetricBeat`) | Filebeat runs on EC2 instances to tail `/var/log/nginx/access.log`, adds ECS metadata via processors, and ships logs to OpenSearch over HTTPS with TLS and IAM authentication.|

### Sample Fluent Bit Config

```ini
[INPUT]
  Name tail
  Path /var/log/app.log
  Tag app.logs

[OUTPUT]
  Name opensearch
  Match *
  Host my-domain.us-east-1.es.amazonaws.com
  Port 443
  Index app-logs
  AWS_Auth On
```

---

## Querying & Search

### Query Languages

| Language | Use Case |
|----------|----------|
| **DSL** | Native OpenSearch/Elasticsearch JSON syntax. |
| **SQL** | Familiar syntax for structured queries. |
| **PPL** | Pipe-based syntax for log-style exploration. |

### Sample Queries

**DSL Search**
```json
GET /logs/_search
{
  "query": {
    "match": {
      "message": "error"
    }
  }
}
```

**SQL Search**
```sql
SELECT timestamp, message FROM logs WHERE message LIKE '%error%'
```

**PPL Search**
```ppl
source=logs | where message like '%error%' | fields timestamp, message
```

---

## Security & Access Control

### IAM Integration

- Use **resource-based policies** to restrict access.
- Fine-grained access via **role mapping** and **OpenSearch Dashboards**.

### Encryption

| Type | Description |
|------|-------------|
| **At Rest** | KMS-managed keys for EBS volumes. |
| **In Transit** | TLS between nodes and clients. |
| **Node-to-Node** | Internal TLS for cluster communication. |

### Fine-Grained Access Control

- Map IAM roles to OpenSearch roles.
- Restrict access to indices, fields, or operations.

```json
{
  "rules": [
    {
      "resource": "index/logs/*",
      "permission": "read"
    }
  ]
}
```

---

## Scaling & Performance

### Scaling Strategies

| Strategy | Description |
|---------|-------------|
| **Vertical** | Increase instance size (CPU, RAM). |
| **Horizontal** | Add more nodes or shards. |
| **Shard Rebalancing** | Use Index State Management (ISM). |
| **Warm Storage** | Move cold data to UltraWarm. |

### Performance Tips

- Use **index templates** to enforce mappings.
- Avoid large documents (>100KB).
- Use **bulk indexing** for ingestion.
- Monitor with **CloudWatch** and **Dashboards**.

---

## Monitoring & Observability

### Metrics via CloudWatch

| Metric | Description |
|--------|-------------|
| `ClusterStatus.red/yellow/green` | Health status. |
| `CPUUtilization` | Node CPU usage. |
| `JVMMemoryPressure` | JVM heap usage. |
| `FreeStorageSpace` | EBS volume availability. |

### Alerting

- Use OpenSearch Dashboards or REST API.
- Notify via SNS, Slack, Chime, or webhooks.

---

## Automation & IaC

### Terraform Snippet

```hcl
resource "aws_opensearch_domain" "example" {
  domain_name           = "my-search-domain"
  engine_version        = "OpenSearch_2.9"
  cluster_config {
    instance_type       = "r6g.large.search"
    instance_count      = 3
    zone_awareness_enabled = true
  }
  ebs_options {
    ebs_enabled = true
    volume_size = 100
    volume_type = "gp3"
  }
}
```

### CDK Snippet (TypeScript)

```ts
new opensearch.Domain(this, 'SearchDomain', {
  domainName: 'my-search-domain',
  version: opensearch.EngineVersion.OPENSEARCH_2_9,
  capacity: {
    dataNodeInstanceType: 'r6g.large.search',
    dataNodes: 3,
  },
  ebs: {
    volumeSize: 100,
    volumeType: ec2.EbsDeviceVolumeType.GP3,
  },
  zoneAwareness: {
    enabled: true,
  },
});
```

---

## Maintenance & Upgrades

- **In-place upgrades** supported for OpenSearch and Elasticsearch ≤ 7.10.
- Use **Index State Management (ISM)** for lifecycle policies.
- Automate **snapshots** to S3 for backup.

---

## Migration Tips

| Source | Strategy |
|--------|----------|
| **Self-hosted Elasticsearch** | Snapshot + restore to OpenSearch. |
| **Kubernetes Elasticsearch** | Export indices, re-ingest via Logstash or OpenSearch Ingestion. |
| **ECS logs** | Use Firehose or Fluent Bit to stream to OpenSearch. |

---

Continuing the technical wiki for Amazon OpenSearch Service:

---

## Cross-Cluster Search and Replication

### Cross-Cluster Search (CCS)

Allows querying multiple OpenSearch domains across regions or accounts.

- Use case: federated search across business units or geographic regions.
- Requires domain-level trust and network connectivity.

**Configuration Steps:**

1. Enable cross-cluster search on source domain.
2. Configure remote cluster settings with endpoint and credentials.
3. Use `search.remote` syntax in queries.

**Example Query:**

```json
GET /remote_cluster:index-name/_search
{
  "query": {
    "match_all": {}
  }
}
```

### Cross-Cluster Replication (CCR)

Replicates indices from a leader domain to one or more follower domains.

- Use case: disaster recovery, geo-redundancy, read-local architecture.
- Only supported for OpenSearch 1.3+.

**Steps:**

1. Enable replication plugin.
2. Configure leader and follower domains.
3. Use `start replication` API.

**Example:**

```json
PUT /_plugins/_replication/_start
{
  "leader_alias": "leader-cluster",
  "leader_index": "logs",
  "follower_index": "logs-copy"
}
```

---

## Custom Analyzers and Tokenizers

OpenSearch supports custom analyzers for advanced text processing.

### Anatomy of an Analyzer

- **Tokenizer**: splits text into tokens.
- **Filters**: modify tokens (e.g., lowercase, stemming).
- **Char Filters**: preprocess raw text.

**Example: Custom Analyzer**

```json
{
  "settings": {
    "analysis": {
      "analyzer": {
        "custom_english": {
          "tokenizer": "standard",
          "filter": ["lowercase", "english_stop", "porter_stem"]
        }
      },
      "filter": {
        "english_stop": {
          "type": "stop",
          "stopwords": "_english_"
        }
      }
    }
  }
}
```

Use this analyzer in mappings:

```json
{
  "mappings": {
    "properties": {
      "content": {
        "type": "text",
        "analyzer": "custom_english"
      }
    }
  }
}
```

---

## Index Lifecycle Management (ILM)

OpenSearch supports automated index transitions using Index State Management (ISM).

### ISM Policy Example

```json
{
  "policy": {
    "description": "Log index lifecycle",
    "default_state": "hot",
    "states": [
      {
        "name": "hot",
        "actions": [],
        "transitions": [
          {
            "state_name": "warm",
            "conditions": {
              "min_index_age": "7d"
            }
          }
        ]
      },
      {
        "name": "warm",
        "actions": [
          {
            "replica_count": {
              "count": 0
            }
          }
        ],
        "transitions": [
          {
            "state_name": "delete",
            "conditions": {
              "min_index_age": "30d"
            }
          }
        ]
      },
      {
        "name": "delete",
        "actions": [
          {
            "delete": {}
          }
        ]
      }
    ]
  }
}
```

Attach policy to index:

```json
PUT logs-2025-09-25/_plugins/_ism/policy/log-policy
```

---

## Plugin Ecosystem

OpenSearch supports a rich plugin architecture.

### Built-in Plugins

| Plugin | Purpose |
|--------|---------|
| Alerting | Threshold-based alerts |
| Anomaly Detection | ML-based outlier detection |
| SQL | SQL query support |
| PPL | Pipe-based query language |
| k-NN | Approximate nearest neighbor search |
| Security | Fine-grained access control |

### Custom Plugins

You can build custom plugins using Java and deploy them to your domain.

- Extend query DSL
- Add new ingest processors
- Create custom visualizations

---

## Serverless OpenSearch

Amazon OpenSearch Serverless is a newer deployment model.

### Key Differences

| Feature | Provisioned | Serverless |
|--------|-------------|------------|
| Scaling | Manual | Automatic |
| Pricing | Per-node | Per-GB ingested and queried |
| Use case | Predictable workloads | Spiky or unpredictable workloads |
| Dashboards | Supported | Supported |
| IAM | Supported | Supported |

**Use case**: ingesting ECS logs with unpredictable volume, or ad-hoc search workloads.

---

## Audit Logging and Compliance

Enable audit logging for compliance and traceability.

### Events Captured

- User logins
- Index access
- Document reads/writes
- Role changes

### Configuration

Enable via domain settings or API:

```json
{
  "logPublishingOptions": {
    "AUDIT_LOGS": {
      "CloudWatchLogsLogGroupArn": "arn:aws:logs:us-east-1:123456789012:log-group:/aws/audit/opensearch"
    }
  }
}
```

---

Continuing the Amazon OpenSearch Service technical wiki:

---

# Integration Patterns with AWS Services

## ECS and Fargate

### Log Streaming from ECS Tasks

Use Fluent Bit or FireLens to stream logs from ECS containers to OpenSearch.

**FireLens Configuration (task definition):**

```json
"logConfiguration": {
  "logDriver": "awsfirelens",
  "options": {
    "Name": "opensearch",
    "Host": "search-my-domain.us-east-1.es.amazonaws.com",
    "Port": "443",
    "Index": "ecs-logs",
    "AWS_Auth": "On"
  }
}
```

- Supports both EC2 and Fargate launch types.
- Use IAM task roles for secure access.

## Lambda

### Real-Time Transformation and Ingestion

Use Lambda to preprocess data before indexing.

**Example Use Case:**

- Parse CloudWatch logs
- Enrich with metadata
- Index into OpenSearch

**Python Snippet:**

```python
import requests
import boto3
from requests_aws4auth import AWS4Auth

host = 'https://search-my-domain.us-east-1.es.amazonaws.com'
region = 'us-east-1'
service = 'es'
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, service, session_token=credentials.token)

def lambda_handler(event, context):
    document = { "message": event['detail']['log'] }
    url = host + "/lambda-logs/_doc"
    headers = { "Content-Type": "application/json" }
    response = requests.post(url, auth=awsauth, json=document, headers=headers)
    return response.status_code
```

## S3

### Indexing Documents from S3

Use OpenSearch Ingestion or Lambda to read files from S3 and index them.

**Use Case:**

- Index PDFs, logs, or CSVs stored in S3.
- Trigger ingestion via S3 event notifications.

**Workflow:**

1. S3 event triggers Lambda.
2. Lambda reads file, parses content.
3. Lambda sends structured document to OpenSearch.

---

## Cost Optimization Strategies

### Instance Selection

- Use Graviton2 (`r6g`) instances for better price/performance.
- Avoid overprovisioning master nodes unless needed.

### Storage Tiers

| Tier | Use Case | Cost |
|------|----------|------|
| Hot | Frequent access | High |
| UltraWarm | Infrequent access | Medium |
| Cold (S3) | Archival | Low |

Use ISM to transition indices across tiers.

### Query Efficiency

- Use filters instead of queries when possible.
- Avoid wildcard and regex queries on large datasets.
- Use doc-value fields for aggregations.

### Snapshot Management

- Schedule snapshots during off-peak hours.
- Store in low-cost S3 buckets.
- Use lifecycle policies to expire old snapshots.

---

## Troubleshooting and Diagnostics

### Common Issues

| Symptom | Cause | Resolution |
|--------|-------|------------|
| `ClusterStatus: red` | Shard allocation failure | Check disk space, node health |
| `Search latency high` | Unoptimized queries | Use filters, reduce result size |
| `JVM memory pressure > 85%` | Heap saturation | Increase instance size or count |
| `Indexing failures` | Mapping conflicts | Use dynamic templates or strict mappings |

### Diagnostic Tools

- OpenSearch Dashboards: node stats, index health
- CloudWatch: metrics and alarms
- `_cat` APIs: cluster introspection

**Example:**

```bash
GET /_cat/indices?v
GET /_cat/nodes?v
```

---

## Backup and Disaster Recovery

### Snapshots

- Automated daily snapshots to S3.
- Manual snapshots via API or console.

**Snapshot API:**

```json
PUT /_snapshot/my_backup/snapshot-2025-09-25
```

### Restore

- Restore to same or new domain.
- Useful for DR, migration, or testing.

**Restore API:**

```json
POST /_snapshot/my_backup/snapshot-2025-09-25/_restore
```

### Cross-Region DR

- Use CCR to replicate indices.
- Use Route 53 failover for DNS-based redirection.

---

## Compliance and Governance

### Audit Logging

- Enable via domain settings.
- Logs published to CloudWatch.
- Covers access, changes, and queries.

### Encryption

- KMS-managed keys for EBS volumes.
- TLS for all communications.
- Node-to-node encryption for internal traffic.

### Access Control

- IAM policies for domain-level access.
- Fine-grained access for index/field-level control.
- OpenSearch roles mapped to IAM identities.

---

## Alternative: ELK Stack on AWS

### ELK Stack on AWS EKS

#### 1. Architecture
- **Elasticsearch, Logstash, and Kibana** run as individual pods on EKS, often with `StatefulSets` for ES.
- **Log Shipping** via `Filebeat`, `Fluentd`, or the `Logstash agent`.
- **Networking**: Pods are exposed using Kubernetes Services, and optionally behind an AWS LoadBalancer for Kibana.

#### 2. Example: Deploy Elasticsearch StatefulSet

**elasticsearch-statefulset.yaml:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.11.1
        env:
        - name: discovery.type
          value: "single-node"   # Use for dev; for prod use cluster config
        resources:
          limits:
            memory: "4Gi"
          requests:
            memory: "2Gi"
        ports:
        - containerPort: 9200
        volumeMounts:
        - name: es-data
          mountPath: /usr/share/elasticsearch/data
      volumes:
      - name: es-data
        emptyDir: {}
```
- For **production**, configure persistent volumes & multi-node clustering.

#### 3. Example: Deploy Kibana

**kibana-deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
      - name: kibana
        image: docker.elastic.co/kibana/kibana:8.11.1
        env:
        - name: ELASTICSEARCH_HOSTS
          value: "http://elasticsearch:9200"
        ports:
        - containerPort: 5601
```
**Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: kibana
spec:
  type: LoadBalancer   # Exposes externally via AWS LB
  ports:
  - port: 5601
    targetPort: 5601
  selector:
    app: kibana
```
- Adjust security groups for your LB to restrict public access.

#### 4. Shipping EKS Application Logs

Install Filebeat or Fluentd as a **DaemonSet**:
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: filebeat
spec:
  selector:
    matchLabels:
      app: filebeat
  template:
    metadata:
      labels:
        app: filebeat
    spec:
      containers:
      - name: filebeat
        image: docker.elastic.co/beats/filebeat:8.11.1
        env:
        - name: ELASTICSEARCH_HOSTS
          value: "http://elasticsearch:9200"
        volumeMounts:
        - name: varlog
          mountPath: /var/log
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
```
- Configure Filebeat to parse container and application logs, then forward to Logstash or ES.

#### 5. Security, Scaling & Management

- Use ServiceAccount/RoleBindings for ES and Kibana pods.
- Protect Elasticsearch and Kibana with network policies and AWS SGs.
- Use Helm charts for easier versioned deployments (ex: Bitnami Elasticsearch Helm Chart).

### ELK Stack with Elastic Beanstalk (EB) & ECS

### 1. Application Log Shipping & Architecture

- Elastic Beanstalk, when running in ECS mode (Multi-Docker), streams logs to /var/log and optionally to S3.
- Use **Filebeat or Logstash** on a sidecar container or on a separate EC2/fargate service to harvest logs.
- Typically, log shipper pushes logs to Elasticsearch endpoint, then visualized in Kibana.[5][6][7][8]

### 2. Example: Docker Compose for Multi-Container EB

**Dockerrun.aws.json v2 Example:**
```json
{
  "AWSEBDockerrunVersion": 2,
  "containerDefinitions": [
    {
      "name": "app",
      "image": "myorg/app:latest",
      "essential": true,
      "memory": 512,
      "environment": [{"name":"LOG_PATH", "value":"/var/log/app.log"}],
      "mountPoints": [{"sourceVolume":"app-logs", "containerPath":"/var/log"}]
    },
    {
      "name": "filebeat",
      "image": "docker.elastic.co/beats/filebeat:8.11.1",
      "essential": false,
      "memory": 256,
      "mountPoints": [{"sourceVolume":"app-logs", "containerPath":"/var/log"}],
      "environment": [{"name":"ELASTICSEARCH_HOSTS", "value":"http://elasticsearch:9200"}]
    }
  ],
  "volumes": [
    {"name":"app-logs", "host": {"sourcePath":"/var/log"}}
  ]
}
```
- Application and log shipper share `/var/log`, allowing Filebeat to forward logs to ELK.[6][8]

### 3. Example: ECS and ELK

- Deploy ES and Kibana containers as ECS services (using Fargate or EC2 launch type).
- Use AWS CloudFormation or ECS task definitions to create networked endpoints and persistent storage for ES.
- Attach IAM policies for S3 log shipping, if used.

### Further Considerations

- For **elasticsearch**, use at least three nodes (multi-AZ recommended) and provision appropriate EBS volumes for data.[9][2]
- Secure ES and Kibana using security groups, HTTP authentication, or TLS proxies.
- For managed ELK, consider AWS OpenSearch Service (compatible APIs).
- Integrate monitoring via CloudWatch and IAM roles for observability.

***

If more detail is needed for advanced scalability, using managed Elasticsearch (OpenSearch), custom Logstash pipelines, security hardening, or automating these setups with Terraform/Helm, request a **follow-up** for extended walkthroughs.

***

**References:**  
Here’s a **technical guide** for integrating the ELK Stack (Elasticsearch, Logstash, Kibana) in **AWS EKS and EB/ECS** environments. If you need deeper details for scaling, security, or sidecar integration, please request a follow-up.[7][8][1][5][3][6][9][2][4]

***

## ELK Stack Integration on AWS EKS

### Architecture

- Deploy Elasticsearch, Logstash, and Kibana as containers or via Helm charts on EKS.[10][1][2]
- Send Kubernetes container/pod logs to Logstash or directly to Elasticsearch via Filebeat/Fluentd DaemonSet.[11][3]

### Example: Deploying Elasticsearch (StatefulSet)
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.11.1
        ports:
        - containerPort: 9200
        env:
        - name: discovery.type
          value: "single-node" # For dev/test only
        volumeMounts:
        - name: es-data
          mountPath: /usr/share/elasticsearch/data
      volumes:
      - name: es-data
        emptyDir: {}
```
- For production, configure persistent storage, cluster discovery, and resource requests/limits.[1][2]

### Kibana Example (LoadBalancer)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
      - name: kibana
        image: docker.elastic.co/kibana/kibana:8.11.1
        env:
        - name: ELASTICSEARCH_HOSTS
          value: "http://elasticsearch:9200"
        ports:
        - containerPort: 5601
---
apiVersion: v1
kind: Service
metadata:
  name: kibana
spec:
  type: LoadBalancer
  ports:
  - port: 5601
    targetPort: 5601
  selector:
    app: kibana
```
- Adjust AWS SG/Network policies for public/private access.[2][1]

### Shipping Logs via Filebeat/Fluentd

- Deploy Filebeat as a DaemonSet to forward container logs:
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: filebeat
spec:
  selector:
    matchLabels:
      app: filebeat
  template:
    metadata:
      labels:
        app: filebeat
    spec:
      containers:
      - name: filebeat
        image: docker.elastic.co/beats/filebeat:8.11.1
        env:
        - name: ELASTICSEARCH_HOSTS
          value: "http://elasticsearch:9200"
        volumeMounts:
        - name: varlog
          mountPath: /var/log
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
```
- Configure Filebeat to parse pod logs and forward to ES/Logstash.

### ELK Stack Integration for Elastic Beanstalk and ECS

#### Architecture

- EB (multi-container ECS mode) and ECS tasks can route logs to common host paths (ex: `/var/log`).
- Use `Filebeat` (sidecar) or `Logstash` for log shipping to ES.
- ES and Kibana can be deployed as ECS services (or use managed OpenSearch).

#### Dockerrun.aws.json v2 Example (EB/ECS Multi-container)
```json
{
  "AWSEBDockerrunVersion": 2,
  "containerDefinitions": [
    {
      "name": "web",
      "image": "myrepo/web:latest",
      "essential": true,
      "memory": 512,
      "mountPoints": [{"sourceVolume":"logs","containerPath":"/var/log"}]
    },
    {
      "name": "filebeat",
      "image": "docker.elastic.co/beats/filebeat:8.11.1",
      "essential": false,
      "memory": 256,
      "mountPoints": [{"sourceVolume":"logs","containerPath":"/var/log"}],
      "environment": [{"name":"ELASTICSEARCH_HOSTS","value":"http://elasticsearch:9200"}]
    }
  ],
  "volumes": [
    {"name":"logs", "host": {"sourcePath":"/var/log"}}
  ]
}
```
- Filebeat picks up logs written by your app and ships them to Elasticsearch.

#### ECS Service Task Definition Example
- Use multiple containers per task; mount shared log volumes, configure env vars.
- Deploy ES/Kibana as separate scalable services; bind security groups appropriately.

#### Best Practices

- Always scope access with IAM roles, Kubernetes RBAC, and least privilege networking
- Encrypt logs in transit (TLS) and at rest (EBS/ES).
- Use ServiceAccount/RoleBindings and network policies for security in EKS.
- For long-term storage, consider shipping logs to S3 and then ingesting to ELK via Logstash S3 plugin.
- For managed Elasticsearch and Kibana, use AWS OpenSearch Service.

