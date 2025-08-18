package main

import (
	"fmt"
	"io/ioutil"
	"os"
)

// FileHandler is our interface for basic file operations
type FileHandler interface {
	Read(path string) ([]byte, error)     // Read file contents
	Write(path string, data []byte) error // Write data to a file
	Delete(path string) error             // Delete a file
}

// LocalFileHandler implements FileHandler for local filesystem
type LocalFileHandler struct{}

// Read reads the entire file into memory
func (l LocalFileHandler) Read(path string) ([]byte, error) {
	return ioutil.ReadFile(path)
}

// Write writes data to a file (overwriting if it exists)
func (l LocalFileHandler) Write(path string, data []byte) error {
	return ioutil.WriteFile(path, data, 0644)
}

// Delete removes a file from the filesystem
func (l LocalFileHandler) Delete(path string) error {
	return os.Remove(path)
}

func main() {
	// Use our FileHandler interface
	var fh FileHandler
	fh = LocalFileHandler{}

	// Example: Write to file
	err := fh.Write("example.txt", []byte("Hello, Go Interfaces!"))
	if err != nil {
		fmt.Println("Write error:", err)
		return
	}

	// Example: Read file
	content, err := fh.Read("example.txt")
	if err != nil {
		fmt.Println("Read error:", err)
		return
	}
	fmt.Println("File content:", string(content))

	// Example: Delete file
	err = fh.Delete("example.txt")
	if err != nil {
		fmt.Println("Delete error:", err)
		return
	}
	fmt.Println("File deleted successfully")
}
