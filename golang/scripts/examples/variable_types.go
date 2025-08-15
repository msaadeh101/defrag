package main

import (
	"fmt"
	"io"
	"strings"
)

type User struct {
	Name string
	Age  int
}

func GetUser() (User, error) {
	return User{Name: "Harry", Age: 30}, nil
}

func main() {
	// 1. Basic types
	var age int = 42
	var price float64 = 19.99
	var name string = "Harry"
	var active bool = true
	fmt.Println("Basic types:", age, price, name, active)

	// 2. Zero values
	var count int
	var ratio float64
	var title string
	var enabled bool
	fmt.Println("Zero values:", count, ratio, title, enabled)

	// 3. Type inference
	var city = "London"
	var temperature = 26.5
	var isOpen = false
	fmt.Println("Type inference:", city, temperature, isOpen)

	// 4. Constants
	const Pi = 3.14
	var radius = Pi
	fmt.Println("Constant assignment:", radius)

	// 5. Composite types
	var numbers []int = []int{1, 2, 3}
	var userMap map[string]string = map[string]string{"name": "Harry"}
	var point struct{ X, Y int } = struct{ X, Y int }{10, 20}
	var colors [3]string = [3]string{"red", "green", "blue"}
	fmt.Println("Composite types:", numbers, userMap, point, colors)

	// 6. Pointers
	var ptr *int
	var value int = 5
	ptr = &value
	fmt.Println("Pointer:", *ptr)

	// 7. Functions
	var greeter func(string) string
	greeter = func(name string) string {
		return "Hello, " + name
	}
	fmt.Println("Function variable:", greeter("Harry"))

	// 8. Interfaces
	var r io.Reader
	r = strings.NewReader("Hi!")
	buf := make([]byte, 3)
	n, _ := r.Read(buf)
	fmt.Println("Interface:", string(buf[:n]))

	// 9. Custom types
	var u User = User{Name: "Hermione", Age: 25}
	fmt.Println("Custom type:", u)

	// 10. Nil values
	var data []int
	var m map[string]int
	var ch chan int
	var f func()
	fmt.Println("Nil values:", data, m, ch, f)

	// 11. Multiple return values
	var user, err = GetUser()
	if err == nil {
		fmt.Println("Multiple returns:", user)
	}

	// 12. Blank identifier
	var _, err2 = GetUser()
	if err2 == nil {
		fmt.Println("Blank identifier: ignored first value")
	}
}
