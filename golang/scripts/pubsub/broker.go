// Declares this file is part of the main package, contains entrypoint for the app
package main
// Import standard library packages
// context - managing request lifecycles/cancellation
// fmt - formatted I/O printing
// sync - synching primitives like mutexes and wait groups

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// Event is a generic type, a simple wrapper for messages.
// It can be extended to include metadata like timestamps, IDs, etc.
type Event[T any] struct { // [T any] is a placeholder for any type
	Data T // this struct has a single field, data, of any type
}

// Broker, another generic type, implements a Publish/Subscribe pattern.
// tracks all subscriber channels that want to receive events
type Broker[T any] struct {
	subs map[chan Event[T]]struct{} // Set of subscriber channels, chan Event[T] is the key, struct{} is the value
	mu   sync.RWMutex               // Guards concurrent access to subs, protects it from race conditions
	// RWMutex allows multiple concurrent readers OR one writer, but not both.

	done chan struct{} // Closed when broker is shutting down, struct{} used because we care only about the channel
}

// NewBroker creates a new broker with no subscribers.
// *Broker[T] pointer to Broker of type T created above
func NewBroker[T any]() *Broker[T] {
	return &Broker[T]{ // create new broker instance and return its memory address
		subs: make(map[chan Event[T]]struct{}), // initialize empty map
		done: make(chan struct{}), // creates unbuffered channel
	}
}

// Subscribe adds a new subscriber and returns a read-only channel for receiving events.
// The subscription ends automatically when the context is cancelled or broker shuts down.
func (b *Broker[T]) Subscribe(ctx context.Context) <-chan Event[T] {
	// (b *Broker[T]) is the method receiver, this method belongs to Broker[T]
	// ctx context.Context - takes a context for cancellation/timeout control
	// <-chan Event[T] - returns a receive-only channel
	// Below is channel creation and registration
	ch := make(chan Event[T], 64) // Buffered to avoid blocking publisher

	b.mu.Lock()
	b.subs[ch] = struct{}{} // Add subscriber to the set
	b.mu.Unlock()

	// use a goroutine for concurrent cleanup
	go func() {
		// Wait until the context is done OR broker shuts down
		select {
		case <-ctx.Done():
		case <-b.done:
		}

		// Cleanup logic: Remove subscriber and close channel
		b.mu.Lock()
		delete(b.subs, ch)
		close(ch)
		b.mu.Unlock()
	}()

	return ch
}

// Publish sends an event to all current subscribers.
// Non-blocking: if a subscriber's channel is full, the event is dropped.
func (b *Broker[T]) Publish(evt Event[T]) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	for ch := range b.subs {
		select {
		case ch <- evt: // Send event if channel has space
		default:
			// Drop event for this subscriber to avoid blocking
		}
	}
}

// Shutdown closes the broker and all subscriber channels.
func (b *Broker[T]) Shutdown() {
	// Only close once
	select {
	case <-b.done:
		return
	default:
		close(b.done)
	}

	// Remove and close all subscriber channels
	b.mu.Lock() // Lock() because we are writing, otherwise RLock()
	for ch := range b.subs {
		delete(b.subs, ch)
		close(ch)
	}
	b.mu.Unlock()
}

// Example usage of the generic pub/sub broker
func main() {
	broker := NewBroker[string]() // Broker for string events

	// Subscriber 1
	ctx1, cancel1 := context.WithCancel(context.Background())
	sub1 := broker.Subscribe(ctx1)

	// Subscriber 2
	ctx2, cancel2 := context.WithCancel(context.Background())
	sub2 := broker.Subscribe(ctx2)

	// Publish messages
	broker.Publish(Event[string]{Data: "Hello, Subscribers!"})
	broker.Publish(Event[string]{Data: "Go is awesome"})

	// Read messages (in a real program, you'd use goroutines)
	go func() {
		for msg := range sub1 {
			fmt.Println("Sub1 received:", msg.Data)
		}
	}()

	go func() {
		for msg := range sub2 {
			fmt.Println("Sub2 received:", msg.Data)
		}
	}()

	time.Sleep(1 * time.Second) // Allow some time for messages to be processed

	// Clean up
	cancel1()
	cancel2()
	broker.Shutdown()
}
