# Lambda

## Introduction

**AWS Lambda** is an event-driven, serverless compute service that runs code in response to triggers, without provisioning or managing servers. It auto scales from a few requests per day to thousands per second. You ONLY pay for compute time consumed.

### Characteristics

|Characteristic	|Description|
|-----|--------|
|**Event-Driven Execution**	|Designed to run in response to events from over 200 AWS services and SaaS applications. Events can be a file upload to S3, an SQS message, a change in a DynamoDB table, or an incoming API Gateway request, etc.|
|**Stateless Ephemeral Execution**	|Functions have a **15 minute max execution time**. Local persistence is limited to the `/tmp` directory, and data is only guaranteed to persist between subsequent invocations. Any necessary data (like user sessions or database connections) must be retrieved from external services (S3, DynamoDB, RDS, etc.).|
|**Automatic Scaling and HA**	|Lambda automatically scales in response to traffic, from zero to thousands of concurrent executions almost instantly. It offers fault tolerance and high availability (HA) across multiple Availability Zones (AZs).|
|**Isolation and Security**|	Each invocation runs in a dedicated, lightweight **Firecracker microVM**, providing a strong security boundary, low overhead, and fast cold start times. Your code is isolated from other customer invocations.|
|**Managed Runtime**|	AWS handles all operational and administrative tasks for the underlying infrastructure, including OS patching, managing language runtimes, capacity provisioning, and logging.|
|**Concurrency and Provisioning**	|Lambda offers three scaling models: `Reserved` (guarantees minimum availability and caps maximum scale to protect downstream resources), `Provisioned` (keeps a specified number of environments warm, eliminating cold start latency), and `Burst/Unreserved` (allows for rapid, automatic scaling, limited by account/function-wide limits).|
|**Pay-Per-Use Billing**	|Billing is based solely on the number of requests and the compute duration (rounded up to the nearest millisecond) your code consumes. **There is no charge for idle resources**.|

### Lambda Fundamental Considerations

|Concept| Example|
|------|------|
|**Execution Environment**|Customizable resources: **512 MB to 10 GB of RAM** and **512 MB to 10 GB of ephemeral storage** (`/tmp`) includes OS, language runtime, and libraries.  |
|**Concurrency**| Default limit is 1,000 per AWS region (adjustable). Managed using Reserved Concurrency (capping max) or Provisioned (keep instances warm)|
|**Invocation Types**|**Synchronous**: Caller waits for response (API Gateway, ELB). **Asynchronous**: Caller places event in queue and does NOT wait (S3, SNS). **Event Source Mapping (ESM)**: Lambda polls source (SQS, Kinesis) and invokes function.|
|**Handler**|Typically formatted as (`event`, `context`, `callback`). The `event` parameter contains the payload (SQS message body), `context` object provides runtime information (function ARN, remaining time)|

### Deployment Formats

#### ZIP/JAR 

- Upload a zip file containing your code + dependencies, or a JAR if using Java.
- Lambda automatically provides the runtime (Python, Node, Java, Go, .NET, Ruby)
- **Use for Standard app logic**

**Pros**:
- Simple Deployment
- Smaller package sizes
- Faster cold starts (on average)
- Automatic runtime management
- Easily integrate with SAM (Serverless Application Model) or Serverless Framework

**Cons**:
- Harder to bundle native binaries
- Runtime versions must match AWS supported versions
- Dependency limits: 250MB unzipped, 50MB zipped.


#### Docker Container Image

- Build docker image (must follow Lambda base image requirements)
- Push to ECR and Lambda runs image directly
- **Use for Heavy dependencies, ML, libraries, or custom tooling**

**Pro**s:
- Full OS-level control
- Bundle ANY binary, tools, libraries, drivers
- Package size can be up to 10GB
- No dependency on AWS runtime

**Cons**:
- Slower cold starts
- You must maintain OS, runtime, dependencies
- More complex workflow


### Language Considerations (Java0)

- Cold start latency (mitigated with Java21+ and SnapStart) compared to interpreted languages.
- High Memory Footprint compared to interpreted languages.
- JVM initialization overhead.
- Larger deployment packagers

## Topics

### Lambda Execution Model

```txt
Request -> API Gateway/Event Source -> Lambda Service -> Execution Env -> VPC -> Response
```

### Execution Environment Reuse

Lambda maintains execution environments for 5-7 minutes after invocation.

Reusable (Outside Handler)
- Database connections
- HTTP clients
- SDK clients
- Cached data

Per-invocation (inside handler)
- Request/Response objects
- Temporary computations
- Handler-scoped variables

#### Proper Resource Initialization

```java
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;

public class OptimizedHandler implements RequestHandler<Request, Response> {
    
    // INITIALIZATION PHASE - runs once per container
    private static final DynamoDbClient dynamoDb = DynamoDbClient.builder()
        .httpClient(UrlConnectionHttpClient.builder().build())
        .build();
    
    // Static initialization for expensive operations
    static {
        // Pre-load configuration, warm up connection pools
        System.setProperty("java.net.preferIPv4Stack", "true");
    }
    
    // Constructor runs once per container
    public OptimizedHandler() {
        // Additional initialization if needed
    }
    
    // INVOCATION PHASE - runs per request
    @Override
    public Response handleRequest(Request request, Context context) {
        // Use pre-initialized clients
        // This executes quickly on warm starts
        return processRequest(request);
    }
}
```

### Runtime Considerations

Java21 / Amazon Corretto 21 is the Recommended and current supported version.
- Virtual Threads (Project Loom) for better concurrency
- Tiered compilation improvements
- Enhanced garbage collection
- Smaller footprint with CDS improvements.

## Patterns

## Performance Optimization

### Cold Start Mitigation Strategy

For Java Lambdas, cold starts range from **3 - 8 seconds** depending on:
- Package size (deployment artifact)
- Class loading (number of classes)
- Dependency injection frameworks (Spring adds 2-4 seconds)
- Static initialization
- Memory allocation


| Strategy	| Use Case	| Cost Impact	| Implementation Complexity| 
| ----------|--------- |---------------- |--------------------- | 
| **SnapStart**	| Java/Python synchronous APIs	| Low| 	Medium| 
| **Provisioned Concurrency**	| Predictable workloads, APIs	| High	| Low| 
| **Warm-up Ping**	| Legacy applications	| Medium| 	High| 
| **Reserved Concurrency**	| Critical path isolation	| Variable	| Low| 

#### Minimize Package Size

- Leverage the **Maven Shade Plugin** to create a single Uber JAR containing all dependencies, but apply minimization to reduce the final size.
- Shade Plugin performs *static code analysis* to determine the actually referenced classes, methods, fields, dependencies.
- Added benefit of reducing S3 storage costs and within Lambda's internal storage, fewer resource errors.

```xml
<!--  Use Maven Shade Plugin with minimization -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-shade-plugin</artifactId>
    <version>3.5.1</version>
    <configuration>
        <createDependencyReducedPom>false</createDependencyReducedPom>
        <minimizeJar>true</minimizeJar>
        <filters>
            <filter>
                <artifact>*:*</artifact>
                <!-- Prevent these signing and verification files from merging, -->
                <!-- only necessary for original signed artifact, not new UBER JAR -->
                <excludes>
                    <exclude>META-INF/*.SF</exclude>
                    <exclude>META-INF/*.DSA</exclude>
                    <exclude>META-INF/*.RSA</exclude>
                </excludes>
            </filter>
        </filters>
    </configuration>
</plugin>
```

#### Snapstart

**Snapstart** creates snapshots of initialized execution environments:
- When a new version is published, Lambda **initializes once**.
- It takes a **Firecracker microVM snapshot** of initialized memory and disk state, and **encrypts** it. 
- When a cold request arrives, lambda **restores the snapshot instead of running the full initialization sequence**.
- NOTE: Adds $0.43 per function/month

- `ApplyOn: PublishedVersions` is for production safety, ensuring SnapStart is NEVER applied to `$LATEST` function versions.
- `AutoPublishAlias: live` ensures that a new numbered version is created when you run `sam deploy`

```yaml
# SAM (Serverless Application Model) Template
Resources:
  MyFunction:
    Type: AWS::Serverless::Function # Defines an AWS Lambda function
    Properties:
      Runtime: java21
      SnapStart:
        ApplyOn: PublishedVersions # SnapStart is only applied when a new function version is published
      AutoPublishAlias: live 
      # Automatically publishes a new version and points an alias ("live") after every sam deployment.
```

#### Provisioned Concurrency

**Provisioned Concurrency** configuration maintains warm execution environments.
- Cost is `$0.015/hour per provisioned execution`.
- Use for latency critical functions where < 500ms p99 required.
- Use for predictable traffic patterns and a cost-effective solution for high-volume functions
- Frontend/API Use cases.

```bash
# AWS CLI
aws lambda put-provisioned-concurrency-config \
  --function-name my-java-function \
  --qualifier v1 \
  --provisioned-concurrent-executions 10

# Cost: ~$0.015/hour per provisioned execution
```

## Memory and Performance Tuning

Lambda allocates CPU proportionally to memory:

| **Memory**| **vCPUs**| **Network**| **Use Case**| 
|---------- | ----------| ---------| -------------| 
| 128MB| 0.08| Low| Light processing| 
| 512MB| 0.31| Low| API handlers| 
| 1024MB| 0.63| Medium| Standard apps| 
| **1769MB**| **1.0**| **Medium**| **Sweet spot**| 
| 3008MB| 1.79| High| CPU-intensive| 
| 10240MB| 6.0| 10Gbps| Data processing| 

### Class Data Sharing (CDS)

For Java17+, enable CDS archives.

```dockerfile
# Custom runtime with CDS
FROM public.ecr.aws/lambda/java:17

# Create CDS archive during build
RUN java -Xshare:dump -XX:SharedArchiveFile=/opt/app-cds.jsa \
    -cp /opt/app.jar com.example.MainClass

ENV JAVA_TOOL_OPTIONS="-Xshare:on -XX:SharedArchiveFile=/opt/app-cds.jsa"
# `-Xshare:dump`: Instructs the JVM to create a shared archive file.
# `-XX:SharedArchiveFile=/opt/app-cds.jsa`: Specifies the output path and name of the archive file.
# `-cp /opt/app.jar com.example.MainClass`: This command simulates the application startup 
#    by running the main class. The JVM loads the necessary classes, and the `-Xshare:dump` 
#    then writes the metadata of these loaded classes into the archive file (`app-cds.jsa`).
```

- **During Build**: `RUN java -Xshare:dump...` loads necessary classes into `.jsa` file.
- **During Runtime (Cold Start)**: `ENV JAVA_TOOL_OPTIONS` tells JVM to load classes directly from `.jsa`.

### Power Tuning Invocation

**AWS Lambda Power Tuning**: state machine, powered by Step Functions in your AWS account to generate cost and speed analysis and visualizations of average cost and speed for each power configured.
- The `num` indicates the number of times to invoke your function for each power value (e.g. 50 times at 512MB)
- `payload` is the JSON payload to be passed as the event input to your target function.
- The **Step Functions** state machine output (a simple status JSON) will be saved to `output.json`, initiating the power tuning process in the background.

```bash
# The target function is the orchestrator Step Functions trigger (Lambda wrapper for State Machine).
# lambdaARN is the ARN of the actual function to test and optimize
aws lambda invoke \
    --function-name lambda-power-tuning \
    --payload '{
        "lambdaARN": "arn:aws:lambda:region:account:function:my-java-function",
        "powerValues": [512, 1024, 1769, 3008, 5120],
        "num": 50,
        "payload": {"test": "data"}
    }' \
    output.json
```

### JVM Tuning for Lambda

- **Note**: `JDK_JAVA_OPTIONS`, applied only when launching `java` command, takes precedence over `JAVA_TOOL_OPTIONS`. `JAVA_TOOL_OPTIONS`is recognized by both JVM and javac, IDEs, its for general purpose. Both are set via `ENV` directives.

- `-XX:+UseSerialGC`: best for short lived functions.
- `-Xms/-Xmx`: Set heap size to prevent resizing overhead.
- `-XX:MaxMetaspaceSize`: Limit metaspace to prevent OOM errors.

```bash
# Environment variables for JVM configuration
JAVA_TOOL_OPTIONS: >-
  -XX:+TieredCompilation
  -XX:TieredStopAtLevel=1
  -XX:+UseSerialGC
  -Xms512m
  -Xmx1024m
  -XX:MaxMetaspaceSize=256m
  -Djava.net.preferIPv4Stack=true
  -Dcom.amazonaws.sdk.disableCertChecking=false
```

### Garbage Collection

```bash
# For most Lambda functions
-XX:+UseSerialGC # Single-threaded, lowest overhead

# For high-throughput, longer-running functions (>30s)
-XX:+UseParallelGC -XX:ParallelGCThreads=2

# For very large heaps (8GB+)
-XX:+UseG1GC -XX:MaxGCPauseMillis=100
```

### Timeout Configuration

```yaml
# SAM Template - set appropriate timeouts
Resources:
  ApiFunction: # Logical name for Lambda Function
    Type: AWS::Serverless::Function
    Properties: # Configuration properties
      Timeout: 29  # API Gateway has a hard limit of 29 seconds for synchronous invocations
      
  AsyncFunction:
    Type: AWS::Serverless::Function
    Properties:
      Timeout: 300  # 5 minutes for async processing, where longer execution times are allowed
      
  StreamFunction:
    Type: AWS::Serverless::Function
    Properties:
      Timeout: 900  # 15 minutes max time for any Lambda, for long-running streaming processing
```

## Security Best Practices

### IAM Policy (Permission Boundary)

- IAM Policy for a **Service Control Policy (SCP)** to enforce strict Lambda function creation rules. 

**Policy Summary**:
- Deny the listed actions (create/delete/IAM access) in all regions *except* us-east-1 and eu-west-1.
- Deny all EC2/Networking actions to anyone *unless* they are tagged as a member of the "NetworkTeam".

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LambdaBoundary", // unique identifier for this statement
      "Effect": "Deny", // Denies these actions, overriding any ALLOW
      "Action": [
        "lambda:CreateFunction*", // Deny creation of new lambda functions/versions
        "lambda:DeleteFunction*", // Denies all delete of lambda functions
        "iam:*",                  // Denies all IAM modifications
        "organizations:*",        // No organizational actions
        "sts:AssumeRole"          // Denies ability to assume other IAM roles
      ],
      "Resource": "*",            // Apply denial to ALL resources
      "Condition": {              // Denial applied ONLY if following conditions are MET
        "StringNotEquals": {
          "aws:RequestedRegion": ["us-east-1", "eu-west-1"] // Does NOT deny (ALLOWS) if in these regions
        }
      }
    },
    {
      "Sid": "NetworkBoundary", // unique identifier for this statment
      "Effect": "Deny",
      "Action": "ec2:*",        // Denies ALL actions related to EC2, which includes VPC, Subnets, Security Groups, etc.
      "Resource": "*",          // Apply denial to ALL resources
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalTag/NetworkTeam": "true" // Denial is applied UNLESS tagged with NetworkTeam
        }
      }
    }
  ]
}
```

## Deployment and Testing Strategies

### Packaging Strategies

#### Fat JAR

Use Maven Shade Plugin in your `pom.xml` to package the Java app into a single, executable JAR.
- Sets the main Class `com.example.Handler` as the entry point for the JAR, which can then be deployed.
- Simple and Self-contained, yet large size can lead to slower uploads and version conflicts.

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-shade-plugin</artifactId>
    <version>3.5.1</version>
    <!-- Configures when and how the plugin runs -->
    <executions>
        <execution>
            <!-- Runs the plugin during the 'package' phase of the Maven lifecycle -->
            <phase>package</phase>
            <!-- Specifies the goal (action) of the plugin -->
            <goals><goal>shade</goal></goals>
            <!-- Plugin-specific configuration -->
            <configuration>
                <!-- Prevents creation of a reduced POM file -->
                <createDependencyReducedPom>false</createDependencyReducedPom>
                <!-- Transformers define how resources are handled -->
                <transformers>
                    <transformer implementation="org.apache.maven.plugins.shade.resource.ManifestResourceTransformer">
                        <!-- Sets the main class for the JAR, which is the entry point for your application -->
                        <mainClass>com.example.Handler</mainClass>
                    </transformer>
                </transformers>
            </configuration>
        </execution>
    </executions>
</plugin>

```

#### Layer-Based Deployment

- **NOTE**: `my-function` must exist already, and configured with a Java runtime, and you need `lambda:PublishLayerVersion` and `lambda:UpdateFunctionsCode` IAM permissions.
- Benefits of faster deployments (only code changes), shared dependencies across functions, reduced packaged sizing and layer caching.

```bash
# Create layer with dependencies
aws lambda publish-layer-version \
  --layer-name java-dependencies \
  --zip-file fileb://dependencies.zip \
  --compatible-runtimes java21

aws lambda update-function-configuration \
  --function-name my-function \
  --layers arn:aws:lambda:region:account:layer:java-dependencies:1


# Deploy function code separately
aws lambda update-function-code \
  --function-name my-function \
  --zip-file fileb://function.zip
```

- Structure:

```txt
layer/
└── java/
    └── lib/
        ├── aws-sdk.jar
        ├── jackson.jar
        └── commons.jar

function/
└── com/
    └── example/
        └── Handler.class
```

#### Container Image

- Use for Large Dependencies (>250MB), custom runtime requirements or Docker-based CICD.

```dockerfile
FROM public.ecr.aws/lambda/java:21

# Copy dependencies
COPY target/lib/* ${LAMBDA_TASK_ROOT}/lib/

# Copy application
COPY target/classes ${LAMBDA_TASK_ROOT}

# Set handler
CMD ["com.example.Handler::handleRequest"]
```

```bash
# Build and push
docker build -t my-java-lambda .
docker tag my-java-lambda:latest 123456789.dkr.ecr.region.amazonaws.com/my-java-lambda:latest
aws ecr get-login-password | docker login --username AWS --password-stdin 123456789.dkr.ecr.region.amazonaws.com
docker push 123456789.dkr.ecr.region.amazonaws.com/my-java-lambda:latest

# Create function
aws lambda create-function \
  --function-name my-function \
  --package-type Image \
  --code ImageUri=123456789.dkr.ecr.region.amazonaws.com/my-java-lambda:latest \
  --role arn:aws:iam::123456789:role/lambda-role
```

### Blue/Green Deployments

**Traffic Shifting Options**:
- `Canary10Percent5Minutes`: 10% → 5min → 100%
- `Canary10Percent10Minutes`: 10% → 10min → 100%
- `Linear10PercentEvery1Minute`: 10% every minute
- `Linear10PercentEvery2Minutes`: 10% every 2 minutes
- `AllAtOnce`: Immediate

```yaml
# SAM Template with traffic shifting
# Uses Canary for risk mitigation and Alarms for automated rollbacks
Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      AutoPublishAlias: live
      DeploymentPreference:
        Type: Canary10Percent5Minutes
        Alarms:
          - !Ref FunctionErrorAlarm
        Hooks: # References separate lambda functions for pre and post deployment validation
          PreTraffic: !Ref PreTrafficHook
          PostTraffic: !Ref PostTrafficHook
```

### IaC

```h
# main.tf
resource "aws_lambda_function" "java_function" {
  function_name = "my-java-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "com.example.Handler::handleRequest"
  runtime       = "java21"
  timeout       = 30
  memory_size   = 1769

  filename         = "target/function.jar"
  source_code_hash = filebase64sha256("target/function.jar")

  environment {
    variables = {
      JAVA_TOOL_OPTIONS = "-XX:+TieredCompilation -XX:TieredStopAtLevel=1"
      TABLE_NAME        = aws_dynamodb_table.data.name
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  tracing_config {
    mode = "Active"
  }

  reserved_concurrent_executions = 100

  snap_start {
    apply_on = "PublishedVersions"
  }

  layers = [
    aws_lambda_layer_version.dependencies.arn
  ]
}

resource "aws_lambda_layer_version" "dependencies" {
  layer_name          = "java-dependencies"
  filename            = "target/dependencies.zip"
  source_code_hash    = filebase64sha256("target/dependencies.zip")
  compatible_runtimes = ["java21"]
}

resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.java_function.function_name
  function_version = aws_lambda_function.java_function.version
}

resource "aws_cloudwatch_log_group" "function_logs" {
  name              = "/aws/lambda/${aws_lambda_function.java_function.function_name}"
  retention_in_days = 14
}
```


## Monitoring and Observability

### CloudWatch

#### CloudWatch Dashboard

```yaml
# CloudWatch Dashboard (JSON)
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/Lambda", "Invocations", {"stat": "Sum"}],
          [".", "Errors", {"stat": "Sum"}],
          [".", "Throttles", {"stat": "Sum"}],
          [".", "Duration", {"stat": "Average"}],
          [".", "Duration", {"stat": "p99"}],
          [".", "ConcurrentExecutions", {"stat": "Maximum"}],
          [".", "PostRuntimeExtensionsDuration"]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "Lambda Performance"
      }
    }
  ]
}
```

#### CloudWatch Alarms

```yaml
# SAM Template
Resources:
  ErrorAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${FunctionName}-errors'
      ComparisonOperator: GreaterThanThreshold
      EvaluationPeriods: 2
      MetricName: Errors
      Namespace: AWS/Lambda
      Period: 60
      Statistic: Sum
      Threshold: 5
      Dimensions:
        - Name: FunctionName
          Value: !Ref MyFunction
      AlarmActions:
        - !Ref AlertTopic

  ThrottleAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${FunctionName}-throttles'
      ComparisonOperator: GreaterThanThreshold
      EvaluationPeriods: 1
      MetricName: Throttles
      Namespace: AWS/Lambda
      Period: 60
      Statistic: Sum
      Threshold: 0
      Dimensions:
        - Name: FunctionName
          Value: !Ref MyFunction

  DurationAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${FunctionName}-high-duration'
      ComparisonOperator: GreaterThanThreshold
      EvaluationPeriods: 3
      Metrics:
        - Id: m1
          ReturnData: true
          MetricStat:
            Metric:
              Namespace: AWS/Lambda
              MetricName: Duration
              Dimensions:
                - Name: FunctionName
                  Value: !Ref MyFunction
            Period: 300
            Stat: p99
      Threshold: 25000  # 25 seconds
```

#### CloudWatch Logs Insights Queries

```sql
-- Find slow requests (p99 duration)
fields @timestamp, @duration, @requestId
| filter @type = "REPORT"
| stats pct(@duration, 99) as p99Duration by bin(5m)

-- Error analysis
fields @timestamp, @message
| filter @type = "ERROR"
| stats count() by @message
| sort count desc

-- Cold start detection
fields @timestamp, @duration, @initDuration
| filter @type = "REPORT" and @initDuration > 0
| stats avg(@initDuration) as avgColdStart, 
        count(*) as coldStarts

-- Memory utilization
fields @timestamp, @maxMemoryUsed, @memorySize
| filter @type = "REPORT"
| stats max(@maxMemoryUsed/@memorySize) * 100 as memoryUtilization
```

### VPC ENI Management

- Python script for monitoring **ENI saturation**:

```python
import boto3
from datetime import datetime, timedelta

class LambdaENIMonitor:
    def __init__(self):
        self.cloudwatch = boto3.client('cloudwatch')
        self.lambda_client = boto3.client('lambda')
        
    def check_eni_limits(self, vpc_id, subnet_ids):
        """Monitor ENI creation limits for Lambda"""
        metrics = self.cloudwatch.get_metric_data(
            MetricDataQueries=[
                {
                    'Id': 'eni_creation',
                    'MetricStat': {
                        'Metric': {
                            'Namespace': 'AWS/Lambda',
                            'MetricName': 'ConcurrentExecutions',
                            'Dimensions': [
                                {'Name': 'VPCId', 'Value': vpc_id},
                                {'Name': 'SubnetId', 'Value': subnet_ids[0]}
                            ]
                        },
                        'Period': 300,
                        'Stat': 'Maximum'
                    }
                }
            ],
            StartTime=datetime.utcnow() - timedelta(hours=1),
            EndTime=datetime.utcnow()
        )
        
        # ENI creation takes 60-100ms, can become bottleneck
        # at scale (>1000 concurrent executions)
        return self.calculate_bottleneck_risk(metrics)
    
    def recommend_scaling(self, current_concurrent, subnet_count):
        """
        Calculate optimal subnet distribution
        
        Rule: Each subnet can support ~250-300 concurrent
        executions before ENI creation becomes bottleneck
        """
        max_per_subnet = 250
        required_subnets = ceil(current_concurrent * 1.2 / max_per_subnet)
        return required_subnets
```