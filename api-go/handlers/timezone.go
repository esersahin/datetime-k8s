package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/esersahin/datetime-api-go/models"
)

// TimezoneConvertHandler handles timezone conversion requests
func TimezoneConvertHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req models.TimezoneConvertRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}

	// Load source timezone
	fromLoc, err := time.LoadLocation(req.FromTimezone)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid from_timezone", err.Error())
		return
	}

	// Load target timezone
	toLoc, err := time.LoadLocation(req.ToTimezone)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid to_timezone", err.Error())
		return
	}

	// Parse or use current time
	var t time.Time
	if req.Time == "" {
		t = time.Now().In(fromLoc)
	} else {
		t, err = time.ParseInLocation(time.RFC3339, req.Time, fromLoc)
		if err != nil {
			respondWithError(w, http.StatusBadRequest, "Invalid time format (use RFC3339/ISO 8601)", err.Error())
			return
		}
	}

	// Convert to target timezone
	convertedTime := t.In(toLoc)

	// Calculate offset
	_, fromOffset := t.Zone()
	_, toOffset := convertedTime.Zone()
	offsetDiff := (toOffset - fromOffset) / 3600

	response := models.TimezoneConvertResponse{
		OriginalTime:      t.Format(time.RFC3339),
		OriginalTimezone:  req.FromTimezone,
		ConvertedTime:     convertedTime.Format(time.RFC3339),
		ConvertedTimezone: req.ToTimezone,
		Offset:            formatOffset(offsetDiff),
	}

	respondWithJSON(w, http.StatusOK, response)
}

func formatOffset(hours int) string {
	if hours >= 0 {
		return "+" + formatHours(hours)
	}
	return formatHours(hours)
}

func formatHours(hours int) string {
	if hours < 0 {
		hours = -hours
	}
	if hours < 10 {
		return "0" + string(rune('0'+hours))
	}
	return string(rune('0'+hours/10)) + string(rune('0'+hours%10))
}
