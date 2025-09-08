# AWS

## Best Practices

### EKS and Secrets
- AWS EKS supports IRSA, bridges Kubernetes RBAC and AWS IAM using OIDC trust relationships.

- Trust Policy snippet:

```json
"Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED1234:sub": "system:serviceaccount:default:s3-reader"
        }
```

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
- NoSQL Key-Value/Document Store
- On-demand (pay per request) vs Provisioned capacity (pre-allocate, cheaper for steady traffic).
- Conflict Resolution is last-writer-wins.
- DynamoDB Streams: Change Data Capture (CDC) for Lambda, Kinesis, etc.
- DAX: DynamoDB accelerator for caching. In-memory cache for microsecond reads.
- PTR: Point-in-time recovery for backups.
- Streams, DAX, and backups are billed separately.

**RDS**:
- MySQL, PostgreSQL, MariaDB, Oracle, SQL Server.
- Storage automatically grows up to max limit.
- Use IAM tokens for authentication.
- Always enable multi-AZ deployments, synchronous replication -> Standby in a different AZ.
- Use read replicas for scale-out reads.
- Rotate passwords with Secrets Manager and Lambda rotation hooks.
- Compute and Storage billed separately based on instance size and GB/month respectively

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
- Aurora MySQL, Aurora PostgreSQL.
- I/O is billed separately per request.
- Aurora Advanced configs:
    - `Aurora Clusters`: Writer + up to 15 low-latency read replicas (shared distributed storage).
    - `Aurora Serverless v2`: Autoscaling CUs, pay per second of usage (good for dev/test, spiky)
    - `Global DB`: Replicates to multiple AWS regions with sub-second lag.


| Database | Managed? | Scaling               | HA  | Global                 | Cost Control         | Best For          |
| -------- | -------- | --------------------- | --- | ---------------------- | -------------------- | ----------------- |
| RDS      | Semi     | Vertical only         | Yes | Read Replicas          | \$\$\$ predictable   | Legacy/OLTP       |
| Aurora   | Yes      | Horizontal/Serverless | Yes | Global DB              | \$\$–\$\$\$          | Cloud-native apps |
| DynamoDB | Yes      | Infinite              | Yes | Global Tables          | \$ (pay per request) | Serverless, IoT   |
| Redshift | Yes      | Cluster resize        | Yes | Cross-region snapshots | \$\$\$ high          | Analytics, BI     |

**DocumentDB**:
- Managed Document db that is MongoDB API compatible. If you have an existing Mongo app with `mongoose`, point to DocumentDB.
- Pricing is similar to RDS (based on instance type, storage, IOPS).

### S3

**S3 Best Practices**:
- Use bucket policies and IAM for access control.

- Grant the myapp-reader IAM role read-only access to the bucket

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

**Storage Classes**: Intelligent Tiering automatically moves data between tiers. Buckets themselves don't have storage classes, the objects inside do.
- `STANDARD`
- `STANDARD_IA`
- `ONEZONE_IA`
- `GLACIER`

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

### CloudWatch

- CloudWatch is deeply service integrated, with most AWS services emitting metrics automatically.

**Core Components**:
1. `Metrics`: 
- Numerical time-series data (CPUUtilization, Latency).
- Granularity: 1 minute is standard, 1-second for custom metrics at the lowest.
2. `Logs`:
- Centralized log storage & query via CloudWatch Logs Insights.
- Supports ingestion from **Lambda**, **ECS**, **EKS**, **EC2**, **VPC Flow Logs**, **ALB Logs**.
- Retention is configurable per log group (days -> indefinite)
3. `Alarms`:
- Threshold-based alerts on metrics.
- Actions: SNS, AutoScaling, EventBridge, Systems Manager.
4. `Events (EventBridge)`:
- Formerly CloudWatch Events.
- Rule-based event bus (trigger Lambda on EC2 instance State=stopped)
5. `Dashboards`:
- Custom visualiation of metrics and logs across accounts.

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

- Enable S3 Storage Metrics (BucketSizeBytes, NumberOfObjects) and monitor per-bucket dashboards to visualize growth.
- Enable CloudWatch Request Metrics per bucket/prefix or operation. (GetRequests, PutRequests, 4xxErrors).

- S3 Event Notifications via CloudWatch/EventBridge:
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
- Trigger alarms if Errors > 0 or Duration > 90th percentile.

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