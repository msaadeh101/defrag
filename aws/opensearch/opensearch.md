# AWS OpenSearch

## Overview and Use Cases

**AWS OpenSearch Service** is a manged service that makes it easy to deploy, operate and scale the OpenSearch project/open-source ElasticSearch in AWS. Apache licensed, AWS OpenSearch takes care of cluster provisioning, scaling, monitoring, and patching

- **Real-Time Analytics**: Quickly ingest, search, and analyze large volumes of data (structured and unstructured)
- **Fully Managed**: AWS handles all overhead, hardware provisioning, patching, failure detection and backup
- **Scalability/HA**: Easily scale your clusters and deploy them across multiple AZs for HA and fault tolerance.
- **Visualization**: Includes fork of Kibana, which is a powerful tool for data visualization, charting and reporting.

| Use Case	| Description| 
|----|-----|
| **Log Analytics / Observability**	| Centralize and analyze app, infra, and network logs to monitor system health, troubleshoot issues, and gain insights into operational performance.| 
| **Full-Text Search**| Power sophisticated search functionality for websites, e-commerce stores, and application data catalogs.| 
| **Security Analytics**	| Analyze security logs (like `VPC flow logs` or `CloudTrail data`) in real-time to detect threats, monitor user activity, and perform forensic analysis.| 
| **Vector Search**| 	Use the built-in `k-nearest neighbors (k-NN)` capabilities to power machine learning-augmented search, similarity search, and generative AI applications.| 

## Technical Details and Architecture

### Core Components

1. **Search (Lucene)**: 
- The core search engine that indexes and retrieves documents, built on `Apache Lucene`. 
- It provides inverted index, relevance scoring, and query execution.
- Powers full-text search, filtering, aggregations, and features like KNN vector search, so **apps and log searches run as REST queries over Lucene-backend indices and shards**.

2. **Analytics (OpenDistro/OpenSearch)**:
- OpenSearch's distributed query and aggregation layer plus plugins originally from `Open Distro`.
- Includes `SQL`, `PPL`, Anomaly detection, alerting, security, and index management.
- Allows for use as an analytical store for logs and metrics to run aggregations, time-series queries, anomaly detection jobs and alerting workflows on the same Lucine indices used for Search.

3. **Monitoring (Dashboards)**:
- OpenSearch **Dashboards** is the web UI for exploring and visualizing data stored in OpenSearch.
- Allows you to build charts, dashboards, and **Discover views over indices and saved searches**.

### Core Concepts

- Domain (Cluster): The OpenSearch environment you provision, consisting of one or more nodes and configuration (instance types, storage, etc).

- Nodes: EC2 instances that make up the domain.
    - Data Nodes: Store the data and process search/indexing requests.
    - Dedicated Cluster Manager (Master) Nodes: Handle cluster-management tasks (tracking cluster state, index creation/deletion) to ensure stability.

- Index: A collection of documents that share similar characteristics (like a table in a relational DB).

- Shard: A portion of an index. Automatically distributes indices acorss multiple shards, which are spread across data nodes to enable horizontal scaling and parallel processing.
    - Primary Shard: Original unit of data.
    - Replica Shard: Copy of primary shard, used for redundancy and to increase throughput.

### Features

| Feature| Description| 
|----|-----------|
| **Query Languages**| Supports the native `OpenSearch DSL` (Domain-Specific Language), `SQL`, and the **Piped Processing Language** (`PPL`) for flexible data exploration.| 
| **Storage Tiers**| `Hot` (fast access, high cost), `UltraWarm` (read-only, S3-backed, cost-effective for warm data), and `Cold Storage` (for historical data).| 
| **Ingestion Integrations**| Easily loads streaming data from services like **Kinesis Data Firehose**, **S3**, **Lambda**, and **CloudWatch Logs**, and also integrates with `Logstash`.| 
| **Security**| **Encryption at Rest** (`KMS`), **Encryption in Transit** (`TLS`), and **Fine-Grained Access Control** (`FGAC`) to manage access down to the index, document, and field level.| 
| **Serverless Option**| **OpenSearch Serverless** abstracts away cluster management completely, automatically scaling compute and storage based on workload, simplifying operations for unpredictable traffic patterns.| 

## Using OpenSearch

### Typical Workflow

1. **Create an OpenSearch `Domain`/`Collection`**:
- **Managed Service (Domain)**: 
    - Specify Deployment type, Version, Instance type, node count, storage options.
    - Network configuration (VPC endpoints) and Access Policy and authentication (IAM, Cognito, or internal user db).
- **Serverless (Collection)**:
    - Choose Serverless to create a collection, selecting a type (e.g. `Search` or `Time-Series`)
    - Configure network and data access policies.

2. **Ingesting Data (`Indexing`)**: Once domain/collection is active, you load data by `indexing` using the following.
- **AWS Services**: Set up pipeline using `Data Firehose` or `Lambda` to stream data from sources (`S3`, `Kinesis`, `DynamoDB`, `CloudWatch`) directly into your OpenSearch Domain.
- **OpenSearch Ingestion**: Use *the managed ingestion pipelines* for ETL before indexing.
- **OpenSearch API**: Use client libraries or tools like `Logstash` to send data to your domain's endpoint via *Bulk API* (for high-volume ingestion).

3. Searching and Visualization:
- **OpenSearch Dashboards**: Access the URL provided in the domain's details.
    - **Discover**: Search, filter, explore raw data.
    - **Visualize**: Create charts, graphs, and maps.
    - **Dashboard**: Combine multiple viz into a unified view.
- **API/Code**: Use the API with a programming language to integrate search functionality into your apps.
    - Send JSON-formatted query to the cluster's endpoint and receive results including `relevance score` for each document.


## Best Practices

1. **Index Design**
- Time-based indices: Use daily/weekly indices for logs (`logs-2024-01-01`)
- Shard sizing: `10-50GB` per shard, avoid >1000 shards per cluster
- Index templates: Standardize mappings and settings

2. **Performance**
- Bulk operations: Use bulk API with `5-15MB` payloads.
- Refresh interval: Increase to `30s` for indexing-heavy workloads.
- Search throttling: Implement circuit breakers in client applications.

3. **Operations**
- Blue/green deployments: Use in-place version upgrades for zero downtime.
- Snapshot lifecycle: Automate backups with retention policies.
- Monitoring: Track shard count, JVM pressure, disk usage.

4. **Security**
- Network isolation: Use VPC endpoints with security groups.
- Encryption: Enable at-rest and in-transit encryption.
- Access control: Implement FGAC with IAM roles.

5. **Cost Management**
- Storage tiers: Use UltraWarm for older data.
- Instance right-sizing: Monitor utilization and adjust instance types.
- Reserved instances: Commit to 1-3 year terms for steady-state workloads.