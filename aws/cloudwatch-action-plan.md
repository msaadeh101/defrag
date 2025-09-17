# CloudWatch Monitoring Action Plan for ECS + EKS Java Microservices

## Goal
Implement CloudWatch **metrics, alarms, and dashboards** for financial services Java microservices on ECS + EKS, starting in **Dev** for validation, and rolling out to **Prod** with zero downtime.

---

## Phased Action Plan

### Phase 1: Preparation (Dev & Prod)

- **Objectives**: Define, Implement and Validagte the Foundational monitoring layer for ECS and EKS workloads in the dev environment. This phase ensures metrics coverage, alarm strategy, and dashboards are aligned to business before scaling.
    - Establish baseline monitoring coverage for all EKS/ECS services.
    - Define key metrics (app, container, cluster, infrastructure).
    - Implement CloudWatch alarms for core SLIs (latency, error rate, CPU/memory, pod restarts)
    - Create team specific dashboards (developers, SRE, architects).
    - Validate alarms against test scenarios (scale-up, failure injection, latency simulation)

- **Inventory services**: Identify all ECS tasks, EKS namespaces, and critical microservices.
- **Define KPIs**:
  - Business: trade/transaction latency (p95, p99), error rates, failed trades.
  - Infra: CPU, memory, task restarts, node health.
  - JVM: heap usage, GC pauses, thread pool queues.
- **Decide retention & compliance**: Align CloudWatch Logs retention with regulatory requirements (e.g., 7 years for audits).

- **Scope**:
    - **Services covered**:
        - ECS Fargate/EC2 task definitions
        - EKS workloads (Deployments, StatefulSets, Services)
    - **Metrics sources**:
        - AWS CloudWatch native metrics
        - Container Insights (ECS/EKS)
        - Application logs/metrics (via CloudWatch Agent, Fluent Bit, or Prometheus exporters)

- **Action Steps**
1. Define Metrics & Alarms
- ECS:
    - `CPUUtilization`, `MemoryUtilization` per service/task.
    - `TaskCount` (desired vs. running).
- EKS:
    - `pod_cpu_utilization`, `pod_memory_utilization` (per namespace).
    - `pod_number_of_container_restarts`.
    - Service-level latency (via ALB/NLB or Prometheus).
- Application:
    - Error rate (from logs or tracing).
    - P95 latency.
- **Deliverable**: YAML/JSON catalog of metrics, thresholds, and escalation actions.

2. Configure Logging & Metrics Pipelines
- Deploy **CloudWatch Agent / Fluent Bit** as DaemonSets (EKS) and sidecars (ECS).
- Standardize log formatting (JSON with trace IDs).
- Send logs to **CloudWatch Logs** and metrics to **CloudWatch Metrics/EMF**.
- **Deliverable**: Helm charts or Terraform modules for agent deployments.

3. Create CloudWatch Alarms
- Use terraform modules for repeatable alarm creation (i.e. ECS High CPU)

```t
resource "aws_cloudwatch_metric_alarm" "ecs_high_cpu" {
  alarm_name          = "ecs-${var.service_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm when ECS service CPU > 80%"
  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
}
```
- **Deliverable**: Alarm definitions stored in Git repo with code reviews.

4. Build Dashboards
- Define CloudWatch Dashboards per environment.
- Key widgets:
    - ECS service health (CPU/memory/task count).
    - EKS namespace health (pod restarts, CPU/memory).
    - Application latency/error rates.
    - Top-level overview for executives (red/green status).
- **Deliverable**: Terraform-managed dashboards versioned in Git.

5. Test & Validate
- Simulate scenarios:
    - Kill ECS tasks.
    - Crash EKS pods.
    - Inject CPU load test.
- Confirm:
    - Alarms trigger correctly.
    - Notifications flow to Slack/SNS/PagerDuty.
    - Dashboards reflect live data.
- **Deliverable**: Test report with screenshots, metrics validation, and gaps.

#### Exit Criteria (Phase 1)
- [ ] Alarms for ECS/EKS core metrics created and validated.
- [ ] Dashboards available for Dev teams and architects.
- [ ] Runbooks documented for responding to test alarms.
- [ ] Approval from architecture team on thresholds and escalation paths.

---

### Phase 2: Dev Environment Rollout
1. **Enable Container Insights** for ECS & EKS (collect pod/task/node metrics).
- ECS: Turn on Container Insights at Cluster Level.
```bash
aws ecs update-cluster-settings \
    --cluster my-ecs-cluster \
    --settings name=containerInsights,value=enabled
```
- EKS: Deploy `amazon-cloudwatch-agent` and `fluent-bit` DaemonSets via the official AWS CloudWatch Agent Helm chart.
```bash
helm repo add amazon-cloudwatch https://aws.github.io/amazon-cloudwatch-agent
helm install cwagent amazon-cloudwatch/amazon-cloudwatch-agent \
  --namespace amazon-cloudwatch \
  --create-namespace
```
- Metrics collected:
    - Node metrics: CPU, memory, disk.
    - Pod/task metrics: restarts, OOM kills, throttling.
    - Service-level metrics: request counts, ALB target health.

2. **Deploy ADOT Collector (DaemonSet / sidecar)** to gather Prometheus + trace data.
- Deploy ADOT (AWS Distro for OpenTelemetry) as a Deamonset in EKS and sidecars in the ECS tasks where deeper app metrics are needed.

- Configmap for configuration:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: observability
data:
  otel-collector-config.yaml: |
    receivers:
      prometheus:
        config:
          scrape_configs:
            - job_name: 'java-services'
              kubernetes_sd_configs:
                - role: pod
      otlp:
        protocols:
          grpc: {}
          http: {}

    processors:
      batch: {}
      memory_limiter:
        check_interval: 1s
        limit_mib: 512
        spike_limit_mib: 128

    exporters:
      awsemf:
        region: us-east-1
        log_group_name: "/aws/otel/java-metrics"
        log_stream_name: "otel-stream"
      awsxray:
        region: us-east-1

    service:
      pipelines:
        metrics:
          receivers: [prometheus]
          processors: [memory_limiter, batch]
          exporters: [awsemf]
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [awsxray]
```
- Daemonset defintion for OpenTelemetry Collector:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: otel-collector
  namespace: observability
  labels:
    app: otel-collector
spec:
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      serviceAccountName: otel-collector
      containers:
        - name: otel-collector
          image: public.ecr.aws/aws-observability/aws-otel-collector:latest
          args: ["--config=/etc/otel/config/otel-collector-config.yaml"]
          volumeMounts:
            - name: otel-config-vol
              mountPath: /etc/otel/config
          resources:
            limits:
              memory: "1Gi"
              cpu: "500m"
            requests:
              memory: "512Mi"
              cpu: "200m"
      volumes:
        - name: otel-config-vol
          configMap:
            name: otel-collector-config
```

3. **Instrument Java apps** with Micrometer → expose `/actuator/prometheus`.

- Use micrometer with Spring Boot Actuator in `pom.xml`
```xml
<dependency>
  <groupId>io.micrometer</groupId>
  <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

- Enable `/actuator/prometheus` endpoint in `application.properties`.

```txt
management.endpoints.web.exposure.include=prometheus
management.metrics.export.prometheus.enabled=true
```

- Verify the endpoint:
```bash
curl http://<service-url>/actuator/prometheus
```
- **Metrics Collected**: JVM heap/non-heap usage, GC duration, thread pools, HTTP server latency, custom business counters (e.g., transaction volume).

4. **Forward logs** to CloudWatch via Fluent Bit / FireLens with structured JSON.
- ECS (FireLens): Configures a sidecar container running Fluent Bit as a log router using FireLens. The main app container uses awsfirelens for logs, instead of direct CloudWatch logging.
```json
"logConfiguration": {
  "logDriver": "awsfirelens",
  "options": {
    "Name": "cloudwatch",
    "region": "us-east-1",
    "log_group_name": "/ecs/myservice",
    "auto_create_group": "true"
  }
}
```
- EKS (Fluent Bit): Fluent Bit is deployed as a daemonset, and configured output plugin `[OUTPUT]`

```txt
[OUTPUT]
    Name cloudwatch_logs
    Match   *
    region  us-east-1
    log_group_name /eks/app-logs
    log_stream_prefix from-fluentbit-
```

5. **Create initial dashboards**:
   - Service-level (latency, error rate, JVM heap, GC).
   - Cluster-level (node health (CPU/Memory), OOM kills, ALB target health).

- Example terraform snippet for dashboards:
```terraform
resource "aws_cloudwatch_dashboard" "service_dashboard" {
  dashboard_name = "ecs-eks-dev-dashboard"
  dashboard_body = <<EOF
  {
    "widgets": [
      {
        "type": "metric",
        "properties": {
          "metrics": [
            [ "ECS/ContainerInsights", "CpuUtilized", "ClusterName", "my-ecs-cluster" ]
          ],
          "title": "ECS Cluster CPU Utilization"
        }
      }
    ]
  }
  EOF
}
```

6. **Define test alarms**:
   - Static thresholds (CPU > 80% for 5 mins), (JVM Heap > 85%)
   - Business metrics (error rate > 2% over 5 minute window).
   - Anomaly detection on latency spikes via CloudWatch Anomaly detection.

- Example terraform alarm for High CPU:
```terraform
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "ecs-eks-dev-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CpuUtilization"
  namespace           = "ECS/ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = [aws_sns_topic.dev_alerts.arn]
}
```

7. **Validate** in Dev:
- Deliberate Stress Testing:
    - Run load tests (e.g., `Gatling`/`JMeter`) to spike CPU/memory.
    - Inject `5xx` errors to verify error-rate alarms.
- Cross-Correlation:
    - Ensure dashboards show the same anomalies detected in logs.
- Alert Routing:
    - Test `SNS` → `PagerDuty`/`Slack` integration with sample alerts.
- Acceptance Criteria:
    - All alarms trigger as expected.
    - Dashboards show correlated metrics/logs/traces.
    - No false positives during normal traffic.

---

### Phase 3: Staging / Pre-Prod Rollout

The purpose of Phase 3 is to validate the monitoring stack at **realistic traffic scale**, refine alarms, and confirm dashboards provide actionable visibility before rolling out to production.


1. Replicate Dev Setup in Staging
- **Re-use Terraform / Helm IaC** modules from Dev.
- Deploy **ADOT Collector**, **Fluent Bit/FireLens**, and **Container Insights** into the staging environment.
- Use the same namespaces/log groups/dashboards with `-staging` suffix for isolation.
- Validate IAM roles are scoped to staging clusters only.

```bash
aws ecs update-cluster-settings \
  --cluster my-ecs-staging \
  --settings name=containerInsights,value=enabled
```

2. Traffic Scale Validation
- Mirror or replay production-like workloads into staging:
    - Use AWS VPC Traffic Mirroring (if applicable).
    - Or replay transactions via `JMeter` / `Locust` with production payload samples.
    - Ensure service KPIs (latency, error rates, JVM heap, GC) scale linearly.
    - Collect baseline metrics for anomaly detection training.

3. Alarm Tuning
- Adjust static thresholds based on observed staging traffic.
    - Example: if normal JVM heap is ~70% under load, set alarm at 85% instead of 80%.
- Implement composite alarms to reduce noise:
    - Only trigger “Service Degraded” if both `Latency > 500ms` AND `Error Rate > 2%`.
    - Example composite alarm in Terraform:
```terraform
resource "aws_cloudwatch_composite_alarm" "service_degraded" {
  alarm_name = "orders-service-degraded-staging"
  alarm_rule = "ALARM(${aws_cloudwatch_metric_alarm.latency.alarm_name}) AND ALARM(${aws_cloudwatch_metric_alarm.error_rate.alarm_name})"
  alarm_actions = [aws_sns_topic.staging_alerts.arn]
}
```

4. Dashboard Validation
- Ensure staging dashboards provide:
    - Cluster View: node CPU/memory, pod restarts, ALB health.
    - Service View: JVM GC, heap, latency histograms, error codes.
    - Validate cross-account dashboards if monitoring multiple clusters (Dev + Staging).
    - Confirm dashboards load under expected concurrency (UI latency `< 2s`).

5. Chaos & Failure Scenarios
- Run controlled chaos experiments in staging:
    - Kill ECS tasks/EKS pods → confirm restart metrics + alarms.
    - Simulate network latency → validate `p95`/`p99` latency alarms.
    - Force OOM in Java container → validate heap alarms + pod eviction alerts.
    - Ensure CloudWatch Logs Insights queries correlate failures:

```sql
fields @timestamp, @message, kubernetes.pod_name, kubernetes.namespace_name, status
| filter kubernetes.labels.app = "orders-service"
| filter status >= 500
| stats count(*) as error_count by bin(5m), kubernetes.pod_name, kubernetes.namespace_name
| sort error_count desc
```

6. Alert Routing & Escalation Validation
- Route alarms to staging SNS topics integrated with Slack/PagerDuty test channels.
- Validate escalation policies (acknowledge, auto-escalate if unacknowledged).
- Confirm deduplication: **repeated alarms should not spam downstream systems**.

7. Compliance & Security Review
- Verify staging log groups are encrypted with KMS:

```bash
aws logs associate-kms-key \
  --log-group-name /ecs/staging/orders-service \
  --kms-key-id <kms-key-arn>
```

- Validate IAM least privilege:
    - ADOT collectors → only `cloudwatch:PutMetricData`, `xray:PutTraceSegments`.
    - Fluent Bit → only `logs:PutLogEvents`.
- Confirm retention policy is configured per compliance requirement (e.g., *30d in staging*).

8. Sign-Off Criteria
- [ ] Alarms tuned with `< 5%` false positive rate.
- [ ] Dashboards provide complete service + cluster visibility.
- [ ] Chaos experiments show alarms trigger and recover correctly.
- [ ] Logs, metrics, and traces correlate for root cause analysis.
- [ ] Security and compliance checks pass.

### Phase 4: Prod Rollout (Zero Downtime)
1. **Blue/Green Monitoring Deployment**:
- Deploy new monitoring components **in parallel** with existing monitoring agents to avoid disruption.
  - **ECS**:
    - Update task definitions to include **FireLens/Fluent Bit sidecars** with distinct log groups (`/ecs/prod/service-new`).
    - Run old log group `/ecs/prod/service` in parallel until cutover.
  - **EKS**:
    - Deploy ADOT collector as a **separate DaemonSet** (`adot-collector-new`) in a dedicated namespace (`observability-v2`).
    - Tag metrics with `environment=prod-new` to distinguish from existing `environment=prod`.
- Namespace/service-tag filters in ADOT:

```yaml
 processors:
    resource:
      attributes:
        - key: environment
          value: prod-new
          action: insert
```

2. **Gradual Enablement**:
- Cluster-by-cluster rollout:
    - Enable Container Insights on one ECS cluster or EKS node group at a time.
    - Validate metrics appear in dashboards before proceeding to the next cluster.
- Service-by-service rollout:
    - Add Micrometer Prometheus endpoint behind a **feature flag**:
```properties
monitoring.prometheus.enabled=${ENABLE_PROMETHEUS:false}
```
    - Toggle flag via environment variable during deployment:
```yaml
env:
  - name: ENABLE_PROMETHEUS
    value: "true"
```
- Dashboards & alarms:
    - Clone staging dashboards into `-prod` versions.
    - Gradually shift alarm actions from staging SNS → prod SNS.
    - Example Terraform for prod SNS subscription:

```hcl
resource "aws_sns_topic_subscription" "prod_pagerduty" {
  topic_arn = aws_sns_topic.prod_alerts.arn
  protocol  = "https"
  endpoint  = "https://events.pagerduty.com/integration/XXXX/enqueue"
}
```

3. **Cutover**:
- Alert routing:
    - Switch alarm actions from test/staging SNS → production SNS/PagerDuty.
    - Confirm via a controlled test alarm:
    
```bash   
aws cloudwatch set-alarm-state \
  --alarm-name ecs-prod-high-cpu \
  --state-value ALARM \
  --state-reason "Testing prod cutover"
```

- Disable old monitoring:
    - Only after new alarms fire and dashboards update reliably.
    - Remove old CloudWatch Agent/sidecars:
        - ECS: deregister old task definitions.
        - EKS: scale down `cloudwatch-agent-old` DaemonSet.

4. **Post-Deployment Checks**:
- Dashboard Validation:
    - Verify live prod traffic appears in both cluster-level and service-level dashboards.
    - Confirm JVM metrics, ALB latency, and error rates are visible **within 1–2 minutes of deployment**.
- Alarm Validation:
    - Run controlled chaos tests (e.g., CPU stress pod) and confirm alarms are delivered to on-call systems.
- Audit & Compliance:
    - Verify **log groups encrypted with KMS**:
```bash    
aws logs describe-log-groups --log-group-name-prefix "/ecs/prod" \
  --query "logGroups[*].kmsKeyId"
```
- Confirm IAM roles scoped to:
    - ADOT → `cloudwatch:PutMetricData`, `xray:PutTraceSegments`.
    - Fluent Bit → `logs:PutLogEvents`.
- Validate retention policies (`365d+` per financial compliance).

5. **Success Criteria**
- No downtime during rollout (monitored via ALB 5xx/latency).
- All prod metrics visible in dashboards within 1 minute of collection.
- Alarms routed to production PagerDuty/Slack without duplication.
- Old monitoring fully decommissioned only after confirmation of parity.
- IAM/KMS/retention compliant with financial regulations.

---

## Best Practices
- **Infrastructure as Code (IaC)**: Manage dashboards, alarms, and log groups with Terraform or CloudFormation.
- **Noise Reduction**: Use composite alarms + anomaly detection to avoid false positives.
- **Security**: Encrypt logs with KMS, apply IAM least privilege, restrict dashboard access.
- **Cost Control**: Retention policies for logs, use high-res metrics only where required.
- **Runbooks**: Link dashboards/alarms to recovery steps for fast MTTR.

---

## Next Steps
- [ ] Enable Container Insights in Dev.
- [ ] Deploy ADOT collector + Micrometer instrumentation in Dev services.
- [ ] Define 3 critical alarms + 1 dashboard in Dev.
- [ ] Validate alarms with test traffic.
- [ ] Plan Prod cutover using Blue/Green monitoring rollout.
