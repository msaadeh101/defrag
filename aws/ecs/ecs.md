# ECS

## Overview

ECS is a fully managed container orchestration service for running Docker containers in AWS. ECS supports EC2 and Fargate lunach types and is tightly integrated with ECS core services.

## Key Components

- **Cluster**: Logical grouping of EC2 or Fargate Resources
- **Task Definition**: Blueprint in JSON describing container settings, networking, resource limits and dependencies.
- **Task**: A running instance of a task definition.
- **Service**: Runs and maintains tasks, ensures availability, supports scaling, load balancing and rolling updates.

## Launch Types

- **EC2**: User-managed EC2 instances provide the cluster's compute resources.

- **Fargate**: Serverless option, AWS manages compute; tasks get isolated networking via ENI.

## Networking Modes

- `awsvpc`: Task ENI Allocation. Each task recieves a dedicated Elastic Network Interface ENI, provisioned in the target VPC/subnet and assigned a private IP.
    - Each ENI may have its own security group(s) allowing segmentation at the task level (not just instance).
    - A special "pause" container is initiated to hold the ENI and provide network namespace. Then all user containers in task join the same namespace and communicate over localhost (loopback) but EXTERNALLY represented by ENI IP. All exposed container ports are directly accssible via ENI.
    - Only ALB or NLB can target awsvpc-mode tasks, and ONLY by IP address.
    - High network performance over AWS backbone.
    - Supports IPv6.
    - If using EC2, consider instance type as it relates to ENI allocation. Check with `aws describe instance types`
- `bridge`: Docker default, with NAT and overlay, port mapping is required and SGs only at the instance level.
- `Host`: Containers share EC2 instance stack directly, highest performance but all tasks must use unique host ports with NO MAPPING.
- `None`: no external stack except loopback, for custom sidecar-driven networking.

|Mode|Isolation|Port Mapping|EC2|Fargate|Performance|OS|
|----|---------|------------|---|-------|-----------|--|
|`awsvpc`	|ENI/IP	|Container ports only |	Yes| Yes	|High	|Linux/Win|
|`bridge`	|DockerNet	|Host<->Container|	Yes|	No |	Moderate|	Linux|
|`host`	|HostNet	|Host ports only|	Yes	| No	|Highest	|Linux|
|`none`	|Loopback|	N/A	|Yes|	No	|N/A|	Linux|
|`nat`|	NAT	| Host <-> Container|	Yes	|No	|Moderate|	Windows|

- **Note**: `awsvpc` mode is preferred for security (per-task ENI/security groups) and required for Fargate.

## Network Architecture

### VPC Networking

- Use VPC isolation for per-environment clusters. DO NOT mix ECS with unrelated EC2 instances.
- Use private subnets plus NAT gateways for outbound Internet (non-public services).
- Public subnets with IGW for services requiring direct internet access.

### Intra-ECS Communication

- Tasks/Services can communicate over private IP within same VPC/subnet.
- Apply security groups at task level (awsvpc) or EC2 host (host/bridge).
- For cross-VPC/clusters, use VPC Peering or Transit Gateway.

## Service Discovery and Service Connect or Cloud Map

- **ECS Service Connect** enables seamless recovery and communication between ECS services in a shared namespace.
    - Each service can have endpoints, DNS-based names, and configurable proxies.
    - Supports both "client-only" and "client-server" service modes for flexibility.
- For tasks outside the namespace or across clusters, use Service Connect + Cloud Map or DNS integration.

## Load Balancing

- ECS integrates with ELBs (ALB/NLB) for HTTP or TCP load distribution and health checks.
- Load balancers can be exposed to the internet or internal for microservices.

## Scaling and Automation

**Service-level scaling**:
- Horizontal Task scaling: ECS services scale by increasing/decreasing number of task replicas (manually, scheduled, or automatically based on CloudWatch metrics).
- Fast network scale-out: Each new task is assigned a new ENI, makes tasks independantly routable, speeding up registration and removal in target groups, minimizing connection drain time.
- Auto Scaling: ECS can leverage Target Tracking (e.g. maintain 70% average CPU) on the service, and use **scale-in protection** for critical tasks.

**Cluster-Level Scaling**:
- Fargate: No Cluster management. AWS provides compute. Fargate has regional resource quotas (soft limits) subject to ENI and IP space.
- EC2: Scaling involces integration with EC2 Auto Scaling Groups.
- Task Placement: binpack (fill up each host by CPU or memory) or spread (breadth-first across AZs or host atributes.)

**Network/Scaling Pitfalls**
- ENI/IP Exhaustion: in awsvpc mode, you can exhaust CIDR limits or ENI limits at scale. Monitor available IPs in subnet regularly.
- Burst Scaling: Large rapid scale outs may trigger ENI quota errors.
- Elastic Load Balancer Registration: With ALB/NLB (IP target mode), large numbers of target registrations can throttle. PRE-WARM if many targets are expected.
- **For EC2 Mode**: A c5.large EC2 Host with awsvpc networking mode (no ENI trunking) can only have 2 running tasks per instance (one is reserved for the primary ENI for the EC2 itself)

### Other Scaling Notes

- Use Auto Scaling for ECS Services and Clusters (*target tracking* and *scheduled*)
- For event-based scaling integrate with KEDA for native container scaling.
- Employ Blue Green Deployments for zero downtime rollouts using ECS service integrations.

## Logging and Monitoring

- Integrate with CloudWatch Logs for centralized app logging.
- Use CloudWatch Metrics/Alarms for task and service health and scale triggers.
- Enable VPC flow logs to audit and troubleshoot network connections.

## Security Best Practices

- Prefer `awsvpc` networking for fine-grained security (*per-task security groups/firewalls*).
- Use application-layer encryption like mTLS, leverage AWS PrivateLink for secure, private access to AWS services.
- Regularly audit your security group and NACL rules.
