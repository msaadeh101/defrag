# Cockroach DB

## Overview

- **CockroachDB** is SQL-like and PostgreSQL compatible:
    - Distributed SQL database with power of Relational DB and horizontal scale of NoSQL.
    - Every node in a CockroachDB cluster is identical and can read/write any request.
    - Data is partitioned into ranges (small continuous chunks of data). As data grows, ranges are split and rebalanced.
    - Resilience: Data ranges are split between multiple nodes.
    - Raft Consensus algorithm: Raft Consensus protocol ensures strong consistency across all replicas.
    - Self-Healing: If a node fails, CockroachDB automatically re-replicates the data to other healthy nodes.
    - Provides built in monitoring endpoints and integrates with Prometheus, Grafana.
    - NOT designed for heavy analytical processing (OLAP workloads).
    - Need Elasticsearch for advanced search.

## Commands

- **String Functions**

```sql
-- lowercase
SELECT LOWER('HELLO');
-- trim whitespace
SELECT TRIM(' hello ');
-- substring
SELECT SUBSTRING('abcdef', 2, 3);
-- replace text
SELECT REPLACE('abcabc', 'a', 'z');
```

- **Math functions**

```sql
-- Round to integer
SELECT ROUND(12.56);
-- Random number 0-1
SELECT RANDOM();
```

- **Date and Time functions**

```sql
-- Current date/time
SELECT NOW();
-- Extract year/month/day
SELECT EXTRACT(YEAR FROM NOW());
-- Format date
SELECT TO_CHAR(NOW(), 'YYYY-MM-DD');
-- Add interval
SELECT NOW() + INTERVAL '1 day';
```

- **JOINS**

|JOIN Type| Returns| Common Use Case|
|----|-----|-----|
|`INNER JOIN`| Rows where there is match in both tables| Getting related data where both sides must exist|
|`LEFT JOIN`| All rows from left table, plus matching from right. `NULL` for non-matching on right|Listing all items from one table and showing related data optionally|
|`RIGHT JOIN`| All rows from right table, plus matching from left. `NULL` for non-matching on left|Less common, showing all items from right table with optional left data|
|`FULL JOIN`| All rows from both tables, `NULL` for non-matching on either side| Finding all data from two tables and identifying missing data|


```sql
-- Basic INNER JOIN
-- Return only riows that match both products and categories table based on ON condition
SELECT p.id, p.name, c.name AS category_name
FROM products p
-- products table has columns like id, name, category_id
JOIN categories c ON p.category_id = c.id;
-- categories table has columns like id, name

-- LEFT JOIN
-- Return all rows from left table along with matching categories from right table
SELECT p.id, p.name, c.name AS category_name
FROM products p
LEFT JOIN categories c ON p.category_id = c.id;
-- If no match right table will have NULL values

-- FULL JOIN (or FULL OUTER JOIN)
-- Union of LEFT JOIN and RIGHT JOIN
SELECT p.id, p.name AS product_name, c.id AS category_id, c.name AS category_name
FROM products p
FULL OUTER JOIN categories c ON p.category_id = c.id;
```

- **Conditional/Case**

```sql
SELECT name,
  CASE
    WHEN price > 100 THEN 'Expensive'
    ELSE 'Affordable'
  END AS price_label
FROM products;
```

- **Schema Management: Create, Alter and Drop tables**

```sql
-- Create table
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name STRING,
  price DECIMAL,
  category_id UUID
);

-- Alter table
ALTER TABLE products ADD COLUMN stock INT;

-- Drop table
DROP TABLE products;
```

- **Indexing**

```sql
-- Create index
CREATE INDEX ON products (name);

-- Drop index
DROP INDEX products@products_name_idx;
```

- **Filtering and Searching**

```sql
-- LIKE
SELECT * FROM products WHERE name LIKE '%briefcase%';

-- ILIKE (case-insensitive LIKE)
SELECT * FROM products WHERE name ILIKE '%BRIEFCASE%';

-- IN clause
SELECT * FROM products WHERE category_id IN (1, 2, 3);
```