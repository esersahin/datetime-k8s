package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/esersahin/datetime-api-go/models"
	"github.com/esersahin/datetime-api-go/utils"
)

// BusinessDaysHandler handles business days calculation requests
func BusinessDaysHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req models.BusinessDaysRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}

	// Default timezone to UTC if not provided
	timezone := "UTC"
	if req.Timezone != "" {
		timezone = req.Timezone
	}

	loc, err := time.LoadLocation(timezone)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid timezone", err.Error())
		return
	}

	// Parse start date
	startDate, err := time.ParseInLocation("2006-01-02", req.StartDate, loc)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid start_date format (use YYYY-MM-DD)", err.Error())
		return
	}

	// Parse holidays
	holidays, err := utils.ParseHolidays(req.Holidays, loc)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid holiday date format", err.Error())
		return
	}

	var endDate time.Time
	var businessDays, weekends, holidayCount, totalDays int

	// If end date is provided, calculate business days between dates
	if req.EndDate != "" {
		endDate, err = time.ParseInLocation("2006-01-02", req.EndDate, loc)
		if err != nil {
			respondWithError(w, http.StatusBadRequest, "Invalid end_date format (use YYYY-MM-DD)", err.Error())
			return
		}

		businessDays, weekends, holidayCount = utils.CalculateBusinessDays(startDate, endDate, holidays)

		// Calculate total days
		if startDate.After(endDate) {
			totalDays = int(startDate.Sub(endDate).Hours() / 24)
		} else {
			totalDays = int(endDate.Sub(startDate).Hours() / 24)
		}
	} else if req.Days != 0 {
		// If days is provided, add that many business days
		endDate = utils.AddBusinessDays(startDate, req.Days, holidays)

		// Calculate the actual business days and weekends/holidays in between
		if req.Days > 0 {
			businessDays, weekends, holidayCount = utils.CalculateBusinessDays(startDate, endDate, holidays)
			totalDays = int(endDate.Sub(startDate).Hours() / 24)
		} else {
			businessDays, weekends, holidayCount = utils.CalculateBusinessDays(endDate, startDate, holidays)
			totalDays = int(startDate.Sub(endDate).Hours() / 24)
		}
	} else {
		respondWithError(w, http.StatusBadRequest, "Either end_date or days must be provided", "")
		return
	}

	response := models.BusinessDaysResponse{
		StartDate:    startDate.Format("2006-01-02"),
		EndDate:      endDate.Format("2006-01-02"),
		BusinessDays: businessDays,
		TotalDays:    totalDays + 1, // +1 to include both start and end dates
		Weekends:     weekends,
		Holidays:     holidayCount,
	}

	respondWithJSON(w, http.StatusOK, response)
}
