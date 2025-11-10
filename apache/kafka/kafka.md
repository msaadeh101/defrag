# Apache Kafka

## Core Concepts

**Apache Kafka** is a distributed event streaming platform capable of handling trillions of events per day.

### Key Components

- **Broker**: A kafka server that stores data and serves clients. A cluster consists of multiple brokers.

- **Topic**: A category or feed name to which records are published. Topics are partitioned for parallelism.

- **Partition**: An ordered, immutable sequence of records within a topic. Each partition is replicated across multiple brokers for fault tolerance.

- **Producer**: An application that publishes records to Kafka topics.

- **Consumer**: An application that subscribes to topics and processes records.

- **Consumer Group**: A group of consumers that cooperate to consume data from topics. Each partition is consumed by exactly one consumer in the group.

- **KRaft**: Coordination service for managing cluster metadata.

- **Offset**: A unique identifier of a record within a partition. Consumers track their position using offsets.

- **ISR (In-Sync Replica)**: Replicas that are caught up with the leader position.

### Message Flow

```txt
Producer → Topic (Partitions) → Consumer Group
              ↓
         [Partition 0] → Consumer 1
         [Partition 1] → Consumer 2
         [Partition 2] → Consumer 3
```

### Storage Model

Kafka stores messages in segments on disks:
- Each partition is divided into segments (default is 1GB or 7 days).
- Segments are immutable once closed.
- Messages are appended sequentially (O(1) writes).
- Index files enable fast lookups by offset.

#### Directory Structure

```txt
/var/lib/kafka/data/
  └── topic-name-0/           # Partition 0
      ├── 00000000000000000000.log    # Segment file
      ├── 00000000000000000000.index  # Offset index
      ├── 00000000000000000000.timeindex
      └── leader-epoch-checkpoint
```

- **Each topic partition has its own folder**, containing files that handle message storage, indexing and recovery processes.
    - `.log` is the **Segment File**, holding all the *actual Kafka messages*.
    - `.index` is the **Offset file**, allowing for fast lookup of message positions by mapping logical offsets (message numbers) to actual byte positions in the Segment file.

### Replication Protocol

1. **Leader Election**: One replica per partition is elected as a leader.
2. **ISR Management**: Leader tracks in-sync management.
3. **High Watermark**: The offset up to which all ISR have replicated.
4. **Producer Acknowledgements**:
- `acks=0`: No acknowledgement.
- `acks=1`: Leader acknowledges.
- `acks=all`: All ISR acknowledge (strongest durability).

## Local Development and CLI Operations

- Example Docker-compose.yaml (additional Kafka brokers `kafka-2`, `kafka-3` for scalability and availability):

```yaml
version: '3.8'  # Compose file version, supports modern Compose features

services:

  kafka-1:  # First Kafka broker node
    image: apache/kafka:3.7.0  # Kafka Docker image version 3.7.0
    container_name: kafka-1  # Container name to identify this instance
    environment:
      KAFKA_NODE_ID: 1  # Unique ID for this Kafka broker node
      KAFKA_PROCESS_ROLES: broker,controller  # This node acts as both broker and controller
      KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093  # Listens for client connections on 9092 and controller on 9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka-1:9092  # Hostname and port advertised to clients for this broker
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER  # Designates which listener handles controller traffic
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT  # Security protocol for listeners (plaintext, no encryption)
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093  # Nodes forming the Kafka controller quorum with their IDs and listener addresses
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3  # Kafka's internal consumer offset topic is replicated across all 3 brokers
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 3  # Replication factor for transaction states topic
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 2  # Minimum in-sync replicas required for transaction log writes
      KAFKA_LOG_DIRS: /var/lib/kafka/data  # Directory inside container to store Kafka data logs
      CLUSTER_ID: 'MkU3OEVBNTcwNTJENDM2Qk'  # Unique cluster ID, same for all brokers
    volumes:
      - kafka-1-data:/var/lib/kafka/data  # Data persisted on host for durability
    networks:
      - kafka-network  # Service connected to custom bridged network (not used in Kubernetes deployment)


  kafka-ui:  # A web-based UI tool to manage and monitor Kafka clusters
    image: provectuslabs/kafka-ui:latest
    container_name: kafka-ui
    ports:
      - "8080:8080"  # Exposes Kafka UI on host port 8080
    environment:
      DYNAMIC_CONFIG_ENABLED: 'true'  # Enables dynamic config reloads in UI
      KAFKA_CLUSTERS_0_NAME: local  # Name of the Kafka cluster in UI
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka-1:9092,kafka-2:9092,kafka-3:9092  # Bootstrap servers for UI to connect to Kafka cluster
    networks:
      - kafka-network
    depends_on:  # Ensures Kafka brokers start before Kafka UI
      - kafka-1

volumes:
  kafka-1-data:  # Persistent storage volumes for Kafka broker data

networks:
  kafka-network:  # Not used in Kubernetes
    driver: bridge
```

- Once deployed, shell scripts located in `/opt/kfaka/bin/*` are available to create topics, list topics, describe topics, produce messages, consume messages, and list consumer groups for **manual testing, and troubleshooting only**.

```bash
docker exec -it kafka-1 /opt/kafka/bin/kafka-topics.sh \
  --create \
  --topic test-topic \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 3 \
  --config retention.ms=604800000
```

## Kubernetes Deployment

- **Strimzi** provides K8 operators for running Apache Kafka. It simplifies automating tasks like provisioning Kafka clusters, managing broker lifecycle, upgrades, configuration changes and rolling restarts.

```bash
kubectl create namespace kafka
# Install Strimzi operator
kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka
# Verify operator is running
kubectl get pods -n kafka -w
```

- You can define kafka specs when you create a Strimzi Kafka manifest: `apiVersion: kafka.strimzi.io/v1beta2`

### Metrics ConfigMap

- `pattern` is a regex matched against the JMX metric names exposed by Kafka.
- **Captured groups** within parenthesis (like `(.+)`) correspond to variables `$1`, `$2`, `$3`, etc.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-metrics
  namespace: kafka
data:
  kafka-metrics-config.yml: |
    lowercaseOutputName: true
    rules:
    - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), topic=(.+), partition=(.*)><>Value
      name: kafka_server_$1_$2
      type: GAUGE
      labels:
        clientId: "$3"
        topic: "$4"
        partition: "$5"
    - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), brokerHost=(.+), brokerPort=(.+)><>Value
      name: kafka_server_$1_$2
      type: GAUGE
      labels:
        clientId: "$3"
        broker: "$4:$5"
  zookeeper-metrics-config.yml: |
    lowercaseOutputName: true
    rules:
    - pattern: "org.apache.ZooKeeperService<name0=(.+)><>(\\w+)"
      name: "zookeeper_$2"
      type: GAUGE
```

- Create Kafka topics via **CRD**:

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: user-events
  namespace: kafka
  labels:
    strimzi.io/cluster: production-cluster
spec:
  partitions: 12
  replicas: 3
  config:
    retention.ms: 604800000  # 7 days
    segment.ms: 3600000      # 1 hour
    compression.type: snappy
    min.insync.replicas: 2
    max.message.bytes: 1048576
    cleanup.policy: delete
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: order-events
  namespace: kafka
  labels:
    strimzi.io/cluster: production-cluster
spec:
  partitions: 24
  replicas: 3
  config:
    retention.ms: 2592000000  # 30 days
    segment.ms: 3600000
    compression.type: lz4
    min.insync.replicas: 2
    cleanup.policy: compact
    min.compaction.lag.ms: 86400000
```

### Kafka Connect

- **Kafka Connect** is a framework for running data pipelines that move data between Kafka and external systems. It uses Source Connectors and Sink Connectors. It enables **declarative pipeline definitions** using configuration files.

- Connector Instance example:

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaConnector
metadata:
  name: postgres-source-connector
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka-connect-cluster
spec:
  class: io.debezium.connector.postgresql.PostgresConnector
  tasksMax: 2
  config:
    database.hostname: postgres.database.svc.cluster.local
    database.port: 5432
    database.user: debezium
    database.password: ${file:/opt/kafka/external-configuration/db-credentials/password}
    database.dbname: production
    database.server.name: postgres-prod
    table.include.list: public.users,public.orders
    plugin.name: pgoutput
    publication.autocreate.mode: filtered
    slot.name: debezium_slot
    transforms: unwrap
    transforms.unwrap.type: io.debezium.transforms.ExtractNewRecordState
    transforms.unwrap.drop.tombstones: false
    key.converter: org.apache.kafka.connect.json.JsonConverter
    value.converter: org.apache.kafka.connect.json.JsonConverter
    key.converter.schemas.enable: false
    value.converter.schemas.enable: false
```

### Helm Chart Deployment

- Bitnami Kafka Helm Chart (`values.yaml`):

```yaml
# Bitnami Kafka Helm Chart
replicaCount: 3

image:
  registry: docker.io
  repository: bitnami/kafka
  tag: 3.7.0

auth:
  clientProtocol: sasl
  interBrokerProtocol: sasl
  sasl:
    mechanism: scram-sha-512
    jaas:
      clientUsers:
        - producer
        - consumer
      clientPasswords:
        - producer-password
        - consumer-password

listeners:
  client:
    protocol: SASL_PLAINTEXT
  controller:
    protocol: SASL_PLAINTEXT
  interbroker:
    protocol: SASL_PLAINTEXT
  external:
    protocol: SASL_PLAINTEXT

controller:
  replicaCount: 3
  persistence:
    enabled: true
    storageClass: fast-ssd
    size: 20Gi

broker:
  replicaCount: 3
  persistence:
    enabled: true
    storageClass: fast-ssd
    size: 100Gi
  
  resources:
    requests:
      memory: 4Gi
      cpu: 2
    limits:
      memory: 8Gi
      cpu: 4

  heapOpts: -Xms2048m -Xmx4096m

  config: |
    num.network.threads=8
    num.io.threads=8
    socket.send.buffer.bytes=102400
    socket.receive.buffer.bytes=102400
    socket.request.max.bytes=104857600
    log.retention.hours=168
    log.segment.bytes=1073741824
    offsets.topic.replication.factor=3
    transaction.state.log.replication.factor=3
    transaction.state.log.min.isr=2
    default.replication.factor=3
    min.insync.replicas=2

metrics:
  kafka:
    enabled: true
  jmx:
    enabled: true

serviceMonitor:
  enabled: true
  namespace: monitoring
  interval: 30s

zookeeper:
  enabled: false  # Using KRaft mode

kraft:
  enabled: true
```

- Install via Helm

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

kubectl create namespace kafka

helm install kafka-cluster bitnami/kafka \
  --namespace kafka \
  --values values.yaml \
  --wait

# Verify installation
kubectl get pods -n kafka
kubectl get svc -n kafka
```

## Cloud Managed Solutions

### Amazon MSK (Managed Streaming for Kafka)

- Amazon Managed Streaming for Apache Kafka (Amazon MSK) is a fully managed service that simplifies running Kafka clusters in AWS. It handles cluster infra, patches, upgrades, monitoring and security.
- MSK Connect: Managed Kafka Connect service wtihin MSK for integrating Kafka with external data sources and sinks using connector plugins.
- MSK Serverless: A serverless deployment option auto scaling Kafka capacity based on applications needs without manual provisioning.

```bash
aws kafka create-cluster \
 --cluster-name my-msk-cluster \
 --kafka-version 3.3.1 \
 --number-of-broker-nodes 3 \
 --broker-node-group-info file://broker-node-group-info.json \
 --encryption-info file://encryption-info.json \
 --client-authentication file://client-authentication.json
```
- `broker-node-group-info.json`: defines instance types, AZs, volume sizes.
- `encryption-info.json`: configures encryption at rest and in transit.
- `client-authentication.json`: sets AWS IAM or TLS authentication options.

- Create a topic using Kafka CLI on MSK:

```bash
kafka-topics.sh --create --topic my-topic --partitions 3 --replication-factor 3 --bootstrap-server b-1.mskcluster.xxx.kafka.amazonaws.com:9092
```

- Example YAML for MSK Connect (for AWS MSK or Strimzi for Kubernetes):

```yaml
apiVersion: kafka.aws/v1alpha1
kind: Connector
metadata:
  name: my-s3-sink-connector
spec:
  connectorClass: io.confluent.connect.s3.S3SinkConnector
  tasksMax: 2
  config:
    topics: my-topic
    s3.region: us-west-2
    s3.bucket.name: my-kafka-bucket
    flush.size: 1000
    aws.access.key.id: <ACCESS_KEY>
    aws.secret.access.key: <SECRET_KEY>
```

### Confluent Cloud Kafka Cluster (AWS)

- Confluent Cloud will host this cluster in AWS (could also be Azure or GCP).

```h
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.60.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

# Environment
resource "confluent_environment" "production" {
  display_name = "production"
}

# Kafka Cluster
resource "confluent_kafka_cluster" "dedicated" {
  display_name = "production-cluster"
  availability = "MULTI_ZONE"
  cloud        = "AWS"
  region       = "us-east-1"
  dedicated {
    cku = 2
  }

  environment {
    id = confluent_environment.production.id
  }
}
```

### Azure EventHubs (Kafka Protocol)

```h
resource "azurerm_eventhub_namespace" "kafka" {
  name                = "production-kafka-ns"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  capacity            = 2

  kafka_enabled = true

  network_rulesets {
    default_action = "Deny"
    
    virtual_network_rule {
      subnet_id = azurerm_subnet.kafka.id
    }

    ip_rule {
      ip_mask = "10.0.0.0/16"
      action  = "Allow"
    }
  }

  tags = {
    environment = "production"
  }
}

resource "azurerm_eventhub" "orders" {
  name                = "orders"
  namespace_name      = azurerm_eventhub_namespace.kafka.name
  resource_group_name = azurerm_resource_group.main.name
  partition_count     = 12
  message_retention   = 7
}

resource "azurerm_eventhub_authorization_rule" "producer" {
  name                = "producer-policy"
  namespace_name      = azurerm_eventhub_namespace.kafka.name
  eventhub_name       = azurerm_eventhub.orders.name
  resource_group_name = azurerm_resource_group.main.name

  listen = false
  send   = true
  manage = false
}

output "eventhub_connection_string" {
  value     = azurerm_eventhub_authorization_rule.producer.primary_connection_string
  sensitive = true
}
```

- Connect to Event Hubs:

```python
from kafka import KafkaProducer

# Connection string from Azure Portal
connection_str = "Endpoint=sb://production-kafka-ns.servicebus.windows.net/;SharedAccessKeyName=producer-policy;SharedAccessKey=<KEY>;EntityPath=orders"

# Parse connection string
parts = dict(item.split('=', 1) for item in connection_str.split(';'))
namespace = parts['Endpoint'].replace('sb://', '').replace('/', '')
sasl_plain_username = '$ConnectionString'
sasl_plain_password = connection_str

producer = KafkaProducer(
    bootstrap_servers=f'{namespace}:9093',
    security_protocol='SASL_SSL',
    sasl_mechanism='PLAIN',
    sasl_plain_username=sasl_plain_username,
    sasl_plain_password=sasl_plain_password,
    acks='all',
    compression_type='snappy'
)

producer.send('orders', b'test message')
producer.flush()
producer.close()
```

## Production Best Practices

### Capacity Planning


| Workload Type| Broker CPU| Broker Memory| Disk| Network|
|----------|-------------|-----------|-------|-------|
|**Low (`< 10MB/s`)**|2-4 cores|4-8GB|500GB SSD|1Gbps|
|**Medium (`10-50MB/s`)**|4-8 cores|8-16GB|1-2TB SSD|10Gbps|
|**High (`50-200MB/s`)**|8-16 cores|16-32GB|2-5TB NVMe|10Gbps|
|**Very High (`> 200MB/s`)**|16+ cores|32-64GB|5-10TB NVMe|25Gbps|

#### Partition Calculator

```txt
Partitions = (Target Throughput / Consumer Throughput) * Safety Factor

Example:
- Target: 100MB/s
- Consumer: 10MB/s
- Safety Factor: 1.5
- Partitions = (100/10) * 1.5 = 15 partitions
```

### Replication Strategy

- Example `.properties`:

```conf
# Minimum replicas for production
replication.factor=3
min.insync.replicas=2
# For critical data
replication.factor=5
min.insync.replicas=3
```

- `RF=3, min.isr=2`: Tolerates 1 broker failure without data loss.
- `RF=5,min.isr=3`: Tolerates 2 broker failures without data loss.
- Always set `min.isr = RF - 1` for maximum durability.

### Topic Configuration

```bash
# High throughput, short retention
kafka-topics.sh --create \
  --topic events \
  --partitions 24 \
  --replication-factor 3 \
  --config retention.ms=86400000 \
  --config segment.ms=3600000 \
  --config compression.type=lz4 \
  --config min.isync.replicas=2

# Log compaction for state
kafka-topics.sh --create \
  --topic user-state \
  --partitions 12 \
  --replication-factor 3 \
  --config cleanup.policy=compact \
  --config min.compaction.lag.ms=3600000 \
  --config delete.retention.ms=86400000 \
  --config segment.ms=3600000

# High durability, longer retention
kafka-topics.sh --create \
  --topic transactions \
  --partitions 12 \
  --replication-factor 5 \
  --config retention.ms=2592000000 \
  --config min.insync.replicas=3 \
  --config unclean.leader.election.enable=false
```

### Producer Configuration

```python
# High-throughput producer
producer = KafkaProducer(
    bootstrap_servers=['broker1:9092', 'broker2:9092', 'broker3:9092'],
    acks='all',                    # Wait for all ISR
    retries=2147483647,            # Infinite retries (with timeout)
    max_in_flight_requests_per_connection=5,  # Throughput vs ordering
    enable_idempotence=True,       # Exactly-once semantics
    compression_type='lz4',        # Good balance
    linger_ms=10,                  # Batch for 10ms
    batch_size=32768,              # 32KB batches
    buffer_memory=67108864,        # 64MB buffer
    max_request_size=1048576,      # 1MB max message
    request_timeout_ms=30000,
    delivery_timeout_ms=120000,
)

# Reliable producer (sacrifice some throughput)
producer = KafkaProducer(
    bootstrap_servers=['broker1:9092', 'broker2:9092', 'broker3:9092'],
    acks='all',
    retries=2147483647,
    max_in_flight_requests_per_connection=1,  # Strict ordering
    enable_idempotence=True,
    compression_type='snappy',
    linger_ms=0,                   # Send immediately
    batch_size=16384,
)
```

### Consumer Configuration

```python
# High-throughput consumer
consumer = KafkaConsumer(
    'my-topic',
    bootstrap_servers=['broker1:9092', 'broker2:9092', 'broker3:9092'],
    group_id='my-consumer-group',
    auto_offset_reset='earliest',
    enable_auto_commit=False,          # Manual commit for reliability
    max_poll_records=500,              # Process in batches
    max_poll_interval_ms=300000,       # 5 minutes max processing time
    session_timeout_ms=30000,          # 30 seconds
    heartbeat_interval_ms=10000,       # 10 seconds
    fetch_min_bytes=1024,              # 1KB minimum fetch
    fetch_max_wait_ms=500,             # Wait 500ms for fetch_min_bytes
    max_partition_fetch_bytes=1048576, # 1MB per partition
)

# Process with manual commit
for message in consumer:
    try:
        process_message(message)
        consumer.commit()  # Commit after successful processing
    except Exception as e:
        logger.error(f"Processing failed: {e}")
        # Handle error appropriately
```

### Multi-Datacenter Replication

- Apache Kafka MirrorMaker2 properties file:

```bash
# clusters
clusters = primary, secondary

# Primary cluster
primary.bootstrap.servers = primary-broker1:9092,primary-broker2:9092
primary.security.protocol = SSL
primary.ssl.truststore.location = /etc/kafka/primary-truststore.jks
primary.ssl.keystore.location = /etc/kafka/primary-keystore.jks

# Secondary cluster
secondary.bootstrap.servers = secondary-broker1:9092,secondary-broker2:9092
secondary.security.protocol = SSL
secondary.ssl.truststore.location = /etc/kafka/secondary-truststore.jks
secondary.ssl.keystore.location = /etc/kafka/secondary-keystore.jks

# Replication flows
primary->secondary.enabled = true
primary->secondary.topics = .*
primary->secondary.groups = .*

# Sync topic configs
sync.topic.configs.enabled = true
sync.topic.acls.enabled = true

# Performance tuning
tasks.max = 4
replication.factor = 3
offset-syncs.topic.replication.factor = 3
heartbeats.topic.replication.factor = 3
checkpoints.topic.replication.factor = 3

# Exactly-once semantics
exactly.once.source.support = enabled
```

- Deploy MirrorMaker 2 on Kubernetes:

```yaml
apiVersion: kafka.strimzi.io/v1beta2  # Strimzi custom resource API version for Kafka MirrorMaker 2
kind: KafkaMirrorMaker2                # Kind of resource, MirrorMaker2 handles Kafka cluster mirroring
metadata:
  name: mm2-cluster                   
  namespace: kafka                   
spec:
  version: 3.7.0                    # Kafka version for MirrorMaker2 container image
  replicas: 3                       # Number of MirrorMaker2 pod replicas for high availability
  connectCluster: "secondary"       # Kafka cluster where the MirrorMaker2 Kafka Connect cluster runs
  clusters:                        # List of Kafka clusters to mirror data between
  - alias: "primary"                # Reference name for source Kafka cluster
    bootstrapServers: primary-cluster-kafka-bootstrap:9093 # Kafka bootstrap endpoint for primary cluster
    tls:
      trustedCertificates:         # TLS configuration
        - secretName: primary-cluster-ca-cert    # Kubernetes Secret holding trusted CA cert for TLS
          certificate: ca.crt
  - alias: "secondary"              # Target Kafka cluster alias
    bootstrapServers: secondary-cluster-kafka-bootstrap:9093 # Kafka bootstrap endpoint for secondary cluster
    tls:
      trustedCertificates:         # TLS config for secondary cluster
        - secretName: secondary-cluster-ca-cert
          certificate: ca.crt
    config:
      config.storage.replication.factor: 3      # Replication factor for connector config storage topic
      offset.storage.replication.factor: 3      # Replication factor for offset storage topic
      status.storage.replication.factor: 3      # Replication factor for status storage topic
  mirrors:                         # List of mirroring definitions
  - sourceCluster: "primary"       # Source cluster alias to mirror from
    targetCluster: "secondary"     # Destination cluster alias to mirror to
    sourceConnector:
      tasksMax: 4                 # Maximum parallel tasks for source connector
      config:
        replication.factor: 3                      # Replication factor for mirrored topics
        offset-syncs.topic.replication.factor: 3  # Replication factor for offset sync topic
        sync.topic.acls.enabled: "true"            # Enable syncing ACLs for topics
        sync.topic.configs.enabled: "true"         # Enable syncing configs for topics
        refresh.topics.interval.seconds: 60       # Interval to refresh topic list for mirroring
    heartbeatConnector:
      config:
        heartbeats.topic.replication.factor: 3   # Replication for heartbeat topic
    checkpointConnector:
      config:
        checkpoints.topic.replication.factor: 3  # Replication for checkpoint topic
        sync.group.offsets.enabled: "true"        # Enable syncing consumer group offsets
    topicsPattern: ".*"             # Regex pattern to mirror all topics
    groupsPattern: ".*"             # Regex pattern to mirror all consumer groups
  resources:                      # Kubernetes resource requests and limits for MirrorMaker2 pods
    requests:
      cpu: "1"                   # Requested CPU resources per pod
      memory: 2Gi                # Requested memory per pod
    limits:
      cpu: "2"                   # CPU limit per pod
      memory: 4Gi                # Memory limit per pod

```

## Monitoring and Observability

### Prometheus Metrics

- Prometheus Scape Configuration:

```yaml
scrape_configs:
  - job_name: 'kafka-brokers'
    static_configs:
      - targets:
        - 'kafka-1:9404'
        - 'kafka-2:9404'
        - 'kafka-3:9404'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+):.*'
        replacement: '${1}'

  - job_name: 'kafka-connect'
    static_configs:
      - targets:
        - 'kafka-connect-1:9405'
        - 'kafka-connect-2:9405'
```

- Key Metrics to Monitor (broker topic metrics, producer send rate, consumer fetch rate):

```yaml
# Broker Metrics
- kafka_server_replicamanager_underreplicatedpartitions
- kafka_controller_kafkacontroller_activecontrollercount
- kafka_network_requestmetrics_totaltimems
- kafka_server_brokertopicmetrics_messagesinpersec
- kafka_server_brokertopicmetrics_bytesinpersec
- kafka_server_brokertopicmetrics_bytesoutpersec

# Producer Metrics
- kafka_producer_record_send_rate
- kafka_producer_record_error_rate
- kafka_producer_request_latency_avg

# Consumer Metrics
- kafka_consumer_fetch_manager_records_consumed_rate
- kafka_consumer_fetch_manager_records_lag_max
- kafka_consumer_coordinator_commit_latency_avg
```

- Alert Manager Rules (Broker Down, High Disk Usage, Consumer Lag, Request latency):

```yaml
groups:
- name: kafka_alerts
  interval: 30s
  rules:
  - alert: KafkaUnderReplicatedPartitions
    expr: kafka_server_replicamanager_underreplicatedpartitions > 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Kafka has under-replicated partitions"
      description: "Kafka broker {{ $labels.instance }} has {{ $value }} under-replicated partitions"

  - alert: KafkaNoActiveController
    expr: sum(kafka_controller_kafkacontroller_activecontrollercount) != 1
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "No active Kafka controller"
      description: "Kafka cluster has {{ $value }} active controllers (should be 1)"

  - alert: KafkaHighProducerRequestLatency
    expr: kafka_producer_request_latency_avg > 1000
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High producer request latency"
      description: "Producer latency is {{ $value }}ms on {{ $labels.instance }}"

  - alert: KafkaConsumerLag
    expr: kafka_consumer_fetch_manager_records_lag_max > 10000
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "High consumer lag"
      description: "Consumer group {{ $labels.group }} has lag of {{ $value }} records"

  - alert: KafkaBrokerDown
    expr: up{job="kafka-brokers"} == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Kafka broker is down"
      description: "Kafka broker {{ $labels.instance }} is down"

  - alert: KafkaHighDiskUsage
    expr: (kafka_log_log_size / kafka_log_log_size_limit) > 0.85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High disk usage on Kafka"
      description: "Kafka disk usage is {{ $value | humanizePercentage }} on {{ $labels.instance }}"
```

### OpenTelemetry Integration

```python
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.kafka import KafkaInstrumentor
from kafka import KafkaProducer

# Setup tracing
trace.set_tracer_provider(TracerProvider())
jaeger_exporter = JaegerExporter(
    agent_host_name="jaeger",
    agent_port=6831,
)
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(jaeger_exporter)
)

# Instrument Kafka
KafkaInstrumentor().instrument()

# Use producer with automatic tracing
producer = KafkaProducer(bootstrap_servers=['localhost:9092'])
producer.send('my-topic', b'message')  # Automatically traced
```

### File Descriptor Limits

```bash
# /etc/security/limits.conf
kafka soft nofile 100000
kafka hard nofile 100000
kafka soft nproc 32000
kafka hard nproc 32000
```

## Performance Tuning

- Kafka Broker JVM Tuning:

```bash
# /etc/kafka/jvm.properties
# Heap size (50-75% of available RAM, max 32GB)
-Xms8G
-Xmx8G
# GC settings (G1GC for Kafka)
-XX:+UseG1GC
-XX:MaxGCPauseMillis=20
-XX:InitiatingHeapOccupancyPercent=35
-XX:G1HeapRegionSize=16M
# GC logging
-Xlog:gc*:file=/var/log/kafka/gc.log:time,tags:filecount=10,filesize=100M
# Performance
-XX:+AlwaysPreTouch
-XX:+DisableExplicitGC
-XX:+ParallelRefProcEnabled
# Out of memory handling
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/var/log/kafka/heap_dump.hprof
# Monitoring
-Dcom.sun.management.jmxremote
-Dcom.sun.management.jmxremote.port=9999
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.ssl=false
```

### Optimized Kafka Streams

```java
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.kstream.KStream;

import java.util.Properties;

public class OptimizedKafkaStreams {
    
    public static KafkaStreams createOptimizedStream() {
        Properties props = new Properties();
        
        // Basic config
        props.put(StreamsConfig.APPLICATION_ID_CONFIG, "optimized-stream-app");
        props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092");
        
        // Performance tuning
        props.put(StreamsConfig.NUM_STREAM_THREADS_CONFIG, 4);  // Parallel processing
        props.put(StreamsConfig.BUFFERED_RECORDS_PER_PARTITION_CONFIG, 1000);
        props.put(StreamsConfig.COMMIT_INTERVAL_MS_CONFIG, 1000);  // Commit every 1s
        props.put(StreamsConfig.CACHE_MAX_BYTES_BUFFERING_CONFIG, 10 * 1024 * 1024);  // 10MB cache
        
        // Producer configs for output
        props.put(StreamsConfig.PRODUCER_PREFIX + "acks", "all");
        props.put(StreamsConfig.PRODUCER_PREFIX + "compression.type", "lz4");
        props.put(StreamsConfig.PRODUCER_PREFIX + "batch.size", 32768);
        props.put(StreamsConfig.PRODUCER_PREFIX + "linger.ms", 10);
        
        // Consumer configs for input
        props.put(StreamsConfig.CONSUMER_PREFIX + "fetch.min.bytes", 1048576);  // 1MB
        props.put(StreamsConfig.CONSUMER_PREFIX + "fetch.max.wait.ms", 500);
        props.put(StreamsConfig.CONSUMER_PREFIX + "max.poll.records", 500);
        
        // State store
        props.put(StreamsConfig.STATE_DIR_CONFIG, "/tmp/kafka-streams");
        props.put(StreamsConfig.ROCKSDB_CONFIG_SETTER_CLASS_CONFIG, 
                  CustomRocksDBConfig.class);
        
        // Topology
        StreamsBuilder builder = new StreamsBuilder();
        KStream<String, String> stream = builder.stream("input-topic");
        
        stream
            .filter((key, value) -> value != null)
            .mapValues(value -> value.toUpperCase())
            .to("output-topic");
        
        return new KafkaStreams(builder.build(), props);
    }
    
    // Custom RocksDB configuration
    public static class CustomRocksDBConfig implements RocksDBConfigSetter {
        @Override
        public void setConfig(String storeName, Options options, 
                            Map<String, Object> configs) {
            // Optimize RocksDB for Kafka Streams
            options.setWriteBufferSize(64 * 1024 * 1024);  // 64MB write buffer
            options.setMaxWriteBufferNumber(3);
            options.setMaxBackgroundCompactions(4);
            options.setCompressionType(CompressionType.LZ4_COMPRESSION);
            
            BlockBasedTableConfig tableConfig = new BlockBasedTableConfig();
            tableConfig.setBlockSize(16 * 1024);  // 16KB blocks
            tableConfig.setBlockCacheSize(100 * 1024 * 1024);  // 100MB cache
            tableConfig.setCacheIndexAndFilterBlocks(true);
            options.setTableFormatConfig(tableConfig);
        }
    }
}
```

### Performance Benchmarks

Bash script that automates Kafka performance: producer, consumer, and end-to-end latency tests.

1. Setup
- Define the Kafka brokers, topic name, and output dir.
- Create the test topic if it doesn't exist.
2. Producer Benchmarks
- Test throughput (`acks=0`, `acks=all`), latency, and various message sizes.
3. Consumer Benchmarks
- Tests consumer throughput and different fetch sizes.
4. End-to-end Latency
- Uses Kafka's built-in EndToEndLatency tool.
5. Cleanup
- Deletes the test topic after benchmarks.
6. Summary
- Extracts and compiles performance metrics into a summary file.

## Security and Authentication

### Authentication

Kafka Supports:
- **SSL/TLS Client Authentication (mTLS)**: Mutual TLS where both client and broker present certificates.
- **SASL (Simple Authentication and Security Layer)**:
    - **SASL/PLAIN**: Username/password over secured connection (TLS).
    - **SASL/SCRAM**: Secure password-based authentication with salted hashes.
    - **SASL/GSSAPI**: Kerberos integration for enterprise environments.
    - **SASL/OAUTHBEARER**: OAuth token-based authentication.

Encryption:
- Encryption in Transit: TLS encrypts data sent between clients and brokers, and between brokers themselves.
- Encryption at Rest: Supports encrypting data stored on disk using filesytem or cloud storage encryption features.

### Authorization

Kafka ACLs control which clients can read/write to topics or perform administrative operations.

```txt
listeners=PLAINTEXT://:9092,SSL://:9093,SASL_SSL://:9094
listener.security.protocol.map=PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_SSL:SASL_SSL
```

## Disaster Recovery

- Replication: Data is replicated across multiple brokers based on topic replication factor to survive broker/node failures.
- MirrorMaker 2: Tool to replicate topics across Kafka clusters.
- Tiered Storage: Offload older topic data to lower-cost long-term storage.
- Backup and Restore: Use backup tools to capture Kafka data snapshots for recovery.

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaMirrorMaker2
metadata:
  name: mm2
spec:
  clusters:
    - alias: primary
      bootstrapServers: primary-cluster:9093
    - alias: secondary
      bootstrapServers: secondary-cluster:9093
  mirrors:
    - sourceCluster: primary
      targetCluster: secondary
      topicsPattern: ".*"
```