package main

import (
	"math/rand"
	"net/http"
	"strconv"
	"sync"

	"github.com/gin-gonic/gin"
)

// Response structures
type MessageResponse struct {
	Message string `json:"message"`
}

type SentenceResponse struct {
	ID       int    `json:"id"`
	Sentence string `json:"sentence"`
}

type SentencesResponse struct {
	Sentences []SentenceResponse `json:"sentences"`
}

type CountResponse struct {
	TotalSentences int `json:"total_sentences"`
}

type CreateSentenceRequest struct {
	Sentence string `json:"sentence" binding:"required"`
}

type UpdateSentenceRequest struct {
	Sentence string `json:"sentence" binding:"required"`
}

// In-memory storage with mutex for thread safety
var (
	sentences = []string{
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
	mutex = sync.RWMutex{}
)

// Handler for root endpoint
// Context is the toolbox Gin gives that has everything about the request headers
func getRootMessage(c *gin.Context) {
	response := MessageResponse{
		Message: "Welcome to the Random Sentence CRUD API! Available endpoints: GET /, GET /sentences, GET /sentences/:id, GET /random, GET /count, POST /sentences, PUT /sentences/:id, DELETE /sentences/:id",
	}
	c.JSON(http.StatusOK, response)
}

// Handler for getting all sentences
func getAllSentences(c *gin.Context) {
	mutex.RLock()
	defer mutex.RUnlock() // Unlock the read lock in case of panic

	sentenceResponses := make([]SentenceResponse, len(sentences))
	for i, sentence := range sentences {
		sentenceResponses[i] = SentenceResponse{
			ID:       i,
			Sentence: sentence,
		}
	}

	response := SentencesResponse{
		Sentences: sentenceResponses,
	}
	c.JSON(http.StatusOK, response)
}

// Handler for getting a specific sentence by ID, passing the gin.Context as param
func getSentenceByID(c *gin.Context) {
	idParam := c.Param("id")         // From the requests URL, grab the part named 'id'
	id, err := strconv.Atoi(idParam) // Convert string to integer
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID format"})
		return
	}

	mutex.RLock()
	defer mutex.RUnlock()

	if id < 0 || id >= len(sentences) {
		c.JSON(http.StatusNotFound, gin.H{"error": "Sentence not found"})
		return
	}

	response := SentenceResponse{
		ID:       id,
		Sentence: sentences[id],
	}
	c.JSON(http.StatusOK, response)
}

// Handler for random sentence endpoint
func getRandomSentence(c *gin.Context) {
	mutex.RLock()
	defer mutex.RUnlock()

	if len(sentences) == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "No sentences available"})
		return
	}

	randomIndex := rand.Intn(len(sentences))
	response := SentenceResponse{
		ID:       randomIndex,
		Sentence: sentences[randomIndex],
	}
	c.JSON(http.StatusOK, response)
}

// Handler for sentence count endpoint
func getSentenceCount(c *gin.Context) {
	mutex.RLock()
	defer mutex.RUnlock()

	response := CountResponse{
		TotalSentences: len(sentences),
	}
	c.JSON(http.StatusOK, response)
}

// Handler for creating a new sentence
func createSentence(c *gin.Context) {
	var req CreateSentenceRequest                  // req of type CreateSentenceRequest
	if err := c.ShouldBindJSON(&req); err != nil { // Gin writes into the CreateSentenceRequest struct
		// could be req := &CreateSentenceRequest {} instead, but this is cleaner
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	mutex.Lock() // Lock the in-mem cache until we are finished
	defer mutex.Unlock()

	// Add the new sentence
	sentences = append(sentences, req.Sentence) // Add the sentence to sentences
	newID := len(sentences) - 1

	response := SentenceResponse{
		ID:       newID,
		Sentence: req.Sentence,
	}
	c.JSON(http.StatusCreated, response)
}

// Handler for updating a sentence
func updateSentence(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.Atoi(idParam)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID format"})
		return
	}

	var req UpdateSentenceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	mutex.Lock()
	defer mutex.Unlock()

	if id < 0 || id >= len(sentences) {
		c.JSON(http.StatusNotFound, gin.H{"error": "Sentence not found"})
		return
	}

	sentences[id] = req.Sentence

	response := SentenceResponse{
		ID:       id,
		Sentence: req.Sentence,
	}
	c.JSON(http.StatusOK, response)
}

// Handler for deleting a sentence
func deleteSentence(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.Atoi(idParam)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID format"})
		return
	}

	mutex.Lock()
	defer mutex.Unlock()

	if id < 0 || id >= len(sentences) {
		c.JSON(http.StatusNotFound, gin.H{"error": "Sentence not found"})
		return
	}

	// Remove the sentence at the specified index
	sentences = append(sentences[:id], sentences[id+1:]...)

	c.JSON(http.StatusOK, gin.H{
		"message": "Sentence deleted successfully",
		"id":      id,
	})
}

func main() {
	// Create Gin router with default middleware
	router := gin.Default()

	// Define routes
	router.GET("/", getRootMessage)
	router.GET("/sentences", getAllSentences)
	router.GET("/sentences/:id", getSentenceByID)
	router.GET("/random", getRandomSentence)
	router.GET("/count", getSentenceCount)
	router.POST("/sentences", createSentence)
	router.PUT("/sentences/:id", updateSentence)
	router.DELETE("/sentences/:id", deleteSentence)

	// Start server on port 8000
	router.Run(":8000")
}
