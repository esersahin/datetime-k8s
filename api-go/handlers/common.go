package handlers

import (
	"encoding/json"
	"net/http"
	"os"
	"time"

	"github.com/esersahin/datetime-api-go/models"
)

// HealthHandler handles health check requests
func HealthHandler(w http.ResponseWriter, r *http.Request) {
	podName := os.Getenv("HOSTNAME")
	if podName == "" {
		podName = "unknown"
	}

	nodeName := os.Getenv("NODE_NAME")
	if nodeName == "" {
		nodeName = "unknown"
	}

	response := models.HealthResponse{
		Status:    "healthy",
		Timestamp: time.Now(),
		Service:   "datetime-api-go",
		Pod:       podName,
		Node:      nodeName,
	}

	respondWithJSON(w, http.StatusOK, response)
}

// respondWithJSON sends a JSON response
func respondWithJSON(w http.ResponseWriter, status int, payload interface{}) {
	response, err := json.Marshal(payload)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("Error marshalling JSON"))
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	w.Write(response)
}

// respondWithError sends an error response
func respondWithError(w http.ResponseWriter, status int, error string, message string) {
	errorResponse := models.ErrorResponse{
		Error:   error,
		Message: message,
	}
	respondWithJSON(w, status, errorResponse)
}
