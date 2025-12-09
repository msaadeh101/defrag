# AWS Solutions Architect Associate Study Guide

## Domain 1: Design Resilient Architectures (30%)

### Multi-AZ Deployments
**Definition**: Resources deployed across multiple Availability Zones within a single AWS region for high availability and fault tolerance against AZ-level failures.

**Key Characteristics**:
- Same region, different physical data centers
- *Synchronous* replication (typically)
- Sub-second to single-digit second failover times
- No additional data transfer charges between AZs in same region

**RDS Multi-AZ**:
```json
{
  "DBInstanceIdentifier": "prod-database",
  "Engine": "mysql",
  "MultiAZ": true,
  "AllocatedStorage": 100,
  "DBInstanceClass": "db.r5.large",
  "VpcSecurityGroupIds": ["sg-12345678"]
}
```

**ELB with Multi-AZ Targets**:
```yaml
# CloudFormation snippet
LoadBalancer:
  Type: AWS::ElasticLoadBalancingV2::LoadBalancer
  Properties:
    Scheme: internet-facing
    Subnets:
      - subnet-12345678  # AZ-1a
      - subnet-87654321  # AZ-1b
      - subnet-13579246  # AZ-1c
```

### Multi-Region Deployments
**Definition**: Resources deployed across multiple AWS regions for disaster recovery, compliance, and global performance optimization.

**Key Characteristics**:
- *Asynchronous* replication (typically)
- Higher latency between regions
- Data transfer charges apply
- Protects against region-level failures

**S3 Cross-Region Replication**: automatically copies objects from one S3 bucket to another in a different region. The role handles replication between buckets. 
- Both source and Destination buckets need to have versioning enabled for CRP.
```json
{
  "Role": "arn:aws:iam::123456789012:role/replication-role",
  "Rules": [{
    "Status": "Enabled",
    "Prefix": "documents/",
    "Destination": {
      "Bucket": "arn:aws:s3:::backup-bucket-us-west-2",
      "StorageClass": "STANDARD_IA"
    }
  }]
}
```

**Route 53 Health Check Failover**: Ensures high availability for the `subdoamin app.example.com`. Type A maps the Cname to the IP4 address.
- Two A records, distinguished by SetIdentifier/Failover values and HealthCheck.
```json
[
  {
    "Type": "A",
    "Name": "app.example.com",
    "SetIdentifier": "Primary",
    "Failover": "PRIMARY",
    "TTL": 60,
    "ResourceRecords": ["203.0.113.1"],
    "HealthCheckId": "abcdef123456"
    // Routes traffic to 203.0.113.1, if health check passes - record is served.
  },
  {
    "Type": "A",
    "Name": "app.example.com",
    "SetIdentifier": "Secondary",
    "Failover": "SECONDARY",
    "TTL": 60,
    "ResourceRecords": ["198.51.100.2"]
    // No HealthCheckId needed; secondary record is used if primary is unhealthy
  }
]
```

### Auto Scaling Groups (ASG)
**Definition**: Service that automatically adjusts the number of EC2 instances based on demand, health checks, and defined policies.

**Key Components**:
- Launch Template/Configuration
- Scaling Policies (Target Tracking, Step Scaling, Simple Scaling)
- Health Checks (EC2, ELB)
- Lifecycle Hooks

**ASG with Target Tracking**: CloudFormation snippet for ASG and Scaling Policy.
- Missing are the EC2 `LaunchTemplate`, `ApplicationLoadBalancer`, `ApplicationLoadBalancerListener`, `ApplicationLoadBalancerTargetGroup`, and `ApplicationLoadBalancerSG`.
- The TargetGroup must be inside the defined VPC, when ASG registers a new instance, they are registered here automatically.

```yaml
AutoScalingGroup:
  Type: AWS::AutoScaling::AutoScalingGroup
  Properties:
    LaunchTemplate:
      LaunchTemplateId: !Ref LaunchTemplate
      Version: !GetAtt LaunchTemplate.LatestVersionNumber
    MinSize: 2 # At least 2 instances running, with up to 10.
    MaxSize: 10
    DesiredCapacity: 4 # start with 4 instances at launch.
    VPCZoneIdentifier: # Place instances in given subnets.
      - subnet-12345678
      - subnet-87654321
    HealthCheckType: ELB # Rely on ELB health check and not only EC2 status
    HealthCheckGracePeriod: 300
    TargetGroupARNs: # Registers new EC2 instances into ALB Target group.
      - !Ref ApplicationLoadBalancerTargetGroup

TargetTrackingPolicy:
  Type: AWS::AutoScaling::ScalingPolicy
  Properties:
    PolicyType: TargetTrackingScaling
    TargetTrackingConfiguration:
      PredefinedMetricSpecification:
        PredefinedMetricType: ASGAverageCPUUtilization
      TargetValue: 70
    AutoScalingGroupName: !Ref AutoScalingGroup
```

### Placement Groups
**Definition**: Logical grouping of instances within a single AZ (cluster) or multi AZ (Partition/Spread) to influence instance placement on underlying hardware.

**Types**:
1. **Cluster Placement Group**: Packs instances within the same rack/close within a **single AZ**.
- **Use Case**: High performance applications requiring low latency, high throughput
- **Benefit**: 10 Gbps network performance between instances
- **Limitation**: Single AZ only, does not provide fault tolerance.

```bash
aws ec2 create-placement-group \
    --group-name hpc-cluster \
    --strategy cluster
```

2. **Partition Placement Group**: Spread instances across logical partitions, each on separate hardware. Multi AZ deployments in the same region.
- **Use Case**: Large distributed workloads (Hadoop, Cassandra, Kafka) where failures should be isolated to a partition. If you align your partitions (3 nodes) with the the apps replication factor (3 HDFS partitions), you can ensure that replicas of the same data are placed on different, isolated partitions.
- **Benefit**: Spreads instances across logical partitions (different hardware). Can span multiple AZs in the same region. High Availability.
- **Limitation**: Does not offer extremely low latency. Max 7 partitions per AZ

```bash
aws ec2 create-placement-group \
    --group-name distributed-app \
    --strategy partition \
    --partition-count 3
```

3. **Spread Placement Group**: Stricly places each instance on distinct underlying hardware in **multiple AZ in a single region**.
- **Use Case**: Small number of critical instances that should be isolated, needing maximum fault isolation.
- **Benefit**: Each instance on separate hardware, protects against simultaneous hardware failures.
- **Limitation**: Doesn't provide enhanced network performance. Max 7 instances per AZ

```bash
aws ec2 create-placement-group \
    --group-name critical-spread \
    --strategy spread
```

### Application Load Balancer (ALB)
**Definition**: Layer 7 load balancer that routes HTTP/HTTPS traffic based on content of requests.

**Key Features**:
- Host-based and path-based routing
- WebSocket support: enables persistent, full-duplex communication channels over HTTP(S)
- HTTP/2 support
- Integration with AWS WAF
- Request tracing and access logs

**Use Cases**: Web applications, microservices, container-based applications.

**ALB CloudFormation**:
```yaml
ApplicationLoadBalancer:
  Type: AWS::ElasticLoadBalancingV2::LoadBalancer
  Properties:
    Type: application
    Scheme: internet-facing
    SecurityGroups:
      - !Ref ALBSecurityGroup
    Subnets: # Place the ALB in these two subnets
      - subnet-12345678
      - subnet-87654321

ListenerRule: # Routes incoming traffic according to patterns
  Type: AWS::ElasticLoadBalancingV2::ListenerRule
  Properties:
    Actions:
      - Type: forward
        TargetGroupArn: !Ref APITargetGroup # APITargetGroups contain EC2/ECS services, or Lambdas.
    Conditions: # Must match api.example.com/api/*
      - Field: path-pattern
        Values: ["/api/*"]
      - Field: host-header
        Values: ["api.example.com"]
    ListenerArn: !Ref HTTPSListener
    Priority: 100
```
- Supported Protocols are HTTP:80/HTTPS:443 and gRPC and HTTP/2. The ALB handles TLS encrytping and decrypting.
- **Alias Records** are used for ALB in Route53 because ALBs have dynamic IPs. ALias records let Route53 abstract the IPs, and reduce latency, TTL management, free AWS resource queries, etc.

### Network Load Balancer (NLB)
**Definition**: Layer 4 load balancer that routes TCP, UDP, and TLS traffic with ultra-low latency. Does not inspect application layer (layer 7) payload.

**Key Features**:
- Static IP addresses, critical for apps requiring fixed IPs or firewall whitelisting
- Preserves source IP, useful for apps requiring clientIP for logging/security
- Handles millions of requests per second
- Cross-zone load balancing (optional)

**Use Cases**: TCP/UDP applications, gaming, IoT, extreme performance requirements

**NLB CloudFormation**:
```yaml
NetworkLoadBalancer:
  Type: AWS::ElasticLoadBalancingV2::LoadBalancer
  Properties:
    Type: network
    Scheme: internal    # Not internet facing
    IpAddressType: ipv4
    Subnets:           # Subnets where NLB node resides, usually 1 per AZ
      - subnet-12345678
      - subnet-87654321

TCPListener:
  Type: AWS::ElasticLoadBalancingV2::Listener
  Properties:
    DefaultActions:
      - Type: forward            # Forward traffic to target group
        TargetGroupArn: !Ref TCPTargetGroup
    LoadBalancerArn: !Ref NetworkLoadBalancer  # Associate the Listener with the NLB
    Port: 1433 # Traffic open on 1433 TCP port and protocol
    Protocol: TCP
```

- The LB Listener can be of Protocol Type: `TCP`, `UDP`, or `TCP_UDP`

### Gateway Load Balancer (GLB)
**Definition**: Layer 3 load balancer for deploying, scaling, and managing third-party network virtual appliances.

**Key Features**:
- GENEVE protocol on port 6081: Network Virtualization Encapsulation adding a GENEVE header allowing traffic to be transparently processed, without changing original IP packets.
- Transparent network gateway: Preserves the original packet context for virtual appliances.
- Distributes traffic across virtual appliances

**Use Cases**: Firewalls, intrusion detection systems, deep packet inspection

**GWLB CloudFormation**:
```yaml
GatewayLoadBalancer:
  Type: AWS::ElasticLoadBalancingV2::LoadBalancer
  Properties:
    Type: gateway
    Subnets:
      - subnet-12345678
      - subnet-87654321

GatewayTargetGroup:
  Type: AWS::ElasticLoadBalancingV2::TargetGroup
  Properties:
    Protocol: GENEVE
    Port: 6081            # Standard Protocol for GENEVE encapsulation
    VpcId: !Ref VPC       # VPC where targets and load balancers reside
    TargetType: instance
    HealthCheckProtocol: TCP       # Health Check info to determine healthy targets
    HealthCheckPort: 80
```

### Classic Load Balancer (CLB)
**Definition**: Legacy load balancer operating at both Layer 4 and Layer 7.

**Status**: Not recommended for new applications
**Migration Path**: Use ALB for HTTP/HTTPS, NLB for TCP/UDP

### ELB Health Checks
**Definition**: Automated checks to determine if targets are healthy and can receive traffic.

**Types**:
- **HTTP/HTTPS**: Checks specific path and expects specific response code
- **TCP**: Attempts to establish TCP connection
- **SSL**: Attempts SSL handshake

**Configuration Parameters**:
```yaml
TargetGroup:
  Type: AWS::ElasticLoadBalancingV2::TargetGroup
  Properties:
    HealthCheckEnabled: true
    HealthCheckIntervalSeconds: 30
    HealthCheckPath: "/health"
    HealthCheckProtocol: HTTP
    HealthCheckTimeoutSeconds: 5
    HealthyThresholdCount: 2
    UnhealthyThresholdCount: 5
    Matcher:
      HttpCode: 200,404
```

### Route 53 Health Checks
**Definition**: Monitors the health of resources and routes traffic only to healthy resources (web servers, endpoints, other infra components) and influence DNS failover by routing traffic to only healthy resources.

**Types**:
- **HTTP/HTTPS Health Checks**: Specified resource path `/health`, responses between 200-399. Useful for web servers, APIs, ALBs, any HTTP-enabled service.
- **TCP Health Checks** : Success means endpoint accepts TCP connection, good for databases or raw TCP apps.
- **Calculated Health Checks**: Combines multiple health checks (child checks)
- **CloudWatch Alarm Health Checks**: Monitor a CloudWatch alarm instead of an endpoint directly.

**HTTP Healthcheck on Endpoint**:
```json
{
  "Type": "HTTP",
  "ResourcePath": "/health",
  "FullyQualifiedDomainName": "example.com",
  "Port": 80,
  "RequestInterval": 30,
  "FailureThreshold": 3,
  "MeasureLatency": true,
  "Regions": ["us-east-1", "us-west-2", "eu-west-1"]
}
```

### Auto Scaling Health Checks
**Definition**: Determines instance health and automatically replaces unhealthy instances.

**Types**:
- **EC2 Health Check**: Instance status checks
- **ELB Health Check**: Load balancer target health, instances failing can be terminated and replavced by Auto Scaling.

**Configuration**:
```bash
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name my-asg \
    --health-check-type ELB \
    --health-check-grace-period 300
```

### RDS Cross-AZ Replication
**Definition**: Synchronous replication of database data across AZs for high availability.

**Multi-AZ Features**:
- Automatic failover (1-2 minutes)
- Synchronous replication
- No performance impact on primary
- Automatic backups from secondary

**Read Replicas vs Multi-AZ**:
```yaml
# Multi-AZ (HA/DR)
PrimaryDatabase:
  Type: AWS::RDS::DBInstance
  Properties:
    MultiAZ: true
    BackupRetentionPeriod: 7

# Read Replica (Read Scaling)
ReadReplica:
  Type: AWS::RDS::DBInstance
  Properties:
    SourceDBInstanceIdentifier: !Ref PrimaryDatabase
    DBInstanceClass: db.r5.large
```

### DynamoDB Cross-AZ Replication
**Definition**: Built-in replication across multiple AZs within a region.

**Features**:
- Automatic replication to 3 AZs
- Strongly consistent reads from same AZ
- Eventually consistent reads cross-AZ

**Global Tables (Cross-Region)**:
```bash
aws dynamodb create-global-table \
    --global-table-name MyGlobalTable \
    --replication-group RegionName=us-east-1 RegionName=us-west-2
```

### EBS Cross-AZ Patterns
**Definition**: Strategies for replicating EBS volume data across AZs.

**Snapshot-Based Replication**:
```bash
# Create automated snapshots
aws ec2 create-snapshot \
    --volume-id vol-1234567890abcdef0 \
    --description "Daily backup"

# Copy snapshot to another region
aws ec2 copy-snapshot \
    --source-region us-east-1 \
    --source-snapshot-id snap-1234567890abcdef0 \
    --destination-region us-west-2
```

**RAID Configuration for Redundancy**:
```bash
# Create RAID 1 mirror across EBS volumes in different AZs
mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/xvdf /dev/xvdg
```

### S3 Cross-AZ Replication
**Definition**: S3 automatically replicates objects across multiple AZs within a region.

**Built-in Features**:
- 99.999999999% (11 9's) durability
- Automatic replication across AZs
- No configuration required

**Cross-Region Replication**:
```json
{
  "Role": "arn:aws:iam::123456789012:role/replication-role",
  "Rules": [{
    "Status": "Enabled",
    "Filter": {"Prefix": "logs/"},
    "Destination": {
      "Bucket": "arn:aws:s3:::destination-bucket",
      "ReplicationTime": {
        "Status": "Enabled",
        "Time": {"Minutes": 15}
      },
      "Metrics": {
        "Status": "Enabled",
        "EventThreshold": {"Minutes": 15}
      }
    }
  }]
}
```

### ElastiCache Cross-AZ Patterns
**Definition**: Replication strategies for in-memory data stores across AZs.

**Redis Cluster Mode**:
```yaml
RedisReplicationGroup:
  Type: AWS::ElastiCache::ReplicationGroup
  Properties:
    ReplicationGroupDescription: "Redis cluster with cross-AZ replicas"
    NumCacheClusters: 3
    Engine: redis
    CacheNodeType: cache.r6g.large
    MultiAZEnabled: true
    AutomaticFailoverEnabled: true
    PreferredCacheClusterAZs:
      - us-east-1a
      - us-east-1b
      - us-east-1c
```

**Memcached (No Built-in Replication)**:
```bash
# Client-side replication using consistent hashing
# or application-level data distribution
```

### Decoupling Components

**SQS**: Simple Queue Service. message queue service that enables asynch communication between distributed components. Different **Queue Types**.
- **Standard**: Delivery guarantee, best effort ordering, but messages may arrive out of order. Unlimited throughput. Use when occaisional duplicate messages are acceptable/order not critical.
- **FIFO**: Exactly-once processing, deduplication enabled by default. Guaranteed ordering. 300 (standard) - 3000 (premium) messages/second throughput. Requires MessageGroupId for ordering, and deduplication token to work properly. Used for financial transactions, inventory management, order processing.
```json
{
  "QueueName": "transaction-queue.fifo",
  "FifoQueue": true,
  "ContentBasedDeduplication": true,
  "MessageRetentionPeriod": 86400,
  "VisibilityTimeout": 60,
  "DeduplicationScope": "messageGroup",
  "FifoThroughputLimit": "perMessageGroupId"
}
```
- **DLQ (dead letter)**: Captures messages that failed to process after x number of attempts.
- Use *batch processing* to improve API call efficiency:
```python
with ThreadPoolExecutor(max_workers=5) as executor:
    receipt_handles = list(executor.map(process_message, messages))
```
- Visibility timeout prevents duplicate processing by hiding messages from other consumers during processing.

**SNS**: Simple Notification Service: Pub-Sub messaging service for one-to-many message distribution with support for multiple protocol endpoints. SNS uses **Topics** as communication channels, *publishers* send messages to topics, and *subscribers* receive notifications. 
- **Protocols**: `SQS`, `Lambda`, `HTTP(S)`,` Email`/`E-JSON`, `SMS`, `Application` (mobile push notifications).
- Create an SNS topic (order-events) and subscribe an SQS queue to the topic:
```bash
aws sns create-topic --name order-events
aws sns subscribe \
    --topic-arn arn:aws:sns:us-east-1:123456789012:order-events \
    --protocol sqs \
    --notification-endpoint arn:aws:sqs:us-east-1:123456789012:order-queue
```
- **Fan-out pattern** enables one message to trigger multiple parallel workflows, good for event-driven architectures. (i.e. an order is created, and SNS delivers a message to inventory, notification, and analytic systems simultaneously).
- Message filtering: Filter policies reduce unnecessary processing (only messages with matching attributes are delivered to certain subscriber). 
```bash
aws sns set-subscription-attributes \
    --subscription-arn arn:aws:sns:us-east-1:123456789012:order-events:12345678 \
    --attribute-name FilterPolicy \
    --attribute-value '{"eventType":["order-created"]}'
```
- *Dead Letter Queue Integration*: SNS can route failed deliveries to SQS Dead-Letter Queues for reply/investigation.

**EventBridge**: Serverless event bus that routes events from AWS services, custom apps, and SaaS to multiple targets (*even cross account*) with rule-based routing. Patterns can match on `source`, `detail-type`, or `detail` fields.
- Events follow standard JSON, with metadata and payload.
```json
{
  "version": "0",
  "id": "6a7e8feb-b491-4cf7-a9f1-bf3703467718",
  "detail-type": "EC2 Instance State-change Notification",
  "source": "aws.ec2",
  "account": "123456789012",
  "time": "2024-10-07T12:34:56Z",
  "region": "us-east-1",
  "resources": ["arn:aws:ec2:us-east-1:123456789012:instance/i-1234567890abcdef0"],
  "detail": {
    "instance-id": "i-1234567890abcdef0",
    "state": "terminated"
  }
}
```
- EventBridge routes events to Lambda, SNS, SQS, Step Functions, API Gateway, and other SaaS providers (Slack, PagerDuty, Datadog).
**Step Functions**: Serverless orchestration service for coordinating distributed workflows, long-running processes, complex business logic with *visual workflows* and *error handling*. 
- State machine types include standard and express workflows.
  - **Standard Workflow**: Runs for up to `1 year`, exactly-one-execution semantics, full audit trail. Good for business processes, order fulfillment, data pipelines.
  - **Express Workflow**: Runs for up to `5 minutes`, at least-once-execution. Optimized for high-volume, event driven scenarios. Synchronous or asynchronous. Stream processing, API backends, real-time responses.
- Retries implement exponential backoff to handle transient errors gracefully:
```json
{
  "ErrorEquals": ["States.TaskFailed"],
  "IntervalSeconds": 1,
  "MaxAttempts": 5,
  "BackoffRate": 2.0
}
```

**API Gateway**: Fully managed service for creating/publishing/monitoring/securing APIs at scale. Acts as the front-door for apps to access data/business logic and more. Its a reverse proxy that sits between the client app and backend services.
- Flow: `Client request -> Request Processing -> Backend Call/Response -> Response Processing`
- During the request processing, API gateway handles the authentication/authorization, throttling, caching (if enabled) and mappings/transformations (optional)
- **Throttling**: Protects backend systems from overload, default 10,000 RPS soft limit. Can apply at the account-level or API-level.
- **Caching**: Stores API responses in an in-memory cache at the edge for a TTL period, reducing backend load. *Tradeoff*: Cache invalidation complexity vs performance gains.
```yaml
OrderAPIMethod:
  Type: AWS::ApiGateway::Method
  Properties:
    RestApiId: !Ref OrderAPI
    ResourceId: !Ref OrderAPIGWResource
    HttpMethod: POST
    AuthorizationType: AWS_IAM
    Integration:
      Type: AWS_PROXY
      IntegrationHttpMethod: POST
      Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:states:action/StartSyncExecution'
      Credentials: !GetAtt APIGatewayRole.Arn
      RequestTemplates:
        application/json: |
          {
            "stateMachineArn": "arn:aws:states:${AWS::Region}:${AWS::AccountId}:stateMachine:order-processor",
            "input": "$input.json('$')"
          }
```
- Cache Invalidation:
```bash
# Flush entire cache
aws apigateway flush-stage-cache \
    --rest-api-id r3pmxmplak7b7a \
    --stage-name prod
# Invalidate specific resource
aws apigateway delete-stage-cache \
    --rest-api-id r3pmxmplak7b7a \
    --stage-name prod \
    --resource-path "/orders/{orderId}"
```

### Disaster Recovery

**RTO/RPO**: **Recovery Time Objective** is the max downtime before restoration is required (minutes/hours). **Recovery Point Objective** is the max data loss measured in time. Data newer than RPO is lost in a disaster.
- **Trafeoffs (RTO vs RPO)** highest to lowest cost:
  - *Zero RTO/RPO* requires always-on replication and multi-region active-active environments.
  - *Short RTO* (minutes) with RPO (hours) uses automated failover with asynchronous replication.
  - *Extended RTO* (hours) with *extended RPO* (days) can use backup-restore approaches

**DR strategies**:
1. **Backup and Restore**: Regular backups to secondary region, manual restoration on disaster.
- Lowest cost, highest RTO/RPO
- **RTO**: Hours - Days, **RPO**: Hours - Days
```bash
# Automated daily snapshots
aws ec2 create-snapshot \
    --volume-id vol-1234567890abcdef0 \
    --description "Daily backup $(date +%Y-%m-%d)"
# Copy snapshot to DR region
aws ec2 copy-snapshot \
    --source-region us-east-1 \
    --source-snapshot-id snap-1234567890abcdef0 \
    --destination-region us-west-2 \
    --description "DR backup"
```
2. **Pilot Light**: Continuous replication, minimal instances running, scale on failover.
- Minimal infra running in DR region.
- **RTO**: 10-15 min, **RPO**: 5-15 min
3. **Warm Standby**: Continuous replication, scaled down infra with traffic shift on failover.
- Fully functional but reduced-capacity environment.
- **RTO**: 5-10 min, **RPO**: 1-5 min
- **Route53** health checks can automatically shift during traffic outages.
```json
{
  "Type": "A",
  "Name": "app.example.com",
  "SetIdentifier": "Primary",
  "Failover": "PRIMARY",
  "TTL": 60,
  "ResourceRecords": ["203.0.113.1"],
  "HealthCheckId": "primary-health-check"
},
{
  "Type": "A",
  "Name": "app.example.com",
  "SetIdentifier": "Standby",
  "Failover": "SECONDARY",
  "TTL": 60,
  "ResourceRecords": ["198.51.100.2"]
}
```
4. **Multi-Site (Active-Active)**: Traffic distributed with automatic failover. Fully active infrastructure in multiple regions.
- **RTO**: Seconds, **RPO** ~zero.
- *Highest cost* with continous synchronization.
- Example: Use DynamoDB global tables for active-active multi-region.
```bash
aws dynamodb create-global-table \
    --global-table-name orders \
    --replication-group RegionName=us-east-1 RegionName=eu-west-1 RegionName=ap-southeast-1
```

**Cross-region replication**: CRR for S3, RDS and DynamoDB.
- **S3 CRR**: Automatically replicates new objects asynch to another bucket in a different region. Good for compliance, low-latency access and DR.
- **RDS**: Supports cross-region read replicas (MySQL, PostgreSQL, Aurora) that can be promoted to standalone instances during a failover. Read replicas require manual promotion.
- **DynamoDB Global Tables**: Fully managed multi-region, multi-master replication. Ensuring low RPO with writes (last write wins) propagated across regions with eventual consistency.

**Database Backup Strategies**:
- RDS Automated backups capture daily snapshots/transaction logs, enabling PITR up to 35 days.
- DynamoDB PITR enables recovery at any point up to 35 days, protecting against accidental deletions or bugs.
```bash
aws dynamodb update-continuous-backups \
    --table-name OrderTable \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
# Restore to specific point in time
aws dynamodb restore-table-to-point-in-time \
    --source-table-name OrderTable \
    --target-table-name OrderTable-Restored \
    --use-latest-restorable-time
```
- On-Demand backups are manual and can be created for critical databases before major changes or maintenance, providing indefinite retention.
```bash
aws rds create-db-snapshot \
    --db-instance-identifier prod-database \
    --db-snapshot-identifier prod-database-pre-migration-$(date +%Y%m%d-%H%M%S)

# Create backup job with lifecycle rules
aws dlm create-lifecycle-policy \
    --execution-role-arn arn:aws:iam::123456789012:role/dlm-role \
    --description "Daily RDS snapshots with 30-day retention" \
    --state ENABLED \
    --policy-details \
        PolicyType=EBS_SNAPSHOT_MANAGEMENT,ResourceTypes=VOLUME,TargetTags=BackupEnabled=true
```
- **Simulate and Test RDS Failover**: Convert existing instance into multi-AZ and trigger manual failover. Validate your RTO, benchmark failover and promotion duration, prepare for operational outages. Can cause minutes of downtime, schedule a maintenance window, ensure app has retry logic and can sustain DNS caching issues.

```bash
# Step 1: Convert an existing RDS DB instance into Multi-AZ for high availability
aws rds modify-db-instance \
    --db-instance-identifier prod-database \
    --multi-az
#  --apply-immediately means changes take effect right away. DO NOT USE 

# Step 2: Trigger a manual failover to test RDS high availability
aws rds reboot-db-instance \
    --db-instance-identifier prod-database \
    --force-failover
# ^ Simulates a failure by rebooting the instance and forcing a failover to the standby (in the other AZ).
#   Lets you measure how long the service takes to switch and recover (typically 60-120 seconds).

# Step 3: Promote a read replica to standalone, measuring promotion time
aws rds promote-read-replica \
    --db-instance-identifier prod-database-dr-test

# Useful for DR drills or scaling out read replicas into standalone databases.
```
- Maintain **runbooks** documenting RTO/RPO for each system, rollback procedures, and post-incident validation steps.



## Domain 2: Design High-Performing Architectures (28%)

### Storage Solutions

**S3 Storage Classes and Lifecycle Policies**:
- Roughly ordered from highest to lowest cost, and general resiliency/durability.
- `S3 Standard`: High durability *(11 9’s)*, low latency, multiple AZs. Highest cost per GB. For frequently accessed data.
- `S3 Intelligent-Tiering`: Automatically moves objects between frequent and infrequent access tiers based on usage patterns. No retrieval fees.
- `S3 Standard-IA (Infrequent Access)`: Lower-cost, high durability, **charged per GB retrieved**. Use for backups or long-lived but rarely accessed data.
- `S3 One Zone-IA`: Similar to Standard-IA but only stored in one AZ (lower durability). Cheaper, but not recommended for critical data.
- `S3 Glacier Instant Retrieval`: Millisecond retrieval, lower cost, used for archived but occasionally needed data.
- `S3 Glacier Flexible Retrieval`: Retrieval in minutes or hours, cheaper.
- `S3 Glacier Deep Archive`: Lowest cost, retrieval in hours. Best for long-term compliance archives.
- `S3 Reduced Redundancy Storage (RRS)`: Legacy, not recommended (lower durability).
- **Example Lifecycle Policy**:
```json
{
  "Rules": [
    {
      "ID": "TransitionToGlacier",
      "Status": "Enabled",
      "Prefix": "logs/",
      "Transitions": [
        { "Days": 30, "StorageClass": "STANDARD_IA" },
        { "Days": 90, "StorageClass": "GLACIER" }
      ],
      "Expiration": { "Days": 365 }
    }
  ]
}
```

**EBS Volume Types and Performance**:
- EBS volumes are block storage devices for EC2 instances, each optimizes for different I/O patterns and costs.
- **General Purpose (gp2/gp3)**:
  - `gp2`: Baseline 3 IOPS/GB, up to 16,000 IOPS. Burst credits.
  - `gp3`: 3000 IOPS and 125 MB/s throughput by default. Can provision up to 16,000 IOPS and 1,000 MB/s independently of volume size.
- **Provisioned IOPS (io1/io2)**:
  - Designed for *I/O-intensive workloads* like databases.
  - Support up to 64,000 IOPS per volume (Nitro).
  - **io2 Block Express**: Sub-millisecond latency, higher durability (99.999%).
- **Throughput Optimized HDD (st1)**:
  - Low-cost *magnetic* storage, optimized for sequential I/O (big data, streaming). Up to 500 MB/s throughput.
- **Cold HDD (sc1)**:
  - Lowest cost, for infrequently accessed data (cold backups). Throughput up to 250 MB/s.
```bash
# Create an EBS gp3 vol
aws ec2 create-volume \
  --availability-zone us-east-1a \
  --size 100 \
  --volume-type gp3 \
  --iops 6000 \
  --throughput 500
```
- RAID: Redundant Array of Independent Disks, combines multiple physical disks into a logical unit. RAID 0: Striping, RAID 1: Mirroring, RAID 5,6,10: Combiniation.
```bash
# Create RAID 0 with two gp3 volumes (8,000 IOPS each = 16,000 combined)
mdadm --create /dev/md0 \
    --level=0 \
    --raid-devices=2 \
    /dev/xvdf \
    /dev/xvdg
# Monitor RAID
mdadm --detail /dev/md0
# Create filesystem
mkfs.ext4 /dev/md0
# Mount
mount /dev/md0 /data
```

**EFS Performance and Throughput Modes**: EFS is AWS managed NFS file system for EC2, supporting multiple AZs.
- **Performance Modes**: Cannot be changed after creation.
  - `General Purpose (Default)`: Lowest latency (1-3ms), web serving, general file serving.
  - `Max IO`: Higher levels of aggregate throughput/operations per second (4-10ms), Higher latency but better parallelization. Big Data analytics, media processing.
- **Throughput Modes**:
  - `Bursting (Default)`: baseline (50kb/s per GB) to burst (100mb/s per file system) Charged per MB/s provisioned/credits based. Most workloads with variable I/O, lower cost.
  - `Provisioned Throughput`: Independent of storage size, 1-1024 MB/s, charged per MB/s provisioned. Fixed cost, for predictable, sustained workloads.
  
- Example Throughput calculator: `Baseline(1TBx50Kb/s/GB) + Burst(100MB/s when credits available)`

```yaml
# General Purpose EFS (default) with Bursting Throughput
GeneralPurposeEFS:
  Type: AWS::EFS::FileSystem
  Properties:
    PerformanceMode: generalPurpose
    ThroughputMode: bursting
    Encrypted: true

# Analytics EFS with Max I/O + Provisioned Throughput
AnalyticsEFS:
  Type: AWS::EFS::FileSystem
  Properties:
    PerformanceMode: maxIO
    ThroughputMode: provisioned
    ProvisionedThroughputInMibps: 500
    Encrypted: true

# Mount Targets (multi-AZ NFS access) Acts as an ENI with own IP in the subnet
# EFS Access remains even if one AZ fails, also avoids across-AZ latency.
MountTargetAZ1:
  Type: AWS::EFS::MountTarget
  Properties:
    FileSystemId: !Ref GeneralPurposeEFS
    SubnetId: !Ref PrivateSubnet1
    SecurityGroups: [!Ref EFSSecurityGroup]

MountTargetAZ2:
  Type: AWS::EFS::MountTarget
  Properties:
    FileSystemId: !Ref GeneralPurposeEFS
    SubnetId: !Ref PrivateSubnet2
    SecurityGroups: [!Ref EFSSecurityGroup]
# Add EFSSecurityGroup to controll access
```
- **Note**: You need to configure the automatic remount/persisting mount on boot using shell commands, `/etc/fstab`. Use EFS `AccessPoint` resources to managed permissions to the file system.

**Storage Gateway**: Connects on-prem data centers to AWS cloud storage, enabling hybrid architectures.
- **S3 File Gateway**: NFS/SMB protocol for S3, data cached locally, backed by S3. On-prem access to S3, cloud-native data sharing. Sub second latency for cached files. 100MB/s per gateway.
- **iSCSI Gateway (Volume)**: Block storage via IsCSI protocol. Cached and Stored volumes, on-prem apps needing block storage/DR.
  - **Cached Volume Architecture**: Primary data in AWS, cache on-prem. App writes to local cache, asych upload to S3 via EBS snapshot. RTO is minutes to restore.
  - **Stored Volume Architecture**: Primary data on-prem, full backup in AWS. No throughput loss, RTO is hours from backup. High bandwidth required.
- Tape Gateway: Virtual Tape Library (VTL) interface for LTFS. Data backed by S3 and Glacier, compliance backups, NetBackup or CommVault compatible. `Type: AWS::StorageGateway::Tape`

- **Note**: You can throttle uploads via the gateway during business hours:
```bash
# Number in bits per second
aws storagegateway update-bandwidth-rate-limit \
    --gateway-arn arn:aws:storagegateway:us-east-1:123456789012:gateway/sgw-12345678 \
    --average-upload-rate-limit-in-bits-per-sec 5242880 \
    --average-download-rate-limit-in-bits-per-sec 10485760
```
- Exammple Hybrid Cloud Architecture visualization:
```txt
On-Premises Data Center
├── Application Servers
│   └── [NFS Mount]
│       └── Storage Gateway (File Gateway)
│           └── [Encrypted HTTPS]
│               └── AWS S3 Bucket (Primary)
│                   └── Lifecycle Policy
│                       └── S3 Intelligent-Tiering
│                           └── Glacier Deep Archive
│
└── Database Servers
    └── [iSCSI Connection]
        └── Storage Gateway (Cached Volume Gateway)
            └── [Encrypted HTTPS]
                └── AWS EBS Snapshots
                    └── Cross-region copy to DR region
```

**FSx**: Managed file systems optimized for specific workloads that require high performance, feature-rich, scalable systems.
- **FSx for Windows File Server**: NTFS technology, SMB protocol, Windows native, seamless Active Directory integration, DFS namespaces, data deduplication.
  - RAID 6 redundancy. Single or Multi-AZ, legacy .NET workloads.
  - Throughput Levels 8-256 MB/s. 
- **FSx for Lustre**: OSS Lustre, POSIX and NFS protocols, High-performance compute, HPC, ML, extreme parallism, S3 integration, Linux compatible.
  - sub-millisecond latency, 100-500MB/s per TB storage (auto-scaled based on capacity).
- **FSx for NetApp ONTAP**: NFS, SMB and iSCSI protocols, Enterprise NetApp, FlexCache/FlexGroup and snapshot features. Migrate NetApp environments.
- **FSx for OpenZFS**: NFS and SMB protocols, ZFS specific features. Data Compression, snapshot and replication locally or cross-region. Cost effective shared storage for PITR scenarios.


### Database Solutions

**RDS vs DynamoDB**

- Read replicas vs Multi-AZ for RDS
- DynamoDB partition keys, GSI/LSI design
- ElastiCache Redis vs Memcached
- Database migration strategies (DMS, SCT)

### Compute Solutions
- EC2 instance types and placement strategies
- Lambda concurrency limits and cold starts
- ECS vs EKS vs Fargate decision matrix
- Spot instances and interruption handling
- Elastic Beanstalk deployment strategies

### Networking
- VPC design patterns and CIDR planning
- Route Tables and traffic routing decisions
- NAT Gateway vs NAT Instance considerations
- Direct Connect vs VPN connectivity
- CloudFront distribution strategies and caching

## Domain 3: Design Secure Applications (24%)

### Identity and Access Management
- IAM roles vs users vs groups
- Cross-account access patterns
- Service-linked roles and trust policies
- Cognito User Pools vs Identity Pools
- STS temporary credentials and federation

### Data Protection
- S3 bucket policies vs ACLs vs access points
- KMS key policies and envelope encryption
- Secrets Manager vs Parameter Store
- CloudHSM use cases
- Certificate Manager and SSL/TLS termination

### Infrastructure Protection
- Security Groups vs NACLs layered approach
- AWS WAF rules and rate limiting
- Shield Standard vs Advanced
- GuardDuty threat detection patterns
- VPC Flow Logs analysis

## Domain 4: Design Cost-Optimized Architectures (18%)

### Cost-Effective Storage
- S3 Intelligent Tiering and lifecycle optimization
- EBS GP3 vs other volume types cost analysis
- Data transfer costs and CloudFront optimization
- Storage class analysis and recommendations

### Cost-Effective Compute
- Reserved Instances vs Savings Plans vs Spot
- Right-sizing recommendations and monitoring
- Lambda cost optimization patterns
- Auto Scaling cost implications

### Cost Monitoring and Governance
- Cost Explorer and budgets setup
- Resource tagging strategies for cost allocation
- Trusted Advisor cost optimization checks
- AWS Organizations and consolidated billing

## Key Services Deep Dive

### Core Compute & Storage
- EC2, Lambda, ECS/EKS, Auto Scaling
- S3, EBS, EFS, Storage Gateway
- CloudFront, Route 53

### Database & Analytics
- RDS, DynamoDB, Redshift, ElastiCache
- Kinesis (Streams, Firehose, Analytics)
- EMR, Athena, QuickSight

### Security & Identity
- IAM, Cognito, KMS, Secrets Manager
- WAF, Shield, GuardDuty, Security Hub
- Certificate Manager, CloudHSM

### Management & Governance
- CloudFormation, Systems Manager
- CloudTrail, CloudWatch, Config
- Organizations, Control Tower

### Networking
- VPC, Direct Connect, Transit Gateway
- Load Balancers, API Gateway
- Route 53, CloudFront

## Exam Strategy Notes

### Question Pattern Recognition
- "Most cost-effective" → Look for Reserved Instances, S3 lifecycle, right-sizing
- "Highest performance" → Consider placement groups, EBS Provisioned IOPS, caching
- "Most secure" → Principle of least privilege, encryption at rest/transit
- "Minimize operational overhead" → Managed services, automation

### Common Anti-Patterns to Avoid
- Using RDS for caching (use ElastiCache)
- Single AZ deployments for production
- Over-provisioning without monitoring
- Ignoring data transfer costs between regions

### Architecture Decision Framework
1. Identify requirements (performance, cost, security, availability)
2. Consider managed vs self-managed trade-offs
3. Plan for scale (both up and down)
4. Design for failure scenarios
5. Optimize for total cost of ownership

## Final Review Checklist
- [ ] Can design multi-tier architectures with proper decoupling
- [ ] Understand when to use each database service
- [ ] Know storage options and lifecycle management
- [ ] Can secure applications using AWS security services
- [ ] Understand cost optimization strategies
- [ ] Can design for disaster recovery scenarios
- [ ] Know networking best practices and hybrid connectivity