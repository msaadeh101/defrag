package main

import (
	"fmt"
	"log"
	"time"
)

func main() {
	userService := NewUserService()

	// Example: Create a valid user
	userReq := UserRequest{
		Username:  "johndoe",
		Email:     "john.doe@example.com",
		BirthDate: time.Date(1985, 3, 15, 0, 0, 0, 0, time.UTC),
	}

	createdUser, err := userService.CreateUser(userReq)
	if err != nil {
		log.Fatalf("Failed to create user: %v", err)
	}

	fmt.Printf("User created successfully:\n")
	fmt.Printf("ID: %s\n", createdUser.ID)
	fmt.Printf("Username: %s\n", createdUser.Username)
	fmt.Printf("Email: %s\n", createdUser.Email)
	fmt.Printf("Age: %d years old\n", userService.GetUserAge(createdUser.BirthDate))

	// Example: Try to create an invalid user
	invalidReq := UserRequest{
		Username:  "ab", // Too short
		Email:     "invalid-email",
		BirthDate: time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC), // Underage
	}

	_, err = userService.CreateUser(invalidReq)
	if err != nil {
		fmt.Printf("\nValidation correctly failed: %v\n", err)
	}
}
