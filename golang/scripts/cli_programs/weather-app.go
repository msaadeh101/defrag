package main

/* 
encoding/json - decoding JSON from API
ioutil - reads data from streams/files
net/url - build query params safely
os - access os level features
*/

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
)

// WeatherData represents the expected structure of the weather API response
// `json:"field"`` is a struct tag, telling JSON how to map JSON keys to Go fields.
type WeatherData struct {
	Main struct {
		Temp      float64 `json:"temp"`
		FeelsLike float64 `json:"feels_like"` // JSON key "feels_like" -> Go field "FeelsLike"
		TempMin   float64 `json:"temp_min"`
		TempMax   float64 `json:"temp_max"`
		Pressure  int     `json:"pressure"`
		Humidity  int     `json:"humidity"`
	} `json:"main"`
	Weather []struct {
		Main        string `json:"main"`
		Description string `json:"description"`
		Icon        string `json:"icon"`
	} `json:"weather"`
	Wind struct {
		Speed float64 `json:"speed"`
		Deg   int     `json:"deg"`
	} `json:"wind"`
	Name string `json:"name"`
}

// Declare multiple compile time constants
const (
	apiKey      = "YOUR_API_KEY"
	apiEndpoint = "https://api.openweathermap.org/data/2.5/weather"
)

func main() {
	// Parse command line flags, define flag "--location"
	location := flag.String("location", "", "City name to check weather for")
	flag.Parse()

	if *location == "" {
		fmt.Println("Please provide a location using --location flag")
		flag.Usage()
		os.Exit(1)
	}

	// Build the API URL
	query := url.Values{}
	query.Add("q", *location)
	query.Add("appid", apiKey)
	query.Add("units", "metric") // Use "imperial" for Fahrenheit

	url := fmt.Sprintf("%s?%s", apiEndpoint, query.Encode())

	// Make the HTTP request
	resp, err := http.Get(url)
	if err != nil {
		fmt.Printf("Error making request: %v\n", err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	// Read and parse the response
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		fmt.Printf("Error reading response: %v\n", err)
		os.Exit(1)
	}

	if resp.StatusCode != http.StatusOK {
		fmt.Printf("API Error: %s\n", body)
		os.Exit(1)
	}

	var data WeatherData
	err = json.Unmarshal(body, &data)
	if err != nil {
		fmt.Printf("Error parsing response: %v\n", err)
		os.Exit(1)
	}

	// Display the weather information
	fmt.Printf("\nWeather in %s:\n", data.Name)
	fmt.Printf("----------------------------\n")
	fmt.Printf("Temperature: %.1f°C (Feels like %.1f°C)\n", data.Main.Temp, data.Main.FeelsLike)
	fmt.Printf("Conditions: %s (%s)\n", data.Weather[0].Main, data.Weather[0].Description)
	fmt.Printf("Humidity: %d%%\n", data.Main.Humidity)
	fmt.Printf("Wind: %.1f m/s at %d°\n", data.Wind.Speed, data.Wind.Deg)
	fmt.Printf("Pressure: %d hPa\n", data.Main.Pressure)
	fmt.Printf("Min/Max Temp: %.1f°C/%.1f°C\n", data.Main.TempMin, data.Main.TempMax)
	fmt.Println()
}