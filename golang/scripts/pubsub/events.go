package main

import "context"

// Event is a simple wrapper for messages.
// It can be extended to include metadata like timestamps, IDs, etc.
type Event[T any] struct {
	Data T
}

// Subscriber interface for receiving events
type Subscriber[T any] interface {
	Subscribe(context.Context) <-chan Event[T]
}

// Publisher interface for sending events  
type Publisher[T any] interface {
	Publish(Event[T])
}

// PubSub combines both Publisher and Subscriber interfaces
type PubSub[T any] interface {
	Publisher[T]
	Subscriber[T]
}