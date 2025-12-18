package main

import (
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"
)

var (
	ErrInvalidEmail    = errors.New("invalid email format")
	ErrInvalidUsername = errors.New("username must be 3-20 alphanumeric characters")
	ErrUserUnderage    = errors.New("user must be at least 13 years old")
	ErrEmptyField      = errors.New("field cannot be empty")
)

// User represents a user in the system
type User struct {
	ID        string    `json:"id"`
	Username  string    `json:"username"`
	Email     string    `json:"email"`
	BirthDate time.Time `json:"birth_date"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// UserRequest represents user data for creation/update
type UserRequest struct {
	Username  string    `json:"username"`
	Email     string    `json:"email"`
	BirthDate time.Time `json:"birth_date"`
}

// UserService provides user-related operations
type UserService struct {
	// This could include database connections, cache, etc.
}

// NewUserService creates a new UserService instance
func NewUserService() *UserService {
	return &UserService{}
}

// ValidateUser validates user input data
func (s *UserService) ValidateUser(req UserRequest) error {
	if strings.TrimSpace(req.Username) == "" {
		return ErrEmptyField
	}

	if strings.TrimSpace(req.Email) == "" {
		return ErrEmptyField
	}

	if req.BirthDate.IsZero() {
		return errors.New("birth date is required")
	}

	// Validate username format (alphanumeric, 3-20 chars)
	usernameRegex := regexp.MustCompile(`^[a-zA-Z0-9]{3,20}$`)
	if !usernameRegex.MatchString(req.Username) {
		return ErrInvalidUsername
	}

	// Validate email format
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	if !emailRegex.MatchString(req.Email) {
		return ErrInvalidEmail
	}

	// Validate age (at least 13 years old)
	age := time.Since(req.BirthDate).Hours() / 24 / 365
	if age < 13 {
		return ErrUserUnderage
	}

	return nil
}

// CreateUser creates a new user after validation
func (s *UserService) CreateUser(req UserRequest) (*User, error) {
	if err := s.ValidateUser(req); err != nil {
		return nil, fmt.Errorf("validation failed: %w", err)
	}

	// In a real application, this would interact with a database
	user := &User{
		ID:        generateID(),
		Username:  strings.TrimSpace(req.Username),
		Email:     strings.ToLower(strings.TrimSpace(req.Email)),
		BirthDate: req.BirthDate,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}

	// Simulate database save operation
	// In real code: err := s.db.Save(user).Error

	return user, nil
}

// GetUserAge calculates and returns the user's age in years
func (s *UserService) GetUserAge(birthDate time.Time) int {
	now := time.Now().UTC()
	years := now.Year() - birthDate.Year()

	// Adjust if birthday hasn't occurred yet this year
	if now.YearDay() < birthDate.YearDay() {
		years--
	}

	return years
}

// generateID generates a simple ID for demonstration
// In production, you might use UUID or database auto-increment
func generateID() string {
	return fmt.Sprintf("user_%d", time.Now().UnixNano())
}
