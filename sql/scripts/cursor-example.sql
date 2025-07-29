-- Example schema
-- CREATE TABLE Employees (Id INT, Name NVARCHAR(100), Email NVARCHAR(100));
-- CREATE TABLE ContactList (EmployeeId INT, Email NVARCHAR(100));

DECLARE @EmployeeId INT
DECLARE @Email NVARCHAR(100)

-- Define cursor
DECLARE employee_cursor CURSOR FOR
SELECT Id, Email FROM Employees

-- Open cursor
OPEN employee_cursor

-- Fetch the first row
FETCH NEXT FROM employee_cursor INTO @EmployeeId, @Email

-- Loop through all rows
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Check if Email is not null
    IF @Email IS NOT NULL AND LEN(@Email) > 0
    BEGIN
        -- Insert into target table
        INSERT INTO ContactList (EmployeeId, Email)
        VALUES (@EmployeeId, @Email)
    END

    -- Fetch next row
    FETCH NEXT FROM employee_cursor INTO @EmployeeId, @Email
END

-- Cleanup
CLOSE employee_cursor
DEALLOCATE employee_cursor
