# AWS Elastic Beanstalk

**AWS Elastic Beanstalk (EB)** is a fully managed service that simplifies the deployment, management, and scaling of web apps and services. It abstracts much of the infrastructure complexity.


## Key Concepts

### Application
An EB `Application` is a logical container for EB components such as environments and application versions.

### Environment
An EB `Environment` is a collection of AWS resources (like EC2 instances, load balancers, auto-scaling groups) running an application version. Each environment runs on a specific platform.

### Platform
A `Platform` is the combination of an OS, runtime (e.g., Java, Node.js, Python), web server, and Beanstalk components. EB provides managed platforms or supports custom platform containers.

### Application Version
An `Application Version` represents a specific, deployable iteration of your source code, typically stored in an Amazon S3 bucket.


## Features

- **Automatic provisioning** of infrastructure resources (EC2, ELB, Auto Scaling, S3, CloudWatch).
- **Support for multiple platforms and languages,** including Java, .NET, Node.js, PHP, Python, Ruby, Go, and Docker.
- **Built-in monitoring and health checks** with automatic recovery and scaling.
- **Customizable environment configuration** via configuration files or console.
- **Managed updates and platform upgrades** with minimal downtime.
- **Integration** with developer tools like AWS CLI, SDKs, and CloudFormation.


## How Elastic Beanstalk Works

### Simplified Process

1. **Create an Application:** Acts as a container and management point for your project.
2. **Upload an Application Version:** Your application code packaged and uploaded (ZIP, WAR, Docker image).
3. **Create an Environment:** EB provisions resources for the application version on the selected platform.
4. **Deploy and Run:** EB deploys your application and manages infrastructure lifecycle.
5. **Monitor and Scale:** Automatically scales based on load, monitors application health, and provides logs.

### Core Architecture

- Repository structure:

```txt
your-app/
├── .ebextensions/
│   ├── platform.config
│   ├── alb.config
│   ├── security-groups.config
│   └── deployment.config
├── src/
├── pom.xml (or build.gradle)
├── Dockerfile
└── target/
    └── your-app.jar
```

- The **Platform Configuration** lives in the `.ebextensions/01-platform.config` at the root of the app projct, at the same level as your Dockerfile. Both the `.ebextensions` and Jar/Dockerfile get included in the deployment bundle.
    - The files in `.ebextensions/` are processed in alphabetical orcer.

```yaml
# .ebextensions/01-platform.config
option_settings:
  aws:elasticbeanstalk:environment:
    EnvironmentType: LoadBalanced
  aws:elasticbeanstalk:application:
    Application Healthcheck URL: /actuator/health
  aws:autoscaling:launchconfiguration:
    InstanceType: m5.large
    IamInstanceProfile: aws-elasticbeanstalk-ec2-role
  aws:elasticbeanstalk:healthreporting:system:
    SystemType: enhanced
  aws:elasticbeanstalk:environment:process:default:
    HealthCheckPath: /actuator/health
    Port: '80'
    Protocol: HTTP
```

- You can define the ALB, SG and Deployments in their own configuration files, here is the 02-alb.config:

```yaml
# .ebextensions/02-alb.config
Resources:
  TargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      HealthCheckPath: /actuator/health
      HealthCheckIntervalSeconds: 15
      HealthyThresholdCount: 2
      UnhealthyThresholdCount: 5
      HealthCheckTimeoutSeconds: 10
      Matcher:
        HttpCode: '200'
      TargetType: instance
      Protocol: HTTP
      Port: 80
```

- Service Discovery Config (`03-service-discovery.config`):

```yaml
# .ebextensions/03-service-discovery.config
option_settings:
  aws:elasticbeanstalk:application:environment:
    SERVICE_DISCOVERY_ID: "srv-abcd1234"
    SERVICE_DISCOVERY_NAMESPACE: "microservices.local"
```
- Or using Parameter Store References:

```yaml
# .ebextensions/03-security-groups.config
Resources:
  ServiceSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Security group for microservice
      VpcId: "{{resolve:ssm:/infrastructure/vpc-id}}"
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 8080
          ToPort: 8080
          SourceSecurityGroupId: "{{resolve:ssm:/infrastructure/alb-security-group-id}}"
      SecurityGroupEgress:
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 3306
          ToPort: 3306
          DestinationSecurityGroupId: "{{resolve:ssm:/infrastructure/db-security-group-id}}"

option_settings:
  aws:autoscaling:launchconfiguration:
    SecurityGroups: !Ref ServiceSecurityGroup
```

## Benefits

- **Simplicity:** Deploy in minutes with minimal setup.
- **Managed Infrastructure:** Focus on code instead of managing servers.
- **Scalability:** Auto Scaling and load balancing configurations are automatic.
- **Flexibility:** Customize configurations or use your own Docker containers.
- **Cost efficiency:** Pay only for the underlying AWS resources you consume.


## Elastic Beanstalk For Multi Docker Container (ECS)

EB supports running **multi-container Docker applications** using ECS to orchestrate containers on EC2 instances within the environment. EB only supports deploying ECS with **EC2 Launch Type**

### Overview
- The **ECS managed Docker platform** in EB allows running multiple Docker containers side-by-side on each EC2 instance.
- It manages the underlying ECS cluster, task definitions, container deployment, and scaling automatically.
- Containers and their configurations are defined in a `Dockerrun.aws.json` (version 2) file, which specifies container images, ports, volumes, and environment variables.
- Beanstalk handles the lifecycle of ECS resources including clusters, tasks, and agents behind the scenes.

### Components Created by Elastic Beanstalk

- **Amazon ECS Cluster:** Each Elastic Beanstalk Docker environment creates a dedicated ECS cluster.
- **ECS Task Definition:** Generated from the `Dockerrun.aws.json` v2 file, it defines how containers run on the instances.
- **ECS Tasks:** Tasks run on each instance to manage container lifecycle.
- **ECS Container Agent:** Runs on EC2 instances to coordinate container orchestration.
- **Volumes for logs:** Beanstalk creates data volumes on instances (e.g., `/var/log/containers`) for container log collection.

### Application Structure

- Define multiple containers with their images, CPU/memory settings, ports, and logging specifics in `Dockerrun.aws.json` v2 at the root of the project directory.
- Containers can share data volumes mounted into host instance paths.
- Common use case: a web application container alongside a reverse proxy or sidecar container.

```json
{
  "AWSEBDockerrunVersion": 2,
  "containerDefinitions": [
    {
      "name": "web",
      "image": "nginx:latest",
      "essential": true,
      "memory": 128,
      "portMappings": [
        { "hostPort": 80, "containerPort": 80 }
      ]
    },
    {
      "name": "api",
      "image": "myorg/my-api:latest",
      "essential": true,
      "memory": 256,
      "portMappings": [
        { "hostPort": 5000, "containerPort": 5000 }
      ],
      "environment": [
        { "name": "ENV", "value": "production" }
      ]
    }
  ]
}
```

### Benefits

- **Simplifies multi-container Docker deployments** without manually managing ECS concepts.
- Supports **automatic scaling and load balancing**.
- Allows **using ECS features** under the hood while providing Elastic Beanstalk simplicity.
- Supports migration from the older Multi-Container Docker on Amazon Linux AMI (AL1) to ECS on Amazon Linux 2/2023 without code changes.

### Actual Workflow

1. Go to Elastic Beanstalk, create a new EB Application.
```bash
# eb init creates or configures an EB app in your local directory
eb init --platform "Multi-container Docker" --region us-east-1 microservices-platform
# Platform specification
eb init
# Select: Multi-container Docker running on 64bit Amazon Linux 2
# Application name: microservices-platform
# SSH keypair: microservices-keypair
```
2. Choose a platform (e.g., Node.js, Python, Docker).
```yaml
# .ebextensions/01-platform.config
option_settings:
  aws:elasticbeanstalk:environment:
    EnvironmentType: LoadBalanced
  aws:elasticbeanstalk:application:
    Application Healthcheck URL: /health
  aws:autoscaling:launchconfiguration:
    InstanceType: m5.xlarge
    IamInstanceProfile: aws-elasticbeanstalk-ec2-role
  aws:elasticbeanstalk:healthreporting:system:
    SystemType: enhanced
    EnhancedHealthAuthEnabled: true
```
3. Upload your application source bundle or select a sample application.
```bash
microservices-eb/ 
├── .ebextensions/  # configuration files for customizing the AWS environment and resources managed by EB.
│   ├── 01-platform.config  # platform-specific options (e.g., software version, instance type).
│   ├── 02-ecs-cluster.config  # setting up the ECS Cluster where the microservices will run.
│   ├── 03-networking.config  # VPC, subnets, and other network settings.
│   ├── 04-security-groups.config  # defining and applying security group rules.
│   ├── 05-service-discovery.config  # integrate with AWS Cloud Map/Service Discovery.
│   ├── 06-logging.config  # EB configuration for log forwarding, retention, or custom log settings.
│   └── 07-monitoring.config  # EB configuration for setting up custom CloudWatch metrics or alarms.
├── .dockerignore  # excluded when building Docker images.
├── Dockerrun.aws.json  # ECS Task Definition format specific to EB, multiple containers/volumes/ports.
├── docker-compose.yml  # Local testing with Docker Compose.
├── services/  # Source code and build files for individual microservice.
│   ├── user-service/ 
│   │   ├── Dockerfile
│   │   ├── pom.xml  # Maven configuration file (used in Java projects)
│   │   └── src/  # Directory containing the main source code files for the user-service.
│   ├── order-service/ 
│   │   ├── Dockerfile 
│   │   ├── pom.xml 
│   │   └── src/
│   ├── gateway-service/  #  API Gateway/Edge Service that routes external requests to internal microservices.
│   │   ├── Dockerfile 
│   │   ├── pom.xml 
│   │   └── src/ 
│   └── discovery-service/  # dedicated service registry/discovery component (e.g., Eureka).
│       ├── Dockerfile
│       ├── pom.xml 
│       └── src/  
├── infrastructure/  # CloudFormation/similar for supporting resources **outside** of the main EB environment.
│   ├── redis.yml  # Template to provision a dedicated Redis cluster (e.g., ElastiCache) for caching.
│   ├── database.yml  # Template to provision a dedicated relational database (e.g., RDS) instance.
│   └── service-mesh.yml  # service mesh (e.g., AWS App Mesh) for traffic routing/security/ observability.
└── buildspec.yml  # Configuration file used by AWS CodeBuild to define commands for CICD (build docker imgs)
```
4. Configure environment settings (instance type, capacity, networking).
```json
{
  "AWSEBDockerrunVersion": 2,
  "containerDefinitions": [
    {
      "name": "discovery-service",
      "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/discovery-service:latest",
      "memory": 512,
      "memoryReservation": 256,
      "cpu": 256,
      "essential": true,
      "portMappings": [
        {
          "hostPort": 8761,
          "containerPort": 8761,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "SPRING_PROFILES_ACTIVE",
          "value": "docker"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/aws/elasticbeanstalk/microservices/discovery",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "discovery"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8761/actuator/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    },
    {
      "name": "gateway-service",
      "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/gateway-service:latest",
      "memory": 768,
      "memoryReservation": 384,
      "cpu": 512,
      "essential": true,
      "portMappings": [
        {
          "hostPort": 80,
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "links": ["discovery-service"],
      "dependsOn": [
        {
          "containerName": "discovery-service",
          "condition": "HEALTHY"
        }
      ],
      "environment": [
        {
          "name": "SPRING_PROFILES_ACTIVE",
          "value": "docker"
        },
        {
          "name": "EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE",
          "value": "http://discovery-service:8761/eureka"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/aws/elasticbeanstalk/microservices/gateway",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "gateway"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 90
      }
    },
    {
      "name": "user-service",
      "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/user-service:latest",
      "memory": 1024,
      "memoryReservation": 512,
      "cpu": 512,
      "essential": true,
      "portMappings": [
        {
          "hostPort": 0,
          "containerPort": 8081,
          "protocol": "tcp"
        }
      ],
      "links": ["discovery-service", "redis"],
      "dependsOn": [
        {
          "containerName": "discovery-service",
          "condition": "HEALTHY"
        }
      ],
      "environment": [
        {
          "name": "SPRING_PROFILES_ACTIVE",
          "value": "docker"
        },
        {
          "name": "EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE",
          "value": "http://discovery-service:8761/eureka"
        },
        {
          "name": "SPRING_REDIS_HOST",
          "value": "redis"
        },
        {
          "name": "DATABASE_URL",
          "value": "{{resolve:ssm:/microservices/database/url}}"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:microservices/db-abc123:password::"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/aws/elasticbeanstalk/microservices/user",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "user"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8081/actuator/health || exit 1"],
        "interval": 30,
        "timeout": 10,
        "retries": 3,
        "startPeriod": 120
      }
    },
    {
      "name": "order-service",
      "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/order-service:latest",
      "memory": 1024,
      "memoryReservation": 512,
      "cpu": 512,
      "essential": true,
      "portMappings": [
        {
          "hostPort": 0,
          "containerPort": 8082,
          "protocol": "tcp"
        }
      ],
      "links": ["discovery-service", "redis"],
      "dependsOn": [
        {
          "containerName": "discovery-service",
          "condition": "HEALTHY"
        }
      ],
      "environment": [
        {
          "name": "SPRING_PROFILES_ACTIVE",
          "value": "docker"
        },
        {
          "name": "EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE",
          "value": "http://discovery-service:8761/eureka"
        },
        {
          "name": "SPRING_REDIS_HOST",
          "value": "redis"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/aws/elasticbeanstalk/microservices/order",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "order"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8082/actuator/health || exit 1"],
        "interval": 30,
        "timeout": 10,
        "retries": 3,
        "startPeriod": 120
      }
    },
    {
      "name": "redis",
      "image": "redis:7-alpine",
      "memory": 256,
      "memoryReservation": 128,
      "cpu": 128,
      "essential": false,
      "portMappings": [
        {
          "hostPort": 6379,
          "containerPort": 6379,
          "protocol": "tcp"
        }
      ],
      "command": ["redis-server", "--appendonly", "yes"],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/aws/elasticbeanstalk/microservices/redis",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "redis"
        }
      }
    }
  ],
  "volumes": [
    {
      "name": "redis-data",
      "host": {
        "sourcePath": "/var/redis-data"
      }
    }
  ]
}
```
5. Launch the environment and wait for resources to provision.
```bash
# options.json can hold vars, load balancer settings, scaling configs.
aws elasticbeanstalk create-environment \
  --application-name microservices-app \
  --environment-name microservices-env \
  --solution-stack-name "64bit Amazon Linux 2 v3.5.6 running Multi-container Docker" \
  --version-label v1 \
  --option-settings file://options.json
```
6. Access your deployed application using the provided EB URL.
- EB provides a defualt URL you can map using Route%3 or anopther DNS, with a CNAME pointing to the EB url.
`http://<env-name>.<random>.<region>.elasticbeanstalk.com`
- Example DNS Record:
```makefile
Type: CNAME
Name: api.example.com
Value: microservices-env.eba-xyz123.us-east-1.elasticbeanstalk.com
TTL: 60
```
7. Monitor environment health and logs via the console.
```yaml
# .ebextensions/07-logging.config
Resources:
  # CloudWatch Log Groups
  DiscoveryServiceLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: /aws/elasticbeanstalk/microservices/discovery
      RetentionInDays: 30
```
- Then stream the logs via the Dockerrun.aws.json:
```json
{
  "AWSEBDockerrunVersion": 2,
  "containerDefinitions": [
    {
      "name": "discovery",
      "image": "myrepo/discovery-service:latest",
      "memory": 256,
      "essential": true,
      "portMappings": [
        { "containerPort": 8761 }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/aws/elasticbeanstalk/microservices/discovery",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```
8. Deploy new versions by uploading new application versions or AWS CLI commands.
- EB will handle blue/green deployments or rolling updates depending on the environment configuration:
```bash
# Upload a new Dockerrun.aws.json zip to S3
aws s3 cp Dockerrun.aws.json s3://my-eb-bucket/microservices-v2.zip

# Create a new EB application version
aws elasticbeanstalk create-application-version \
  --application-name microservices-app \
  --version-label v2 \
  --source-bundle S3Bucket=my-eb-bucket,S3Key=microservices-v2.zip

# Deploy the new version
aws elasticbeanstalk update-environment \
  --environment-name microservices-env \
  --version-label v2
```


## Use Cases

- Web applications and APIs
- Microservices hosted on managed platforms
- Background worker tasks and batch processing (worker environments)
- Rapid prototyping and development
- Applications requiring managed operation with support for customization



