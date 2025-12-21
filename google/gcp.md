# GCP

## GCP Core Services

### Compute

| Service	| Abstraction Level	| Use Case| Scaling Behavior|
|----|-------|-----------|-----|
| **Compute Engine (GCE)**	| IaaS (VMs)| 	Legacy lift-and-shift, custom kernels, or high-performance computing (HPC) with local SSDs/GPUs. Good for when you need root access, custom images, or tight control on scaling/scheduling.| Manual or script-based scaling. |
| **GKE** |	Managed K8s/CaaS	| Standard for microservices. Supports `Autopilot` (fully managed nodes/scaling) and `Standard` (customer managed nodes/scaling) modes. More control than serverless but less than VMs.| Pod and Cluster autoscaling.|
| **Cloud Run**	| Knative/Serverless	| Fully managed; Request-driven containers. Scales to zero. Ideal for APIs and event-driven processing. Supports HTTP-triggered containers and integrates with `Pub/Sub`, `Eventarc`, `Cloud Build`, etc.| Request-based instant autoscaling (to zero).|
| **App Engine**	| PaaS| 	Classic "No-Ops" for web apps and APIs. `Flexible` environment (Docker) vs. `Standard` (Auto scaling and sandboxed runtimes with limited customization but fast startups).| Version-based autoscaling, warm instances for web traffic.|

#### Compute Notes

- **GKE Autopilot**: Minimizes operational overhead, manages the control plane and worker nodes (billing per pod resource, NOT per node).
- **Confidential Computing**: GCP Allows for Confidential VMs/GKE Nodes that encrypt data in memory using AMD SEV or Intel TDX, critical for high-security or healthcare architectures.


### Networking

**GCP's VPC is global**, not regional.

#### VPC

**VPC** is a global resource. Subnets are regional

- Instances in different regions can communicate over private fiber/GCP backbone without the need for complex VPN peering or public internet.

#### Load Balancing

**Google Cloud Load Balancing (GCLB)** is a software-defined, distributed system.

- **External HTTP(S) LB**: Uses a single Anycast IP globally. Traffic enters the Google network at the PoP nearest to the user.

#### Cloud Interconnect

**Cloud Interconnect** allows for Direct (Dedicated) or Partner connections for low-latency hybrid cloud.

#### Service Directory

**Service Directory** is a managed service registry that helps manage microservice discovery across different compute environments (GCE, GKE, On-prem).

#### Networking Notes

- **Shared VPC**: used to allow central network administrators to manage a host project (VPC, subnets, firewalls) while developers consume the resources in service projects. 


### Storage

GCP differentiates through global consistency for its object storage.

#### Cloud Storage (GCS)

GCS has a unified API for object storage.
- Classes:
    - Standard:
    - Nearline:
    - Coldline:
    - Archive:
- Autoclass: A feature that automatically moves objects between tiers based on access patterns to optimize spend.

#### Persistent Disk (PD)

Persistent Disk is a network-attached block storage.
- Supports Multi-writer mode (shared disk clusters) and Regional PD (synchronous replication across two zones for HA)

#### Filestore

Filestore is a managed NFS for apps requiring traditional file systems.

### Database

| Service	| Category	|  Use Case | 	Scaling Vector | 	Notes | 
|--------|----------------|------------|----------------|--------------|
| **Cloud SQL**	| Relational	| Standard Web Apps, ERP, CRM	| Vertical (Read Replicas for reads)	| Managed MySQL, Postgres, SQL Server. Best for "Standard" workloads.| 
| **AlloyDB**| 	Relational	| High-performance enterprise Postgres| Vertical + Disaggregated Storage| 	**4x faster than standard Postgres**; integrates column-store for hybrid workloads (`HTAP`).| 
| **Cloud Spanner**| 	Relational	| Global Transactional Systems (FinTech, Inventory)| 	Horizontal (Regional/Global)| 	**Global ACID compliance** via `TrueTime` (Atomic Clocks). No manual sharding required.| 
| **Firestore**| NoSQL (Doc)	| Mobile/Web state, User profiles, Metadata	| Horizontal (Automatic)	| Live synchronization, offline support, seamless integration with Firebase.| 
| **Bigtable**	| NoSQL (Wide-column)	| AdTech, IoT, Time-series, ML Features	| Horizontal (Linear)| 	Sub-10ms latency at petabyte scale. Requires careful Row Key design to avoid "hotspots."| 
| **Memorystore**	| NoSQL (Key-Value)	| Caching, Session Mgmt, Leaderboards	| In-memory	| Managed Redis, Valkey, and Memcached. Offloads primary DBs for sub-ms latency.| 


#### Cloud SQL

- **Vertical Scaling**: instance size (CPU, RAM, Disk) increase for higher throughput. Use regional storage for faster failover and HA. It is reactive, you must tune parameters and instances sizes based on observed lag and query performance.
- **Read Replicas**: Offload read-heavy workloads to replicas, reducing primary node load and improving latency.
- Monitor CPU and memory usage, use connection pooling and set up automatic failover.

**Replication Lag** in CloudSQL (MySQL/Postgres) is usually a throughput mismatch between the Primary write capability and the Replica's apply capability (`Primary Write != Replica Apply`).
- Check the `cloudsql.googleapis.com/database/replication/replica_lag` metric:
    - Sawtooth patterns, indicate large periodic batch jobs.
    - Constant upward slope means the replica is under-provisioned for the current write IOPS.

Common Bottlenecks / Solutions:

| Cause	| Mitigation Strategy|
|-------|-------------------|
| **Monolithic Transactions**| 	Break down `DELETE` or `UPDATE` batches. A single 10GB transaction on the Primary must be processed as one serial unit on the Replica (causing lag).| 
| **Replica Undersizing**| Replicas CPU/RAM >= Primary CPU/RAM. A busy replica serving heavy OLAP/Read queries won't have the cycles to apply incoming logs.| 
| **DDL Locks**	| `ALTER TABLE` operations on the Primary can block the replication thread on the Replica. Use **Online DDL features** or run schema changes during maintenance windows.| 
| **Parallel Replication**	| For MySQL, ensure `slave_parallel_workers` is tuned. For Postgres, check `max_standby_streaming_delay` to prevent long-running reads from killing the replication stream.| 

#### AlloyDB

- **Vertical Scaling**: scale compute nodes for higher OlTP throughput.
- **Disaggregated Storage:** Scale storage independently, allowing for larger datasets and analytics workloads.
- **Hybrid Transactional/Analytical Processing (HTAP)**: Use columnar storage for hybrid transactional and analytical queries, scaling storage and compute as needed.

#### Cloud Spanner

- **Horizontal Scaling**: Add more nodes for higher throughput and lower latency. Spanner handles sharding automatically for global scale.
- Monitor node utilization, set appropriate node counts, and use regional/multi-regional config for global consistency.

#### Firestore

- **Automatic Scaling**: Firestore scales horizontally by default, handling increased request rates and data size.
- Use `composite indexes` for complex queries, and monitor document and index size to avoid performance bottlenecks.

- Index supporting queries like "get all users in a city, sorted by age".

```json
// Firestore composite index definition
{
  "collectionGroup": "users",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "city",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "age",
      "order": "ASCENDING"
    }
  ]
}
```

#### BigTable

- **Horizontal Scaling**: Add more nodes for higher throughput and lower latency. Bigtable is designed for linear scaling at petabyte scale.​ It is proactive, meaning you must design the key correctly BEFORE data arrives.
- Design `row keys` to avoid hotspots, and monitor node utilization for optimal performance.​

In Bigtable, **Row Keys are the only index**. Data is stored in sorted byte string order. Avoid hotspots/bottlenecks by correctly designing your key. High Value Design Patterns:
- **Field Promotion (Reverse Domain/Entity)**: Use `device_id#timestamp`, ensuring data from different devices is spread across cluster's nodes. While data for a single device remains contiguous for fast range scans.
- **Salting (Massive Write concurrency)**: If a single entity causes a hotspot, hash/salt the key (e.g. `hash(userid) % 10 # userid`). Trade-off is now 10 parallel scans are needed to read that user.
- **Reverse Timestamps**: Bigtable sorts `0` before `1`.  To see recent logs/data first, use `Long.MAX_VALUE - timestamp`.
- **Multi-Tenancy**: Always start your row keys with `tenant_id#`, allowing you to drop an entire customer's data instantly by deleting a row range.

- Create a composite `row_key`:

```python
# Efficiently retrieve all events for a device or for a time range
import time

device_id = "phone#4c41053"
timestamp = int(time.time())
row_key = f"{device_id}#{timestamp}" # phone#4c410523#1702992000
```

- Schema which allows you to query specific segments of the row key using GoogleSQL for Bigtable.

```json
// Define row key schema for structured access
{
  "fields": [
    {
      "fieldName": "user_id",
      "type": {
        "stringType": {
          "encoding": {
            "utf8Bytes": {}
          }
        }
      }
    },
    {
      "fieldName": "purchase_date",
      "type": {
        "stringType": {
          "encoding": {
            "utf8Bytes": {}
          }
        }
      }
    },
    {
      "fieldName": "order_number",
      "type": {
        "stringType": {
          "encoding": {
            "utf8Bytes": {}
          }
        }
      }
    }
  ],
  "encoding": {
    "delimitedBytes": {
      "delimiter": "#"
    }
  }
}
```

#### Memorystore

- **In-Memory Scaling**: Add more memory or nodes for higher throughput and lower latency.​
- Use connection pooling, monitor memory usage, and set appropriate eviction policies for optimal cache performance.​