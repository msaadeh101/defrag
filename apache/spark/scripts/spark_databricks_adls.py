from pyspark.sql import SparkSession

# Initialize Spark session (already available in Databricks as 'spark')
spark = SparkSession.builder.appName("ADLS-Gen2-Example").getOrCreate()

# ===== AUTHENTICATION =====
# Configure ADLS Gen2 access (using access key - simplest method)
storage_account = "mystorageaccount"
access_key = "your-storage-account-key"

spark.conf.set(
    f"fs.azure.account.key.{storage_account}.dfs.core.windows.net",
    access_key
)

# ===== ADLS GEN2 PATHS (ABFS - Azure Blob File System) =====
# Format: abfss://container@storageaccount.dfs.core.windows.net/path/to/file

container = "datalake"
base_path = f"abfss://{container}@{storage_account}.dfs.core.windows.net"

# ===== READ DATA FROM ADLS GEN2 =====

# Read CSV from ADLS Gen2
df_csv = spark.read \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .csv(f"{base_path}/raw/sales_data.csv")

# Read Parquet from ADLS Gen2
df_parquet = spark.read.parquet(f"{base_path}/processed/customer_data.parquet")

# ===== CREATE RDD EXAMPLE =====

# Create RDD from Python list
data = [("Alice", 25, "Engineer"), ("Bob", 30, "Manager"), ("Charlie", 35, "Analyst")]
rdd = spark.sparkContext.parallelize(data)

# Convert RDD to DataFrame
columns = ["name", "age", "role"]
df = rdd.toDF(columns)

# ===== BASIC OPERATIONS =====

# Show data
df.show()

# Basic transformations
df_filtered = df.filter(col("age") > 28)
df_with_bonus = df.withColumn("bonus", col("age") * 1000)

# ===== WRITE TO ADLS GEN2 =====

# Write as Parquet
df_with_bonus.write \
    .mode("overwrite") \
    .parquet(f"{base_path}/output/employee_data.parquet")

# Write as Delta Lake (recommended for ADLS Gen2)
df_with_bonus.write \
    .format("delta") \
    .mode("overwrite") \
    .save(f"{base_path}/delta/employee_delta")

# ===== HIERARCHICAL NAMESPACE FEATURES =====

# List files using ADLS Gen2 hierarchical structure
files = dbutils.fs.ls(f"{base_path}/raw/")
for file in files:
    print(f"Name: {file.name}, Size: {file.size}")

# Create directory structure (HNS feature)
dbutils.fs.mkdirs(f"{base_path}/processed/year=2024/month=01/")

print("Azure Databricks with ADLS Gen2 setup complete!")