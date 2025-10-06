package handlers

import (
	"net/http"
	"time"

	"github.com/esersahin/datetime-api-go/models"
)

// WorldClockHandler handles world clock requests for multiple cities
func WorldClockHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Major world cities with their timezones
	cities := map[string]string{
		"New York":    "America/New_York",
		"London":      "Europe/London",
		"Paris":       "Europe/Paris",
		"Istanbul":    "Europe/Istanbul",
		"Tokyo":       "Asia/Tokyo",
		"Sydney":      "Australia/Sydney",
		"Dubai":       "Asia/Dubai",
		"Singapore":   "Asia/Singapore",
		"Hong Kong":   "Asia/Hong_Kong",
		"Los Angeles": "America/Los_Angeles",
		"Chicago":     "America/Chicago",
		"Toronto":     "America/Toronto",
		"Berlin":      "Europe/Berlin",
		"Moscow":      "Europe/Moscow",
		"Mumbai":      "Asia/Kolkata",
		"Beijing":     "Asia/Shanghai",
		"São Paulo":   "America/Sao_Paulo",
		"Mexico City": "America/Mexico_City",
		"Cairo":       "Africa/Cairo",
		"Seoul":       "Asia/Seoul",
	}

	var responses []models.WorldClockResponse

	for city, tz := range cities {
		loc, err := time.LoadLocation(tz)
		if err != nil {
			continue
		}

		now := time.Now().In(loc)
		zoneName, offset := now.Zone()

		response := models.WorldClockResponse{
			City:     city,
			Timezone: tz,
			Time:     now.Format("15:04:05"),
			Date:     now.Format("2006-01-02"),
			Offset:   formatOffsetString(zoneName, offset),
			IsDST:    isDST(now),
		}

		responses = append(responses, response)
	}

	respondWithJSON(w, http.StatusOK, responses)
}

// WorldClockCityHandler handles world clock request for a specific city
func WorldClockCityHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Get timezone from query parameter
	timezone := r.URL.Query().Get("timezone")
	if timezone == "" {
		respondWithError(w, http.StatusBadRequest, "Missing timezone parameter", "")
		return
	}

	loc, err := time.LoadLocation(timezone)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid timezone", err.Error())
		return
	}

	now := time.Now().In(loc)
	zoneName, offset := now.Zone()

	response := models.WorldClockResponse{
		City:     timezone,
		Timezone: timezone,
		Time:     now.Format("15:04:05"),
		Date:     now.Format("2006-01-02"),
		Offset:   formatOffsetString(zoneName, offset),
		IsDST:    isDST(now),
	}

	respondWithJSON(w, http.StatusOK, response)
}

func formatOffsetString(zone string, offset int) string {
	hours := offset / 3600
	minutes := (offset % 3600) / 60

	sign := "+"
	if hours < 0 {
		sign = "-"
		hours = -hours
	}

	if minutes != 0 {
		return zone + " (UTC" + sign + formatInt(hours) + ":" + formatInt(minutes) + ")"
	}
	return zone + " (UTC" + sign + formatInt(hours) + ")"
}

func formatInt(n int) string {
	if n < 10 {
		return "0" + string(rune('0'+n))
	}
	return string(rune('0'+n/10)) + string(rune('0'+n%10))
}

func isDST(t time.Time) bool {
	// Get the timezone offset in January (standard time)
	jan := time.Date(t.Year(), 1, 1, 0, 0, 0, 0, t.Location())
	_, janOffset := jan.Zone()

	// Get current offset
	_, currentOffset := t.Zone()

	// If current offset is greater than January offset, we're in DST
	return currentOffset > janOffset
}
