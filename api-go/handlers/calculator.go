package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/esersahin/datetime-api-go/models"
	"github.com/esersahin/datetime-api-go/utils"
)

// TimeCalculatorHandler handles time calculation requests
func TimeCalculatorHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req models.TimeCalculatorRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}

	// Parse start time
	startTime, err := time.Parse(time.RFC3339, req.StartTime)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid start_time format (use RFC3339/ISO 8601)", err.Error())
		return
	}

	var response models.TimeCalculatorResponse

	// If end time is provided, calculate difference
	if req.EndTime != "" {
		endTime, err := time.Parse(time.RFC3339, req.EndTime)
		if err != nil {
			respondWithError(w, http.StatusBadRequest, "Invalid end_time format (use RFC3339/ISO 8601)", err.Error())
			return
		}

		years, months, days, hours, minutes, seconds, duration := utils.CalculateTimeDifference(startTime, endTime)

		response = models.TimeCalculatorResponse{
			Result: endTime.Format(time.RFC3339),
			Difference: &models.TimeDifference{
				Years:   years,
				Months:  months,
				Days:    days,
				Hours:   hours,
				Minutes: minutes,
				Seconds: seconds,
				Total:   duration.String(),
			},
		}
	} else {
		// Perform add/subtract operation
		result := startTime

		if req.Operation == "add" {
			result = result.AddDate(req.Years, req.Months, req.Days)
			result = result.Add(time.Duration(req.Hours)*time.Hour +
				time.Duration(req.Minutes)*time.Minute +
				time.Duration(req.Seconds)*time.Second)
		} else if req.Operation == "subtract" {
			result = result.AddDate(-req.Years, -req.Months, -req.Days)
			result = result.Add(-time.Duration(req.Hours)*time.Hour -
				time.Duration(req.Minutes)*time.Minute -
				time.Duration(req.Seconds)*time.Second)
		} else {
			respondWithError(w, http.StatusBadRequest, "Invalid operation", "operation must be 'add' or 'subtract'")
			return
		}

		response = models.TimeCalculatorResponse{
			Result: result.Format(time.RFC3339),
		}
	}

	respondWithJSON(w, http.StatusOK, response)
}
