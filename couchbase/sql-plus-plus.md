# SQL++ (N1QL) Basics for Couchbase

## Introduction
`SQL++` (formerly `N1QL`) is Couchbase's query language that extends SQL for JSON documents. It allows querying NoSQL data using familiar SQL-like syntax.


## Selecting Data

### **Simple SELECT**
```sql
SELECT * FROM `my_bucket` LIMIT 5;
```
- Fetches all documents from `my_bucket` (limit to 5).

### **Selecting Specific Fields**
```sql
SELECT name, age FROM `my_bucket` WHERE type = "user";
```
- Retrieves only `name` and `age` where `type` is `"user"`.

### **Using Aliases**
```sql
SELECT name AS UserName FROM `my_bucket`;
```
- Renames `name` to `UserName`.

### **Filtering with WHERE**
```sql
SELECT * FROM `my_bucket` WHERE age > 30;
```
- Fetches documents where `age` is greater than `30`.

### **Sorting Results**
```sql
SELECT * FROM `my_bucket` ORDER BY age DESC;
```
- Orders results by `age` in descending order.


## Inserting Data

### **Basic INSERT**
```sql
INSERT INTO `my_bucket` (KEY, VALUE) VALUES 
("user123", {"name": "John", "age": 28, "type": "user"});
```
- Inserts a new document with key `user123`.


## Updating Data

### **Update a Field**
```sql
UPDATE `my_bucket` SET age = 35 WHERE name = "John";
```
- Updates `age` to `35` for users named `"John"`.

### **Increment a Numeric Value**
```sql
UPDATE `my_bucket` SET age = age + 1 WHERE type = "user";
```
- Increases `age` by `1` for all `user` documents.


## Deleting Data

### **Delete a Document**
```sql
DELETE FROM `my_bucket` WHERE name = "John";
```
- Deletes documents where `name` is `"John"`.

### **Delete Multiple Documents**
```sql
DELETE FROM `my_bucket` WHERE age > 60;
```
- Deletes all documents where `age` is greater than `60`.


## Working with Arrays

### **Filtering by Array Values**
```sql
SELECT * FROM `my_bucket` WHERE "developer" IN roles;
```
- Finds documents where `roles` array contains `"developer"`.

### **Updating an Array (Adding a Value)**
```sql
UPDATE `my_bucket` SET skills = ARRAY_APPEND(skills, "Python") WHERE name = "John";
```
- Adds `"Python"` to the `skills` array for `John`.


## Indexing for Performance

### **Creating a Primary Index**
```sql
CREATE PRIMARY INDEX ON `my_bucket`;
```
- Enables full-bucket queries.

### **Creating a Secondary Index**
```sql
CREATE INDEX idx_age ON `my_bucket`(age);
```
- Optimizes queries filtering by `age`.


## - Joins in SQL++

### **Simple JOIN Between Buckets**

```sql
SELECT u.name, o.order_id 
FROM `users` u 
JOIN `orders` o ON KEYS u.order_i
```