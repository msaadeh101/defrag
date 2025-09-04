# Alibaba Cloud

## Infrastructure and Resources

**Resource Orchestration Service**: In addition to Terraform and OpenTofu, Alibaba Cloud provides its own native `Resource Orchestration Service (ROS)`. It allows you to create resources like ECS, AsparaDB, SLB, VPC, etc and their dependencies in JSON and YAML templates.
    - Resources are grouped as `stacks` deployed from templates, simplifying lifecyle management.
    - ROS can provision resources across multiple regions/accounts with shared templates.
    - Includes terraform support, to use both Alibaba and Terraform side-by-side.
    - Includes Drift Detection.
    - Stacks can be managed via the console's visual editor or using APIs/SDKs.
    - Integrates with Ali Resource Access Management (RAM) for access control, and ActionTrail for logging/auditing.

- Deploy the below ECS and VPC ROS with cli: `aliyun ros CreateStack --StackName ecs-demo --TemplateBody file://ecs-demo.yaml`


```yaml
#ecs-demo.yaml
ROSTemplateFormatVersion: '2015-09-01'
Description: Simple ECS instance with VPC
Resources:
  MyVPC:
    Type: ALIYUN::VPC::Vpc
    Properties:
      VpcName: my-vpc
      CidrBlock: 192.168.0.0/16

  MyVSwitch:
    Type: ALIYUN::VPC::VSwitch
    Properties:
      VpcId: !Ref MyVPC
      ZoneId: cn-hangzhou-h
      CidrBlock: 192.168.1.0/24

  MyECS:
    Type: ALIYUN::ECS::Instance
    Properties:
      InstanceType: ecs.g6.large
      ImageId: centos_7
      VSwitchId: !Ref MyVSwitch
      SecurityGroupId: !Ref MySecurityGroup

  MySecurityGroup:
    Type: ALIYUN::ECS::SecurityGroup
    Properties:
      VpcId: !Ref MyVPC
```

### Network

**Virtual Private Cloud (VPC)**: Use private subnets for your backend resources (databases, internal services) and public subnets only for resources that need direct internet access (like a `Server Load Balancer)`.

**Server Load Balancer (SLB)**: Use `SLB` to distribute traffic across your application instances for high availability and to protect them from direct internet exposure.

**Network Access Control**: Implement `Security Groups` as your first line of defense to control inbound and outbound traffic at the instance level.

### Compute

**Elastic Compute Service (ECS)**: For traditional VMs, use ECS. When scaling, use `Auto Scaling` to automatically adjust the number of ECS instances based on real-time metrics, ensuring you can handle traffic spikes.

**Container Service for Kubernetes (ACK)**: For modern, microservices-based applications, `ACK` is the go-to. Use a managed ACK cluster to offload the burden of managing the Kubernetes control plane.

### DevOps

**Cloud Code**: Use a centralized repository like `Alibaba Cloud Code`, GitHub, or GitLab. 

**Ali Container Registry**: Store all build artifacts in a central location. For Docker images, `Container Registry (ACR)` is the dedicated service. Use private repositories to keep your images secure.

### Observability: Monitoring and Logging

**Simple Log Service (SLS)**: Use `SLS` to collect logs from all your services—ECS instances, ACK containers, and other Alibaba Cloud services.

- Collect logs from ECS:

```bash
aliyun log CreateLogstore --project myproj --logstore ecs-logs
```

**CloudMonitor**: `CloudMonitor` provides real-time metrics for all Alibaba Cloud resources. Set up `alarm rules` to notify your team via email, DingTalk, or an API endpoint when key metrics (e.g., high CPU usage, low disk space, network errors) exceed predefined thresholds.

- Example Trigger Alarm for CPU > 80%:
```json
{
  "MetricName": "CPUUtilization",
  "ComparisonOperator": ">=",
  "Threshold": "80",
  "EvaluationCount": "5",
  "AlarmActions": ["http://my-webhook.example.com"]
}

```

**Application Real-Time Monitoring (ARMS)**: For deeper insights into application performance, use `ARMS`. It helps identify bottlenecks in your application code, database queries, or microservice calls.

### Security and Compliance

**Resource Access Management (RAM)**: Use `RAM` to enforce the principle of least privilege. Create specific RAM roles and users for applications and team members.

**Security Center**: This service provides automated vulnerability scanning, malware detection, and real-time threat analysis for your ECS instances.

**Web Application Firewall (WAF)**: Place a `WAF` in front of your public-facing applications to protect against common web exploits like `SQL injection `and `cross-site scripting (XSS)`.

- Deny requests matching `(?i)select.*from` in query string.

**ActionTrail**: Enable `ActionTrail` to log all API calls and operations performed on your account. This provides a detailed audit trail for compliance and forensic analysis.

- Enable via CLI:
```bash
aliyun actiontrail CreateTrail --Name mytrail --OssBucketName my-audit-bucket
```

## Example Project

- Set Credentials in Github or Jenkins

- Run the Swiss Army Knife:

```bash
# Configure and deploy
./general-swiss-army.sh config
./general-swiss-army.sh deploy

# Monitor deployed resources
./general-swiss-army.sh health-check
```

- User_data script sets up the ECS instance:

It runs again upon changes to the script due to `lifecycle`
