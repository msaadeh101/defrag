package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"sync"
)

const WeatherAPIKey = "API_KEY"
const WeatherAPIBaseURL = "http://api.weatherapi.com/v1/current.json"

// WeatherInfo struct holds the city, and temp (json tags for future serialization/deserialization)
type WeatherInfo struct {
	City        string  `json:"city"`
	Temperature float64 `json:"temperature"`
	Unit        string  `json:"unit"`
	Error       string  `json:"error,omitempty"` // Added for reporting any fetch-time errors
}

type WeatherAPIResponse struct {
	Location struct {
		Name string `json:"name"`
	} `json:"location"`
	Current struct {
		TempC float64 `json:"temp_c"`
	} `json:"current"`
}

// Sends result to provided channel and signals waitgroup when done
func fetchWeather(city string, weatherCh chan<- WeatherInfo, wg *sync.WaitGroup) {
	defer wg.Done() // make sure wg always closes in case of panic

	fmt.Printf("Fetching weather for %s...\n", city)

	requestURL := fmt.Sprintf("%s?key=%s&q=%s", WeatherAPIBaseURL, WeatherAPIKey, city)

	resp, err := http.Get(requestURL)
	if err != nil {
		weatherCh <- WeatherInfo{City: city, Error: fmt.Sprintf("HTTP request failed: %v", err)}
		return
	}
	defer resp.Body.Close() // Make sure response is closed

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body) // Read the body for error details
		weatherCh <- WeatherInfo{City: city, Error: fmt.Sprintf("API returned status %d: %s", resp.StatusCode, string(bodyBytes))}
		return
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		weatherCh <- WeatherInfo{City: city, Error: fmt.Sprintf("Failed to read response body: %v", err)}
		return
	}

	// Unmarshal the JSON response
	var apiResponse WeatherAPIResponse
	err = json.Unmarshal(body, &apiResponse)
	if err != nil {
		weatherCh <- WeatherInfo{City: city, Error: fmt.Sprintf("Failed to parse JSON response: %v", err)}
		return
	}

	// Create the weather info based on the struct
	weatherInfo := WeatherInfo{
		City:        apiResponse.Location.Name,
		Temperature: apiResponse.Current.TempC,
		Unit:        "°C",
	}
	weatherCh <- weatherInfo // Finally, send the weather info to the channel

}

func main() {
	// Calls the fetchWeather func with goroutines

	cities := []string{"New York", "London", "Tokyo", "Tampa"}

	var wg sync.WaitGroup
	weatherCh := make(chan WeatherInfo, len(cities)) // Create a buffered channel for the weather results

	fmt.Println("starting weather for selected cities...\n")

	for _, city := range cities {
		wg.Add(1) // Increment the WaitGroup counter
		go fetchWeather(city, weatherCh, &wg)
	}

	// Launch a goroutine to close the channel once all weather fetching is done
	// Use separate goroutine to avoid blocking main
	go func() {
		wg.Wait()        // Wait for all goroutines to complete
		close(weatherCh) // Close channel when all data has been sent
	}() // Call the go func

	fmt.Println("\n Weather Reports:   ")
	for weather := range weatherCh {
		if weather.Error != "" {
			fmt.Printf("Error fetching weather for %s: %s\n", weather.City, weather.Error)
		} else {
			fmt.Printf("Weather in %s: %.2f%s\n", weather.City, weather.Temperature, weather.Unit)
		}
	}

	fmt.Println("\nAll weather reports processed")
}
