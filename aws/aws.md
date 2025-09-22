# AWS

## Best Practices

### EC2 Instances and Logging In

1. Prerequisites:
- Key Pair (`.pem` file) or SSM Session Manager access.
  - Never retreivable again after download, secure in a vault or secret manager.
  - SSM Session Manager requires the SSM agent + IAM role on instance + VPC endpoints (if no internet).
- Private IP (if inside network) or Public IP/DNS (external).
  - Inside network: Use Private IP (no NAT/IGW hop).
  - External laptop: Use Public DNS or Elastic IP (requires IGW/NAT, SG rules)
- Correct IAM permissions to describe instances, use SSM or download key pairs.
- Installed SSH client (ssh for Mac/Linux, PuTTY or PowerShell for Windows).
- Network access: Security Groups (SGs) and NACL/Route Table configured.
  - SGs are stateful, inbound 22 must be open from source, outbound must allow `>1024` for responses.
  - NACLs are stateless, must allow inbound/outbound explicitly. Check if experiencing timeout.
  - Route Tables:
    - Public subnet -> IGW route (`0.0.0.0/0` -> `igw-xxxxx`)
    - Private subnet (Workspaces or VPN) -> routes via VPC peering, TGW, or internal routing.

2. IAM Permissions: You or Workspace user needs an IAM policy that allows EC2/SSM actions. Add IAM conditions to restrict by (`aws:SourceIp`, `aws:ResourceTag`) for zero-trust.

```yaml
Version: "2012-10-17"
Statement:
  - Effect: Allow
    Action:
      - ec2:DescribeInstances
      - ec2:DescribeKeyPairs
      - ec2-instance-connect:SendSSHPublicKey
      - ssm:StartSession
      - ssm:SendCommand
    Resource: arn:aws:ec2:region:account:instance/*
```

3. SSH Key Pair setup: When you create an EC2, you associate a Key pair.
- Download the `.pem` file locally.
- Set file permissions: `chmod 400 my-key.pem`
- Example SSH config (`~/.ssh/config`)

```yaml
Host my-ec2
  HostName ec2-18-123-45-67.compute-1.amazonaws.com
  User ec2-user
  IdentityFile ~/.ssh/my-key.pem
```
- Next you can connect: `ssh my-ec2`

4. Logging in from AWS Workspaces
- Workspaces in the same VPC directly can reach the EC2 using private IP. Ensure the SG of the EC2 allows inbound SSH.

```bash
ssh -i ~/.ssh/my-key.pem ec2-user@10.0.2.45
```

5. Networking Checklist
- Security Groups should allow Inbound TCP on port 22 from your IP.
- NACLs should allow inbound/outbound TCP 22.
- Route Table: Internet Gateway or VPC Peering/Private subnet routing.

6. Alternative using AWS SSM (No SSH keys needed).

```bash
aws ssm start-session --target i-1234567890abcdef
```

- IAM Role attached to instance:

```yaml
Version: "2012-10-17"
Statement:
  - Effect: Allow
    Action:
      - ssm:*
      - ec2messages:*
      - cloudwatch:PutMetricData
    Resource: "*"
```

7. Troubleshooting
- Permission denied (public key): Username may vary by AMI, wrong .pem file, permissions.
- SG/NACL disallowing or no route.
- Key Lost: Use SSM Session manager or stop instance, detach root volume, attach to another instance and fix `~/.ssh/authorized keys`

8. Best Practices
- Use SSM Session Manager for auditing and no key managment.
- Rotate keys regularly.
- Consider a jump box or bastion host for many private instances.
- Store SSH configs in`~/.ssh/config`

### EKS and Secrets
- AWS EKS supports IRSA, bridges Kubernetes RBAC and AWS IAM using OIDC trust relationships.

- Trust Policy snippet:

```json
"Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED1234:sub": "system:serviceaccount:default:s3-reader"
        }
```

- `"oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED1234:sub"` is the fully qualified OIDC provider URL.
  - `EXAMPLED1234` is the unique ID for your EKS cluster's OIDC identity provider.
- `"system:serviceaccount:default:s3-reader"` is the K8 SA identity.
  - `system:serviceaccount:<namespace>:<serviceaccount-name>` where namespace is `default` and SA is `s3-reader`
- This ensures that only the s3-reader SA in the default namespace can assume that IAM role.

- Lock `sub` to a sepcific namespace and SA for security.
- Use `StringLike` with `system:serviceaccount:*:s3-reader` if multiple namespaces sare the same role.

- Store secrets in AWS secrets manager for encryption at rest using Secrets Manager and transit using TLS.

```bash
aws secretsmanager create-secret \
  --name myapp/database \
  --secret-string '{"password":"password123","apiKey":"apikey12345"}'
```

- Since there is a single AWS Secrets Manager per account, store secrets using `<AppName>/<Env>/<secretType>`:
    - `myapp/production/database`
    - `myapp/production/third-party-api-key`
    - `reporting-service/staging/database-user`
    - `reporting-service/production/snowflake`

- So the secret name for example, is `myapp/production/third-party-api-key`, and the value is: `{"key": "somekey"}`

### IAM

- Use least privelege for IAM roles, group by environment.

- Example: S3 access scoped to a single bucket

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject","s3:PutObject"],
      "Resource": "arn:aws:s3:::myapp-prod-data/*"
    }
  ]
}
```

### Networking

- Use **Security Groups (SGs)** for app-level traffic (fine-grained)
- Use **NACLs** for subnet level isolation.

### Data Services

**DynamoDB**:
- Fully Managed NoSQL Key-Value + Document Store
- **Capacity Modes**:
  - **On-demand**: autoscales throughput, pay per request (good for unpredictable workloads).
  - **Provisioned**: preallocate `RCU`/`WCU` (read/write capacity units). Use Auto scaling to adjust dynamically.
- **Conflict Resolution** is last-writer-wins based on timestamp. For multi-region Global Tables, replication conflicts follow this rule.
- **Features**:
  - **DynamoDB Streams**: Change Data Capture (CDC). Triggers Lambda/Kineses -> good for event-driven designs.
  - **DAX**: DynamoDB accelerator for caching. In-memory cache for microsecond latency for write-through/read-through.
  - **PITR**: Point-in-time recovery for backups.
  - **Global Tables**: multi region, active-active replication. Sub-second cross-region replication.
- **Billing**:
  - Streams, DAX, PITR are billed separately.
  - Hot partitions (from uneven key distribution) -> throttle costs and latency. Use composite partition keys (`userId#timestamp`)

```yaml
Version: "2012-10-17"
Statement:
  - Effect: Allow
    Action:
      - dynamodb:GetItem
      - dynamodb:PutItem
      - dynamodb:Query
      - dynamodb:UpdateItem
    Resource: arn:aws:dynamodb:us-east-1:123456789012:table/MyAppTable
```

**RDS**:
- **Supported Engines**: MySQL, PostgreSQL, MariaDB, Oracle, SQL Server.
- **Storage**:
  - Allocated storage does not shrink, but automatically grows up to max limit if Storage Auto Scaling enabled.
  - Billing for storage (GB/Month) + IOPS
- **Authentication**:
  - Supports IAM Database Authentication (short-lived tokens via `rds-db:connect`).
- **High Availability**:
  - Multi-AZ: Synchronous replication. Standby in another AZ. Automated failover (< 60s).
  - Single-AZ: Cheaper and riskier, only daily snapshot backups.
- **Scaling**:
  - Vertifcal scaling only (bigger instance sizes).
  - Use read replicas (async replication) for read scaling, but not HA.
- **Operational Practices**:
  - Rotate creds with Secrets Manager and Lambda rotation hooks to auto update the db password.
  - Monitor with Enahnced Monitoring and CloudWatch Alarms.
- **Billing**: Compute (instance type), Storage (GB/month), IOPS separately. Backups beyond retention billed.

- IAM policy for RDS IAM Authentication
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds-db:connect"
      ],
      "Resource": "arn:aws:rds-db:us-east-1:123456789012:dbuser:db-ABCDEFGHIJKL12345/dbuser"
    }
  ]
}
```

**Aurora**:
- **Engines**: Aurora MySQL & Aurora PostgreSQL.
- **Architecture**: Writer + up to 15 low-latency read replicas. All share distributed, multi-AZ storage layer (6-way replication across 3 AZs).
- **Scaling**:
  - **Aurora Serverless v2**: Auto-scales Aurora Capacity Units (`ACU`), billed per second. Good for bursty/spiky workloads.
  - **Horizontal scaling** via replicas. Aurora supports reader endpoints with load-balancing.
- **Global Databases**: Cross-region read replicas with sub-second replication lag. Failover is manual (promote replica).
- **Billing**:
  - Compute billed per instance/ACU.
  - I/O billed separately per request (this is often the hidden cost).
  - Backups and snapshots billed separately after retention.


**Redshift**
- **Type**: Fully managed data warehouse for analytics and BI.
- **Scaling**:
  - **Elastic Resize**: Quickly change node count.
  - **Concurrency Scaling**: Temporary extra clusters auto-spin up for heavy query load.
  - **Spectrum**: Query S3 data directly via external tables.
- **Availability/Recovery**:
  - Snapshots automatically replicated to S3. Cross-region snapshot copy supported.
  - No multi-AZ concept — entire cluster in one AZ, but snapshots provide DR.
- **Cost**:
  - Node-hour billing + separate Spectrum query charges.
  - Reserved instances save up to 75%.


**DocumentDB**
- **Type**: Managed MongoDB-compatible API (not true Mongo).
- **Usage**: Good for lift-and-shift of Mongo apps (e.g., Mongoose ORM). Limited feature parity — no `mapReduce`, certain aggregation stages missing.
- **HA**: Storage is replicated across 3 AZs. Failover within ~30s.
- **Scaling**:
  - Vertical scaling (larger instances).
  - Read replicas supported.
- **Cost Model**:
  - Same as RDS (instance-based compute + storage + IOPS).
  - Snapshots stored in S3 billed separately.

| Database   | Managed? | Scaling                  | HA                   | Global             | Cost Control            | Best For             |
| ---------- | -------- | ------------------------ | -------------------- | ------------------ | ----------------------- | -------------------- |
| RDS        | Semi     | Vertical + read replicas | Multi-AZ failover    | Read Replicas only | \$\$\$ predictable      | Legacy apps, OLTP    |
| Aurora     | Yes      | Horizontal + Serverless  | Multi-AZ, shared vol | Global DB          | \$\$–\$\$\$ (I/O heavy) | Cloud-native OLTP    |
| DynamoDB   | Yes      | Infinite (partitioned)   | Multi-AZ by default  | Global Tables      | \$ pay per request      | Serverless, IoT, KV  |
| Redshift   | Yes      | Cluster + concurrency    | Snapshots (S3 DR)    | Cross-region snaps | \$\$\$ high             | Analytics, BI, DW    |
| DocumentDB | Yes      | Vertical + read replicas | Multi-AZ storage     | No (single region) | \$\$ like RDS           | Mongo lift-and-shift |




### S3

**Core Concepts**:
- **Buckets**: Global namespace containers for objects.
- **Objects**: Data stored in S3, consisting of:
  - Key (unique identifier within a bucket).
  - Value (data payload).
  - Metadata (system + user-defined).
- **Regions**: Buckets are created in a specific AWS region and never move.

**S3 Best Practices**:
- Use bucket policies and IAM for access control.

- Grant the **`myapp-reader` IAM role** read-only access to the bucket (readonly.json)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReadOnlyAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/myapp-reader"
      },
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::myapp-prod/*"
    }
  ]
}
```
- Attach the policy using `--role-name`, `--policy-name`, and `--policy-document`.

```bash
aws iam put-role-policy \
  --role-name myapp-reader \
  --policy-name ReadOnlyS3Policy \
  --policy-document file://readonly.json
```

**Storage Classes**: Intelligent Tiering automatically moves data between tiers. 

- `STANDARD`: Frequent access, high durability.
- `STANDARD_IA`: Infrequent access, lower cost.
- `ONEZONE_IA`: Infrequent access, stored in a single AZ.
- `GLACIER`/`GLACIER_DEEP_ARCHIVE`: Archival, retrieval required.

- Buckets themselves don't have storage classes, the objects inside do. For example:
  - **Bucket**: `myapp-data-bucket`
  - `logs/2025-04-04.json` -> GLACIER
  - `images/banner.jpg` -> STANDARD
  - `reports/monthly.csv` -> INTELLIGENT_TIERING

- Data protection using **Oject Lock** (Write Once, Read Many (WORM) compliance).

- **Lifecycle policies** transition or expire objects automatically as well.

```json
{
  "Rules": [
    {
      "ID": "MoveToIA",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "logs/"
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ]
    }
  ]
}
```

- **Versioning** protects against accidental overwrite or deletion. Versioning is required for Object Lock and replication.

- Using the low-level aws s3api API interface to modify the versioning:
  - Overwrites and deletes do not erase data, they create new versions.

```bash
# Every new object version is uniquely stored.
aws s3api put-bucket-versioning \
  --bucket myapp-prod \
  --versioning-configuration Status=Enabled
```

- When you enable versioning, every `PUT` creates a new version, not a replacement. Every `DELETE` creates a delete marker, not a true deletion. `Version IDs` are assigned to each object.
  - Versioning can not be disabled, only suspended.

- **Encryption**
  - In Transit: TLS/SSL
  - At Rest: 
    - SSE-S3: AWS Managed Keys.
    - SSE-KMS: Customer Managed KMS Keys.
    - Client-side encryption: Encrypt before upload

- Example Bucket Encryption using SSE-KMS, a specific KMS key `abcd-efgh`.
  - If a PUT request does not specify encryption, S3 will automatically apply the KMS Key.
  - Existing objects are not retroactively encrypted

```bash
# Example Bucket Encryption (SSE-KMS)
aws s3api put-bucket-encryption \
  --bucket myapp-prod \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "arn:aws:kms:us-east-1:123456789012:key/abcd-efgh"
      }
    }]
  }'
```

- Use **CloudTrail** to track `Decrypt`, `Encrypt`, and `GenerateDataKey` events.
- Enforce encryption at the bucket level and deny uploads that do not use SSE-KMS.
- Inspect an object to see if SSE was used `aws s3api head-object --bucket mybucket --key path/to/object.txt`

### Elastic Beanstalk

AWS Elastic Beanstalk is a PaaS service that simplifies deployments and scaling of web apps and services. It provides a managed environment that handles provisioning, load balancing, and auto-scaling of underlying AWS resources. Less granular control than ECS/EKS. **It abstracts EC2, ELB, AutoScaling Groups, and CloudWatch**.

**Core Concepts and Platforms**
- Application: A logical container for your app.
- Application Version: A specific, deployable artifact of your app in `.jar` or `.war` (or `.zip`) format, uploaded to S3.
- Environment: An instance-specific app version running on a chosen stack. Each env is a collection of resources (Ec2. ALB, Auto Scaling Group, etc) managed by Beanstalk.
- Platforms (Java): Corretto (Standalone Java SE application, ideal for Spring Boot apps) and Tomcat (traditional Java web apps from WAR files to a managed Tomcat server)
- Configuration: Managed via EB console, `ebextensions/` or `.ebignore` + `Dockerrun.aws.json`.

**Customizing the Environment**
- Place `.ebextensions` folder in the root of the app source bundle, includes additional configuration files.
  - `.config`: Install additional packages.
  - `container_commands`: Run custom scripts.
  - `nginx.conf`: Modify server configuration.
  - `JAVA_TOOL_OPTIONS`: Env variable for JVM customizations (also JAVA_OPTS, JVM_ARGS).

**Deployment Strategies**
- All at once: NOT recommended, causes downtime.
- Rolling: Updates a batch of instances at a time. Rest of instances serve traffic.
- Rolling with additional batch: A new batch of instances is added to the env before updating the old instances.
- **Immutable**: Safest method for zero-downtime deployments. A new Auto Scaling Group is provisioned with new instances running the new version. Once instances are heavy, traffic is swapped. 

**Deployment Pipeline**
1. Build artifact (Maven/Gradle -> JAR/WAR)
2. Upload to S3 with `aws elasticbeanstalk create-application-version`
3. Deploy via:
- CLI: `aws elasticbeanstalk create-application-version`
- EB CLI: `eb deploy`

```bash
# Example: upload + deploy
aws elasticbeanstalk create-application-version \
  --application-name myservice \
  --version-label v1.0.0 \
  --source-bundle S3Bucket="my-bucket",S3Key="builds/myservice-v1.0.0.jar"

aws elasticbeanstalk update-environment \
  --environment-name myservice-prod \
  --version-label v1.0.0
```

**Architecture Pattern**
- Each microservice = separate EB app + environment.
- Shared services like DB, Redis, Kafka live outside of EB.
- Prefer ALBs for routing.
- Integrate with Route53 for DNS and service discovery.
- Use VPC-enabled environments with private subnets + NAT Gateways.
- Configure min/max instance counts and set scaling triggers.

**Best Practices and Notes**
- Extend metrics with Micrometer/Prometheus JMX Exporter sidecar.
- For Secrets, integrate with Secret Manager and SSM Parameter Store.
- Use Amazon Linux 2 instances for long term support.
- Pin dependencies to external services.

- Example .ebextensions/01-env.config

```yaml
option_settings:
  aws:elasticbeanstalk:application:environment:
    SPRING_PROFILES_ACTIVE: prod
    JAVA_OPTS: "-Xms512m -Xmx1024m"
  aws:autoscaling:launchconfiguration:
    InstanceType: t3.medium
  aws:elasticbeanstalk:environment:
    ServiceRole: "arn:aws:iam::123456789012:role/eb-service-role"
```

### CloudWatch

- CloudWatch, a monitoring and observability service, is deeply integrated with other AWS services, with most AWS services emitting metrics automatically.

**Core Components**:
1. `Metrics`: 
- Numerical time-series data published by AWS services or custom apps (CPUUtilization, Latency. RequestCount).
- Granularity: Standard resolution == 1 minute, High resolution == 1-second for custom metrics or select AWS services.

- Publish a custom metric:

```bash
aws cloudwatch put-metric-data \
  --metric-name PageLoadTime \
  --namespace MyApplication \
  --unit Seconds \
  --value 1.45
```
- Best Practices:
  - Use namespaces to organize metrics logically.
  - Standardize dimensions (e.g. InstanceId, Environment) for query efficiency.
  - Enable high resolution metrics only where required for the cost/performance tradeoff.

2. `Logs`:
- Centralized log storage & query via CloudWatch Logs Insights.
- Supports ingestion from **Lambda**, **ECS**, **EKS**, **EC2**, **VPC Flow Logs**, **ALB/ELB Logs**, **customApps**.
- Retention is configurable per log group (days -> indefinite)

- Query logs:

```bash
aws logs start-query \
  --log-group-name /aws/lambda/my-function \
  --start-time 1694300000 \
  --end-time 1694303600 \
  --query-string "fields @timestamp, @message | sort @timestamp desc | limit 20"
```

- Best Practices:
  - Use structured logging (JSON) for easier queries.
  - Configure log retention policies to manage costs.
  - Protect sensitive data before logging (avoid secrets, PII)

3. `Alarms`:
- Threshold-based alerts on metrics.
- Types: Can be statistic thresholds (CPU > 80%) or Anomaly detection (dynamic thresholds using ML)
- Actions: Can trigger SNS notifications, AutoScaling policies, EventBridge rules, Systems Manager automation.

- Create a CloudWatch Alarm of a specific EC2 instance must be triggered twice:
  - If triggered, will publish a message to the SNS topic `NotifyMe`

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name HighCPUAlarm \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=i-1234567890abcdef0 \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:us-east-1:111122223333:NotifyMe
```


4. `Events (EventBridge)`:
- Formerly CloudWatch Events. Delivers real-time event streams from AWS services and SaaS apps.
- Rule-based event bus (trigger Lambda on EC2 instance `State=stopped`).

- Event Rule for EC2 Instance State Change:

```bash
aws events put-rule \
  --name EC2StopRule \
  --event-pattern '{
    "source": ["aws.ec2"],
    "detail-type": ["EC2 Instance State-change Notification"],
    "detail": { "state": ["stopped"] }
  }'
```

- Best Practices:
  - Use **event buses** to separate environments (e.g., prod, dev).
  - Apply **dead-letter queues (DLQ)** for undeliverable events.
  - Prefer **EventBridge Pipes** for transformations before consumption.

5. `Dashboards`:
- Custom visualiation of metrics, alarms and logs across accounts.
- Cam aggregate across many accounts and regions.

- Create a Dashboard for CPU Utilization:

```bash
aws cloudwatch put-dashboard \
  --dashboard-name MyAppDashboard \
  --dashboard-body '{
    "widgets": [
      {
        "type": "metric",
        "x": 0,
        "y": 0,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            [ "AWS/EC2", "CPUUtilization", "InstanceId", "i-1234567890abcdef0" ]
          ],
          "title": "EC2 CPU Utilization"
        }
      }
    ]
  }'
```

- Best Practices:
  - Use **tag-based metrics selection** to make dashboards reusable.
  - Share dashboards with **cross-account IAM roles** for centralized visibility.
  - Use dashboards alongside **CloudWatch Synthetics Canaries** for user experience monitoring.

#### EKS

- For **EKS**, use CloudWatch Container Insights and Fluent Bit for logs.
    1. Install CloudWatch agent or Fluent Bit Daemonset.
    2. Logs go to CloudWatch Logs.
    3. Metrics -> Container Insights (CPU, Memory per pod, task)

- FluentBit Daemonset (pushes logs to CloudWatch per namespace/pod):

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: amazon-cloudwatch
spec:
  selector:
    matchLabels:
      k8s-app: fluent-bit
  template:
    metadata:
      labels:
        k8s-app: fluent-bit
    spec:
      serviceAccountName: fluent-bit
      containers:
        - name: fluent-bit
          image: public.ecr.aws/aws-observability/aws-for-fluent-bit:latest
          env:
            - name: AWS_REGION
              value: us-east-1
```

- Set Log Retention:

```hcl
resource "aws_cloudwatch_log_group" "eks_app" {
  name              = "/eks/myapp/dev"
  retention_in_days = 30
}
```

- Use metrics for autoscaling (scale pods when queue_length > 1000).
- Restrict IAM policies to `logs:PutLogEvents` and `cloudwatch:PutMetricData` only.

#### S3

- Enable S3 Storage Metrics (`BucketSizeBytes`, `NumberOfObjects`) and monitor per-bucket dashboards to visualize growth.
- Enable CloudWatch Request Metrics per bucket/prefix or operation. (GetRequests, PutRequests, 4xxErrors).

- **S3 Event Notifications** via CloudWatch/EventBridge:
    - S3 emits events like PutObject to AWS EventBridge, where rules can match events
    - The target would be an arn: `arn:aws:lambda:us-west-2:123456789012:function:ValidateFile`

```json
{
  "Source": ["aws.s3"],
  "DetailType": ["AWS API Call via CloudTrail"],
  "Detail": {
    "eventName": ["PutObject"]
  }
}
```

#### Lambda

- For **Lambda**, every invocation emits:
    - Duration
    - Errors
    - Throttles
    - IteratorAge (for streams)
- Logs from `console.log`, CloudWatch Logs automatically.
- Trigger alarms if `Errors > 0` or `Duration > 90th percentile`.

#### CloudTrail

- For **CloudTrail**, you can stream API events into CloudWatch Logs.
    - Use CloudTrail and CloudWatch to detect suspicious activity (root login, IAM policy changes, EC2 unusual provisioning).

```json
{
  "logGroupName": "CloudTrail/Logs",
  "filterPattern": "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }",
  "metricTransformations": [
    {
      "metricName": "UnauthorizedAPICalls",
      "metricNamespace": "Security",
      "metricValue": "1"
    }
  ]
}
```

### Load Balancing

1. **Application Load Balancer (ALB)**:
- Layer 7, best for HTTPS traffic and advanced routing based on URL paths, hostnames, query params.
- Supports WebSockets, HTTP/2 SSL/TLS offloading.
- Microservices, containerized applications, web applications with complex routing.
2. **Network Load Balancer (NLB)**:
- Operates at layer 4 (transport layer).
- Handles millions of requests at low latency.
- Provides a static IP per availability zone, supports TCP/UDP traffic.
- Preserves client IP addresses.
3. **Gateway Load Balancer (GWLB)**:
- Operates at layer 3 (network layer).
- Deploy, scale and manage virtual appliances.
4. **Classic Load Balancer (CLB)**:
- Legacy option, operates at layer 4 and layer 7.
- Basic load balancing for HTTP/S/TCP

**Best practices for AWS LBs**:
- Enable cross-zone load balancing to evenly distribute traffic across targets in multiple AZs.
- Use HTTPS/SSL with TLS offloading to improve security and lessen load on backend servers.
- Use autoscaling with your load balancer to dynamically adjust backend instances based on traffic demand, optimizing cost/performance.
- Use CloudWatch metrics and enable anomaly detection for early alerts.

**ALB with ECS**:
1. Each service (orders-service) is associated with a target group.
2. Tasks (containers) in that service are automatically registered/deregistered from the target group as they scale.
3. ALB listener rule routes traffic based on host/path to correct target group.

```yaml
ALB: my-app-alb
Listener 443: HTTPS
  Rule: Host = orders.example.com → TargetGroup: orders-service-tg
  Rule: Host = users.example.com → TargetGroup: users-service-tg
```

**ALB with EKS**
1. You don't assign an ALB directly, you use AWS Load Balancer Controller.
2. Define an Ingress resource in Kubernetes.
3. The controller:
- Provisions the ALB with listener on 443.
- Creates listeners and rules.
- Maps your K8 sercice -> ALB Target Group.
- Registers EKS pods dynamically as targets.

| Feature             | ECS                                              | EKS                                        |
| ------------------- | ------------------------------------------------ | ------------------------------------------ |
| How ALB is attached | Directly in ECS service definition               | Via AWS Load Balancer Controller (Ingress) |
| Target registration | ECS tasks auto-register                          | K8s pods auto-register                     |
| Routing rules       | Listener rules tied to ECS service target groups | Defined in Kubernetes Ingress              |


## Azure to AWS

### Networking and Security

**Azure Concept**:
- **NSG**: Stateful rules applied at subnet or NIC level.

**AWS Concepts**:
- **Security Group (SG)**: Stateful, instance-level firewall (Like Azure NSG at NIC level). Meant for the app/service-specific level security.
- **Network ACL (NACL)**: Stateless, subnet-level firewall (like Azure NSG at subnet level). Coarse subnet filtering, DDoS or broad controls.

### Identity and Access

**IAM vs Azure RBAC**
- Azure: RBAC is role-based, applied at resource/subscription level.
- AWS: IAM policies are JSON-based, attached to users, roles, or groups.

**Deny S3 Deletes with IAM policy**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyS3Delete",
      "Effect": "Deny",
      "Action": ["s3:DeleteObject"],
      "Resource": "arn:aws:s3:::mybucket/*"
    }
  ]
}
```

- This policy can be *attached* to an IAM user, role, group OR attached directly to the S3 bucket.

- `Statement` block is an array containing 1+ rules.
- `Sid` "DenyS3Delete" is an optional statyemnt ID for documentation purposes.
- `Effect` "Deny" means this rule *explicitly forbids* the action. This is regardless of other Allow statements. Deny ALWAYS overrides Allow in AWS evaluation.
- `Action` "s3:DeleteObject" lists 1+ S3 API actions to deny.
- `Resource` "arn:aws:s3:::mybucket/*" means every key/object within the bucket, not the bucket itself.

**Public Read Only Policy**

- Placed on the S3 bucket itself.

```json
{
  "Statement": [
    {
      "Sid": "AllowEveryoneReadOnlyAccess",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::examplebucket",
        "arn:aws:s3:::examplebucket/*"
      ]
    }
  ]
}
```

### CICD Pipelines

**AWS CodePipeline CodeBuild CodeDeploy**: more modular than Azure DevOps.

- AWS CodePipeline Yaml

```yaml
Version: '1.0'
Resources:
  MyPipeline:
    Type: AWS::CodePipeline::Pipeline
    Properties:
      RoleArn: arn:aws:iam::123456789012:role/CodePipelineRole
      Stages:
        - Name: Source
          Actions:
            - Name: GitHubSource
              ActionTypeId:
                Category: Source
                Owner: ThirdParty
                Provider: GitHub
                Version: '1'
              OutputArtifacts:
                - Name: SourceOutput
              Configuration:
                Owner: myorg
                Repo: myrepo
                Branch: main
        - Name: Build
          Actions:
            - Name: CodeBuild
              ActionTypeId:
                Category: Build
                Owner: AWS
                Provider: CodeBuild
                Version: '1'
              InputArtifacts:
                - Name: SourceOutput
              OutputArtifacts:
                - Name: BuildOutput
              Configuration:
                ProjectName: my-build-project
```

### Observability and Logging

**Azure Monitor vs AWS CloudWatch**

| **Feature**  | **Azure Monitor** | **AWS CloudWatch/X-Ray/CloudTrail** |
| -------- | ------------- | ------------------------------- |
| Metrics  | Metrics       | CloudWatch Metrics              |
| Logs     | Log Analytics | CloudWatch Logs                 |
| Tracing  | App Insights  | X-Ray                           |
| Auditing | Activity Logs | CloudTrail                      |

- Example CloudWatch Metric Filter (Error Logs):

```hcl
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "ErrorCount"
  log_group_name = "/aws/lambda/my-func"
  pattern        = "ERROR"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "MyApp"
    value     = "1"
  }
}
```

- `metric_transformation` defines the CloudWatch Metric to name and increment. Namespace organizes metrics under a given label.

### Kubernetes and Containers

**AKS vs EKS**
- **AKS**: Integrated with Azure AD, managed control plane.
- **EKS**: IAM integration with `IAM Role for Service Accounts (IRSA)`, more explicit. Still managed control plane.

- Pod with IAM role (EKS IRSA):

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-reader
  namespace: default # if you dont specify, it will go into default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/s3-reader-role
```

- The `annotation` associates the SA s3-reader with the specific IAM role `arn:aws:iam::123456789012:role/s3-reader-role`. A webhook intercepts requests from the pod using s3-reader SA, and injects env variables (`AWS_WEB_IDENTITY_TOKEN_FILE`, `AWS_ROLE_ARN`) and token into pod. Uses that info to make an API call to `sts:AssumeRoleWithWebIdentity` to assume the role defined in the annotation.

- When a pod runs with this service account, the AWS SDK inside the pod uses credentials from this IAM role, instead of the node's IAM role via OIDC Web Identity token.

- **OIDC Trust Relationship**: The IAM role has a trust policy, allowing it to be assumed by the EKS Service Account's OIDC token (issued by the cluster's OpenID Connect Provider)

- IAM Role Trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/1234EXAMPLE"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/1234EXAMPLE:sub": "system:serviceaccount:default:s3-reader"
        }
      }
    }
  ]
}
```

**How it works**:

1. EKS clusters create an OIDC Identity Provider (IdP) and endpoint (https://oidc.eks.us-east-1.amazonaws.com/id/1234EXAMPLE) for issuing service account tokens.
2. The IAM Role's trust policy includes a `sts:AssumeRoleWithWebIdentity` permission referencing the OIDC provider and restricting the subject (sub) claim to the specific namespace and service account name.
3. The annotation on the Kubernetes ServiceAccount tells EKS to inject the required credentials in any pod using that service account.
4. Your applications running inside that pod automatically receive AWS credentials from the assumed IAM role via environmental variables and SDKs.

**In English**
1. EKS creates an OIDC endpoint (like `https://oidc.eks.us-east-1.amazonaws.com/id/1234EXAMPLE`).
2. You tell IAM: “Hey, trust tokens from this OIDC provider.”
3. You make an IAM Role with a trust policy:
- Only accept tokens from this OIDC provider.
- Only if the token belongs to a specific service account + namespace in Kubernetes.
4. A pod running with that service account automatically gets AWS creds for that role.