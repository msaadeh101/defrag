# Prometheus and Grafana

## Overview

Prometheus and Grafana are commonly used together for cloud-native monitoring observability and metrics.

- Prometheus is used for monitoring and metrics storage, as well as alerting (AlertManager). Prometheus scrapes metrics from configured endpoints in an application (e.g. `/metrics`) and stores them in its **Time-series database**, which allows querying via **PromQL**

- Grafana is used for visualization and dashboards. Grafana connects to Prometheus as a data source and provides a UI to display graphs, tables, heatmaps, etc. Grafana can also be used for alerting

- How they work together: Deployed in Kubernetes, Prometheus can scrape pod metrics and Grafana can display these in a dashboard.

### How it Works

- Prometheus uses a *pull based* system that sends HTTP requests called a **scrape**. 
- Each scrape is created according to the config defined in the deployment file.
- Grafana or other API consumers can visualize the collected data.
- Each prometheus server is standalone, not depending on network storage or other remote services.
- **Not a good choice for 100% accuracy conditions.**

### Metrics Components

- **Core Prometheus App** - Responsible for scraping and storing metrics in an internal time series database, or sending to remote storage.
- **Exporters** - Add-ons that ingest data from various sources and produce *scrapable* metrics for the Prometheus app. Exporters ensure that the HTTP requests can be accepted from prometheus and that the format is supported.
- **AlertManager** - manages alerts.
- **Client Libraries** - can be used to instrument your application.

Prometheus monitoring works by identifying a target, a physical endpoint that supplies metrics for Prometheus.

- `__meta_kubernetes_*`: `__` is used for internal labels.

### Metrics Provided

- `Counter`: This cumulative metric is suitable for tracking the number of requests, errors or completed tasks. It cannot decrease, and must either go up or be reset to zero. Use Cases: request count, tasks completed, error count.
    - Used for recording a value that ONLY increases
    - Used for assessing the rate of increase
- `Gauge`: This point-in-time metric can go both up and down. Suitable for measuring current memory use and concurrent requests. Use cases: queue size, memory usage, number of requests in progress.
    - Used for recording a value that can go up or down
    - Cases where we DONT need to query the rate 
- `Histogram`: Groups observed values into predefined buckets, helpful for analyzing precentiles, trends, performance bottlenecks. This metric is suitable for aggregated measures, including request durations, response sizes, and Apdex scores that measure application performance. Histograms sample observations and categorize data into buckets that you can customize.
    - Used for multiple measurements of a single value, allowing for averages/percentages calculation. Use cases are request duration and response size.
    - Calues that can be approximate
    - A predetermined range of values for a histogram bucket.
- `Summary`: Metric is suitable for accurate **quantiles**. Samples observations and provides a total count as well as sum of observed values and calculates quartiles.
    - Multiple measurements of a single value.
    - Used for a range that CANNOT be determined upfront.
    - Request duration and Response size.

### Data Model

- Every *time series* is uniquely identified by its `metric name` and optional key-value pair `label`
- Metric Names specify the general feature of a system that is measured (i.e. `http_requests_total`)
- Metric Labels enable identification among any given combination of labels for the same metric name.
- Given a metric name and set of labels, time series are written as such
`<metric name>{<label name>=<label value>, ...}`


## PromQL

### Basic Concepts

Prometheus stores time-series data, meaning each metric has:
- **Metric Name** - e.g, `node_cpu_seconds_total`
- **Labels** - Key/Value pairs for filtering, e.g `{instace="node1", job="node-exporter"}`
- **Timestamps and Values** - Numeric data points over time.

### Basic Queries

```promql
# get all Values of a Metric with different labels
node_cpu_seconds_total

# Filter Using labels
node_cpu_seconds_total{instance="node1"}

# filter for a specific instance
node_cpu_seconds_total{mode="idle"}
```

### Aggregation Functions

```promql
# Sum over All Instances
sum(node_cpu_seconds_total)

# node_cpu_seconds_total is a counter metric
sum by (cpu) (node_cpu_seconds_total{mode!="idle"})
# if we want to count usage, exclude the idle time

# Average CPU usage
avg(node_cpu_seconds_total)

# Max Memory usage
max(node_memory_Active_bytes)

# Total percentage of memory used
node_memory_Active_bytes/node_memory_MemTotal_bytes*100

# Check free disk space
node_filesystem_avail_bytes/node_filesystem_size_bytes*100

# Group by label (CPU usage per instance)
sum by (instance) (node_cpu_seconds_total)

# Differentiate instances by labels
avg(metrics_per_second) by (project, location)
```

### Rate & Increase

```promql
# Rate of Change per second, useful for cpu usage
rate(node_cpu_seconds_total[5m])

# Use rate to calculate growth rate of a counter
(sum by (cpu)(rate(node_cpu_seconds_total{mode!="idle"}[5m]))*100)
# above query gives rate of increase over last 5 minutes

# Increase over a time range
increase(node_network_receive_bytes_total[1h])
```

### Mathematical Operations

```promql
# Caluclate the memory usage as a percentage
(node_memory_Active_bytes / node_memory_MemTotal_bytes) * 100
```

### Alerts

```promql
# Triggers an alert if node_load1 exceeds 1
node_load1 > 1
```

### Histograms
```promql
# a histogram metric like http_request_duratation_seconds_bucket can give percentiles
histogram_quantile(0.95, rate(http_request_duratation_seconds_bucket[5m]))
# Finds response time that 95% of requests are faster than

# How many requests finished in under 200 ms
http_request_duration_seconds_bucket{le="0.2"}

## Breakdown
histogram_quantile(0.95, sum by(le) (rate([$__rate_interval]))) # grafana variable
#histogram_quantile(quantile, rate_of_histogram)
# rate is the result of applying the rate() to the histogram bucket data

# calculate the 95%ile of pod start durations
# a percentile of 95% is >= 95% of the scores
histogram_quantile(0.95, sum by(le) (rate(kubelet_pod_start_duration_seconds_bucket[5m])))


```

## Prometheus on Kubernetes

- Some Default Kubernetes Metrics

|Metric Name | Description|
|-----|--------|
| `kube_pod_container_resource_requests_cpu_cores` | CPU requested by a container  |
| `kube_pod_container_resource_limits_memory_bytes` | Memory limit set for a pod  |
| `node_memory_MemAvailable_bytes` | Available memory on a node  |
| `container_cpu_usage_seconds_total` | CPU usage per container  |
| `kube_deployment_status_replicas_available` | Available replicas for a deployment  |

- Some Default Kuberrnetes labels

|Label Name | Description|
|-----|--------|
| `namespace` | Namespace name  |
| `pod` | Pod Name  |
| `container` | Container Name  |
| `node` | Node running the pod  |
| `instance` | IP address of node or pod  |
| `job` | Prometheus scrape job |

- Example PromQL using metric name and label for Kubernetes:
`container_cpu_usage_seconds_total{namespace="default", pod="my-app"}`

- Prometheus/Thanos/Grafana

|Component| Description|
|-----|--------|
| `Prometheus` | Scrapes metrics, stores them locally (short-term)  |
| `Thanos Sidecar` |  Exposes Prometheus metrics to Thanos & uploads to object storage (S3) |
| `Thanos Store` | Reads metrics from object storage for querying  |
| `Thanos Querier` | Queries across multiple Prometheus instances  |
| `Thanos Compactor` | Reduces storage size by compressing older data  |
| `Grafana` | Visualizes metrics via dashboards |