package client

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	"github.com/sony/gobreaker"
)

// CSharpAPIClient handles communication with C# API
type CSharpAPIClient struct {
	baseURL        string
	httpClient     *http.Client
	circuitBreaker *gobreaker.CircuitBreaker
}

// CSharpDateTimeResponse represents the response from C# API
type CSharpDateTimeResponse struct {
	Date      string `json:"date"`
	Time      string `json:"time"`
	DayOfWeek string `json:"dayOfWeek"`
	Timestamp string `json:"timestamp"`
}

// NewCSharpAPIClient creates a new client with circuit breaker
func NewCSharpAPIClient() *CSharpAPIClient {
	baseURL := os.Getenv("CSHARP_API_URL")
	if baseURL == "" {
		baseURL = "http://datetime-api-csharp-service"
	}

	// Circuit breaker settings
	settings := gobreaker.Settings{
		Name:        "CSharpAPI",
		MaxRequests: 3,                // Max requests in half-open state
		Interval:    10 * time.Second, // Interval to clear counts
		Timeout:     30 * time.Second, // Time to stay in open state
		ReadyToTrip: func(counts gobreaker.Counts) bool {
			failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
			return counts.Requests >= 5 && failureRatio >= 0.5
		},
		OnStateChange: func(name string, from gobreaker.State, to gobreaker.State) {
			fmt.Printf("Circuit Breaker '%s' changed from '%s' to '%s'\n", name, from, to)
		},
	}

	return &CSharpAPIClient{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
		circuitBreaker: gobreaker.NewCircuitBreaker(settings),
	}
}

// GetDateTime calls C# API's /api/datetime endpoint with retry and circuit breaker
func (c *CSharpAPIClient) GetDateTime() (*CSharpDateTimeResponse, error) {
	var result *CSharpDateTimeResponse
	var err error

	// Execute with circuit breaker
	_, cbErr := c.circuitBreaker.Execute(func() (interface{}, error) {
		// Retry logic with exponential backoff
		maxRetries := 3
		for attempt := 0; attempt < maxRetries; attempt++ {
			result, err = c.makeRequest()
			if err == nil {
				return result, nil
			}

			// Exponential backoff: 100ms, 200ms, 400ms
			if attempt < maxRetries-1 {
				backoff := time.Duration(100*(1<<uint(attempt))) * time.Millisecond
				time.Sleep(backoff)
			}
		}
		return nil, err
	})

	if cbErr != nil {
		return nil, fmt.Errorf("circuit breaker error: %w", cbErr)
	}

	return result, err
}

// makeRequest performs the actual HTTP request
func (c *CSharpAPIClient) makeRequest() (*CSharpDateTimeResponse, error) {
	url := fmt.Sprintf("%s/api/datetime", c.baseURL)
	resp, err := c.httpClient.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to call C# API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("C# API returned status %d: %s", resp.StatusCode, string(body))
	}

	var response CSharpDateTimeResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &response, nil
}

// GetCircuitBreakerState returns the current state of the circuit breaker
func (c *CSharpAPIClient) GetCircuitBreakerState() gobreaker.State {
	return c.circuitBreaker.State()
}
