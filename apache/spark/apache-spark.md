# Apache Spark

## Overview

- **Spark** is a distributed data-processing engine for large-scale data processing. Provides APIs for batch, streaming, in-memory computation, libraries for SQL, ML Graph processing and more. It is **cluster-native** *(drivers + execectors)* and supports multiple deployment modes (local, standalone, YARN, Mesos, K8s).


## Spark Architecture

- **High Level Architecture**:
    - `Driver`: Runs the main program, creates RDD/DataFrame, builds DAG (Directional Acyclycal Graph), schedules tasks. *Single process per application*.
    - `Executors`: worker JVM processes where tasks run, hold cached data.
    - `Cluster manager`: allocates resources - Yarn, K8, Mesos, Standalone.
    - `Master` (Standalone) or `ResourceManager` (YARN) or K8 API server allocates the resources.
    - `Task`: unit of work secheduled to executors.
    - `Shuffle`: data exchange between tasks (expensive-disk + network + spilling). Fundamental operation that redistributes data across partitions in a cluter. Shuffles occur during transformations that require data movement. Happens during Map (shuffle write), transfer, Reduce (shuffle read) phases.
    - `Job / Stage`: Job = collection action; stages are breakpoints around shuffle boundaries.

- **Note**: It is important from an Ops perspective to make sure Drivers and Executors have stable network, resource limits, logs, metrics and access to data stores (HDFS/S3/Object store/databases).

## Core Abstractions and Languages

- **Core Abstractions**:
    - `RDD`: Resilient Distributed Dataset, low-level, immutable collection of objects partitioned across nodes. Good for custom transformations and persistence control.
    - `DataFrame`: distributed table with a schema.
    - `Dataset`: typed DataFrame (Scala/Java) with compile-time type safety.
    - `Structured Streaming`: high-level API streaming that treats a stream as an unbounded table.
    - `MLLib`: Distributed ML Library.
    - `GraphX`: distributed processing.

- **Languages and APIs**:
    - `Scala`: native and best performance and features.
    - `Java`
    - `PySpark` (ptyhon): Convenient, but memory overhead and serialization concerns.
    - `R` (SparkR):

## Code Examples

### Submitting a Spark Job

- Essential Flags for `spark-submit`, the standard CLI:

- `--master` : `local[*]`, `yarn`, `k8s://...`, `spark://master:7077`
- `--deploy-mode`: `client` (driver runs where you launch), `cluster` (driver runs on cluster).
- `--class`: for JVM jobs.
- `--conf`: arbirtrary Spark configs e.g. `--conf spark.executor.memory=8g`
- `--num-executors` , `--executor-memory`, `--executor-cores` (YARN).
- `--driver-memory`, `--driver-cores`
- `--jars` and `--py-files` for dependencies.

```shell
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --num-executors 10 \
  --executor-memory 8G \
  --executor-cores 4 \
  --conf spark.dynamicAllocation.enabled=true \
  my_app.py
```

### PySpark

- **PySpark** - simple batch word count (local)

```python
# wordcount.py
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("wordcount").getOrCreate()

sc = spark.sparkContext
text_rdd = sc.textFile("s3a://my-bucket/some-data.txt")
words = text_rdd.flatMap(lambda line: line.split())
pairs = words.map(lambda w: (w.lower(), 1))
counts = pairs.reduceByKey(lambda a, b: a + b)
counts.saveAsTextFile("s3a://my-bucket/results/wordcount")
spark.stop()
```
- `SparkSession` is the unified entry point for both RDD (low-level) and DataFrame (high-level) APIs.
- `wordcount` is the `.appname()` of the Spark Job. It appears in the Spark UI and Application Logs
- `SparkContext` is the core interface for Spark (RDD API).
- Each element of the RDD is one line from the file. `s3://` is the modern Hadoop/Spark connector for S3.
- `.flatMap()` takes each element of the RDD (here, each line) and applies the function of `line.split()`
- `1` is the initial word count. and `pairs` is the RDD of tuples: `[("hello", 1), ("spark", 1), ...]`
- `reduceByKey`: Groups all the tuples by keyword and applies the reduction function `lambda a, b: a + b` to combine values for the same key.
- Save the results of counts to a text file, and stop the session with `spark.stop()`

- **Note**: the transformations are only saved when `.saveAsTextFile` is run, until then only a `DAG` is built.

```txt
TextFile (s3) -> flatMap (splitting words into lines) -> map (word to (word, 1)) -> 
-> reduceByKey (aggregate counts) -> saveAsTextFile (ouput results)
```

### Azure

- **Azure Synapse Analytics** (Spark included as component as well as data warehouse and integration features)

```python
from pyspark.sql import SparkSession
# In Synapse, `spark` is usually already available
spark = SparkSession.builder.getOrCreate()
sc = spark.sparkContext
# 1. Read text file from Azure Data Lake Storage Gen2
text_rdd = sc.textFile(
    "abfss://<container>@<storage-account>.dfs.core.windows.net/some-data.txt"
)
# 2. Split lines into words (map step)
words_rdd = text_rdd.flatMap(lambda line: line.split())
# 3. Convert words to lowercase and map each to (word, 1)
word_pairs_rdd = words_rdd.map(lambda word: (word.lower(), 1))
# 4. Reduce by key to get word counts
word_counts_rdd = word_pairs_rdd.reduceByKey(lambda a, b: a + b)
# 5. Save results back to Azure Data Lake
word_counts_rdd.saveAsTextFile(
    "abfss://<container>@<storage-account>.dfs.core.windows.net/results/wordcount"
)
```

- **Azure DataBricks** is a unified analytics platform built on Apache Spark.

- **Azure Data Lake Storage Gen2 (ADLS Gen2)** is a big data store built on Blob storage. Combines best features of Azure Data Lake Gen1 and Blob storage, specifically designed for large-scale data.
    - Hadoop Compatible (Hadoop Distributed File System `HDFS`) with the BLob File System ABFS driver, enabling seamless use with Spark and Hadoop.
    - `Hierarchical Namespace` (HNS) features, similar to traditional file systems, enabled to serve as a data lake in Azure.


```python
# In Azure Databricks, the `spark` object is automatically available.
# You can just start using it.
df = spark.read.format("delta").load("/mnt/delta/table")
df.show()
```

## Setup and Environment

- Spark is a JVM-based application, so it requires a JDK. And for PySpark, Python is required.
- Download Spark from the Apache website, it is often bundled for a specific version of Hadoop.
- Install Hadoop, HDFS distributed File System (recommended).
- Set up `JAVA_HOME`, `SPARK_HOME`, `HADOOP_HOME` env variables.
- Pass `--py-files` as `.zip` or `.egg` files to distribute python code and dependencies to all workers.
    - In production, use Conda environments and package an archive `.zip` or `.tar.gz` with `--archives`.

### Configuration

- Optimizing Spark requires configuration of its resources specified in the `conf/spark-defaults.conf` file or in `spark-submit` args.

- Memory: 
    - `spark.driver.memory`: is the amount of mem for the driver process, which runs the main function of your app. Important for actions like collect(), which brings data to the driver.
    - `spark.executor.memory`: amount of mem for each executor process. Where most of data processing occurs.
- CPU Cores:
    - `spark.executor.cores`: number of CPU cores to use for each executor. Common practice is 4-5 per executor to balance I/O and parallelism.
    - `spark.cores.max`: max cores across entire cluster.
- Other:
    - `spark.executor.instances`: number of executors
    - `spark.shuffle.manager`: determines shuffle implementation, default is `sort`.
    - `spark.sql.autoBroadcastJoinThreshold=50MB`: limit the size of joins during serialization.
    

## Best Practices

### Performance Tuning

- **Resource Allocation**:
    - Start with fewer, large executors.
    - Start with 4-6 cores per exec with 6-10 GB memory.
    - Monitor CPU utilization and aim for 80%+.

- **Serialization**:
    - The process of converting an object in memory into a byte stream so it can be sent over the network to driver/executors.
    - Use Kyro serializer: `spark.serializer=org.apache.spark.serializer.KyroSerializer`.
    - Register custom classes with Kyro for better performance.
    - Avoid Java serialization of large objects.

```python
# Bad: capturing a large object in closure (forces full serialization each task)
large_lookup = {"a": 1, "b": 2, ...}  # huge dict

rdd.map(lambda row: (row.key, large_lookup[row.key]))

# Good: broadcast (explained below)
bc_lookup = sc.broadcast(large_lookup)
rdd.map(lambda row: (row.key, bc_lookup.value[row.key]))
```

- Use cache() when DataFrames/RDDs accessed multiple times in the same job.
- Storage levels are managed with `persist()`: `df.persist(StorageLevel.MEMORY_AND_DISK)`

### Shuffle Configuration

- It's good to minimize shuffles when possible:
    - Use `mapPartitions()` instead of `map()` when possible.
    - Leverage broadcast joins for small data.
    - Cache frequently shuffled datasets.

### Data Partitioning

- Target 100-200MB per partition to begin with.

```python
# Partition by frequently joined/grouped columns
# For user-based analytics
df = df.repartition("user_id")

# For time-based queries
df = df.repartition("date")

# Use coalesce() to reduce partitions without full shuffle
# Better than repartition(10) when reducing
df = df.coalesce(10)
```

## Monitoring and Troubleshooting

- The Spark Web UI is the primary tool for monitoring, debugging, and optimizing Apache Spark apps. You can view job execution, resource utilization and performance bottlenecks.

- Jobs Tab: Job timeline, Completed Jobs, Failed Jobs, Active Jobs, Shuffle Read/Write volumes
- Stages Tab: Stage DAG, Task summary, metrics
- Storage Tab: Memory vs disk usage, cached size per partition, evicted partitions.
- Environment Tab: Configs, properites for Spark, JVM, env variables, Hadoop properties.

### Troubleshooting

- **Data Skew**:

```txt
Symptoms: Few tasks taking much longer than others
Diagnosis: Stages tab → Task duration distribution
Solutions: Repartition data, add salt keys, broadcast joins
```

- **Memory Issues**:

```txt
Symptoms: Tasks failing with OOM, high GC time
Diagnosis: Executors tab → Memory usage patterns
Solutions: Increase executor memory, reduce partition size, optimize caching
```

- **Data Processing Issues**:

```txt
High Shuffle Read Time:
- Network bottlenecks between nodes
- Too many small partitions
- Inefficient join strategies

High Shuffle Write Time:
- Disk I/O bottlenecks
- Large partition sizes
- Memory spilling to disk
```

## Advanced Topics

### UDF User Defined Functions

- UDFs can be used for feature engineering, data cleaning, evaluation, etc.

```python
from pyspark.sql.functions import udf, col, when, isnan, isnull
from pyspark.sql.types import DoubleType, StringType, IntegerType
# 1. Simple mathematical UDF
@udf(returnType=DoubleType())
def calculate_bmi(weight, height):
    """Calculate BMI with null handling"""
    if weight is None or height is None or height == 0:
        return None
    return float(weight) / (float(height) ** 2)

# 2. Complex feature engineering UDF
@udf(returnType=StringType())
def risk_category(age, income, credit_score):
    """Categorize risk based on multiple factors"""
    if any(x is None for x in [age, income, credit_score]):
        return "unknown"
    
    risk_score = 0
    if age < 25 or age > 65:
        risk_score += 1
    if income < 30000:
        risk_score += 2
    if credit_score < 600:
        risk_score += 3
    
    if risk_score >= 4:
        return "high"
    elif risk_score >= 2:
        return "medium"
    else:
        return "low"
```

- Always use appropriate return types with UDFs (`DoubleType()`, `StringType()`, etc.)

- Apply UDFs

```python
# Apply UDFs for feature engineering
df_engineered = df \
    .withColumn("bmi", calculate_bmi(col("weight"), col("height"))) \
    .withColumn("risk_category", risk_category(col("age"), col("income"), col("credit_score"))) \
    .withColumn("special_char_count", count_special_chars(col("description"))) \
    .withColumn("price_volatility", calculate_volatility(col("price_history")))
```

### MLLib

```python
from pyspark.ml.classification import LogisticRegression
from pyspark.ml.feature import VectorAssembler
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("ml-example").getOrCreate()
df = spark.read.parquet("s3a://data/features.parquet")
assembler = VectorAssembler(inputCols=["f1", "f2", "f3"], outputCol="features")
data = assembler.transform(df).select("features", "label")

train, test = data.randomSplit([0.8, 0.2])
lr = LogisticRegression(maxIter=20)
model = lr.fit(train)
pred = model.transform(test)
pred.select("label", "prediction", "probability").show(5)
spark.stop()
```