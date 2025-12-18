package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"time"
)

func main() {
	// Define command line flags
	filename := flag.String("file", "note.txt", "Output file name")
	flag.Parse()

	// Get the remaining arguments as the message
	args := flag.Args()
	if len(args) == 0 {
		fmt.Fprintf(os.Stderr, "Error: Please provide a message to write\n")
		fmt.Fprintf(os.Stderr, "Usage: %s -file <filename> <message>\n", os.Args[0])
		os.Exit(1)
	}

	// Join all arguments into a single message
	message := strings.Join(args, " ")

	// Create timestamp for the note
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	noteContent := fmt.Sprintf("[%s] %s\n", timestamp, message)

	// Write to file (append mode)
	file, err := os.OpenFile(*filename, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error opening file: %v\n", err)
		os.Exit(1)
	}
	defer file.Close()

	// Write the note
	if _, err := file.WriteString(noteContent); err != nil {
		fmt.Fprintf(os.Stderr, "Error writing to file: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Note written to %s\n", *filename)
}
