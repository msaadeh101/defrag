package main

import (
	"math/rand"
	"net/http"

	"github.com/gin-gonic/gin"
)

// Response structures
type MessageResponse struct {
	Message string `json:"message"`
}

type SentenceResponse struct {
	Sentence string `json:"sentence"`
}

type CountResponse struct {
	TotalSentences int `json:"total_sentences"`
}

// List of random sentences
var sentences = []string{
	"The quick brown fox jumps over the lazy dog.",
	"Life is what happens when you're busy making other plans.",
	"The only way to do great work is to love what you do.",
	"In the middle of difficulty lies opportunity.",
	"The future belongs to those who believe in the beauty of their dreams.",
	"It is during our darkest moments that we must focus to see the light.",
	"Success is not final, failure is not fatal: it is the courage to continue that counts.",
	"The only impossible journey is the one you never begin.",
	"Happiness is not something ready made. It comes from your own actions.",
	"Be yourself; everyone else is already taken.",
	"Two things are infinite: the universe and human stupidity; and I'm not sure about the universe.",
	"A room without books is like a body without a soul.",
	"The journey of a thousand miles begins with one step.",
	"Yesterday is history, tomorrow is a mystery, today is a gift of God.",
	"A person who never made a mistake never tried anything new.",
}

// Initialize random seed, no init() needed

// Handler for root endpoint
func getRootMessage(c *gin.Context) {
	response := MessageResponse{
		Message: "Welcome to the Random Sentence API! Visit /random to get a random sentence.",
	}
	c.JSON(http.StatusOK, response)
}

// Handler for random sentence endpoint
func getRandomSentence(c *gin.Context) {
	randomIndex := rand.Intn(len(sentences))
	response := SentenceResponse{
		Sentence: sentences[randomIndex],
	}
	c.JSON(http.StatusOK, response)
}

// Handler for sentence count endpoint
func getSentenceCount(c *gin.Context) {
	response := CountResponse{
		TotalSentences: len(sentences),
	}
	c.JSON(http.StatusOK, response)
}

func main() {
	// Create Gin router with default middleware
	router := gin.Default()

	// Define routes
	router.GET("/", getRootMessage)
	router.GET("/random", getRandomSentence)
	router.GET("/random/count", getSentenceCount)

	// Start server on port 8000
	router.Run(":8000")
}
