package main

import "fmt"

// Outer struct
type Employee struct {
	Name    string
	Age     int
	Address Address // Nested struct
}

// Inner struct
type Address struct {
	Street string
	City   string
	Zip    string
}

func main() {
	// Example 1: Initialize with nested struct literal
	emp1 := Employee{
		Name: "Alice",
		Age:  30,
		Address: Address{
			Street: "123 Main St",
			City:   "New York",
			Zip:    "10001",
		},
	}

	// Example 2: Initialize step-by-step
	var emp2 Employee
	emp2.Name = "Bob"
	emp2.Age = 40
	emp2.Address.Street = "456 Elm St"
	emp2.Address.City = "Chicago"
	emp2.Address.Zip = "60601"

	// Output
	fmt.Println("Employee 1:", emp1)
	fmt.Println("Employee 2:", emp2)

	// Access nested struct field directly
	fmt.Println("Employee 1 City:", emp1.Address.City)
}
