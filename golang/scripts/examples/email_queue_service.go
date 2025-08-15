package main

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"
)

// EmailMessage custom struct represents email message to be sent
type EmailMessage struct {
	ID        string    `json:"id"`
	To        string    `json:"to"`
	Body      string    `json:"body"`
	Subject   string    `json:"subject"`
	Priority  int       `json:"priority"`
	Timestamp time.Time `json:"timestamp"`
	Retries   int       `json:"retries"`
}

// Represents results of sending email
type EmailResult struct {
	MessageID string
	Success   bool
	Error     error
	Duration  time.Duration
}

// Handles async email sending with priority queueing
type EmailQueueService struct {
	highPriorityQueue   chan EmailMessage
	normalPriorityQueue chan EmailMessage
	lowPriorityQueue    chan EmailMessage
	resultChan          chan EmailResult
	workers             int
	ctx                 context.Context
	cancel              context.CancelFunc
	wg                  sync.WaitGroup // Used to sync goroutines, wait for them to complete before continue
	stats               struct {
		mu             sync.RWMutex // Read-Write Mutex, locks better for more reads
		totalSent      int64
		totalFailed    int64
		totalDuration  time.Duration
		totalProcessed int64
		avgProcessTime time.Duration
	}
}

// Create a new EmailQueueService email queue service
func NewEmailQueueService(workers int) *EmailQueueService {
	ctx, cancel := context.WithCancel(context.Background()) // returns non-nil empty context

	return &EmailQueueService{
		highPriorityQueue:   make(chan EmailMessage, 100),  // Create Smaller buffer for urgent emails
		normalPriorityQueue: make(chan EmailMessage, 500),  // Create Medium buffer
		lowPriorityQueue:    make(chan EmailMessage, 1000), // Create Large buffer for bulk emails
		resultChan:          make(chan EmailResult, 100),   // Create Result channel for email results
		workers:             workers,
		ctx:                 ctx,
		cancel:              cancel,
	}
}

/*
Start function implements EmailQueueService type
begins processing with specified number of workers
*/
func (e *EmailQueueService) Start() {
	// Start worker go routines
	for i := 0; i < e.workers; i++ {
		e.wg.Add(1) // Add delta to waitgroup counter
		go e.worker(i)
	}

	// Start result processor
	e.wg.Add(1)
	go e.resultProcessor()

	log.Printf("Email queue service started with %d workers", e.workers)
}

// Stop gracefully shuts down the service
func (e *EmailQueueService) Stop() {
	log.Println("Stopping the email queue service...")
	e.cancel()

	// Wait for all workers to finish with the wg
	e.wg.Wait()

	// Close all channels to signal workers to stop
	close(e.highPriorityQueue)
	close(e.normalPriorityQueue)
	close(e.lowPriorityQueue)

	close(e.resultChan)

	log.Println("Email queue service stopped!")
}

// Add an email to appropriate priority queue
func (e *EmailQueueService) QueueEmail(email EmailMessage) error {
	email.Timestamp = time.Now()

	select { // Switch, but for channels
	case <-e.ctx.Done(): // Checking if channel is closed
		return fmt.Errorf("service is shutting down")
	default:
	}

	//route to appropriate queue based on priority, checks priority 1,2,3
	switch email.Priority {
	case 1: // High Priority
		select {
		case e.highPriorityQueue <- email: // if queue has space, this succeeds immediately
			return nil
		case <-time.After(5 * time.Second): // if 5 seconds pass after queue is full, this case is triggered
			return fmt.Errorf("high priority queue is full")
		}
	case 2: // normal priority
		select {
		case e.normalPriorityQueue <- email:
			return nil
		case <-time.After(10 * time.Second):
			return fmt.Errorf("normal priority queue is full")
		}
	case 3: // Low priority
		select {
		case e.lowPriorityQueue <- email:
			return nil
		case <-time.After(30 * time.Second):
			return fmt.Errorf("low priority queue is full")
		}
	default:
		return fmt.Errorf("invalid priority %d", email.Priority)
	}
}

// worker processes emails with priority ordering
func (e *EmailQueueService) worker(workerID int) {
	defer e.wg.Done() // this will happen before the function worker will return.

	log.Printf("Worker %d started", workerID)

	for {
		select {
		case <-e.ctx.Done():
			log.Printf("Worker %d stopping due to context cancellation", workerID)
			return

		// Check high priority first
		case email, ok := <-e.highPriorityQueue: // queue will provide an email and ok (true or false)
			if !ok {
				log.Printf("Worker %d: high priority queue closed", workerID)
				return
			}
			e.processEmail(workerID, email)

		// Check normal priority next
		case email, ok := <-e.normalPriorityQueue:
			if !ok {
				log.Printf("Worker %d: normal priority queue closed", workerID)
				return
			}
			e.processEmail(workerID, email)

		// Check low priority lastly
		case email, ok := <-e.lowPriorityQueue:
			if !ok {
				log.Printf("Worker %d: low priority queue closed", workerID)
				return
			}
			e.processEmail(workerID, email)

		/*
			prevent busy waiting if all queues are empty, acts as a timeout
			returns a channel that will send a single value after 100 milliseconds
		*/
		case <-time.After(100 * time.Millisecond):
			continue
		}
	}
}

// simulate sending an email and handling retries
func (e *EmailQueueService) processEmail(workerID int, email EmailMessage) {
	start := time.Now()

	log.Printf("Worker %d processing email ID: %s, To: %s, Priority: %d",
		workerID, email.ID, email.To, email.Priority)

	// simulate sending the email
	success := e.simulateEmailSending(email)
	duration := time.Since(start) // since initial start from beginning of function

	result := EmailResult{
		MessageID: email.ID,
		Success:   success,
		Duration:  duration,
	}

	if !success {
		result.Error = fmt.Errorf("Failed to send email to %s", email.To)

		// Retry logic for failed emails
		if email.Retries < 3 {
			email.Retries++
			log.Printf("Retrying email ID: %s (attempt %d)", email.ID, email.Retries+1)

			// Requeue + exponential backoff
			go func() {
				backoff := time.Duration(email.Retries*email.Retries) * time.Second
				time.Sleep(backoff)

				// Lower the priority for retries to avoide blocking new messages
				if email.Priority < 3 {
					email.Priority++
				}

				e.QueueEmail(email)
			}() // This means we define and immediately call the anonymous function
		}
	}

	/*
		Send result to result processor
		<- is the channel operator
	*/
	select {
	case e.resultChan <- result: // this is the send operation
	case <-time.After(1 * time.Second):
		log.Printf("Failed to send result for email ID: %s", email.ID)
	}
}

// simulate email sending process with another func of type EmailQueueService
func (e *EmailQueueService) simulateEmailSending(email EmailMessage) bool {
	// basing on priority
	var processingTime time.Duration // define a var processingTime
	// based on email.Priority 1,2 or 3
	switch email.Priority {
	case 1:
		processingTime = 50 * time.Millisecond // Fast processing for urgent emails
	case 2:
		processingTime = 100 * time.Millisecond // Normal processing
	case 3:
		processingTime = 200 * time.Millisecond // Slower for builk emails
	}

	time.Sleep(processingTime)

	/*
		Simulate 90% success rate
		time.Now().UnixNano gets current time to the nanosecond
		%10 is the modulo
		so it gives a random int from 0 to 9
		false only if 0
	*/
	return time.Now().UnixNano()%10 != 0
}

// resultProcessor handles email sending results
func (e *EmailQueueService) resultProcessor() {
	defer e.wg.Done()

	for result := range e.resultChan { // Check each item (result) in resultChan
		e.stats.mu.Lock() // Lock for writing
		if result.Success {
			e.stats.totalSent++
			log.Printf("Email Sent successfully: %s (took %v)",
				result.MessageID, result.Duration)
		} else {
			e.stats.totalFailed++
			log.Printf("Email failed: %s - %v (took %v)",
				result.MessageID, result.Error, result.Duration)
		}

		e.stats.totalDuration += result.Duration
		e.stats.totalProcessed++
		if e.stats.totalProcessed > 0 {
			e.stats.avgProcessTime = e.stats.totalDuration / time.Duration(e.stats.totalProcessed)
		}
		e.stats.mu.Unlock() // unlock the stats
	}
}

// GetStats returns the current service statistics
func (e *EmailQueueService) GetStats() (int64, int64, time.Duration) {
	e.stats.mu.RLock() // Locks for reading, getting the stats
	defer e.stats.mu.RUnlock()
	return e.stats.totalSent, e.stats.totalFailed, e.stats.avgProcessTime
}

// function to return current queue lengths for monitoring
func (e *EmailQueueService) GetQueueLengths() (int, int, int) {
	return len(e.highPriorityQueue), len(e.normalPriorityQueue), len(e.lowPriorityQueue)
}

// demo
func main() {
	// create an email service with (3) workers
	emailService := NewEmailQueueService(3)
	emailService.Start() // Implement the emailService type by starting the workers

	// Real emails would come from a different service
	emails := []EmailMessage{
		{ID: "urgent-1", To: "admin@company.com", Subject: "System Alert", Body: "Server down!", Priority: 1},
		{ID: "normal-1", To: "user1@company.com", Subject: "Welcome", Body: "Welcome to our service", Priority: 2},
		{ID: "bulk-1", To: "user2@company.com", Subject: "Newsletter", Body: "Monthly newsletter", Priority: 3},
		{ID: "urgent-2", To: "admin@company.com", Subject: "Critical Issue", Body: "Database error", Priority: 1},
		{ID: "normal-2", To: "user3@company.com", Subject: "Password Reset", Body: "Reset your password", Priority: 2},
		{ID: "bulk-2", To: "user4@company.com", Subject: "Promotion", Body: "Special offer", Priority: 3},
	}

	// Queue the emails
	for _, email := range emails { // _, ignores the email's index which we don't care about
		if err := emailService.QueueEmail(email); err != nil {
			log.Printf("Failed to queue email %s: %v", email.ID, err)
		}
	}

	// let it run for 5 seconds
	time.Sleep(5 * time.Second)

	//print stats
	sent, failed, avgTime := emailService.GetStats()
	highQ, normalQ, lowQ := emailService.GetQueueLengths()

	fmt.Printf("\n📊 Email Service Statistics:\n")
	fmt.Printf("   Emails sent: %d\n", sent)
	fmt.Printf("   Emails failed: %d\n", failed)
	fmt.Printf("   Average processing time: %v\n", avgTime)
	fmt.Printf("   Queue lengths - High: %d, Normal: %d, Low: %d\n", highQ, normalQ, lowQ)

	emailService.Stop()

}
