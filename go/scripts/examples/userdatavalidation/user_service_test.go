package main

import (
	"errors"
	"strings"
	"testing"
	"time"
)

func TestUserService_ValidateUser(t *testing.T) {
	tests := []struct {
		name    string
		user    UserRequest
		wantErr error
	}{
		{
			name: "valid user",
			user: UserRequest{
				Username:  "john_doe123",
				Email:     "john@example.com",
				BirthDate: time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC),
			},
			wantErr: nil,
		},
		{
			name: "empty username",
			user: UserRequest{
				Username:  "",
				Email:     "john@example.com",
				BirthDate: time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC),
			},
			wantErr: ErrEmptyField,
		},
		{
			name: "invalid email",
			user: UserRequest{
				Username:  "johndoe",
				Email:     "invalid-email",
				BirthDate: time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC),
			},
			wantErr: ErrInvalidEmail,
		},
		{
			name: "username too short",
			user: UserRequest{
				Username:  "ab",
				Email:     "john@example.com",
				BirthDate: time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC),
			},
			wantErr: ErrInvalidUsername,
		},
		{
			name: "underage user",
			user: UserRequest{
				Username:  "younguser",
				Email:     "young@example.com",
				BirthDate: time.Now().AddDate(-10, 0, 0), // 10 years old
			},
			wantErr: ErrUserUnderage,
		},
	}

	service := NewUserService()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := service.ValidateUser(tt.user)

			if tt.wantErr == nil {
				if err != nil {
					t.Errorf("ValidateUser() unexpected error = %v", err)
				}
				return
			}

			if err == nil {
				t.Errorf("ValidateUser() expected error %v, got nil", tt.wantErr)
				return
			}

			if !errors.Is(err, tt.wantErr) {
				t.Errorf("ValidateUser() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestUserService_CreateUser(t *testing.T) {
	service := NewUserService()

	validRequest := UserRequest{
		Username:  "testuser",
		Email:     "test@example.com",
		BirthDate: time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC),
	}

	t.Run("successful creation", func(t *testing.T) {
		user, err := service.CreateUser(validRequest)
		if err != nil {
			t.Fatalf("CreateUser() unexpected error: %v", err)
		}

		if user.ID == "" {
			t.Error("CreateUser() should generate an ID")
		}

		if user.Username != validRequest.Username {
			t.Errorf("CreateUser() username = %v, want %v", user.Username, validRequest.Username)
		}

		if user.Email != strings.ToLower(validRequest.Email) {
			t.Errorf("CreateUser() email = %v, want %v", user.Email, validRequest.Email)
		}

		if user.CreatedAt.IsZero() {
			t.Error("CreateUser() should set created_at timestamp")
		}
	})

	t.Run("creation with invalid data", func(t *testing.T) {
		invalidRequest := validRequest
		invalidRequest.Username = "" // Empty username

		_, err := service.CreateUser(invalidRequest)
		if err == nil {
			t.Error("CreateUser() should return error for invalid data")
		}

		if !errors.Is(err, ErrEmptyField) {
			t.Errorf("CreateUser() error = %v, want %v", err, ErrEmptyField)
		}
	})
}

func TestUserService_GetUserAge(t *testing.T) {
	service := NewUserService()
	now := time.Now().UTC()

	tests := []struct {
		name      string
		birthDate time.Time
		wantAge   int
	}{
		{
			name:      "exact birthday today",
			birthDate: now.AddDate(-25, 0, 0),
			wantAge:   25,
		},
		{
			name:      "birthday yesterday",
			birthDate: now.AddDate(-30, 0, -1),
			wantAge:   30,
		},
		{
			name:      "birthday tomorrow",
			birthDate: now.AddDate(-18, 0, 1),
			wantAge:   17, // Not yet 18
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			age := service.GetUserAge(tt.birthDate)
			if age != tt.wantAge {
				t.Errorf("GetUserAge() = %v, want %v", age, tt.wantAge)
			}
		})
	}
}

func TestUserService_EdgeCases(t *testing.T) {
	service := NewUserService()

	t.Run("email with uppercase", func(t *testing.T) {
		req := UserRequest{
			Username:  "testuser",
			Email:     "TEST@Example.COM",
			BirthDate: time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC),
		}

		user, err := service.CreateUser(req)
		if err != nil {
			t.Fatalf("CreateUser() unexpected error: %v", err)
		}

		expectedEmail := "test@example.com"
		if user.Email != expectedEmail {
			t.Errorf("CreateUser() email should be normalized, got %v, want %v", user.Email, expectedEmail)
		}
	})

	t.Run("username with spaces", func(t *testing.T) {
		req := UserRequest{
			Username:  "  testuser  ",
			Email:     "test@example.com",
			BirthDate: time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC),
		}

		user, err := service.CreateUser(req)
		if err != nil {
			t.Fatalf("CreateUser() unexpected error: %v", err)
		}

		if user.Username != "testuser" {
			t.Errorf("CreateUser() should trim username, got '%v'", user.Username)
		}
	})
}

// Benchmark test for performance
func BenchmarkCreateUser(b *testing.B) {
	service := NewUserService()
	req := UserRequest{
		Username:  "benchuser",
		Email:     "bench@example.com",
		BirthDate: time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC),
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := service.CreateUser(req)
		if err != nil {
			b.Fatalf("CreateUser failed: %v", err)
		}
	}
}
