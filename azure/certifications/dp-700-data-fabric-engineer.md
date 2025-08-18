# Microsoft Fabric

- [Link to study](https://learn.microsoft.com/en-us/credentials/certifications/fabric-data-engineer-associate/?practice-assessment-type=certification)


Quick Definitions:

|Concept|ETL|ELT|
|------|----|---|
|Stands for| Extract -> Transform -> Load| Extract -> Load -> Transform|
|When to use|transformation needs to happen before loading into storage|storage is scalable and transformations can be done after loading|
|Data flow |Source -> transform (Data factory or Spark) -> Storage|Source -> Storage (OneLake) -> Transform (SQL/Spark)|
|Good for |Strict schemas, organized data, more control over data quality, target has limited compute|faster initila load, scales well with big data, keeps raw data, flexible|
|Real Example|Clean and enrich data in pipeline before storage in Power BI|Dump raw sales data into OneLake and clean using Synapse SQL|
|Reusability|reusable by design, shared across reports, models|Can be reused via: SQL Views, notebooks, lakehouse sql endpoints|


## End-To-end Analytics using Microsoft Fabric
- `Fabric` is a unified `SaaS` platform where all data is stored in a single open format in OneLake, accessible by all analytics engines on the platform.
- Fabric administration is handled in the `Admin portal`: Manage groups and permissions, configure data sources and gateways, monitor usage.
- `OneLake` is Fabric's centralized data storage that enables collaboration by eliminating need for copying data between systems.
    - Built on `Azure Data Lake Storage (ADLS)` and supports Delta, Parquet, CSV, JSON, more.
    - `Shortcuts` are references to files or locations external to OneLake, allowing you to use without copying.
        - In `Tables` folder, you can only create shortcuts at top level. NOT supported in subdirectories.
        - No restrictions to on where to create shortcuts in `Files` folder.
    - `OneLake catalog` helps you analyze, monitor, and maintain data governance. Search and filter available data.
- `Workspaces` serve as logical containers for your data, reports, and assets.
    - Workspace Settings: License type, OneDrive access, Data Lake Gen2 storage, Git integration, Spark workload settings.
    - Workspaces can be managed for: `admin`, `contributor`, `member`, `viewer`.
- `Workloads` in Fabric offers different item types: `Data Engineering`, `Data Factory`, `Data Science`, `Data Warehouse`, `Databases`, `Industry Solutions`, `Real-Time Intelligence`, `Power BI`.

- Fabric allows for different roles to collaborate effectively:

|Role| Description|
|------|----------|
|Data engineers|Can injest, transform, load data into OneLake using pipelines, use Notebooks|
|Data analysts| transform data upstream with dataflows, Direct Lake mode, interactive reports with Power BI|
|Data scientists|integrate notebooks with Python/Spark, ML models|
|Analytics Engineers|bridge gap between engineering and analysis, create semantic models in Power BI|
|Low-to-no-code users/Citizens| discover curated datasets at OneLake Hub, use PowerBI templates, simple ETL tasks|

- **Note Fabric must be enabled for your org first** with one of: Fabric Admin, Power Platform admin, Microsoft 365 admin.
    - Power BI Service -> Admin portal -> Tenant settings -> Enabled (for entire org or specific groups.)

## Lakehouses in Microsoft Fabric
- Foundation of Fabric is a `lakehouse`, built on top of OneLake with ability to scalably store data in a lake, and query in a data warehouse.
    - A lakehouse is a database, using `Delta format tables`.
    - Organized in a schema-on-read format (define schema as needed)
    - Support ACID transactions.
    - Single location for data engineers, data scientists, and data analysts
    - Ingested data can be transformed using Apache Spark with notebooks or Dataflows Gen2 (based on Power Query)

- Secure a Lakehouse by **managing access** at workspace or item-level sharing.
    - `Data Gateway `can be On-prem and or Vnet Data gateway.
- Limit access to data using `RLS (Row-level security)` or `CLS (Column-level security)` or `OLS (Object-level security)`.
    - **Note** You can add RLS to `DirectLake` dataset, if you define for both SQL and DAX, it falls back to `DirectQuery` for tables.
- Protect data with security labels like: `General`, `Confidential`, `Highly Confidential`
- You can enable `Customer Lockbox` for Fabric by going to `Portal` -> `Customer Lockbox for Azure` -> `Administration` tab -> `Enabled`.
    - Lockbox provides a UI to approve or deny data access requests.


|Role|Workspace Access| OneLake Access|
|---|----------------|----------------|
|Admin, member, contributor|Can use all items in workspace| Yes|
|Viewer| Can see all items in workspace|No|

- When you create a lakehouse, three data items automatically created in your workspace:
    - `lakehouse` (contains shortcuts, folders, files, tables)
    - `semantic model (default)`: easy data source for Power BI report developers (includes all tables, auto-detected relationship, auto refresh, precreated dataset)
    - `SQL analytics endpoint`: read-only access to query data with SQL. (enables you to write queries, manage semantic model, query visually)
- Use any of these methods to ingest data into lakehouse:
    - `Upload`: local file
    - `Dataflows Gen2`: Import and transform using visual Power Query.
    - `Notebooks`: Use Apache Spark (PySpark, SQL, Scala) to ingest, transform, load data.
    - `Data Factory pipelines`: Use copy data activity.
    - `Spark job definitions`: submit batch/streaming jobs to Spark clusters

## Delta Lake tables in Microsoft Fabric

- Tables in Fabric Lakehouses are based on Linux `Delta Lake table format` (commonly in Apache Spark).
- `Delta Lake` is open-source storage layer that adds relational DB semantics to Spark-based data lake processing
- Microsoft Fabric lakehouses are Delta tables (schema abstractions), signified by the `triangle Delta icon`.
    - For each table, the lakehouse stores a folder with (a) `Parquet data files` and (b) a `delta_Log` folder for transactional JSON logs.
    - Pros of Delta Tables: ACID support, `time travel` and data versioning, interoperability of formats, support for batch and streaming.
        - Time Travel: `DESCRIBE HISTORY table_name LIMIT 1` (provides version, timestamp, notebook, readversion, isolationlevel, job, etc.)

- Create a Delta table from a dataframe using `saveAsTable`:
```python
# Load a file into a dataframe
df = spark.read.load('Files/mydata.csv', format='csv', header=True)

# Save the dataframe as a delta table
df.write.format("delta").saveAsTable("mytable")
```
- `Managed Table`: table definition in metastore and files are managed by Spark runtime for Lakehouse.
    - If you drop a managed table, the table metadata and actual delta data files are deleted.
- `External Table`: metastore mapped to an alternative file storage lcocation.
- Specify a fully qualified path for storage: `df.write.format("delta").saveAsTable("myexternaltable", path="abfss://my_store_url..../myexternaltable")`

- `DeltaTableBuilder API` lets you write Spark code to create a table, or use SQL `CREATE TABLE mytable`
- Save data in delta format:
```python
delta_path = "Files/mydatatable"
df.write.format("delta").save(delta_path)
```
- Add rows from a dataframe to existing folder: `new_rows_df.write.format("delta").mode("append").save(delta_path)`

- **Omtimize delta lake tables** to avoid the `small file problem` (since Parquet files are immutable, and needs overwriting)
    - `OptimizeWrite` is a feature of Delta Lake which reduces number of files as they are written (enabled by default, fewer larger files, better compression, efficient data distribution.)
    - `spark.conf.set("spark.microsoft.delta.optimizeWrite.enabled", True)`
    - To run optimize: Go to `Lakehouse Explorer` -> `Maintenance` -> Select `Run OPTIMIZE command` -> (Optional) `Apply V-order to maximize reading speeds in Fabric` -> (Optional) `Run VACUUM command using retention threshold x time` -> `Run now`.
- `V-Order` provides optimized sorting, encoding and compression to Delta parquet files. It is **enabled by default** in Fabric Warehouse (but not lakehouse) to boost read times by 10-50%. write time optimization for parquet files.
- `VACUUM` command enables you to remove old data files (old parquet files are retained to enable time travel)
    - Data files that are not currently referenced in transaction log AND older than retention period permanantly deleted by VACUUM.
    - Using SQL:
- `OPTIMIZE` command consolidates multiple small parquet files into large file.
```sql
%%sql
VACUUM lakehouse2.products RETAIN 168 HOURS;
```

- `Partitioning` delta lake tables improves performance by enabling `data skipping` (over irrelavent objects). **i.e parition by year**
    - Use partioning only when you have VERY large amounts of data, and tables can be split into few large partitions.
    - `df.write.format("delta").partitionBy("Category").saveAsTable("partitioned_products")`
        - Data will be partitioned physically in storage by category (separate paths after Category)
        - `saveAsTable()` handles storage automatically, whereas `save()` takes the path without metastore registration.
    - DO NOT parition if column has high cardinality (# unique values, like users, timestamp).

- Most common way to work with delta tables in Spark is `spark.sql` library: `spark.sql("INSERT INTO products VALUES (1, 'Widget', 'Accessories', 2.99)")`
- Use time-travel to work with table versioning `versionAsOf` and `timestampAsOf` options.

### Delta Tables with Streaming Data

- `Spark Structured Streaming API` based on a boundless dataframe. Can read data from network ports, real-time message brokers, file system locations.
- Loading data into a streaming DataFram from a delta table with `spark.readStream`:
```python
# ignoreChanges means only NEW ROWS, ignore updates or deletes.
stream_df = spark.readStream.format("delta") \
    .option("ignoreChanges", "true") \
    .load("abfss://your-container@your-storage-account.dfs.core.windows.net/delta/orders_in")
```
- Only `append` operations can be used when using a Delta table as a streaming source. No data modifications unless you specify `ignoreChanges` or `ignoreDeletes`
- Verify a stream is streaming: `stream_df.isStreaming`
- Use delta table as streaming sink: `deltastream = transformed_df.writeStream.format("delta").option("checkpointLocation", checkpointpath).start(output_table_path)`
    - `checkpointLocation` is used to write a checkpoint file that tracks state of stream processing.
- Stop the stream: `deltastream.stop()`


## Ingest Data with Dataflows Gen2 in Microsoft Fabric

- `Dataflows Gen2` are used to ingest and transform data from multiple sources, and then land the cleansed data to another destination.
    - Can be incorporated into data pipelines for more complex activity orch, and also used as data source in Power BI.
    - Allows you to ensure consistency, then stage data in preferred destination.
    - *Without a dataflow, you would have to manually extract and transform the data*

- `Dataflows` are a type of cloud-based ETL tool for building and executing scalable data transformation processes.
    - Using `Power Query Online` (a low-code data transformation tool) allows for visual interface to perform the tasks.

### How to use Dataflows Gen2
- Adding a destination to your dataflow is optional, and dataflow preserves all transformation steps.
- Dataflows can be horizontally partitioned(split data by rows, to make loading and processing faster.). Once you create a global dataflow (central dataset, standardized), data analysts can create specialized semantic models.
- Dataflows allow you to promote reusable ETL logic, so you do not need to create new connections to data.

|DataFlows Gen2 Pros|Dataflows Gen2 Cons|
|------------------|-------------------|
|Extend data with consistent data, like a standard date dimension table|Not a replacement for data warehouse|
|Allow self-service access to subset of data|Row-level security not supported|
|Simplify data source complexity by exposing to analyst group|fabric capacity workspace required|
|Enable users to clean/transform before loading||
|Low-code interface that ingests from various sources||

- Data pipelines activities include: Copy data, icorprate dataflow, Add notebook, get metadata, execute script

#### PowerQuery
- Top Row:
- Data source Connectors can be: On-prem db, excel, or flat files, sharepoint, SalesForce, Spark, Fabric Lakehouses.
- Possible Data transformations:
    - Filter and Sort rows:
    - Pivot and unpivot: turns rows into columns.
    - Split and Condtional Split: Separate column into parts (like first name last name).
    - Replace values and Remove duplicates:
    - Add, Rename, Reorder, Delete columns:
    - Rank and Percentage calculator:
    - Choose Top N and Bottom N:

- `Queries Pane`: Shows different data sources, called `queries`. Queries are called tables when loaded into your data store
- `Diagram view`: visually see how data sources are connected and applied transformations.
- `Data preview Pane`: subset of data to allow to see which transformations to make/how they affect data.
- `Query Settings Pane`: includes Applied Steps (each transformation represented as step)
    - You can set Data Destination option: Lakehouse, Warehouse, SQL database, Azure SQL, Data Explorer, or Synapse Analytics.

## Data movement in Microsoft Fabric

- The graphical pipeline canvas in the Fabric UI allows you to build complex pipelines with minimal or no coding required.
- **Core Pipeline Concepts:**
    - `Activities`: 
        - `Data transformation` activities:
            - Copy data activities: Connect data source, destination, review and save.
            - **Data flow activities**: Implement transformations using dataflow Gen2 (power query interface)
            - Notebook activities: Run Spark code
            - Stored Procedure activities
            - Delete data activities
        - `Control Flow` activities:
            - Implement loops, branching, variable, parameter values
    - `Parameters`: Ability to specify a different folder for each run.
    - `Pipeline Runs`: Can be on-demand in the Fabric UI or scheduled. Each has a unique run ID

- `Templates` provide pipelines for commone scenarios that you can cusomize from the `Home` page.   
    - Bulk Copy from/to Database, AI RAG, Copy data to Lakehouse, Azure SQL DB, etc.
- Use `Validate` option at top, to check configuration is valid.
    - Only executes once attached dataset reference exists, and meets validation criteria.
- `View Run history`: Activity name, start time, submitted by, Status.

## Apache Spark in Microsoft Fabric
- `Apache Spark` is an open-source parallel processing framework for large-scale data analytics and processing. Azure implementations: `Azure HDInsight`, `Azure Synapse Analytics`, `Microsoft Fabric`.
    - Uses a `Spark Pool`, a cluster of nodes to process large volumes of data quickly.
    - Can run with Java, Scala, Spark R, Spark SQL, and PySpark.
    - `Head` node in Spark pool coordinates processes via `driver` program. Pool includes worker `executor` processes.
    - Fabric provides a `starter pool` for each workspace, but you can configure the pool yourself.
    - The Spark `runtime` determines the version of Spark, Delta Lake, Python, others. (`1.1, 1.2, 1.3`)
        - View runtime from `Workspace settings` -> `Data Engineering/Science (Spark settings)` -> `Runtime Version` (Spark and Delta)
    - Use custom `environments` in a Fabric workspace, to use specific Spark runtimes, libs, configs, resource files, etc.

- From `Fabric Admin portal`, you can go to `Capacity Settings` -> `Create new pool` 
    - Node Family: type of VMs, usually memory optimized
    - Autoscale:
    - Dynamic Allocation: dynamically allocate executor processes on worker nodes based on volume.

- The `Native Execution Engine` in Fabric is a vectorized processing engine that runs spark directly on lakehouse infrastructure.
```json
    %%configure 
{ 
   "conf": {
       "spark.native.enabled": "true", 
       "spark.shuffle.manager": "org.apache.spark.shuffle.sort.ColumnarShuffleManager" 
   } 
}
```
- Enable `high concurrency mode` to share Spark sessions across users/processes, enabling isolation of code to avoid comingling of notebooks from the `Data Engineering/Science` section of workspace settings.
    - High Concurrency enables multiple notebooks to use same Spark application, saving sessing start time.
- Automatic MLFlow logging (manage ML training and model deployment.)

- To edit and run Spark code in Fabric, use `notebooks` (interactive, multi format), or define a `Spark job` (automated process).
    - `Notebooks` allow you to combine code, images, text into one place. They consist of `cells`, containing markdown formatted or executable code. You can run code interactivly here.
    - Spark jobs: Main defintion file, reference file, command-line args, Lakehouse references. Needs a `spark job definition` in your workspace.

- `dataframe` is the most common used datastructure, provided by the Spark SQL library. (spark itself uses RDD resilient distributed dataset)

- In a Spark notebook, you can use PySpark code to load a products.csv file, which will auto create a table.
```csv
ProductID,ProductName,Category,ListPrice
771,"Mountain-100 Silver, 38",Mountain Bikes,3399.9900
772,"Mountain-100 Silver, 42",Mountain Bikes,3399.9900
773,"Mountain-100 Silver, 44",Mountain Bikes,3399.9900
...
```

```python
%%pyspark  # Magic for notebooks like Azure Synapse or Databricks

df = spark.read.format('csv') \
    .option('header', 'true') \
    .load('Files/data/products.csv')

display(df.limit(10))
```

- `%%spark` is used to specify Scala

- Specify an `explicit schema` which improves performance:
```python
from pyspark.sql.types import *
from pyspark.sql.functions import *

productSchema = StructType([
    StructField("ProductID", IntegerType()),
    StructField("ProductName", StringType()),
    StructField("Category", StringType()),
    StructField("ListPrice", FloatType())
    ])

df = spark.read.load('Files/data/product-data.csv',
    format='csv',
    schema=productSchema,
    header=False)
display(df.limit(10))
```

- Use `withColumn` to change or transform a column: `df = df.withColumn("Date", to_date("Date", "yyyy-MM-dd"))`

- Filtering and grouping dataframes: `pricelist_df = df.select("ProductID", "ListPrice")`
- Select a subset: `pricelist_df = df["ProductID", "ListPrice"]`
- Display counts: `counts_df = df.select("ProductID", "Category").groupBy("Category").count`
- Save a dataframe: `bikes_df.write.mode("overwrite").parquet('Files/product_data/bikes.parquet')`
    - **Parquet** format is preferred for data files used for further analysis/ingestion.
- `Partioning` (optimization technique to max performance across worker nodes) can be done with `partitionBy` method:
    - `bikes_df.write.partitionBy("Category").mode("overwrite").parquet("Files/bike_data")`
    - Creates `column=value` format containing subfolders: Each subfolder contains one+ parquet files with the data for appropriate category.
        - `Category=Mountain Bikes`
        - `Category= Road Bikes`
    - Load partitioned data: `road_bikes_df = spark.read.parquet('Files/bike_data/Category=Road Bikes')` This will not include the category column in dataframe.

- Creating a temporary `view` (automatically deleted at end of session) is the simplest way to make data in dataframe available for querying in Spark catalog: `df.createOrReplaceTempView("products_view")`
- `tables` are persisted in the catalog. In Fabric, data for managed tables stored in the `Tables` location shown in data lake.
    - Create an empty table: `spark.catalog.createTable` or save a dataframe as a table: `df.write.format("delta").saveAsTable("products")`
    - Preferred table format is `delta` in Fabric for rleational data technology in Spark (Delta Lake)
    - Create an external table: `spark.catalog.createExternalTable` (typcally a folder in the `Files` storage area of lakehouse)

- SQL Example:

```sql
%%sql

SELECT Category, COUNT(ProductID) AS ProductCount
FROM products
GROUP BY Category
ORDER BY Category
```

- Built-in Notebook charts: dataframes/SQL queries are displayed under the `code cell`. By default, results are a table.
    - Python supports `Matplotlib` library for graphics and data visualizations. (Seaborn is another library)

## Real-Time Intelligence in Microsoft Fabric
- Two common patterns for data analytics: `Batch` (data loaded into store, periodically analyized) and `Real-time` (streams of data).
- Characteristics of real-time data analytics:
1) Data stream is `unbounded` - data constantly added to stream.
2) Records in stream include `temporal data`.
3) Aggregation of streaming performed over several `temporal windows`
4) Results of streaming data can be processed in real-time to visualize or persist data.

- `Microsoft Fabric Real-Time Intelligence` allows you to: 
    - Create `eventstream`: Runs perpetuallly to ingest and transform real-time data.
        - Sources can be: External (Azure storage, Event Hubs, IoT, Kafka Hubs, CDC feeds, etc) Fabric events, or Sample Data.
        - Data transformations: `Filter`, `Manage fileds`, `Aggregate`, `Group by`, `Union`, `Expand`, `Join`.
        - Data destinations: `Eventhouse`, `Lakehouse`, `Derived stream` (only applicable if transformations), `Fabric Activator`, `Custom Endpoint`.
    - Store data in `eventhouse`: includes KQL databases which are real-time data stores
        - Turn on **OneLake availability** to create a logical copy of the KQL database data, to query from other fabric engines.
    - Query using `KQL Queryset`: collection of KQL queries. Statements: `take`, `filter`, `transform`, `aggregate`, `join`. **Support common subset of SQL**
    - Visualize `real-time dashboard` or Power BI: Each `tile` in a dashboard shows real-time data. Use Power BI for Visualizations and Data options.
    - Configure alerts that use `Activator` trigger actions: Automated processing of events that trigger actions.
        - Activator concepts: `Events`, `Objects`, `Properties`, `Rules`.
        - Activator is used for any real-time action.

- `app.powerbi.com/` -> `Real-Time` on left blade -> `Real-Time Hub`:
    - All Data streams
    - Connect to Data sources
    - Subscribe to Azure or Fabric events.

### Using Real-Time Eventstreams in Microsoft Fabric
- `Eventstreams` allow you to capture/process real-time events with no-code: 
    - **Sources**: Event Hubs, IoT Hub, Azure SQL DB/PostgreSQL/MySQL/Cosmos Change Data Capture (CDC), Google Pub/Sub, Confluent Kafka, AWS Kinesis, Fabric workspace events, Blob storage events (support for `streamed` and `unstreamed` events), Custom endpoint, sample data OOB.
        - `Change Data Capture`: better job performance to only read source data that has changed since last run.
    - **Destinations**: Eventhouse, Lakehouse, Custom endpoint, Derived Stream, Fabric Activator
    - **Transformations**: `Filter` (on null or is not null), `Manage fields` (add, remove, change fields), `Aggregate` (sum, min, max, avg), `Group by`, `Union` (connect two or more nodes), `Expand` (array transformation to create new row), `Join` (combine two streams based on matching condition)

- `Windowing functions` perform operations on data contained in a temporal window.
    - `Window type`: 
        - `tumbling`: fixed, non-overlapping, distinct time segments (duration). Each event belongs to 1 window.
        - `hopping`: fixed, overlapping. Events can belong to more than 1 hopping window, based on hop size (uses duration and hop size, when to create the new window).
        - `sliding`: dynamically triggered, overlapping. High overlapping. Similar to hopping, events appear in every window they fall in. Moving averages.
        - `snapshot`: capture stat in specific point in time. Not a window, but a consistent view. Non overlapping, different snapshots.
        - `session`: dynamic, based on user activity. Grouping based on sessions.
    - `Window duration`: Seconds -> Days
    - `Window offset`: Shift start of window
    - `Grouping Key`: one+ columns to group by
    - `Aggregation function`: one+ functions to apply in each window.

### Work with Real-time data in Microsoft Fabric Eventhouse
- An `Eventhouse` is a data store for large volumes of data, optimized for time-based events data. 
    - Must be working in a workspace with Fabric capacity that supports Real-Time Intelligence Fabric capability.
    - To import your data into a KQL db in an eventhouse, take it from a `static location` (local file, OneLake, Storage) or `real-time` (Event Hubs, Fabric eventstream) location.
        - You can enable `OneLake` option for a database or individual tables.

- Simplest query in KQL consists of a table name: `myTable`
- KQL is the preferred langauge in a KQL db for simplicity, performance, flexibility, integration.
- Summarize data to not retrieve at an individual level, but analyze patterns
```kql
myTable
| where fare_amount > 20
| summarize trip_time = count() by vendor_id
| project trip_time, fare_amount
| sort by fare_amount
```

- Create a materialized view (summary of data from a table) with `.create materialized-view` to improve performance on complex queries:
```kql
.create materialized-view TripsByVendor on table Automotive
{
    Automotive
    | summarize trips = count() by vendor_id, pickup_date = format_datetime(pickup_datetime, "yyyy-MM-dd")
}
```
- Use `.create-or-alter function` command to repeat a query with parameterized values.

### Create Real-Time Dashboards in Fabric
- Real-time dashboards in Fabric are built on tables in `Eventhouse` that are populated by `eventstream`.
- When connecting a dashboard to a data source, you have two options for authorization:
    - Pass-through identity - data accessed using identity of user viewing dashboard.
    - Dashboard editor's identity - data accessed using identity of dashboard creator.
- You can add multiple `tiles` consisting of KQL queries, as well as `text tiles` for additonal info.
- Make your dashboard more maintainable by defining `base queries` to retrieve general records, then `tile specific queries` to filter.
- By default, there is 1 page, but you can add more.
- Editors can establish a default auto refresh rate
- Create a variable:
```bash
base_bike_data
| project Neighbourhood, latest_observation, No_Bikes, No_Empty_Docks
| order by Neighbourhood asc
```
- Use paramters like selected_neighborhood:
```bash
bikes
| where ingestion_time() between (ago(30min) .. now())
    and (isempty(['selected_neighbourhoods']) or Neighbourhood in (['selected_neighbourhoods']))
| summarize latest_observation = arg_max(ingestion_time(), *) by Neighbourhood
```

### Fabric Lakehouse Medallion architecture design
- `Medallion Architecture`: design pattern used to organize data in lakehouse logically. Also known as multi-hop. Framework for data cleaning.
    - `Bronze`: Raw data, landing zone for all data, sructured, semi-/un-structured. No changes made. Use pipelines, dataflows, notebooks.
    - `Silver`: Validated layer, refinement and merging and enforcing of validation rules. Data consistently stored and accessed by multiple teams. Use Dataflows or notebooks.
    - `Gold`: Enriched, further refinement for business/analytics needs. Could involve aggregation with external info, use downstream and in MLOps. Might use a `Warehouse` SQL Analytics endpoint or Semantic model. Can have multiple gold layers.

- **Data transformation tools**: 
    - `Dataflows Gen2`: smaller semantic models simple transformations
    - `Notebooks`: larger semantic models, complex transformations, save data as Delta table in Lakehouse
- **Data orchestration**:
    - `Pipelines`: a series of steps that move data from one place to another.

- Data analysts can connect to the semantic model in Lakekhouse using `Direct Lake mode`, semantic model accesses data directly from Delta tables in Lakehouse, no data import, fast, up-to-date, interactive reports.
    - Good for Lake-centric architectures, large volumes of data in OneLake.
    - Semantic model-level setting `Keep your Direct Lake data up to date`: does auto updates of Direct lake tables, enabled by default.
        - If disabled, you can trigger refresh programmatically of semantic model.


## Data Warehouses in Microsoft Fabric
- Fabric `Data Warehouse` is a relational warehouse (**SQL experiences**), that supports Transactional (T-SQL) capabilities. It centralizes and organizes data from different systems into a unified view for **analysis and reporting purposes**.
    - Full control of creating tables, load, transform data, querying using portal or T-SQL commands. Use Spark to process data and create ML models.
- Warehouses are organized by dimensional modeling: fact tables and dimension tables.
    - `Fact tables`: numerical data to analyze. Large number rows, primary source for data analysis.
    - `Dimension Tables`: descriptive information about data in fact tables, small number of rows. Provide context, info about customers.
        - `Time dimensions`: might include columns for year, quarter, month order was placed.
        - `Slowly changing dimensions`: changing product price or address.
        - A dimension table contains a `unique key column` (or two) that uniquely identifies each row in the table.
            - `Surrogate Key`: Specific to the data warehouse. automatically generated integer as a unique identifier.
            - `Alternate Key`: natural or business key, a specific transactional entity such as a product code.
- **You need BOTH surrogate and alternate keys in a data warehouse**
- In a Data Warehouse, data is `de-normalized` (star) to reduce number of joins required to query the data. Uses `star schema` where fact table is in middle of Dimensional tables.
    - Could make sense to use a `snowflake schema`, where some info is shared amongst different dimensions, here it is `normalized` (snowflake) to reduce redundancy.
- **Ingest data into your Warehouse with**: `Pipelines`, `Dataflows Gen2`, `cross-db querying`, or `COPY INTO`
```sql
COPY INTO dbo.Region 
FROM 'https://mystorageaccountxxx.blob.core.windows.net/private/Region.csv' WITH ( 
            FILE_TYPE = 'CSV'
            ,CREDENTIAL = ( 
                IDENTITY = 'Shared Access Signature'
                , SECRET = 'xxx'
                )
            ,FIRSTROW = 2
            )
GO
```
- `Clone tables` are zero-copy tables that contain metadata but reference the same data files in OneLake. So the underlying parquet file is not duplicated: `CREATE TABLE AS CLONE OF` T-SQL command.
- Use `staging tables` as temp tables for data cleansing, tranformation, validation. Use T-SQL to load from table into Data Warehouse

- Loading data process:
- Ingest data into data lake -> load files into staging table in warehouse -> load dimension data, update surrogate keys -> load fact tables in staging tables and lookup -> perform post-load optimization by updating indexes.

- Two ways to query data in a warehouse:
1) `Visual query editor`: drag and drop interface, similar to Power Query online. Use Transform menu.
2) `SQL query editor`:

- You can switch between `Data` (tables), `Query` (SQL queries), and `Model` (semantic model) views in Fabric on the left blade.
    - `Relationships` allow you to connect tables in the semantic model.
    - Create `Measures`, metrics that you want to analyze, by using `New measure` button in Model view (using DAX: data analysis expressions)
    - Use `Hide` to hide fields from table or column view, but still available in semantic model.
- Use `New Report` button to create new Power BI report.

- **Warehouse Security**: RBAC to warehouse, TLS between warehouse and client apps, `Azure Storage Service Encryption` in transit and rest, Monitor and LA, MFA to add extra security, Entra ID.
    - In addition to workspace roles, you can add `item permissions` via SQL:
        - `Read`: CONNECT using SQL connection string, not access to data. (NEEDED FOR SQL ANALYTICS ENDPOINT)
        - `ReadData`: read within table/view in warehouse, still respects RLS.
        - `ReadAll`: read raw parquet files in OneLake, not SQL-level access.

- `Dynamic management views (DMVs)`: monitor connection, sesssion, and request status to see live SQL insights. Get details like number of active queries, long running queries.
    - `sys.dm_exec_connections`: returns information about connections established to instance (session_id, most_recent_session_id, connection_id, etc)
    - `sys.dm_exec_sessions`: all active and user connections (session_id, login_time, client_version, memory_usage, last_request_end_time, reads, etc.)
    - `sys.dm_exec_requests`: provide info to each request executing in SQL server (session_id, status, start_time, command, sql_handle, connection_id, etc)

```sql
SELECT request_id, session_id, start_time, total_elapsed_time
    FROM sys.dm_exec_requests
    WHERE status = 'running'
    ORDER BY total_elapsed_time DESC;

```
- **MUST be a workspace Admin to run `KILL` command**. Member, Contributor, Viewer roles can only see own results.

### Load Data into Microsoft Fabric Data Warehouse
- Data extraction/ingestion moves raw data from sources into a central repo. `Data loading` takes that transormed data and loads it.

- Data Load types:
    - Full (initial) load: populate data warehouse for first time, all tables are truncated, old data lost, less complex, best for new data.
    - Incremental load: updating the warehouse with changes, history preserved, takes less time, complex, regular updates.

- **Load a dimension table** (who, what, where, why) as a desriptive backdrop.
    - Slowly Changing Dimensions (SCD): slow, unpredictable changes. **6 total SCDs**. Star schema design theory refers to common SCD types. Type 1 and Type 2 SCD are most commonly used:
        - `Type 1 SCD`: Overwrite. Just update value, no history kept.
        - `Type 2 SCD`: Add Row. Full history, Add new row with surrogate key/dates. Tracks every change.
        - `Type 3 SCD`: Add Column. Partial History. Adds column to store previous value.
        - `Type 4 SCD`: History Table. Move old records to separate history table.
        - `Type 6 SCD`: Hybrid of 1+2+3. Overwrite, Row versioning, and Column versioning. One row shows all.

- Below code is `SCD type 2`: SourceKey is the business key.
```sql
-- @ProductID is a parameter
-- SourceKey is the business key from source system 
-- SELECT 1 is a lightweight way to check for existence
IF EXISTS (SELECT 1 FROM Dim_Products WHERE SourceKey = @ProductID AND IsActive = 'True')
BEGIN -- Begin if active product exists already
    -- Existing product record
    UPDATE Dim_Products
    SET ValidTo = GETDATE(), IsActive = 'False' -- Expire the existing record but keep it
    WHERE SourceKey = @ProductID 
        AND IsActive = 'True';
END
ELSE
BEGIN -- Now create the new product record/row
    -- New product record
    INSERT INTO Dim_Products (SourceKey, ProductName, StartDate, EndDate, IsActive)
    VALUES (@ProductID, @ProductName, GETDATE(), '9999-12-31', 'True');
END

```

- **Load a fact table:** Loading logic must lookup corresponding surrogate keys
```sql
-- Lookup keys in dimension tables
INSERT INTO dbo.FactSales
SELECT  (SELECT MAX(DateKey) -- convert order data into DateKey
         FROM dbo.DimDate
         WHERE FullDateAlternateKey = stg.OrderDate) AS OrderDateKey,
        (SELECT MAX(CustomerKey) -- max is a safe way to return a single value
         FROM dbo.DimCustomer
         WHERE CustomerAlternateKey = stg.CustNo) AS CustomerKey,
        (SELECT MAX(ProductKey)
         FROM dbo.DimProduct
         WHERE ProductAlternateKey = stg.ProductID) AS ProductKey,
        (SELECT MAX(StoreKey)
         FROM dbo.DimStore
         WHERE StoreAlternateKey = stg.StoreID) AS StoreKey,
        OrderNumber,
        OrderLineItem,
        OrderQuantity,
        UnitPrice,
        Discount,
        Tax,
        SalesAmount
FROM dbo.StageSales AS stg -- reading raw transactional data from staging table
```

- **Data pipelines** in Fabric come from Azure Data Factory. Two ways to create a pipeline:
- *From Workspace*: Select `+ New` -> `Data pipeline`
- *From warehouse asset* -> Select `Get Data` -> `New data pipeline`
1) Add pipeline activity: launches pipeline editor
2) Copy data: launches copy assistent, new pipeline activity preconfigured Copy Data task.
    - Choose data source: select connector, provide connection info
    - Connect to data source: select, preview, and choose data
    - Choose data destination:
    - Settings: staging, default values, etc.
3) Choose a task to start: Choose from predefined templates.

- `COPY statement` is main method for importing data, especially from storage account.
    - Option to use different storage account for `ERRORFILE` (`REJECTED_ROW_LOCATION`) for beter debugging.

```sql
COPY INTO test_parquet
FROM 'https://myaccount.blob.core.windows.net/myblobcontainer/folder1/*.parquet'
WITH (
    CREDENTIAL=(IDENTITY= 'Shared Access Signature', SECRET='<Your_SAS_Token>')
)
```

- Load data from another warehouse or lakehouse: `CREATE TABLE AS SELECT` and `INSERT...SELECT`

- Load and transform with Dataflows Gen2:
    - Navigate to your workspace -> Select `+ New` (Select more options if not visible, under Data Factory section.)
    - Once it launches, you can `import data` from several sources (excel, csv, SQL server, other dataflows)
    - On `Query Settings` tab -> select `+` and `Add data destination` (Azure SQL, Lakehouse, Data Explorer (Kusto), Synapse analytics, Warehouse)
    - Select `Append` or `Replace`.

### Query a data warehouse in Microsoft Fabric

- You can use T-SQL to query dimension and fact tables in a data warehouse.
- Use `JOIN` clauses to link fact tables with dimension tables.
    - Intermediate JOINs might be necessary, even if you don't select columns from some tables, in order to relate data.
- Use `GROUP BY` clauses to define aggregation hierarchies.
- Use `T-SQL ranking functions` to partition results: Uses `OVER()` and `PARTITION BY()`
    - `ROW_NUMBER`: Returns sequential row number within a partition. Starts at 1 for each partition. `(1,2,3,4,5)`.
    - `RANK`: Returns the rank of each row within the partitioned result. Includes ties and skips `(1,2,2,4,5)`.
        - Rank of a row is 1+ number of ranks before the row.
        - Temporary value for duration of query.
    - `DENSE_RANK`: Returns rank of each row within partition, with no skips in ranking. `(1,2,2,3,4)`
        - Rank of row is 1+ number of *distinct* rank values before the row.
    - `NTILE`: returns specified percentile. Groups numbered starting at 1. `(NTILE(4))`

```sql
SELECT  ProductCategory, -- select and rank products within each category, ORDER BY listPrice
        ProductName,
        ListPrice,
        ROW_NUMBER() OVER -- assign unique rown number, inc by 1
            (PARTITION BY ProductCategory ORDER BY ListPrice DESC) AS RowNumber,
        RANK() OVER -- same price gets same rank
            (PARTITION BY ProductCategory ORDER BY ListPrice DESC) AS Rank,
        DENSE_RANK() OVER -- does not skip rank numbers
            (PARTITION BY ProductCategory ORDER BY ListPrice DESC) AS DenseRank,
        NTILE(4) OVER -- divides rows within each category by 4
            (PARTITION BY ProductCategory ORDER BY ListPrice DESC) AS Quartile
FROM dbo.DimProduct
ORDER BY ProductCategory;
```

- `COUNT` function to retrieve number of sales each year.
- `APPROX_COUNT_DISTINCT` function approximate count (uses HyperLogLog algo with max error rate of 2%, 97% probability). Quicker.

- Access T-SQL Query editor:
1) `Home` -> Select `New SQL query` -> Select template.
2) `Queries` node: Select `... My queries` -> `New SQL Query`
3) `Query` tab: opens query editor.
    - Results are limited to `10k` rows. Can `download excel file`.
    - `Save as view` or `Save as table`.
    - Can also choose `New visual query` for non-technical members.

- Use `SQL Server Management Studio (SMSS)` to connect to a data warehouse in Fabric by `copying SQL connection string` from `more options`
- Can also use `ODBC` or `OLE DB drivers` to connect.

### Monitor a Microsoft Fabric warehouse
- The license determines the capacity, `capacity units (CUs)`. Every action can consume CUs.
- The `Fabric Capacity Metrics app` that administrators can install in the Fabric environment to monitor CUs and see if `throttling` is occurring.

- Query insights is a feature of Fabric to provide historical, aggregated info about queries.
    - `queryinsights.exec_requests_history`: each completed SQL query
    - `queryinsights.long_running_queries`: execution time.
    - `queryinsights.frequently_run_queries`: 
    - Queries can take up to `15 minutes` to be reflect in query insights.


### Secure a Microsoft Fabric Data warehouse

- Warehouses are powered by SQL, and you can use the same security features:
    - **Workspace roles**: `Admin`, `Member`, `Contributor`, `Viewer`
    - **Item permissions**: Individual warehouses can have item permissions assiend direcly to them. facilitate sharing of warehouse downstream
    - **Data protection security**: use T-SQL to filter and add column-level, row-level and object-level security for tables using `WHERE`

- `Dynamic Data Masking (DDM)` is a security feature that offers real time masking/obscuring sensitive data. 
    - Data is not changed when DDM is applied, masking rules are applied to query results.

|Masking Type|Limitations|Masking Rule| Notes|
|-------------|----------|-----------|---------|
|Default|No info is visible|`default()`| `1900-01-01` `00:00:000` are defaults for dataetime|
|Email|only for email fields, first letter and .com|`email()`| `aXXX@XXXXX.com`|
|Custom Text|not for numeric data, time|`partial(prefix_padding,prefix_string,suffix_padding)`| `555.123.1234` -> `5xxxxxx`|
|Random|only for numeric or bytes, within range|`random(low,high)`| `random(1, 12)`|
|Datetime|Masks part of a datetime Only SQL Server 2022|`year => datetime("Y")`| |

- Example: `ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');`
- **Row-level security**: Access restriction logic in the database tier. Works behind the scenes: Implemented in 2 steps:
1) `Security predicates`: 
    - Filter predicates: Silently filter the rows available to read operations: `SELECT`, `UPDATE`, `DELETE`
    - Block Predicates: explicitly block write operations: `AFTER INSERT`, `AFTER UPDATE`, `BEFORE UPDATE`, `BEFORE DELETE`.
        - `SCHEMABINDING = ON` - Default. the join or function is accessible from the query and works as expected without extra permissions.
2) `Security policy`: Attaches the security predicate to the table.
    - `CREATE SECURITY POILICY mypolicy` then `ADD FILTER PREDICATE` then `ON dbo.Sales` then `WITH (STATE = ON)`
```sql
--Create a separate schema to organize security-related objects
CREATE SCHEMA [Sec];
GO  

--Create the filter predicate function for RLS
CREATE FUNCTION sec.tvf_SecurityPredicatebyTenant(@TenantName AS NVARCHAR(10))  -- NVARCHAR = A variable-length up to 10 chars.
    RETURNS TABLE  -- tvf is a table value function
WITH SCHEMABINDING  -- Required for security predicates; ensures function doesn't reference external tables.
AS  
    RETURN	SELECT 1 AS result 
            --Row only visible if:
            -- - @TenantName in row matches current USER_NAME
            -- - OR current user is tenantAdmin@contoso.com (Has access to all tenants)
			WHERE @TenantName = USER_NAME() 
                OR USER_NAME() = 'tenantAdmin@contoso.com';  -- Admin can see anything
GO

--Create security policy that uses above function as a filter
CREATE SECURITY POLICY sec.SalesPolicy  
-- Apply the filter predicate to the TenantName column in Sales table
ADD FILTER PREDICATE sec.tvf_SecurityPredicatebyTenant(TenantName) ON [dbo].[Sales]
WITH (STATE = ON);  -- Enable the policy so it's actively filtering.
GO
```
- tenant1 to tenant5 users see their own rows only
- `WITH (STATE = OFF)` Turns the policy off. users see all rows.
- A `side-channel attack` is where an attacker forces an exception if `WHERE` is true.
    - Uses observable behavior changes like timing, response codes, if db exists - all from error messages.
    - Prevent with parameterized queries to prevent injection. Constant time logic, generic error messages.

- **Column-level security**: Prevent column access based on restrictions. `GRANT SELECT`, `DENY SELECT ON` to specific roles in T-SQL.
    - **DENY always supersedes the GRANT**

```sql
GRANT SELECT ON Membership(MemberID, FirstName, LastName, Phone) TO TestUser;
-- Does not include SSN column from table
```

- **Object-level security**: `GRANT SELECT ON SCHEMA::marketing TO [john@example.com]`
    - `DENY SELECT ON marketing.budget TO [xxx@example.com]`
    - `REVOKE SELECT ON hr.salaries TO [xxx@example.com]`

- `ALTER`: Grants user ability to change definition.
- `CONTROL`: Grants user all rights to object.

- `Dynamic SQL` is a concept where query is built programatically, like functions.

## Manage Microsoft Fabric environment

- **Use CI/CD in Fabric**: integration (git), deployment (Fabric deployment pipelines).
- Connect a Fabric workspace to a Git repository: 
- Go to `Workspace` -> `Workspace Settings` -> `Git Integration` on left blade:
    - Create or select an existing Git repository branch.
- Go to `Source control` at the top of a workspace, and choose `Changes` in the Source control window to sync workspace to git branch.  
    - When new commits are made in git branch, synch them with `Updates`. **Must happen so git repo can be updated**
- From `Source control` window:
    - `New workspace`: `Branch out to new workspace`
    - `Current workspace`: `Checkout new branch` or `Switch branch`

- Create a Deployment pipeline:
    - Go to Workspaces on left pane of Fabric:
        - Select New pipeline -> Next
        - Define name and stages -> Create and continue
        - Assign a workspace to a stage
        - Select the stage by clicking `Deploy from (drop-down)` and select the `Deploy` button.
        - To synch, select the `Commit` button in source control window.

### Monitor activities in Microsoft Fabric

- These activities should be monitored:
    - Data pipleine activities:
    - Dataflows
    - Semantic model refreshes:
    - Spark jobs, notebooks, lakehouses:
    - Fabric eventstreams:

- Open the Monitor hub by going to `Monitor` on the left of Fabric:
    - View `Activity name`, `status`, `Item type`, `Start time`, `Submitted by`
    - View Spark monitoring.

- `Activator` enables you to automate processing events and triggering actions, like email, or run a notebook to perform Spark-based data processing logic when a real-time dashboard is updated.
    - Use cases: sales drop -> marketing action, notifications of temperature, respond to anomalies
    - Basically can tell a change in values from eventstream and do an action.
- Definition Window:
    - Monitor: Attribute (Add filter, Add summarization)
    - Condition: Above/below value every occurance
    - Property Filter
    - Action: Type (email), To, Subject, Headline, Message

### Fabric Security Model

- Fabric has three security levels:
1) Entra ID: Can authenticate with azure identity
2) Fabric Access: can access Fabric?
3) Data security: checks if user can perform action on table or file.
    - Workspace roles: (in order!)
        - `Admin`: view, modify, share, manage all content and data in workspace, and manage permissions. (can manage permissions)
        - `Member`: view, modify, share all content and data in workspace. **(can share content)**
        - `Contributor`: view, modify all content and data in workspace. **(Can modify content)**
        - `Viewer`: view all content and data in workspace.
    - Item permissions: items within a workspace like lakehouses, warehouses, semantaic models. Can be inherited from workspace role or set individually. (Read, ReadData, ReadAll)
    - Compute or granular permissions: can be applied at SQL endpoint or semantic model
    - OneLake data access controls (preview): RBAC for lakehouse files.

- Select the `...` next to any Fabric item to `Manage permissions`
    - `Grant people access` window:
        - Choose people
        - `Additonal Permissions` (Read all sql endpoint, read all data apache spark, build reports)
        - `Notification options`
        - Click `Grant`

- Granular permissions, like RLS and file/folder access can be set through: SQL Endpoint, OneLake data access roles, Warehouse, Semantic model
    - Data in a lakehouse is stored as `/Files` `/Tables`
    - Click the top right of a lakehouse to see `SQL analytics endpoint`
    - Granular Lakehouse permissions (T-SQL): `GRANT`, `DENY`, `REVOKE`

- Manage Roles for **RLS** under (Power Query editor view) `Modeling` -> `Manage roles` -> `Select tables` -> `Filter data`.
- **Semantic model permissions**: `Read`, `Build`, `Reshare`, `Write`, `Owner`

### Fabric Governance
- All data in Fabric is stored in OneLake (Built on Data Lake Storage Gen2). There is `only one OneLake per tenant` that spans users, regions and clouds.

- `Tenant` -> `Capacity` (resources available based on SKU) -> `Domain` is a logical grouping of workspaces -> `Workspaces` -> `Items`

- Roles that can administer Fabric: `Microsoft 365 admin`, `Power Platform admin`, `Fabric capacity admin`

- Fabric Admin Portal:
    - Tenant settings:
    - Usage metrics:
    - Users:
    - Premium per User:
    - Audit logs:
    - Domains:
    - Workloads
    - Tags:
    - Capacity settings:
    - Embed Codes:
    - Organizational visuals:
    - Azure connections:
    - Custom branding:
    - Fabric Identities:
    - Featured Content

- Access to the `admin monitoring workspace`: you can share this, it includes Feature usage and Adoption dataset and report == Performance of your fabric environment.
- `User licenses` control level of user access/functionality.
    - License management is handled in the `Microsoft 365 admin center`.
    - `Pro` (Power BI), `Premium Per User (PPU)` (PowerBI), `Premium per capacity` (All), `Embedded (A SKUs)` (PowerBI), `Fabric Capcity (F SKUs)` (All), `Trial`
    - To create Power BI items that are not in your workspace, you need a `Pro` license.

- `Endorsement`: Endorsed items display a badge, indicating reliability.
    - `Promoted`: ready for sharing and resuse.
    - `Certified`: formal, authorized review, regarded as reliable and authoratative.
        - All Fabric items and Power BI items, except Power BI dashboards can be *promoted* or *certified*.
    - `Master data`: core source of organizational data, single source of truth for business data
        - All Fabric and Power BI items that contain data can be labeled *Master data*.

- The `scanner API` does metadata scanning for sensitive data. **First needs to be setup by admin**.
- `Data lineage` aka `impact analysis` to see where data comes from, transformed, etc.

- The `Microsoft Purview hub (preview)` allows you to manage and govern your organizations Fabric data estate (Data catalog, info protection, data loss prevention, audit)


## Service Comparison

| Tool/Storage        | Type          | Language(s) Used               | Speed / Parallelism           | Real-Time Capable | Cost Factor | Gateway Needed?            | Network Considerations                                          | Common Destinations                        | Typical Data Types                  | Primary Use Cases                                          |
|---------------------|---------------|--------------------------------|------------------|-------------------|-------------|-----------------------------|----------------------------------------------------------------|---------------------------------------------|-------------------------------------|-------------------------------------------------------------|
| **Notebook**        | Processing    | PySpark, T-SQL, KQL            | Fast, Full parallelism             | ❌ (Batch only)    | High        | ✅ If accessing on-prem     | Requires internet or Fabric VNET                                 | Lakehouse (Delta), CSV, Warehouse          | Structured, Semi-structured, Un-Structured       | ML, data exploration, Spark-based ETL                      |
| **Dataflow Gen2**   | Processing    | Power Query M, Low-code UI     | Moderate, Partial paralellism         | ⚠️ (Near Real-Time) | Medium      | ✅ If accessing on-prem     | Gateway for private SQL/SAP/Oracle                              | Lakehouse, Warehouse, Datamarts            | Structured                          | Data shaping, cleaning, business logic prep                |
| **Data Pipeline**   | Orchestration | UI + low-code steps, Python    | Scheduled/Triggered, Concurrent activity support        | ❌  (Supports Blob triggers)              | Low         | ✅ If sourcing on-prem      | Gateway for private data movement                               | Lakehouse, Warehouse, Eventstream          | Structured, Semi-structured         | Scheduled data movement, orchestration                     |
| **Eventstream**     | Streaming     | Event rules, UI config         | Real-Time, High parallelism        | ✅                 | Medium      | ❌                           | Requires public endpoints unless supported internal integration (Lakehouse, PowerBI RealTime)                 | Lakehouse (Delta), KQL DB, Event House      | Streaming, Semi-structured (JSON)   | IoT ingestion, telemetry routing                           |
| **Lakehouse**       | Storage       | PySpark, T-SQL, Notebooks      | High throughput  | ⚠️ With triggers   | Medium      | ❌                           | Internet-based; VNET support (preview)                         | Consumed by Notebooks, Power BI, Pipelines  | Structured, Semi-structured, Unstructured | Data lake for curated and raw layers                  |
| **Warehouse**       | Storage       | T-SQL                          | High             | ❌                | High        | ❌                           | Fabric-managed; private endpoints (preview)                    | Consumed by Power BI, Dataflows, Pipelines  | Structured                          | Structured analytics, BI model storage                    |
| **KQL Database**    | Storage       | KQL                            | Very High        | ✅                 | Low         | ❌                           | Fabric-native, streaming input support                         | KQL dashboards, Eventstream, Notebooks      | Semi-structured (logs/events)       | Log analytics, telemetry, real-time dashboards            |
| **Real-Time Hub**   | Integration   | Config/UI                      | Real-Time, parallel event-routing       | ✅                 | Medium      | ❌                           | Requires public streaming endpoints                            | Eventstream, Lakehouse, KQL DB              | Streaming, Semi-structured (JSON)   | Stream routing into Fabric destinations                   |
| **Event House**     | Storage       | KQL                            | Real-Time        | ✅                 | Low         | ❌                           | Same as KQL DB; native event ingestion                         | KQL Dashboards, Power BI                    | Streaming, Semi-structured (events) | Durable storage for streamed/logging data                |


## Cost Insight

| Layer   | Tool(s) Used             | Typical Activities                             | Storage Volume | Compute Cost Estimate | Total Est. Monthly Cost | Notes                                                           |
|---------|--------------------------|--------------------------------------------------|----------------|------------------------|--------------------------|-----------------------------------------------------------------|
| Bronze  | Data Pipeline + Lakehouse| Ingest raw data from blob/IOT/Event Hub         | 1 TB           | ~$30 (pipeline runs)   | ~$53                     | Mostly append-only; minimal processing                        |
| Silver  | Notebook (Spark)         | Clean, filter, transform raw to curated         | 1 TB           | ~$150 (Spark CU hours) | ~$175                    | Transformation-heavy using Notebooks                         |
| Gold    | Dataflow Gen2 + Warehouse| Aggregate, business logic, dimension modeling   | 0.5 TB         | ~$100 (Warehouse + DF) | ~$111                    | Optimized for Power BI; fewer records but more refinement     |
| 🔄 Realtime | Eventstream + Lakehouse | (Optional) Near real-time raw ingestion         | 0.1 TB         | ~$75                   | ~$77                     | If streaming used for telemetry or IoT                        |


## Architecture Flow

- SKU Stays the same and is shared across all workloads.
- Multiple steps may run in parallel, so budget CU usage and stagger jobs.
- Fabric manages scheduling and queueing time internally, so if multiple jobs ask for more CUs than available, some will wait or scale down.


| Step | Component                | Description                                      | Tools / Connectors                                  | Est. CU Usage (of F64) | Use Case Size (Storage/Throughput) | Notes                                                                 |
|------|--------------------------|--------------------------------------------------|-----------------------------------------------------|------------------------|------------------------------------|-----------------------------------------------------------------------|
| 1    | Source: On-Prem SQL Server | Extract raw customer & sales data               | Data Pipeline + Data Gateway                        | 2–4 CUs                | ~100K rows/day                     | Light workload; occasional copies; Data Gateway connection           |
| 2    | Source: Azure Blob Storage | Ingest raw IoT sensor JSON files                | Data Pipeline with Blob Storage connector           | 4–6 CUs                | ~1–5 GB/day                        | More frequent ingestion; semi-structured JSON                        |
| 3    | Ingest Raw Data (Bronze)   | Copy raw data into Lakehouse tables             | Data Pipeline → Lakehouse (Delta)                   | 6–8 CUs                | ~1 TB stored                       | Moderate load; parallel writes into Delta                            |
| 4    | Transform Raw (Silver)     | Clean, enrich, filter with Notebook             | Notebook (PySpark)                                  | 16–32 CUs              | ~10M rows/day                      | Heavy compute — uses Spark; benefits from high parallelism           |
| 5    | Enrich with Lookup Data    | Join against master data from Warehouse         | Notebook or Dataflow Gen2                           | 12–16 CUs              | Joins on dimension tables          | Parallel joins; performance improves with partitioning               |
| 6    | Apply Business Logic       | Aggregation, KPIs, logic                        | Dataflow Gen2 or Notebook                           | 8–16 CUs               | ~100K–500K rows/day                | Medium compute; parallel steps can share CU                          |
| 7    | Load Curated (Gold)        | Load into Warehouse for BI use                  | Dataflow or Pipeline → Warehouse                    | 4–8 CUs                | 500 GB optimized DW                | Smaller output; less compute than Silver                             |
| 8    | Serve to BI / Analytics    | Power BI reads Warehouse or Lakehouse           | Power BI Direct Lake or SQL                        | 8–16 CUs (query time)  | Ad-hoc reporting, dashboards       | Read latency is low; BI refresh jobs use capacity briefly            |
| 9    | Optional Real-Time Updates | Ingest IoT events at scale                      | Eventstream + Real-Time Hub                         | 16–32 CUs (peak)       | 1M+ events/hour                    | Bursty traffic; auto-scales if Fabric is Premium + bursting enabled  |
