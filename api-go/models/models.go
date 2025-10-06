package models

import "time"

// TimezoneConvertRequest represents a request to convert time between timezones
type TimezoneConvertRequest struct {
	Time         string `json:"time"`          // ISO 8601 format or empty for current time
	FromTimezone string `json:"from_timezone"` // IANA timezone name (e.g., "America/New_York")
	ToTimezone   string `json:"to_timezone"`   // IANA timezone name (e.g., "Europe/Istanbul")
}

// TimezoneConvertResponse represents the response of timezone conversion
type TimezoneConvertResponse struct {
	OriginalTime     string `json:"original_time"`
	OriginalTimezone string `json:"original_timezone"`
	ConvertedTime    string `json:"converted_time"`
	ConvertedTimezone string `json:"converted_timezone"`
	Offset           string `json:"offset"`
}

// TimeCalculatorRequest represents a request for time calculations
type TimeCalculatorRequest struct {
	StartTime string `json:"start_time"` // ISO 8601 format
	EndTime   string `json:"end_time"`   // ISO 8601 format or empty
	Operation string `json:"operation"`  // "add" or "subtract"
	Years     int    `json:"years,omitempty"`
	Months    int    `json:"months,omitempty"`
	Days      int    `json:"days,omitempty"`
	Hours     int    `json:"hours,omitempty"`
	Minutes   int    `json:"minutes,omitempty"`
	Seconds   int    `json:"seconds,omitempty"`
}

// TimeCalculatorResponse represents the response of time calculation
type TimeCalculatorResponse struct {
	Result     string `json:"result"`
	Difference *TimeDifference `json:"difference,omitempty"`
}

// TimeDifference represents the difference between two times
type TimeDifference struct {
	Years   int     `json:"years"`
	Months  int     `json:"months"`
	Days    int     `json:"days"`
	Hours   int     `json:"hours"`
	Minutes int     `json:"minutes"`
	Seconds int     `json:"seconds"`
	Total   string  `json:"total_duration"`
}

// WorldClockResponse represents time in a specific city
type WorldClockResponse struct {
	City     string `json:"city"`
	Timezone string `json:"timezone"`
	Time     string `json:"time"`
	Date     string `json:"date"`
	Offset   string `json:"offset"`
	IsDST    bool   `json:"is_dst"`
}

// CountdownRequest represents a request for countdown calculation
type CountdownRequest struct {
	TargetTime string `json:"target_time"` // ISO 8601 format
	FromTime   string `json:"from_time,omitempty"` // Optional, defaults to now
}

// CountdownResponse represents the countdown to a target time
type CountdownResponse struct {
	TargetTime    string         `json:"target_time"`
	CurrentTime   string         `json:"current_time"`
	TimeRemaining *TimeDifference `json:"time_remaining"`
	IsPast        bool           `json:"is_past"`
	TotalSeconds  int64          `json:"total_seconds"`
}

// BusinessDaysRequest represents a request for business days calculation
type BusinessDaysRequest struct {
	StartDate string   `json:"start_date"` // Format: "2006-01-02"
	EndDate   string   `json:"end_date,omitempty"`   // Optional
	Days      int      `json:"days,omitempty"`       // Number of business days to add
	Timezone  string   `json:"timezone,omitempty"`   // IANA timezone, defaults to UTC
	Holidays  []string `json:"holidays,omitempty"`   // List of holiday dates in "2006-01-02" format
}

// BusinessDaysResponse represents the response of business days calculation
type BusinessDaysResponse struct {
	StartDate    string   `json:"start_date"`
	EndDate      string   `json:"end_date"`
	BusinessDays int      `json:"business_days"`
	TotalDays    int      `json:"total_days"`
	Weekends     int      `json:"weekends"`
	Holidays     int      `json:"holidays"`
}

// ErrorResponse represents an error response
type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message,omitempty"`
}

// HealthResponse represents a health check response
type HealthResponse struct {
	Status    string    `json:"status"`
	Timestamp time.Time `json:"timestamp"`
	Service   string    `json:"service"`
	Pod       string    `json:"pod"`
	Node      string    `json:"node"`
}
