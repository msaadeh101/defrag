# AWS EKS to ECS Migration Plan

## Executive Summary

ECS/ECS Fargate removes the Kubernetes control-plane/node management from operations and can simplify costs at medium scale compared to EKS. ECS integrates tightly with other AWS services.

## High Level Migration Phases

1. **Assessment and Discovery**: Understand the current landscape.
- **Inventory everthing**: Catalog all workloads, persitent volumes, secrets, CRDs, microservices, and their current resource requirements.
- **Dependency Mapping**: Identify all service-service communication, database communication, external APIs, shared volumes.
- **Stateful needs**: Flag services with persistent storage, sticky sessions or long-lived connections.
- **Operational patterns**: Take note of scaling behavior, deployment frequency, failure recovery patterns.
- **Tooling Audit**: List CI/CD pipelines, monitoring tools, secrets management, and ingress controllers.

2. **Design and Mapping**: Translate Kubernetes concepts into ECS concepts.
- **Workload Mapping**:
    - Deployment -> `ECS Service` + `Task Definition`
    - Pod -> `ECS Task`
    - ReplicaSet -> `ECS Desired Count`
- **Configuration/Secrets**:
    - ConfigMap -> A`WS SSM Parameter Store` or `ECS env variables`.
    - Secret -> `ECS Task secrets` or `AWS Secrets Manager`.
- **Networking and Ingress**:
    - Ingress -> `Application Load Balancer` + `Target Groups`.
    - Service (ClusterIP/NodePort) -> `ECS Service` with appropriate **networking mode** (`bridge`, `awsvpc`).
- **Scheduling and Affinity**:
    - Node Affinity -> `ECS placement constraints`.
    - Tolerations -> `ECS capacity providers` or `Fargate vs EC2 decisions`.

3. **Preparation**: Groundwork for a smooth migration.
- **Containerization**:
    - Ensure Dockerfiles are ECS-compatible (e.g. health checks, logging drivers).
- **Infrastructure setup**:
    - Create ECR, new repositories, IAM roles, ECS Clusters.
    - Set up terraform configuration for IaC.
    - Configure VPC, subnets, security groups, service discovery.
- **CI/CD Integration**:
    - Update Jenkins pipelines to support ECS deployments.
- **Monitoring**:
    - Set up `CloudWatch`, `X-Ray`, `container insights`.

4. **Parallel Pilot Deployment**: Deploy the real service in a non-prod ECS environment.
- **Clone the service**: Use the same container image, config, secrets as production.
- **Isolated ECS setup**: Create a separate ECS cluster/environment with completely different VPC to avoid interference.
- **Simulate traffic**: Replay real traffic using tools like `Locust`, `K6`, or `mirror requests` from production.
- **Validate End-to-end**:
    - Ensure networking, IAM roles, secrets, logging, autoscaling all behave as expected.
    - Confirm parity with Kubernetes in terms of performance, reliability, observability.
- **Feedback Loop**:
    - Iterate: Document gaps, refine ECS configurations, update deployment playbooks.

5. **Controlled Cutover**: Switch production traffic to ECS once parallel deployment is stable.
- **Prepare for Swtichover**:
    - Ensure ECS service is scaled and warmed up.
    - Set up health checks, alarms, and rollback mechanisms.
- **Traffic Redirection**:
    - Use DNS changes, ALB target group updates/ or service discovery to shift traffic.
    - Consider gradual rollout (i.e. weighted routing, canary).
- **Monitor**:
    - Watch metrics, logs, and user experience during and after cutover.
    - Be ready to revert back to kubernetes.
- **Optimization**:
    - Right-size ECS tasks based on actual usage.
    - Optimize costs using Spot instances where appropriate.

## Success Criteria

- Zero data loss during migration
- Application performance meets or exceeds current levels
- All security and compliance requirements maintained
- Operational processes established and documented
- Team trained and comfortable with new platform
- Cost savings achieved within 6 months post-migration


## Extra Notes
- Create **IAM Roles** and **policies** for ECS.
- **Hybrid approach**: Mix of both Fargate and EC2 launch type based on workload requirements.
- **Service discovery**: Kubernetes DNS vs AWS Service Discovery.
- **Storage**: Persistent volumes vs EFS/EBS integration.
- **Blue-Green** deployment with gradual traffic shifting. Green is the target ECS environment, keep Blue EKS environment for rollback option.
- **Validate data integrity** and consistency, database connectivity, set up data replication.
- **Load testing and security testing** to ensure availability and compliance.
- **Decommission** EKS resources after validation period.
- Configure ECS services with **service discovery integration**.
- Update application to use **new endpoints**.
- Configure **X-Ray SDK** in applications for distributed tracing.
- Migrate existing **monitoring solutions** (Prometheus, Grafana) and configure **APM tools**.
- Update **Alerting** channels.


### Technical Notes

- Container Image Migration
```bash
# Example: Tag and push existing images to ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com
docker tag my-app:latest <account-id>.dkr.ecr.us-west-2.amazonaws.com/my-app:latest
docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/my-app:latest
```

- Task Definition Conversion (Kubernetes Deployment, ConfigMap, Persistent Volume)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-app-config
data:
  APP_MODE: "production"
  LOG_LEVEL: "info"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web-app
        image: my-app:latest
        ports:
        - containerPort: 8080
        envFrom:
        - configMapRef:
            name: web-app-config
        volumeMounts:
        - name: app-storage
          mountPath: /data
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: app-storage
        persistentVolumeClaim:
          claimName: web-app-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: web-app-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

- ECS Equivalent Task Definition and Service. The Task Definition is a blueprint for your app, while the Service is what runs and manages the blueprint. The Service takes the task defintion and makes seure the specified number of copies/tasks are running and constantly healthy.

- Task Definition:

```json
{
  "family": "web-app",
  "taskRoleArn": "arn:aws:iam::account:role/ecsTaskRole",
  "executionRoleArn": "arn:aws:iam::account:role/ecsExecutionRole",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "containerDefinitions": [
    {
      "name": "web-app",
      "image": "account.dkr.ecr.region.amazonaws.com/my-app:latest",
      "cpu": 256,
      "memoryReservation": 256,
      "memory": 512,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "APP_MODE",
          "value": "production"
        },
        {
          "name": "LOG_LEVEL",
          "value": "info"
        }
      ],
      "mountPoints": [
        {
          "sourceVolume": "app-storage",
          "containerPath": "/data",
          "readOnly": false
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/web-app",
          "awslogs-region": "us-west-2",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ],
  "volumes": [
    {
      "name": "app-storage",
      "efsVolumeConfiguration": {
        "fileSystemId": "fs-12345678",
        "rootDirectory": "/web-app-data",
        "transitEncryption": "ENABLED"
      }
    }
  ]
}
```

- `"family": "microservice-app"`: Task definition family, used to group multiple revisions of the same task def.
- `"networkMode": "awsvpc"`: Each task gets its own ENI, private IP and can use SGs like EC2 instances.
- `"cpu": "512"`: The maximum CPU allocated to the task. CPU usage may be throttled if attempting to go higher.
- `"memory": "1024"`: Max memory the task can use, will be terminated with OOM if it exceeds the limit.
- `"executionRoleArn": "arn:aws:iam::account:role/ecsTaskExecutionRole"`: Pull container images/write CloudWatch Logs.
- `"taskRoleArn": "arn:aws:iam::account:role/ecsTaskRole"`: Containers assume this role at runtime for Dynamo,S3, etc.
- `"containerPort"`: 8080: ECS forwards traffic to port 8080 inside the container.
- `"cpu": 256` and `"memoryReservation": 256`: CPU and memory reservation for the container. A request not a limit.
- `"memory": 512`: Hard memory limit for the container, it may be killed if it exceeds or restarted.
- `"mountPoints": [...]`: Mounts a volume named app-storage inside the container at path /data. Writable.
- `"logConfiguration": {...}`: Uses AWS CloudWatch Logs driver for container logs. Prefixed with ecs.
- `"volumes": [...]`: Declares a volume named app-storage backed by AWS EFS at the task level.

- Service Definition:

```json
{
  "serviceName": "web-app-service",
  "cluster": "your-cluster-name",
  "taskDefinition": "web-app",
  "desiredCount": 3,
  "launchType": "FARGATE",
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "subnets": ["subnet-abc123", "subnet-def456"],
      "securityGroups": ["sg-xyz789"],
      "assignPublicIp": "ENABLED"
    }
  },
  "loadBalancers": [
    {
      "targetGroupArn": "arn:aws:elasticloadbalancing:region:account:targetgroup/web-app-tg/abc123",
      "containerName": "web-app",
      "containerPort": 8080
    }
  ]
}
```

- `"taskDefinition": "web-app"`: Service applies to the web-app task definition that defines the web-app container.
- `"desiredCount": 3`: ECS ensures 3 tasks are running at all times.
- `"subnets": ["subnet-abc123", "subnet-def456"]`: The VPC subnets where the ENIs will be placed.
- `"securityGroups": ["sg-xyz789"]` — Security groups applied to the task ENIs controlling inbound/outbound traffic.
- `"assignPublicIp": "ENABLED"` — Assigns a public IP address to each task for internet accessibility.
- `"targetGroupArn"` — ARN of the ELB target group that routes traffic to the tasks.

- An internal application would have PublicIP disabled:

```json
{
  "serviceName": "internal-microservice-service",
  "cluster": "your-cluster-name",
  "taskDefinition": "internal-microservice",
  "desiredCount": 2,
  "launchType": "FARGATE",
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "subnets": ["subnet-private1", "subnet-private2"],
      "securityGroups": ["sg-internal-service"],
      "assignPublicIp": "DISABLED"
    }
  }
}
```