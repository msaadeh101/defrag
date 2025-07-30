import pyodbc

conn = pyodbc.connect("your-connection-string")
cursor = conn.cursor()

cursor.execute("""
    SELECT 'Employee: ' + Name AS Output
    FROM Employees
    WHERE Name IS NOT NULL
""")

for row in cursor.fetchall():
    print(row.Output)
