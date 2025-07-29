# Couchbase Server

- Distributed NoSQL platform
- Supports Web Admin Console (UI), REST and CLI
- [Docs](https://docs.couchbase.com/server/current/getting-started/look-at-the-results.html)

## Setup

- Installation: `docker run -t --name db -p 8091-8096:8091-8096 -p 11210-11211:11210-11211 couchbase/server:enterprise`
- "Setup New Cluster" with Configuration:
  - Cluster Name:
  - Admin credentials
  - Node services: Data Key-value, Index, Query, Search (FTS), Analytics (CBAS)
  - Memory quotas:
  - Data paths:

- Or use the couchbase CLI

```bash
/opt/couchbase/bin/couchbase-cli cluster-init \
  --cluster-name mycluster \
  --cluster-username Administrator \
  --cluster-password password \
  --services data,index,query \
  --cluster-ramsize 256 \
  --cluster-index-ramsize 256 \
  --cluster-analytics-ramsize 256 \
  --cluster-eventing-ramsize 256 \
  --cluster-fts-ramsize 256 \
  --cluster-port 8091
```

  - Create Buckets, which are logical containers for your JSON documents.
    - Bucket Types: Couchbased, Memcached, Ephemeral
  - Eviction Policy:
  - Replicas:
  - `XDCR`: `Cross Data Center Replication` is feature for global distribution, disaster recovery, high availability, conflict resolution, topology planning.
    - Utilizes Change Data Capture and an XDCR agent, relies on open firewall communication.


## Overview

- Stores data as `items`, each of which has a `key` and a `value`.
- Multiple instances of Couchbase server can be combined into a single cluster
- A **Cluster Manager** program coordinates all node-activities, privdes a cluster-wide interface to all clients.
- Individual nodes can be added/removed/replaced with no down-time for cluster as a whole.
- Couchbase logically partitions data into `VBuckets`, assigned to a specific active node in the cluster.
  - Couchbase maintains 1+ replica per bucket, configurable per bucket.
  - Configurable auto-failover timeout.
  - During node failures a client request may timeout or fail.
  - When SDK receives new cluster map after changes, the cluster automatically promotes new nodes based on affected VBuckets.

- **Couchbase Hierarchy**: `Cluster -> Bucket -> Scope -> Collection -> Document`
  - A `Cluster` is one or more instances of Couchbase Server.
  - A `Bucket` is the primary logical container that groups items (Couchbase, Ephemeral, Memcached)
  - A `Scope` is a logical grouping of related collections within a bucket.
  - A `Collection` is the finest-grained logical container for documents within a scope.
  - A `document` is the JSON object, equivalent to a row in a relational database.

```markdown
Couchbase Cluster
└── Bucket (e.g., my_application_data)
    └── Scope (e.g., customer_data, product_catalog, tenant_A_data)
        └── Collection (e.g., users, orders, inventory, tenant_A_users)
            └── Document (Your JSON data, e.g., {"id": "user::123", "name": "Alice"})
```

## Terms

- **Core Concepts**:
    - Buckets: Databases.
    - Documents: JSON objects.
    - Scopes and Collections: like schemas and tables.
    - N1QL - SQL for JSON (Couchbase query language)
    - Indexes - Primary and Secondary Indexes.
    - Key-Value vs document access

### Services

- **Data**: Supports `storing`, `setting`, `retreiving` of data items, specified by Key.
  - REST Flag: `kv`
- **Query**: Parses queries in the SQL++ language, executes and returens results
  - REST Flag: `n1ql`
  - Interacts with both Data and Index services
- **Index**: Creates indexes, for use by the Query Service.
  - REST Flag: `index`
- **Search**: Creates indexes specially purposed for Full Text Search. This supports language-aware searching; allowing users to search for, say, the word beauties, and additionally obtain results for beauty and beautiful.
  - REST Flag: `search`
- **Analytics**: Supports `join`, `set`, `aggregation`, and `grouping` operations; which are expected to be large, long-running, and highly consumptive of memory and CPU resources.
  - REST Flag: `cbas`
- **Eventing**: Supports near real-time handling of changes to data: code can be executed both in response to document-mutations, and as scheduled by timers.
  - REST Flag: `eventing`
- **Backup**: Supports both the scheduling and the immediate execution of full and incremental data backups, either for specific individual buckets, or for all buckets on the cluster. Also allows the scheduling and immediate execution of merges of previously made backups.

### Failover

- After **failover** (Automatic/`Hard` or manual/`Graceful`) there are two options:
  - Node can be `removed`, by means of `rebalance` command.
  - Node can be `recovered`, and added back to cluster by `rebalance` command.

- `Recovery` can be **Full** (all pre-existing data from, and new data added to node) or **Delta** (maintains and synchs only pre-existing data, only changes copied).
  - If a node is down for a while, do a Full recovery usually.

## Couchbase/N1QL

```sql
-- Test connection to Couchbase with function
SELECT 'Today is ' || NOW_STR() AS message;
```

```sql
-- List all buckets, scopes, collections available where datastore_id = /tutorial/data
SELECT name FROM system:keyspaces WHERE `datastore_id` = "/tutorial/data";
```

- `system:keyspaces` is a special system collection showing metadata for buckets, scopes and collections.

- `USE KEYS` to retreive documents when you know the exact document key (optimized):

```sql
-- Direct key value lookup using fast KV speed
SELECT * FROM my_bucket USE KEYS 'doc1'
-- OR
SELECT * FROM my_user_bucket.my_scope.my_collection USE KEYS 'user::john.doe'
```


```sql
-- query returns a JSON object with bucket_name and document_count
SELECT name as bucket_name, count as document_count
FROM system:keyspaces
WHERE `namespace` = "default";
-- Needed `` for `namespace` key
```

```sql
-- Returns total_documents from purchases bucket
SELECT COUNT(*) as total_documents FROM `default`:`purchases`;
```

```sql
-- Return total_buckets count
SELECT COUNT(*) as total_buckets FROM system:keyspaces;
```

```sql
-- Returns a json object with count from bucket named product
SELECT * FROM system:keyspaces WHERE `name` = `product`

-- Get a sample of products to see the structure
SELECT * FROM `default`:`product` LIMIT 5;

-- See total products and average number fields per product
SELECT COUNT(*) as total_products,
       AVG(ARRAY_LENGTH(OBJECT_NAMES(p))) as avg_fields_per_product
FROM `default`:`product` p;

-- Find unique field names across all products
SELECT DISTINCT ARRAY field FOR field IN OBJECT_NAMES(p) END as all_fields
FROM `default`:`product` p
LIMIT 1;
```

```sql
SELECT META().id, name, unitPrice, categories, type
-- commas separate the fields to retrieve
FROM `default`:`product` -- backticks handle special chars in namespace:bucket format
WHERE categories IS NOT MISSING -- similar to SQL IS NOT NULL
  AND (categories = "Luggage" OR ARRAY_CONTAINS(categories, "Luggage"))
  -- Categories are often arrays, so the above handles both
  -- ARRAY_CONTAINS is a an array function
LIMIT 10;
```

- `META().id` is a N1QL specific function to get the document id/key

```sql
-- Sort by luggage product price descending
-- Always use p.unitPrice to prefix field names with the alias
SELECT p.name, p.unitPrice, p.categories
FROM `default`:`product` p
UNNEST p.categories as category
WHERE category = "Luggage"
ORDER BY p.unitPrice DESC;
```

```sql
SELECT 
  CASE -- CASE creates conditional logic like if/else
    WHEN p.unitPrice < 200 THEN "Budget" -- Assign the label budget
    WHEN p.unitPrice < 400 THEN "Mid-range" 
    ELSE "Premium" -- Assign label Premium if all else not applicable
  END as price_tier, -- Close the CASE and names the result column
  COUNT(*) as count, -- Calculates count for each tier
  AVG(p.unitPrice) as avg_price -- calculates average price for each tier
FROM `default`:`product` p
UNNEST p.categories as category -- unnest flattens categories into individual rows
WHERE category = "Luggage"
GROUP BY CASE 
    WHEN p.unitPrice < 200 THEN "Budget"
    WHEN p.unitPrice < 400 THEN "Mid-range" 
    ELSE "Premium"
  END;
```

- `END as price_tier` closes the CASE and names result column price_tier

```sql
-- Create literal columns based on conditions
SELECT 
  name,
  unitPrice,
  'Premium Item' AS badge
FROM `default`:`product`
WHERE unitPrice > 300
LIMIT 3;
```

### Funcitons

- String Functions (similar in SQL): `UPPER()`, `LOWER()`, `LENGTH()`, `SUBSTR()`, `TRIM()`

```sql
-- Same as SQL
SELECT UPPER(name), LOWER(name), LENGTH(name) FROM `default`:`product` LIMIT 3;
SELECT SUBSTR(name, 1, 10), TRIM(name) FROM `default`:`product` LIMIT 3;
SELECT name || ' - ' || type AS full_name FROM `default`:`product` LIMIT 3; -- concatenation
```

- Math functions (similar in SQL): `ROUND()`, `ABS()`, `CEIL()`, `FLOOR()`, `MIN()`, `AVG()`, `SUM()`

```sql
-- Same as SQL
SELECT ROUND(unitPrice, 2), ABS(unitPrice), CEIL(unitPrice), FLOOR(unitPrice) 
FROM `default`:`product` LIMIT 3;
SELECT MIN(unitPrice), MAX(unitPrice), AVG(unitPrice), SUM(unitPrice) 
FROM `default`:`product`;
```

- Date/Time Functions (similar in SQL but different syntax): `NOW_STR()`, `DATE_ADD_STR()`

```sql
-- Similar to SQL but different syntax
SELECT NOW_STR() AS current_time; -- like SQL's NOW()
SELECT DATE_ADD_STR(NOW_STR(), 30, 'day') AS future_date; -- like SQL's DATE_ADD
```

- Conditional Logic (Same CASE syntax as SQL): `CASE`, `THEN`, `ELSE`, `END`

```sql
-- Same CASE syntax as SQL
SELECT name, unitPrice,
  CASE WHEN p.unitPrice > 2000 THEN 'Expensive' ELSE 'Affordable' END AS price_category
FROM `default`:`product` p
ORDER BY p.unitPrice DESC LIMIT 10;
```

- Document Metadata (Unique to N1QL): META().id, META().type, META().cas

```sql
-- Unique to N1QL
SELECT META().id, META().type, META().cas FROM `default`:`product` LIMIT 3;
```

- JSON/OBJECT functions (N1QL specific):

```sql
-- Get all field names in a document
SELECT OBJECT_NAMES(p) AS products FROM `default`:`product` p LIMIT 1;
-- Get all field values in a document
SELECT OBJECT_VALUES(p) AS object_values FROM `default`:`product` p LIMIT 1;
-- Get specific field value dynamically
SELECT p.unitPrice AS products_price FROM `default`:`product` p LIMIT 1;
-- Check if something is an object/array
SELECT name, IS_OBJECT(categories), IS_ARRAY(categories) 
FROM `default`:`product` LIMIT 3;
```

- Array Functions (Couchbase): ARRAY_LENGTH(), ARRAY_CONTAINS(), ARRAY_AGG(), etc.

```sql
-- Work with arrays in documents
SELECT ARRAY_LENGTH(categories) as categories_length, ARRAY_CONTAINS(categories, 'Luggage') as Luggage
FROM `default`:`product` LIMIT 3;

-- Create a list of distinct categories
SELECT DISTINCT
  SUBSTR(ENCODE_JSON(p.categories), 2, LENGTH(ENCODE_JSON(p.categories)) - 2) AS category_list
FROM `default`:`product` p
LIMIT 30;

-- Array aggregation
SELECT ARRAY_AGG(name) AS all_product_names 
FROM `default`:`product` 
WHERE ARRAY_CONTAINS(categories, 'Luggage');
```

- Type Checking Functions (Good for flexible JSON): `IS_STRING()`, `IS_NUMBER()`, `IS_ARRAY()`

```sql
-- Check data types (useful for flexible JSON)
SELECT name, 
  IS_STRING(name) AS name_is_string,
  IS_NUMBER(unitPrice) AS price_is_number,
  IS_ARRAY(categories) AS categories_is_array
FROM `default`:`product` LIMIT 3;
```

- Pattern Matching: `REGEXP_LIKE()`

```sql
SELECT DISTINCT p.name
FROM `default`:`product` p
UNNEST p.categories AS cat
WHERE LOWER(cat) = "luggage"
  AND REGEXP_LIKE(p.name, ".*12.*")
LIMIT 50;
```

- Advanced Array Functions: `ARRAY_FLATTEN()`, `ARRAY_FIRST()`, `ARRAY_LENGTH()`

```sql
-- Flatten nested arrays
SELECT ARRAY_FLATTEN(nested_array, 1) FROM some_bucket;

-- Select where Array length greater than 2
SELECT p.name,
       p.categories AS all_categories
FROM `default`:`product` p 
WHERE ARRAY_LENGTH(p.categories) >= 2 
LIMIT 5;

-- First/Last array elements
SELECT ARRAY_FIRST(categories), ARRAY_LAST(categories) 
FROM `default`:`product` LIMIT 3;
```

- N1QL Control Functions: `IFMISSING()`, `IFMISSINGORNULL()`

```sql
-- Handle missing values (instead of SQL's COALESCE)
SELECT name, IFMISSING(unitPrice, 0) AS price 
FROM `default`:`product` LIMIT 3;

-- Multiple conditions
SELECT name, IFMISSINGORNULL(unitPrice, 'No price') AS display_price
FROM `default`:`product` LIMIT 3;
```

- UUID and Random: UUID(), RANDOM()

```sql
-- Generate UUIDs (useful for document keys)
SELECT UUID() AS new_id;

-- Random numbers
SELECT RANDOM() AS random_value;
```

- Full Text Search: `SEARCH()`
    - Needs a full text search index

```sql
-- When FTS index exists
SELECT name, unitPrice, SCORE() 
FROM `default`:`product` 
WHERE SEARCH(product, 'briefcase') 
ORDER BY SCORE() DESC;
```


## Other notes

- Items are stored in named `Buckets`; some kept in memory only, some in both mem/disk.
- Data can be replicated across clusters residing in different data centers if needed.
- [Couchbase CLI](https://docs.couchbase.com/server/current/cli/cbcli/couchbase-cli.html)