package handlers

import (
	"net/http"
	"time"

	"github.com/esersahin/datetime-api-go/client"
	"github.com/esersahin/datetime-api-go/models"
)

// CSharpDateTimeHandler calls C# API and returns the data
func CSharpDateTimeHandler(csharpClient *client.CSharpAPIClient) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		data, err := csharpClient.GetDateTime()
		if err != nil {
			respondWithError(w, http.StatusServiceUnavailable,
				"service_unavailable",
				"Failed to call C# API: "+err.Error())
			return
		}

		response := struct {
			Source        string                              `json:"source"`
			CalledService string                              `json:"calledService"`
			Endpoint      string                              `json:"endpoint"`
			Data          *client.CSharpDateTimeResponse      `json:"data"`
			Timestamp     time.Time                           `json:"timestamp"`
			CircuitBreaker string                             `json:"circuitBreakerState"`
		}{
			Source:        "go-api",
			CalledService: "csharp-api",
			Endpoint:      "/api/datetime",
			Data:          data,
			Timestamp:     time.Now().UTC(),
			CircuitBreaker: csharpClient.GetCircuitBreakerState().String(),
		}

		respondWithJSON(w, http.StatusOK, response)
	}
}

// ResiliencyStatusHandler returns the current resiliency status
func ResiliencyStatusHandler(csharpClient *client.CSharpAPIClient) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		response := models.ResiliencyStatus{
			Service:              "datetime-api-go",
			CircuitBreakerState:  csharpClient.GetCircuitBreakerState().String(),
			RateLimitConfigured:  true,
			RetryPolicyActive:    true,
			Timestamp:            time.Now(),
		}

		respondWithJSON(w, http.StatusOK, response)
	}
}
