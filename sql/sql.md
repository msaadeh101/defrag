# SQL

## SQL Commands

- SQL Commands let you interact with a relational database, and the commands fall into different categories.

### Data Query Language (DQL)

- **DQL** For reading data
- `SELECT` - retrieves data from one+ tables

```sql
SELECT name, email FROM customers WHERE status = 'active';
```

### Data Definition Language (DDL) 

- **DDL** for structuring tables

- `CREATE`: Creates new tables, databases, etc.
- `ALTER`: Modifies table structure.
- `DROP`: Deletes tables or databases
- `TRUNCATE`: Removes all data from a table (Faster than `DELETE`)

```sql
CREATE TABLE employees (
    id INT PRIMARY KEY,
    name NVARCHAR(100),
    hire_date DATE
);
```

### Data Manipulation Language (DML)

- DML for changing data.

- `INSERT`: Adds new records.
- `UPDATE`: Changes existing records.
- `DELETE`: Removes records from a table.

```sql
-- target table is "employees"
-- (id, name, hire_date) are specific columns we are providing values for
-- You DO NOT have to specify all columns
INSERT INTO employees (id, name, hire_date)
-- VALUES provides the actual data values that correspond to each column in order
VALUES (1, 'Alice', '2023-01-01'); -- Strings need quotes, numbers do not
-- '2023-01-01' is the standard YYYY-MM-DD
-- without id, name, hire_date, must match column structure EXACTLY
```
### Data Control Language (DCL)

- DCL for permissions.

- `GRANT`: Give permissions to user
- `REVOKE`: Remove permissions

```sql
GRANT SELECT ON employees TO analyst_user;
```

### Transaction Control Language (TCL)

- **TCL** for managing transcations, works with most SQL databases.

- `BEGIN TRANSACTION`: Starts a transaction.
- `COMMIT`: Saves changes permanently.
- `ROLLBACK`: Undoes changes in case of error.
- `SAVEPOINT`: Creates a point within a transcation to rollback to.

```sql
BEGIN TRANSACTION;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;
```

### T-SQL

- Transact-SQL or **T-SQL** is Microsoft's proprietary extension of SQL used in SQL Server, Azure SQL and Azure Synapse SQL.
    - Microsoft-specific features: 
        - Stored procedures with programming constructs:
        - User-defined functions:
        - Triggers:
        - Variables and control flow (IF/ELSE, WHILE loops)
        - Error handling (TRY/CATCH)

```sql
-- T-SQL uses DECLARE to declare a table variable
-- T-SQL uses @ to define scalar and table variables
DECLARE @EmployeeRecord TABLE (
    Id INT,
    Name NVARCHAR(100),
    Email NVARCHAR(100)
);

INSERT INTO @EmployeeRecord VALUES (1, 'Alice', 'alice@example.com');

SELECT * FROM @EmployeeRecord;
```

## SQL Concepts

### Set-Based SQL

- Set-based SQL *DOES NOT* offer row-by-row control. But it is much faster.
- Result set is returned all at once.
- Good for simple-read only scenarios

```sql
-- Step 1: Clean data
UPDATE Employees -- Update the Employees table setting all names to uppercase
SET Name = UPPER(Name)
WHERE Name IS NOT NULL;

-- Step 2: Format data for output
-- For each row, create a string by concatenating Employee + value from name column
SELECT 'Employee: ' + Name AS Output
-- Result is returned as a column named Output
FROM Employees
-- Filters result where rows Name is not null
WHERE Name IS NOT NULL;
```

- You can then view this in a GUI, export this to Excel, view in a dashboard.

- Example of writing to another table to persist the formatted data.

```sql
INSERT INTO EmployeeLog (Message, LoggedAt)
SELECT 'Employee: ' + Name, GETDATE()
FROM Employees
WHERE Name IS NOT NULL;
```

### Cursor

- A **cursor** is a pointer to a result set. It allows you to loop through rows one at a time to perform *row-by-row* logic.

1. Declare the cursor
1. Open the cursor
1. Fetch rows one at a time
1. Process the row(s)
1. Close and Deallocate the cursor

```sql
-- Declare two variables, @Id and @Name
DECLARE @Id INT, @Name NVARCHAR(100)

-- Declare a cursor named employee_cursor
DECLARE employee_cursor CURSOR FOR
SELECT Id, Name FROM Employees
-- The cursor is based on the above SELECT query
-- So far the query is not run, just defined the cursor.

-- Open the cursor and execute the SELECT query
OPEN employee_cursor
-- Now the cursor is positioned before the first row of the result set

-- FETCH the next row from result set, i.e. first row in this case
FETCH NEXT FROM employee_cursor INTO @Id, @Name
-- INTO @Id, @Name means the values from the row's Id and name columns are stored here

-- WHILE loop checks fetch status succeeded (i.e. no more rows or an error)
WHILE @@FETCH_STATUS = 0
BEGIN -- Start the body of the loop
    PRINT 'Employee: ' + @Name -- Print to the SQL server output window
    -- Do something with @Id, @Name
    -- Below line moves cursor to next row
    FETCH NEXT FROM employee_cursor INTO @Id, @Name
    -- Need this new FETCH NEXT FROM .. INTO .. so loop is not infinite
END

-- Close cursor once loop is finished
CLOSE employee_cursor
-- Above Close releases the result set, but not the cursor definition

-- DEALLOCATE deletes the cursor definition from memory.
DEALLOCATE employee_cursor
-- Cursor is now fully cleaned up unless we declare it again
```

### ACID

- **ACID** stands for Atomicity, Consistency, Isolation, Durability. These are guarantees for safe Database operations.

- **Transaction**: All steps succeed or none do, `ROLLBACK`

```sql
BEGIN;

UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
-- parameterize using ? to prevent against SQL injection

COMMIT;
```

- `Deadlocks`: **Important**, if two transactions update the same rows in reverse order, they can lock eachother forever


- **Incorrect order**
```md
# This is incorrect:
- Transaction1: `UPDATE A THEN B`
- Transaction2: `UPDATE B THEN A`
```

- **ALWAYS** lock rows in same order and keep transactions short.
- Use `READ COMMITTED` instead of SERIALIZABLE if possible.

### Triggers and Stored Procedures

- **Triggers** and **Stored Procedures** are server-side logic. These are good for enforcing rules, but can create side effects.

- Good use: simple enforcement like updating a timestamp.

```sql
CREATE TRIGGER update_timestamp -- creates a new trigger
BEFORE UPDATE ON users -- specify when and where trigger will fire
FOR EACH ROW -- trigger executes once per row
EXECUTE FUNCTION update_modified_column(); -- the trigger will run this function
```

- **Important**: Do not use the database triggers and stored procedures to write to another table or some other 'hidden' action.

### Indexes

- Use **indexes** to optimize read performance. Indexes speed up `SELECT` queries, but can slow down `INSERT`, `UPDATE`, `DELETE` because the index needs to be updated too.
    - Avoid indexing on high-churn or rarely-used columns.
    - Periodically analyze unused indexes.

```sql
CREATE INDEX idx_email ON users(email); 
-- This index makes the below select fast
SELECT * FROM users WHERE email = 'test@example.com'
```