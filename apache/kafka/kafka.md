# Kafka

## Overview

- **Apache Kafka** is designed to handle large volumes of data in a scalable and fault-tolerant manner, making it ideal for use cases such as real-time analytics, data ingestion, data streaming, microservices communication, and event-driven architectures.

- An **event streaming platform** captures events *in order* and these streams of events are stored durably for processing, manipulation, and responding in real time or to be retreived later.

- **Use Cases**:
    - Messaging System
    - Activity Tracking
    - Metrics Gathering
    - Real-time customer interactions
    - Integrate with other Big Data technologies


## Architecture Components

- **Brokers**: A broker refers to a server in the Kafka storage layer that stores event streams from one or more sources. 
    - A Kafka cluster is typically comprised of several brokers.
    - Each broker is a bootstrap server, so if you connect to one, you are connected to them all.


- **Topics**: The cluster organizes and durably stores streams of events in categories called *topics*, which are *Kafka’s most fundamental unit of organization*.
    - A topic is *append-only*
    - Events are immutable. Cannot be modified after write
    - Consumer reads a log by looking for an offset
    - **Topics are ALWAYS multi-producer and multi-subscriber**. A topic can have `0+ producers` that write events to it. And `0+ consumers` that subscribe to the events

- **Partitions**: Topics are broken up into `partitions`; meaning a single topic log can be broken up into multiple logs located on different brokers.
    - Any consumer of a given topic partition will always read that partition's events in the exact same order they are written.

- **Producers**: Clients that write events, publishes messages to kafka topics.
    - Provides the Java Producer API to enable apps to send streams to a Kafka cluster.

- **Consumers**: Clients that read events from kafka topics.
    - Only the offset metadata is retained and used by consumers to control its position. So it can consume records in any order.
    - Provides the Java Consumer API to enable apps to read streams of events from a Kafka Cluster.

- **Consumer Groups**: Set of consumers working together to consume a topic.

- Kafka includes *supporting infrastructure*:
    - **Zookeeper** (legacy) or **KRaft**: Cluster coordination and metadata management.
    - **Schema Registry**: Manages Avro/JSON schemas (Confluent)
    - **Connect**: Framework for streaming data between Kafka and external systems.


```markdown
Kafka Architecture
-------------------

Producers  --->  [ Topics / Partitions ]  --->  Consumers
                  (inside Kafka Cluster)

Detailed Flow:

[ Producer(s) ]
     |
     v
+-------------------+
|  Kafka Broker(s)  |
|-------------------|
|  Topic: Orders    |-- Partition 0 --> Consumer Group A (Consumer 1)
|                   |-- Partition 1 --> Consumer Group A (Consumer 2)
|                   |-- Partition 2 --> Consumer Group B (Consumer 3)
|-------------------|
|  Topic: Payments  |-- Partition 0 --> Consumer Group C (Consumer 4)
+-------------------+
     ^
     |
[ ZooKeeper / KRaft Controller ]
(Manages cluster metadata, leader election, configs)

Key Concepts:
-------------
Producer  --> Sends messages to a topic (decides partition via key/hash or round-robin)
Topic     --> Named stream of data (split into partitions)
Partition --> Ordered, immutable sequence of messages
Broker    --> Kafka server that stores data and serves clients
Consumer  --> Reads messages from topic partitions
Consumer Group --> Set of consumers sharing work for a topic
ZooKeeper / KRaft --> Coordinates and manages metadata (KRaft in newer Kafka versions)

```

- **Replication**: Each partition of a topic has a configurable number of copies stored on different brokers.
    - A replication factor of `3`: 
        - 1 leader replica (handles reads/writes)
        - 2 follower replicas (synch with leader for redundancy)

## Kafka Streams and Kafka Connect

- **Kafka Streams**: A stream processor is anything that takes the continual stream of data from input topics, and performs some processing on the input, then produces a continual stream of data to output topics.
    - Simple processing can be done directly from producer and consumer APIs alone
    - Streams solve the problem of reprocessing data for example.


- **Kafka Connect**: Provides data integration between databases, key-value stores, indexes and Kafka brokers using sink and source connectors.
    - Two kinds of connectors are `source connectors` that act as producers, and `sink connectors` that act as consumers.
    - Meant to move data into Kafka without custom code.


### Kafka Core vs Streams

| Feature             | Kafka (Core)                          | Kafka Streams                                  |
|---------------------|--------------------------------------|------------------------------------------------|
| **Purpose**        | Messaging & event storage           | Real-time stream processing                   |
| **Data Handling**  | Just stores & delivers messages     | Processes, transforms, and enriches messages  |
| **How it Works**   | Producers write & consumers read messages | Reads Kafka topics, processes data, and writes results back |
| **Stateless/Stateful** | Stateless (just stores messages) | Supports stateful operations (e.g., windowing, joins) |
| **Deployment**     | Runs as a Kafka cluster             | Embedded in Java applications                 |

- **When to Use What?**
    - **Use Kafka** when you need a reliable message broker to transport data between systems.
    - **Use Kafka Streams** when you need to process and transform real-time data within your applications.


## Monitoring and Observability

- Export Kafka Configuration: `export KAFKA_OPTS="-javaagent:/path/to/jmx_exporter.jar=8080:/path/to/jmx_exporter_config.yaml"`

- Key Metrics to monitor:
1. Broker:
    - `kafka.server:type=BrokerTopicMetrics,name=MessagesInPerSec`
    - `kafka.server:type=BrokerTopicMetrics,name=BytesInPerSec`
    - `kafka.network:type=RequestMetrics,name=TotalTimeMs`
    - `kafka.server:type=ReplicaManager,name=UnderReplicatedPartitions`
1. Producer:
    - `kafka.producer:type=producer-metrics,client-id=*,attribute=record-send-rate`
    - `kafka.producer:type=producer-metrics,client-id=*,attribute=batch-size-avg`
1. Consumer:
    - `kafka.consumer:type=consumer-fetch-manager-metrics,client-id=*,attribute=records-consumed-rate`
    - `kafka.consumer:type=consumer-coordinator-metrics,client-id=*,attribute=commit-latency-avg`


- **Prometheus monitoring**:

```yaml
rules:
  - pattern: 'kafka.consumer<type=consumer-fetch-manager-metrics, client-id=(.+)><>records-consumed-rate'
    name: kafka_consumer_records_consumed_rate
    labels:
      client_id: "$1"
    type: GAUGE
```

```bash
# Grafana panel query
kafka_consumer_records_consumed_rate{client_id=~".+"}
```

- **Consumer Lag Monitoring**:

```bash
# Check consumer group lag
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group user-event-processors
```

- **SSL Configuration**:

```bash
# Server configuration
listeners=PLAINTEXT://localhost:9092,SSL://localhost:9093
security.inter.broker.protocol=SSL
ssl.keystore.location=/var/ssl/private/kafka.server.keystore.jks
ssl.keystore.password=password
ssl.key.password=password
ssl.truststore.location=/var/ssl/private/kafka.server.truststore.jks
ssl.truststore.password=password
ssl.client.auth=required
```

## Best Practices

- **General Best Practices**:

- Choose partition count based on target throughput/parallelism.
- Use message keys for ordering guarantees within partitions.
- Set appropriate retention policies.
- 2-4 Cores per broker at minimum.
- 32-64GB RAM, 25% to heap.
- Use SSDs for logs, and separate disks (OS and logs)
- Network 10 GBps minimum for production.

## Backup and Recovery

- **Backup and Recovery examples**:

```bash
# Mirror topics to another cluster
kafka-mirror-maker.sh \
  --consumer.config source-consumer.properties \
  --producer.config target-producer.properties \
  --whitelist "user-events|user-profiles"

# Export topic data
kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic user-events \
  --from-beginning > backup.json
```

- **High Consumer Lag**:
1. Check consumer group bakance: `kafka-consumer-groups.sh --describe`
1. Increase consumer instances/partitions.
1. Optimize consumer processing logic.

- **Broker performance issues**:
1. Monitor JVM heap usage GC logs.
1. Check disk I/O utiliation.
1. Review network bandwidth.

- **Data Loss Prevention**:
1. Set `acks=all` and `min.insync.replicas=2`
1. Enable producer idempotence