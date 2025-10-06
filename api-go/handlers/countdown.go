package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/esersahin/datetime-api-go/models"
	"github.com/esersahin/datetime-api-go/utils"
)

// CountdownHandler handles countdown calculation requests
func CountdownHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req models.CountdownRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}

	// Parse target time
	targetTime, err := time.Parse(time.RFC3339, req.TargetTime)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid target_time format (use RFC3339/ISO 8601)", err.Error())
		return
	}

	// Parse or use current time
	var fromTime time.Time
	if req.FromTime == "" {
		fromTime = time.Now()
	} else {
		fromTime, err = time.Parse(time.RFC3339, req.FromTime)
		if err != nil {
			respondWithError(w, http.StatusBadRequest, "Invalid from_time format (use RFC3339/ISO 8601)", err.Error())
			return
		}
	}

	// Calculate difference
	isPast := targetTime.Before(fromTime)
	var start, end time.Time
	if isPast {
		start = targetTime
		end = fromTime
	} else {
		start = fromTime
		end = targetTime
	}

	years, months, days, hours, minutes, seconds, duration := utils.CalculateTimeDifference(start, end)

	response := models.CountdownResponse{
		TargetTime:  targetTime.Format(time.RFC3339),
		CurrentTime: fromTime.Format(time.RFC3339),
		TimeRemaining: &models.TimeDifference{
			Years:   years,
			Months:  months,
			Days:    days,
			Hours:   hours,
			Minutes: minutes,
			Seconds: seconds,
			Total:   duration.String(),
		},
		IsPast:       isPast,
		TotalSeconds: int64(duration.Seconds()),
	}

	if isPast {
		response.TotalSeconds = -response.TotalSeconds
	}

	respondWithJSON(w, http.StatusOK, response)
}
