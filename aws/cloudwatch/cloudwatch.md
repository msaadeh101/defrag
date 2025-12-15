# CloudWatch

## Overview and Concepts

**CloudWatch** is a monitoring and observability service that provides data and actionable insights for AWS resources, apps, and services. It collects monitoring and observational data in the form of logs, metrics, and events.

### Key Features

- Real-time monitoring of AWS resources:
- Custom metrics from apps:
- Log aggregation and analysis:
- Automated alarms and notifications:
- Distributed tracing with X-Ray integration:
- Container insights for EKS/ECS:
- Lambda insights for serverless:

### Architecture Components

- **Metrics**: Numerical data points tracked over time.
- **Logs**: Text-based app and system logs.
- **Events**: System events and scheduled tasks.
- **Alarms**: Automated notifications based on thresholds.
- **Dashboards**: Visual UI for metrics.
- **Insights**: Query and analysis tools.

### Core Concepts

#### Namespaces

**Namespaces** are containers for CloudWatch metrics. 
- AWS services use namespaces like `AWS/EC2`, `AWS/Lambda`, etc.
- Custom namespaces are formatted like `MyOrg/Microservices` (`<NamespaceName/MetricName>`).
- Agent Namespaces are formated like `CWAgent`, and are used for system-level metrics collected by **CloudWatch Agent** (memory and disk usage for example.)

- Metric names can exist in multiple namespaces, but within a namespace, metric names must be uniquely defined by its name (plus dimensions).

#### Dimensions

**Dimensions** are name-value pairs that uniquely identify a metric, allowing you to filter and aggregate metrics.

**Common Dimensions (Example)**:
- `InstanceId`: (EC2)
- `FunctionName`: (Lambda)
- `ClusterName`: (ECS/EKS)
- `ServiceName`: (Custom App)
- `Environment`: (Prod, Staging, Dev)

- **Uniqueness**: CPUUtilization with InstanceId: i-123 is separate from CPUUtilization with InstanceId: i-456.
- **Cardinality**: Assign up to 30 dimensions to a single custom metric. High-cardinality dimensions (many unique values i.e. `RequestID`) should be used only when necessary, as they greatly increase cost.

#### Resolution and Retention

**Metric Resolutiion**:
- **Standard Resolution**: 1-minute granularity (free tier eligible). Default for all AWS Service Metrics, used for capacity planning, trend analysis and general monitoring.
- **High Resolution**: 1-second granularity for additional cost. **Custom metrics only**. Used for troubleshooting, immediate incident detection, checking sub-minute latency/alarms.

**Retention Periods**:
| Data Type	| Retention Period| 	Granularity / Rollup	| Cost Considerations |
|-----------|------------------|-------------------------|---------|
|**Metrics (CloudWatch Metrics)**|	**15 months rolling retention** for metric data.	|**Tiered resolution**: 1-minute data for 15 days, 5-minute for 63 days, 1-hour for ~455 days (15 months). Data aggregated over time. |**Retention is included**; however standard/detailed/custom metric charges still apply.|
|**Logs (CloudWatch Logs)**	|**Configurable** — per log group, from 1 day up to “Never expire”. |**Logs are stored at full resolution (exact events)**, not aggregated. |**Indefinite retention can accumulate significant storage costs** if not managed. Best practice is set defined retention ( 30/90/365 days) and export older logs to S3 for cheaper long-term storage. |
|**Events (CloudWatch Events / EventBridge)**	|Default: unarchived events are short-lived in the bus (EventBridge doesn’t persist events long-term by default). Create archives and choose retention (days up to indefinite). |EventBridge does not automatically retain every event for 90 days by default; **Archived events can be kept for up to whatever retention you choose**. Replays, once created, are deleted after 90 days. | **EventBridge archive storage incurs costs**; raw event traffic also incurs **`PutEvents` costs**. Only Archiving allows long term storage.|


## CloudWatch Logs

Logs is the centralized, scalable service for storing, monitoring and analyzing log files from your AWS resources and applications.

### Log Groups and Log Streams

**Log Group**: Container for log streams that share retention, monitoring, and access control settings. It is the administrative boundary for shared settings.
- **Retention**: 14 days, 365 days, never expire, etc.
- **IAM**: Permissions to read/write logs set at Log Group level.
- **Monitoring/Processing**: **Metric Filters** and **Subscription Filters** are configured at the log group level.

**Log Stream**: Sequence of log events from the same source.
- **Lambda**: Typically, each running container (warm instance) of a Lambda function creates its own log stream.
- **EC2**: An application log on a specific instance maps to one log stream.
- **Naming**: Log Streams are names are generated automatically (Lambda stream contains invocation date/time and ID of warm container)

```bash
aws logs create-log-group --log-group-name /aws/app/production

aws logs put-retention-policy \
  --log-group-name /aws/app/production \
  --retention-in-days 14

aws logs tag-log-group \
  --log-group-name /aws/app/production \
  --tags Environment=Production,Team=Platform
```

### Log Event

A **Log Event** is the atomic unit of data in Logs. It contains the application data and essential metadata.

```json
{
  "timestamp": 1638360000000,   // Time event occurred (in ms since epoch). This is the time from the source.
  "message": "User authentication successful", // The raw log data (your application's output).
  "ingestionTime": 1638360001234 // Time CloudWatch Logs received the event.
}
```

- Structured JSON Format allows easy parsing of fields like `timestamp`, `level`, `duration`. You can then write complex queries and aggregations like `avg(duration)` or `p90(duration)` using **CloudWatch Logs Insights Query Langugage (Logs Insights QL)**.

```json
{
  "timestamp": "2024-12-12T10:30:00Z", // Human-readable timestamp
  "level": "INFO",                     // Log level (INFO, WARN, ERROR) - crucial for filtering
  "service": "user-service",           // Application or service name
  "traceId": "abc123xyz",              // Correlation ID for tracing across services (e.g., X-Ray trace ID)
  "userId": "user-456",                // Business-level identifier
  "action": "login",
  "duration": 245,                     // Time in ms, for extracting performance metrics
  "message": "User login successful"   // Human-readable message
}
```

### Metric Filters

**Metric Filters**: extract metric data from log events. Passive, real-time mechanisms to search for terms/patterns in log events and convert the occurrences to CloudWatch Metrics.
- Extracts metric data points from the streams in the Log Group.

- Creates a CloudWatch Logs metric filter that counts 4xx errors and emits them as CloudWatch metrics:

```bash
# Pattern matches log events that are ERROR level and have a status_code starting with '4'
aws logs put-metric-filter \
  --log-group-name /aws/app/production \
  --filter-name 4xxErrors \
  --filter-pattern '[timestamp, request_id, level = ERROR, status_code = 4*, ...]' \
  --metric-transformations \
    metricName=4xxCount,metricNamespace=CustomApp,metricValue=1
```

- Create API Latency metric filters:

```bash
# Pattern extracts the 'duration' field from the structured log message.
aws logs put-metric-filter \
  --log-group-name /aws/lambda/api-gateway \
  --filter-name APILatency \
  --filter-pattern '[..., duration]' \
  --metric-transformations \
    metricName=APILatency,metricNamespace=CustomApp,metricValue=$duration,unit=Milliseconds
```

### Subscription Filters

**Subscription Filters** enable real-time delivery of log events to other services for continuous processing, analysis, or long-term archival.
- **Lambda**: Custom processing like creating alerts, transforming log structure, or intergration with 3rd party.
- **Kinesis Data Streams**: Near real-time ingestion, fan-out to multiple consumers, or custom Kinsesis Data Analytics processing.
- **Kinsesis Data Firehose**: Automated, low-latency delivery to persistence (S3, etc) or OpenSearch Service.


```bash
# Stream to Lambda for processing
aws logs put-subscription-filter \
  --log-group-name /aws/app/production \
  --filter-name ErrorProcessor \
  --filter-pattern "ERROR" \ # Simple text filter: Only streams log events that contain the literal text "ERROR".
  --destination-arn arn:aws:lambda:us-east-1:123456789:function:ProcessErrors
```

## CloudWatch Metrics

**Metrics** are the built-in metrics AWS services emit without any code or sidecars. You consume them for SLOs, autoscaling, first-line alerting.

### Standard AWS Metrics

#### EC2 Instance Metrics

- `CPUUtilization`
- `NetworkIn`/`NetworkOut`
- `DiskReadBytes`/`DiskWriteBytes`
- `StatusCheckFailed`

#### Lambda Metrics

- `Invocations`
- `Duration`
- `Errors`
- `Throttles`
- `ConcurrentExecutions`

#### Container Metrics

EKS and Container Metrics are usually surfaced with **CloudWatch Container Insights** or agent (**CloudWatch Agent** / Fluent Bit / Managed Prometheus)

- `node_cpu_utilization`
- `node_memory_utilization`
- `pod_cpu_utilization`
- `pod_memory_utilization`


### Custom Metrics

The CloudWatch Metrics API gives you full control and language agnostic custom metrics.

```java
import software.amazon.awssdk.services.cloudwatch.CloudWatchClient;
import software.amazon.awssdk.services.cloudwatch.model.*;

public class MetricsPublisher {
    private final CloudWatchClient cloudWatch;
    
    public MetricsPublisher() {
        this.cloudWatch = CloudWatchClient.builder().build();
    }
    
    public void publishCustomMetric(String metricName, double value, String unit) {
        Dimension dimension = Dimension.builder()
            .name("Environment")
            .value("Production")
            .build();
        
        MetricDatum datum = MetricDatum.builder()
            .metricName(metricName)
            .unit(StandardUnit.fromValue(unit))
            .value(value)
            .dimensions(dimension)
            .timestamp(Instant.now())
            .build();
        
        PutMetricDataRequest request = PutMetricDataRequest.builder()
            .namespace("MyCompany/Application")
            .metricData(datum)
            .build();
        
        cloudWatch.putMetricData(request);
    }
    
    // Batch publishing for efficiency
    public void publishMetricsBatch(List<MetricDatum> metrics) {
        // CloudWatch accepts up to 20 metrics per request
        List<List<MetricDatum>> batches = partition(metrics, 20);
        
        for (List<MetricDatum> batch : batches) {
            PutMetricDataRequest request = PutMetricDataRequest.builder()
                .namespace("MyCompany/Application")
                .metricData(batch)
                .build();
            
            cloudWatch.putMetricData(request);
        }
    }
    
    // Helper method for business metrics
    public void trackOrderProcessed(String orderId, double amount, long durationMs) {
        List<MetricDatum> metrics = Arrays.asList(
            MetricDatum.builder()
                .metricName("OrdersProcessed")
                .unit(StandardUnit.COUNT)
                .value(1.0)
                .timestamp(Instant.now())
                .build(),
            MetricDatum.builder()
                .metricName("OrderAmount")
                .unit(StandardUnit.NONE)
                .value(amount)
                .timestamp(Instant.now())
                .build(),
            MetricDatum.builder()
                .metricName("OrderProcessingTime")
                .unit(StandardUnit.MILLISECONDS)
                .value((double) durationMs)
                .timestamp(Instant.now())
                .build()
        );
        
        publishMetricsBatch(metrics);
    }
}
```

#### CloudWatch Agent

- Stored as a ConfigMap in the cluster for the agent Daemonset to read from `/etc/cwagentconfig/cwagentconfig.json`

```json
{
  "metrics": {
    "namespace": "MyCompany/Application",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {"name": "cpu_usage_idle", "rename": "CPU_IDLE", "unit": "Percent"},
          {"name": "cpu_usage_iowait", "rename": "CPU_IOWAIT", "unit": "Percent"}
        ],
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          {"name": "used_percent", "rename": "DISK_USED", "unit": "Percent"}
        ],
        "resources": ["*"]
      },
      "mem": {
        "measurement": [
          {"name": "mem_used_percent", "rename": "MEM_USED", "unit": "Percent"}
        ]
      }
    }
  }
}
```

### Embedded Metric Format (EMF)

**EMF** allows you to embed custom metrics in structured log events. It is optimized for microservices and serverless.
- The `EMFLogger` builds a structured JSON object. When the JSON is written as `stdout` (Lambda containers) and shipped into CloudWatch Logs.
- Use EMF for per-request metrics: Latency, error flags, business events.
- Alternatively use **SDK**/ `PutMetricData` for coarse-grained, aggregated or scheduled metrics (once per minute job counts).
- Keep metric naming conventions and dimensions schemas identical between EMF and SDK.

```java
public class EMFLogger {
    
    public void logMetricWithEMF(String metricName, double value) {
        Map<String, Object> emfLog = new HashMap<>();
        
        // Metric metadata
        Map<String, Object> cloudWatchMetrics = new HashMap<>();
        cloudWatchMetrics.put("Namespace", "MyApp/Business");
        cloudWatchMetrics.put("Dimensions", Arrays.asList(
            Arrays.asList("Service", "Environment")
        ));
        
        Map<String, String> metricDefinition = new HashMap<>();
        metricDefinition.put("Name", metricName);
        metricDefinition.put("Unit", "Count");
        
        cloudWatchMetrics.put("Metrics", Arrays.asList(metricDefinition));
        
        emfLog.put("_aws", Map.of(
            "Timestamp", System.currentTimeMillis(),
            "CloudWatchMetrics", Arrays.asList(cloudWatchMetrics)
        ));
        
        // Dimensions
        emfLog.put("Service", "OrderService");
        emfLog.put("Environment", "Production");
        
        // Metric value
        emfLog.put(metricName, value);
        
        // Additional log data
        emfLog.put("message", "Order processed successfully");
        
        // Output as JSON to stdout (captured by Lambda/EKS)
        System.out.println(new ObjectMapper().writeValueAsString(emfLog));
    }
}
```

- EMF Output:

```json
{
  "_aws": {
    "Timestamp": 1638360000000,
    "CloudWatchMetrics": [{
      "Namespace": "MyApp/Business",
      "Dimensions": [["Service", "Environment"]],
      "Metrics": [{"Name": "OrdersProcessed", "Unit": "Count"}]
    }]
  },
  "Service": "OrderService",
  "Environment": "Production",
  "OrdersProcessed": 1,
  "message": "Order processed successfully"
}
```

## CloudWatch Alarms

**CloudWatch Alarms** allow you to watch a single metric OR result of a metric expression over a specified period. They perform one or more actions based on the metric value and predefined threshold.

### Alarm States

| State| Description| Transition Trigger| 
|---|---|------|
| `OK`| The metric is within the defined threshold and **not breaching**.| The metric value has returned to a non-breaching state for the required number of evaluation periods.| 
| `ALARM`| The metric has **breached the threshold** for the number of periods specified by `EvaluationPeriods` (and `DatapointsToAlarm`).| The threshold condition is met (e.g., `CPU > 80%`) for M out of N data points.| 
| `INSUFFICIENT_DATA`| The **alarm cannot determine its state** because the metric is not available, or not enough data has been published.| Typically occurs right after creation or when the **underlying resource stops publishing data**.| 

### Creating Alarms

- `--metric-name CPUUtilization`: The metric to be evaluated for alarm.
- `--period 300`: Data is aggregated into 5-minute intervals.
- `--evaluation-periods 2`: Alarm will evaluate the last 2 periods (10 minutes total). Must fail 2 consecutive times.
- `--treat-missing-data notBreaching`: Used when occasional missing data not being published expected. Default is `missing`, others are `breaching` and `ignore`. `breaching` is recommended for critical services.

```bash
# CPU utilization alarm
aws cloudwatch put-metric-alarm \
  --alarm-name high-cpu-utilization \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=i-1234567890abcdef \
  --alarm-actions arn:aws:sns:us-east-1:123456789:alerts

# Lambda error rate alarm
aws cloudwatch put-metric-alarm \
  --alarm-name lambda-high-errors \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 3 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=my-function \
  --alarm-actions arn:aws:sns:us-east-1:123456789:alerts \
  --treat-missing-data notBreaching
```

### Composite Alarms

**Composite Alarms** allow you to create an alarm based on the logical combination of the states of multiple individual metric alarms.
- Composite alarms reduce notification noise and can trigger more genuinely indicating critical failure.
- In this example, the composite alarm only enters `ALARM` state if *both* underlying alarms are currently in `ALARM`.

```bash
aws cloudwatch put-composite-alarm \
  --alarm-name critical-system-health \
  --alarm-rule "ALARM(high-cpu-utilization) AND ALARM(high-memory-utilization)" \
  --actions-enabled \
  ...
```

### Alarm Actions

*Actions* are the responses triggered by a sustained alarm state change.

- **SNS Notification**:
- **Auto Scaling actions**:
- **EC2 actions** (`stop`, `terminate`, `reboot`, `recover`):
- **Systems Manager Actions** (`OpsItems`/`Incidents`):

## CloudWatch Dashboards

**Dashboards** are customizable, interactive home pages in the CloudWatch console that allows you to monitor your resources in a single unified view. They are primarily defined using a JSON body which acts as the layout/configuration.

### Dashboard Structure (Widgets)

**Widgets** define a specific visualization or piece of content.

The `properites` object within a `metric` widget is where most of the configuration lies.

| Property	| Example Value| 	Description	|
| ----------|------------- | ----------------| 
| `metrics`	| `[["AWS/Lambda", "Invocations", ...]]`| 	Array that defines the **specific metrics to display**.	Syntax: `[Namespace, MetricName, [DimensionName, DimensionValue, ...], {optional_options}]`. The use of `.` is a shorthand to **inherit the previous metric's Namespace**.| 
| `period`	| `300`	| The aggregation period in seconds. This determines the **time granularity of the metric data points displayed on the graph**. Smaller periods provide more detail, but cost more for High Resolution metrics.| 
| `stat`| 	`Average`| 	The **statistic to calculate over the period** (e.g., `Sum`, `Maximum`, `Minimum`, `SampleCount`).	For **latency metrics** (i.e. lambda duration), `Average` or `p99` are common. For **availability metrics** (i.e. invocations), `Sum` is used.| 
| `yAxis`| 	`{"left": {"min": 0}}`| Controls the appearance and scale of the Y-axes. Essential for **ensuring graphs start at zero for count-based metrics** (to prevent misleading visuals) or **setting maximums for percentage metrics**.| 
| `annotations`	| `[{"value": 500, "label": "Target Latency", "color": "#ff0000"}]`	| Horizontal or vertical lines overlaid on the graph.	Used to **represent static thresholds, service-level objectives (SLOs), or deployment markers**.| 

- `file://dashboard.json` is the configuration file for the dashboard.

```bash
# Create dashboard
aws cloudwatch put-dashboard \
  --dashboard-name MyApplicationDashboard \
  --dashboard-body file://dashboard.json
# List dashboards
aws cloudwatch list-dashboards
# Get dashboard (retrieves the JSON body for backup or editing)
aws cloudwatch get-dashboard --dashboard-name MyApplicationDashboard
```

**Widget Types**:
- **Line Graphs**: Trending data over time.
- **Stacked Area**: Cumulative values.
- **Number**: Single value display.
- **Log Widgets**: Recent log events.
- **Alarm Status**: Current alarm states.

```text
┌─────────────────────────────────────────────────┐
│ System Health Overview                          │
├─────────────────────────────────────────────────┤
│ [Active Alarms]  [Request Rate]  [Error Rate]   │
├─────────────────────────────────────────────────┤
│                                                 │
│  Lambda Performance     │   EKS Performance     │
│  ┌────────────────┐     │   ┌────────────────┐  │
│  │ Invocations    │     │   │ CPU Usage      │  │
│  │ Errors         │     │   │ Memory Usage   │  │
│  │ Duration       │     │   │ Pod Count      │  │
│  └────────────────┘     │   └────────────────┘  │
├─────────────────────────────────────────────────┤
│  Database Metrics       │   Cache Performance   │
│  ┌────────────────┐     │   ┌────────────────┐  │
│  │ Connections    │     │   │ Hit Rate       │  │
│  │ Query Time     │     │   │ Evictions      │  │
│  └────────────────┘     │   └────────────────┘  │
└─────────────────────────────────────────────────┘

```

## CloudWatch Insights

### Basic Query Syntax

```sql
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20
```

### Common Queries

```sql
-- Find errors with context:
fields @timestamp, @message, @logStream
| filter level = "ERROR"
| sort @timestamp desc
| limit 50
```

```sql
-- Calculate percentiles for latency:
fields @timestamp, duration
| filter ispresent(duration)
| stats avg(duration), 
        pct(duration, 50), 
        pct(duration, 95), 
        pct(duration, 99) by bin(5m)
```

```sql
-- Count errors by type:
fields @timestamp, errorType
| filter level = "ERROR"
| stats count() by errorType
| sort count desc
```

```sql
-- Track API endpoint usage:
fields @timestamp, endpoint, method
| filter method in ["GET", "POST", "PUT", "DELETE"]
| stats count() by endpoint, method
| sort count desc
```

```sql
-- Find Slow Queries:
fields @timestamp, query, duration
| filter duration > 1000
| sort duration desc
| limit 20
```

```sql
-- Parse JSON logs:
fields @timestamp, @message
| parse @message '{"user":"*","action":"*","duration":*}' as user, action, duration
| stats avg(duration) by action
```

```sql
-- Complex Aggregations:
fields @timestamp, statusCode, responseTime
| filter statusCode >= 400
| stats count() as ErrorCount, 
        avg(responseTime) as AvgResponseTime,
        max(responseTime) as MaxResponseTime 
  by statusCode, bin(5m) as Time
| sort Time desc
```

### Container Insights

- Enable Container Insights for EKS:

```bash
# Using Fargate
eksctl utils update-cluster-logging \
  --enable-types all \
  --region us-east-1 \
  --cluster my-cluster \
  --approve

# Deploy CloudWatch agent
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml
```

```sql
-- Pod CPU by namespace
STATS avg(pod_cpu_utilization) by Namespace, PodName

-- Memory usage
STATS avg(pod_memory_utilization) by Namespace 
| FILTER Namespace = "production"

-- Container restart count
STATS max(number_of_container_restarts) by PodName
| SORT number_of_container_restarts DESC

```

## Lambda Integration

- Enable Lambda Insights:

```bash
# Add layer to Lambda function
aws lambda update-function-configuration \
  --function-name my-function \
  --layers arn:aws:lambda:us-east-1:580247275435:layer:LambdaInsightsExtension:14
```

### Lambda Insights Queries

```sql
-- Cold start analysis
filter @type = "platform.initReport"
| stats count() as coldStarts, 
        avg(@initDuration) as avgInitDuration,
        max(@initDuration) as maxInitDuration

-- Memory usage patterns
filter @type = "platform.report"
| stats avg(@maxMemoryUsed / @memorySize * 100) as avgMemoryUtilization,
        max(@maxMemoryUsed) as maxMemoryUsed
  by bin(5m)

-- Error analysis
filter @type = "platform.report" and @message like /ERROR/
| stats count() as errors by @logStream
| sort errors desc
```

## Java Integration

### Enable X-Ray Tracing

```java
// Add X-Ray SDK dependencies
import com.amazonaws.xray.AWSXRay;
import com.amazonaws.xray.entities.Subsegment;

public class TracedService {
    
    public void processRequest(String requestId) {
        Subsegment subsegment = AWSXRay.beginSubsegment("ProcessRequest");
        try {
            subsegment.putAnnotation("RequestId", requestId);
            subsegment.putMetadata("Environment", "Production");
            
            // Your business logic
            performDatabaseQuery();
            callExternalAPI();
            
        } catch (Exception e) {
            subsegment.addException(e);
            throw e;
        } finally {
            AWSXRay.endSubsegment();
        }
    }
    
    private void performDatabaseQuery() {
        Subsegment dbSegment = AWSXRay.beginSubsegment("DatabaseQuery");
        try {
            dbSegment.putAnnotation("QueryType", "SELECT");
            // Database operations
        } finally {
            AWSXRay.endSubsegment();
        }
    }
}
```

### Maven Dependencies

```xml
<dependencies>
    <!-- CloudWatch SDK -->
    <dependency>
        <groupId>software.amazon.awssdk</groupId>
        <artifactId>cloudwatch</artifactId>
        <version>2.20.0</version>
    </dependency>
    
    <!-- CloudWatch Logs SDK -->
    <dependency>
        <groupId>software.amazon.awssdk</groupId>
        <artifactId>cloudwatchlogs</artifactId>
        <version>2.20.0</version>
    </dependency>
    
    <!-- X-Ray SDK -->
    <dependency>
        <groupId>com.amazonaws</groupId>
        <artifactId>aws-xray-recorder-sdk-core</artifactId>
        <version>2.13.0</version>
    </dependency>
</dependencies>
```
