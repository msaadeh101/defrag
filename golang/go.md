# Golang

- **Go** is open-source by Google. It is simple, efficient, and highly concurrent with features like built-in garbage collection, static typing and support for concurrency with goroutines and channels. Compiles directly to machine code making it fast and suitable for systems programming.

## Installation and Setup

```bash
# Homebrew/Mac
brew install go
```

```powershell
# chocolatey/Windows
choco install golang
```

## Syntax

### Variables

```go
var name string = "Go" // strongly typed, explicit declaration
age := 10 // shortand, infers the variable type
```

### Constants

- **Constants** are immutable and must be declared using `const`

```go
const Pi = 3.14
```

### Packages

- **Packages**: every Go file must declare a package at the top. The main package is special and denotes an executable program.

```go
package main

import "fmt"
```

### Functions

```go
// takes two integer args and returns an int
func add(a int, b int) int {
    return a + b
}

func main() {
    // Call the function from inside the main function
    result := add(5, 7)
    fmt.Println(result)
}
```

- Syntax in functions.

```go
// both num/den are floats, it returns a float(result) and error
func divide(numerator, denominator float64) (float64, error) {
    if denominator == 0 {
        return 0, fmt.Errorf("cannot divide by zero")
    }
    return numerator / denominator, nil
}

// Named return values (optional, but can improve readability for complex returns)
func subtract(a, b int) (result int) {
    result = a - b
    return // Returns the value of 'result' implicitly
}

func main() {
    // Calling the 'add' function
    sumResult := add(5, 7)
    fmt.Println("5 + 7 =", sumResult) // Output: 5 + 7 = 12

    // You can strongly type the variables divResult and err
    // var divResult float64
    // var err error
    // change the assignment of divide to simply =

    // Calling the 'divide' function and handling multiple returns
    divResult, err := divide(10, 2)
    if err != nil {
        fmt.Println("Error:", err)
    } else {
        fmt.Println("10 / 2 =", divResult) // Output: 10 / 2 = 5
    }

    // If we don't need the integer because division by 0 will fail
    _, err = divide(10, 0) // Ignoring the first return value (int)
    if err != nil {
        fmt.Println("Error:", err) // Output: Error: cannot divide by zero
    }
}
```


## Control Structures

### Loops

- Only `for` exists in Golang, not while. Can be used like a while or for-each loop as well.

```go
// Traditional for loop
// starting value of i is 0
// condition is i < 5, loop keeps running
for i := 0; i < 5; i++ {
    fmt.Println(i)
}

// While-like loop
sum := 1
for sum < 100 {
    sum += sum
}

// Iterate over string
for i, char := range "GoLang" {
    fmt.Printf("Char at index %d: $c\n", i, char)
}
```
- Using `range` to perform a for-each.

```go
package main

import "fmt"

func main() {
    nums := []int{2, 4, 6, 8}

    // For-each style loop with the index and value
    for index, value := range nums {
        fmt.Printf("index: %d, Value: %d'n", index, value)
    }

    // If you only need the value, skip the index with underscore (_)
    for _, value := range nums {
        fmt.Println("Value: ", value)
    }
}

```

### Conditionals

```go
if age < 18 {
    fmt.Println("You are less than 18")
} else if age >=18 && age <65 {
    fmt.Println("You are an adult")
} else {
    fmt.Println("You are a senior")
}
```

### Switch and Cases

- The switch statement is a more concise way to write a series of `if-else`.
- `break` statements are not needed as switch cases do not fall through by default.

```go
switch day := "Wednesday"; day {
case "Saturday", "Sunday":
    fmt.Println("It's the weekend")
case "Wednesday":
    fmt.Println("It's hump day.")
default:
    fmt.Println("It's a weekday")
}
```

```go
// Switch with no expression
var num int = 7 // interpret with num := 7
switch {
case num < 0:
    fmt.Println("Negative")
case num%2 == 0:
    fmt.Println("Even")
default:
    fmt.Println("Odd")
}
```

```go
// Using fallthrough to make sure you move to the next condition
finger :=2
switch finger {
case 1:
    fmt.Println("Thumb")
    fallthrough // Continues to next case
case 2:
    fmt.Println("Index")
    fallthrough
default:
    fmt.Println("Middle")
}
```

## Data Types

- **Boolean**: `bool` (`true` or `false`).
- **Numeric**:
    - **Integers**: `int` and `uint` are platform-dependant.
        - `Signed`: Can store positive or negative values (`int`, `int8`, `int16`, `int32`, `int64`) 
        - `Unsigned`: Can store 0 or positive(`uint`, `uint8`, `uint16`, `uint32`, `uint64`, `uintptr`)
    - **Floating-point**: `float32`, `float64`
    - **Complex Numbers**: `complex64`, `complex128`
    - **Aliases**: `byte` (alias for uint8), rune (alias for int32)
- **String**: string, immutable sequence of bytes

```go
var isActive bool = true
var integerVal int = 42
var floatVal float64 = 3.14159
var myByte byte = 'A' // ASCII A
var myRune rune = '🤔' // Unicode emoji
var message string = "Good news, everyone!"
var k uintptr = 0x12345 // Pointer address integer

fmt.Printf("Type: %T, Value: %v\n", isActive, isActive)
fmt.Printf("Type: %T, Value: %v\n", integerVal, integerVal)
fmt.Printf("Type: %T, Value: %v\n", floatVal, floatVal)
fmt.Printf("Type: %T, Value: %v\n", myByte, myByte)
fmt.Printf("Type: %T, Value: %v\n", myRune, myRune)
fmt.Printf("Type: %T, Value: %v\n", message, message)
```

## Pointers

- Go provides **pointers**, which hold the memory address of a value. Enabling you to refer to the same data without copying it.

```go
var x int = 10
p := &x // p is a pointer to an int, store's x's memory address
fmt.Println("Value of x:", x)   // Output: 10
fmt.Println("Address of x:", p) // Output: memory address (e.g. 0xc0000140c8)
fmt.Println("Value at address p:", *p) // Dereference p to get the value: 10

*p = 20 // Change  value at address p points to
fmt.Println("New value of x:", x) // Output: 20 (x has also changed)
```

## Structs

- **Structs** are a way to create custom data types by grouping fields (variables) together. Used to represent *records*.

```go
// Define a struct type named Person
type Person struct {
    Name string
    Age int
    City string
}

p1 := Person{Name: "Arthur", Age: 37, City: "Jacksonville"}
```

## Arrays and Slices

- **Arrays** are *fixed-size* sequence of elements of the same type. Size is a part of the type.

```go
var a [5]int // Declare array 'a' of 5 ints, all zeros
a[2] = 10 // assign value to an index (2)
fmt.Println("Array a:", a) // Output: [0 0 10 0 0]

//Declare and initialize array at once
primes := [6]int{2, 3, 5, 7, 11, 13}
fmt.Println("Primes array:", primes) // [2 3 5 7 11 13]
```

- An array has a fixed size, whereas a *slice* can grow or shrink.

```go
// Creating a slice from an array
var primesArray = [6]int{2, 3, 5, 7, 11, 13}
slice := primesArray[1:4] // From index 1 (inclusive) to 4 (exclusive)
fmt.Println("Slice slice:", slice) // [3, 5, 7]

// Slice literal
cities := []string{"Ny", "Fl", "Tx"}
fmt.Print("Cities slice:", cities) // Cities slice: [Ny Fl Tx]

cities // type: []string
len(cities) == 3
cap(cities) == 3

// Using make to create a slice (type, length, capacity)
numbers := make([]int, 5, 10) // length 5, capacity 10
fmt.Println("Numbers slice (initial):", numbers) // Output: [0 0 0 0 0]
// Can hold up to 10 ints

// Appending to a slice (can exceed initial length but not capacity)
numbers = append(numbers, 100, 200)
fmt.Println("Numbers slice (after append):", numbers) // Output: [0 0 0 0 0 100 200]

// Slices are reference types: modifying a slice also modifies its underlying array (and other slices pointing to it)
slice[0] = 99
fmt.Println("Modified slice slice:", slice) // Output: [99 5 7]
fmt.Println("Original array after slice modification:", primesArray) // Output: [2 99 5 7 11 13]
```

## Maps

- **Maps** are also known as hash maps or dictionaries. Unordered collections of key/value pairs.

```go
// Declare and initialize a map where key is string and value is int.
salaries := map[string]int{
    "Alice": 50000,
    "Bob":   60000,
}
fmt.Println("Salaries map:", salaries) // Output: map[Alice:50000 Bob:60000]

// Add a new key-value pair
salaries["Charlie"] = 75000
fmt.Println("Salaries after adding Charlie:", salaries)

// Access a value
fmt.Println("Bob's salary:", salaries["Bob"]) // Output: Bob's salary: 60000

// Check if a key exists
val, ok := salaries["David"] // 'ok' will be false if "David" doesn't exist
fmt.Println("David's salary (if exists):", val, ok)

// Delete a key-value pair by key Alice
delete(salaries, "Alice")
fmt.Println("Salaries after deleting Alice:", salaries) // Output: map[Bob:60000 Charlie:75000]

// Create an empty map using make
employees := make(map[string]string)
employees["CEO"] = "Jane Doe"
fmt.Println("Employees map:", employees)
```

## Error Handling

- Go handles errors explicitly through `error` interface. Functions that might fail return a result and an `error`. `nil` error indicates success.

```go
func safeDivide(a, b float64) (float64, error) {
    if b == 0 {
        // Return a custom error
        return 0, fmt.Errorf("cannot divide by zero")
    }
    return a / b, nil
}

func main() {
    result, err := safeDivide(10, 2)
    if err != nil {
        fmt.Println("Error:", err)
    } else {
        fmt.Println("Result:", result) // Output: Result: 5
    }

    result, err = safeDivide(10, 0)
    if err != nil {
        fmt.Println("Error:", err) // Output: Error: cannot divide by zero
    }
}
```

### Concurrency

- Go's built in **concurrency** model is based on `goroutines` (lightweight threads managed by Go runtime).

```go
// A function that will run as a goroutine
func sayHello(s string) {
    for i := 0; i < 3; i++ {
        fmt.Println(s)
    }
}

func main() {
    // Run sayHello as a goroutine (concurrently)
    go sayHello("Hello from goroutine!")

    // This will run concurrently with the goroutine
    sayHello("Hello from main!")

    // Give some time for the goroutine to finish (in a real app, use sync.WaitGroup)
    // Output order may vary due to concurrency
    var input string
    fmt.Scanln(&input) // Waits for user input, allowing goroutines to run
    fmt.Println("Done with main.")
}
```

## Channels and Interfaces

- **Channels** are special types used for communication between goroutines. They act like pipes that connect conccurent parts of the program.

```go
// Declare channel variable ch1, nil by default.
var ch1 chan int              // nil channel
// Unbuffered channels required sender/receiver to be ready at same time
ch2 := make(chan int)         // Unbuffered channel, provides synchronization
// Capacity of 5 can hold up to 5 values before send operatons block
ch3 := make(chan int, 5)      // Buffered channel with capacity 5
```

```go
func main() {
    ch := make(chan int, 2)  // Buffered channel with capacity 2

    ch <- 1  // Send 1 into channel (non-blocking since buffer has room)
    ch <- 2  // Send 2 into channel (non-blocking)
    // ch <- 3  // Would block here because buffer is full

    fmt.Println(<-ch) // Receive 1
    fmt.Println(<-ch) // Receive 2
}

// nil channel behavior
var ch chan int // nil
// ch <- 1       // Sending would block forever
// fmt.Println(<-ch) // Receiving would block forever
```

- **Interfaces** define method sets that types can implement. They specify *behavior* rather than concrete data.

```go
// Decalres interface Writer with one method
// Write takes slice of bytes
// returns number and an error
type Writer interface {
    Write([]byte) (int, error)
}

// By default, w is nil, holding no value and no concrete type implementing Writer
var w Writer                  // nil interface
```

```go
type MyWriter struct {}

func (mw MyWriter) Write(p []byte) (int, error) {
    fmt.Println("Writing:", string(p))
    return len(p), nil
}

func main() {
    var w Writer      // nil interface initially

    w = MyWriter{}    // Assign MyWriter instance to interface
    n, err := w.Write([]byte("hello"))
    fmt.Printf("Wrote %d bytes, err: %v\n", n, err)
}
```

- An interface variable can hold any value that implements its method.

### Modules and Dependency Management

```bash
# Initialize a module
go mod init mymodule
# Add dependency
go get github.com/pkg/errors
# Update dependency
go mod tidy
```

### Profiling and Optimization

- Go provides **built-in profiling** for testing and optimization.

```bash
go test -bench . -benchman
go tool pprof cpu.prof
```

## Concepts

### Pub/Sub

- Publish-Subscribe is a message pattern where:
    - Publishers send messages (events) to a broker without knowing who will receive them.
    - Subscribers registers interest in specific events and get notified without knowing who sent.

- Publishers and Subscribers do not message each other, instead they use **Channels**.
    - `Channels` deliver messages between goroutines.
    - **Maps of subscriber channels** keep track of who is listening.
    - `sync.Mutex` / `sync.RWMutex` safely manage concurrent access to subscribers.
    - `context.Context` to handle cancellations and timeouts for subscriptions.

```text
Time →
1. Create a Broker that holds subscriber channels.
2. A subscriber calls Subscribe() and gets a channel.
3. A publisher calls Publish() to send messages to all subscribers.
4. Subscribers receive messages through their channels.
5. On shutdown, all subscriber channels are closed.
```
