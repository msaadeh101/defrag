package main

import (
	"fmt"
	"time"
)

func main() {
	// 1. Basic unbuffered channel
	fmt.Println("== Unbuffered channel ==")
	ch1 := make(chan int)

	go func() {
		ch1 <- 42 // send value into channel
	}()

	val := <-ch1 // receive value
	fmt.Println("Received:", val)

	// 2. Buffered channel
	fmt.Println("\n== Buffered channel ==")
	ch2 := make(chan string, 2)
	ch2 <- "hello"
	ch2 <- "world"
	fmt.Println(<-ch2)
	fmt.Println(<-ch2)

	// 3. Closing a channel + ranging over it
	fmt.Println("\n== Closing a channel ==")
	ch3 := make(chan int)
	go func() {
		for i := 1; i <= 3; i++ {
			ch3 <- i
		}
		close(ch3) // signal no more values
	}()

	for v := range ch3 {
		fmt.Println("Got:", v)
	}

	// 4. Select statement (waiting on multiple channels)
	fmt.Println("\n== Select statement ==")
	ch4 := make(chan string)
	ch5 := make(chan string)

	go func() {
		time.Sleep(100 * time.Millisecond)
		ch4 <- "from ch4"
	}()
	go func() {
		time.Sleep(50 * time.Millisecond)
		ch5 <- "from ch5"
	}()

	select {
	case msg := <-ch4:
		fmt.Println("Received:", msg)
	case msg := <-ch5:
		fmt.Println("Received:", msg)
	}

	// 5. Worker pool example
	fmt.Println("\n== Worker pool ==")
	jobs := make(chan int, 5)
	results := make(chan int, 5)

	// 3 workers
	for w := 1; w <= 3; w++ {
		go func(id int, jobs <-chan int, results chan<- int) {
			for j := range jobs {
				fmt.Printf("Worker %d processing job %d\n", id, j)
				time.Sleep(time.Second)
				results <- j * 2
			}
		}(w, jobs, results)
	}

	// Send 5 jobs
	for j := 1; j <= 5; j++ {
		jobs <- j
	}
	close(jobs)

	// Collect results
	for a := 1; a <= 5; a++ {
		fmt.Println("Result:", <-results)
	}
}
