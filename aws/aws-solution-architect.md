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
- SQS (Standard vs FIFO) and dead letter queues
- SNS fan-out patterns and message filtering
- EventBridge rule patterns and cross-account events
- Step Functions state machines and error handling
- API Gateway throttling and caching strategies

### Disaster Recovery
- RTO/RPO requirements and DR strategies
- Backup and restore vs pilot light vs warm standby vs multi-site
- Cross-region replication for S3, RDS, DynamoDB
- Database backup strategies and point-in-time recovery

## Domain 2: Design High-Performing Architectures (28%)

### Storage Solutions
- S3 storage classes and lifecycle policies
- EBS volume types and performance characteristics
- EFS performance modes and throughput modes
- Storage Gateway types and hybrid patterns
- FSx options and use cases

### Database Solutions
- RDS vs DynamoDB use cases and scaling patterns
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