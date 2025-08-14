package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// GraphQLRequest defines the JSON structure sent in a GraphQL POST request
type GraphQLRequest struct {
	Query     string                 `json:"query"`              // GraphQL query string
	Variables map[string]interface{} `json:"variables,omitempty"` // Optional variables for the query
}

// GraphQLResponse is a generic map to unmarshal GraphQL responses
type GraphQLResponse map[string]interface{}

func main() {
	// URL of the GraphQL API endpoint
	url := "http://localhost:4000/graphql" // Localhost skips https

	// GraphQL query with a variable placeholder ($id)
	query := `
		query ($id: ID!) {
			user(id: $id) {
				id
				name
			}
		}
	`

	// Variables to pass into the query
	variables := map[string]interface{}{
		"id": "123",
	}

	// Build the request body struct
	reqBody := GraphQLRequest{
		Query:     query,
		Variables: variables,
	}

	// Convert struct to JSON
	payload, err := json.Marshal(reqBody)
	if err != nil {
		panic(fmt.Errorf("failed to marshal request: %w", err))
	}

	// Create a new HTTP POST request
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(payload))
	if err != nil {
		panic(fmt.Errorf("failed to create HTTP request: %w", err))
	}

	// Set the content type to JSON for GraphQL
	req.Header.Set("Content-Type", "application/json")

	// Create an HTTP client with a timeout
	client := &http.Client{
		Timeout: 10 * time.Second, // Prevent hanging connections
	}

	// Send the HTTP request
	resp, err := client.Do(req)
	if err != nil {
		panic(fmt.Errorf("HTTP request failed: %w", err))
	}
	defer resp.Body.Close()

	// Read the HTTP response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		panic(fmt.Errorf("failed to read response body: %w", err))
	}

	// Parse the JSON response into a map
	var result GraphQLResponse
	if err := json.Unmarshal(body, &result); err != nil {
		panic(fmt.Errorf("failed to unmarshal response: %w", err))
	}

	// Print the parsed result
	fmt.Printf("%+v\n", result)
}
