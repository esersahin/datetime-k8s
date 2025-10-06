package utils

import (
	"time"
)

// IsWeekend checks if a given date is a weekend
func IsWeekend(t time.Time) bool {
	weekday := t.Weekday()
	return weekday == time.Saturday || weekday == time.Sunday
}

// IsHoliday checks if a given date is in the list of holidays
func IsHoliday(t time.Time, holidays []time.Time) bool {
	dateStr := t.Format("2006-01-02")
	for _, holiday := range holidays {
		if holiday.Format("2006-01-02") == dateStr {
			return true
		}
	}
	return false
}

// IsBusinessDay checks if a given date is a business day
func IsBusinessDay(t time.Time, holidays []time.Time) bool {
	return !IsWeekend(t) && !IsHoliday(t, holidays)
}

// CalculateBusinessDays calculates the number of business days between two dates
func CalculateBusinessDays(start, end time.Time, holidays []time.Time) (businessDays, weekends, holidayCount int) {
	// Normalize times to start of day
	start = time.Date(start.Year(), start.Month(), start.Day(), 0, 0, 0, 0, start.Location())
	end = time.Date(end.Year(), end.Month(), end.Day(), 0, 0, 0, 0, end.Location())

	if start.After(end) {
		start, end = end, start
	}

	for d := start; !d.After(end); d = d.AddDate(0, 0, 1) {
		if IsWeekend(d) {
			weekends++
		} else if IsHoliday(d, holidays) {
			holidayCount++
		} else {
			businessDays++
		}
	}

	return
}

// AddBusinessDays adds a specified number of business days to a date
func AddBusinessDays(start time.Time, days int, holidays []time.Time) time.Time {
	current := start
	daysAdded := 0
	increment := 1

	if days < 0 {
		increment = -1
		days = -days
	}

	for daysAdded < days {
		current = current.AddDate(0, 0, increment)
		if IsBusinessDay(current, holidays) {
			daysAdded++
		}
	}

	return current
}

// ParseHolidays parses a slice of date strings into time.Time slice
func ParseHolidays(holidayStrs []string, location *time.Location) ([]time.Time, error) {
	var holidays []time.Time
	for _, dateStr := range holidayStrs {
		t, err := time.ParseInLocation("2006-01-02", dateStr, location)
		if err != nil {
			return nil, err
		}
		holidays = append(holidays, t)
	}
	return holidays, nil
}

// CalculateTimeDifference calculates the difference between two times
func CalculateTimeDifference(start, end time.Time) (years, months, days, hours, minutes, seconds int, duration time.Duration) {
	if start.After(end) {
		start, end = end, start
	}

	duration = end.Sub(start)

	// Calculate years
	years = end.Year() - start.Year()

	// Calculate months
	months = int(end.Month()) - int(start.Month())
	if months < 0 {
		years--
		months += 12
	}

	// Calculate days
	days = end.Day() - start.Day()
	if days < 0 {
		// Go back one month
		months--
		if months < 0 {
			years--
			months += 12
		}
		// Add days from previous month
		prevMonth := end.AddDate(0, -1, 0)
		days += DaysIn(prevMonth.Month(), prevMonth.Year())
	}

	// Calculate hours, minutes, seconds from the remaining duration
	remainingDuration := duration - time.Duration(years)*365*24*time.Hour -
		time.Duration(months)*30*24*time.Hour - time.Duration(days)*24*time.Hour

	hours = int(remainingDuration.Hours()) % 24
	minutes = int(remainingDuration.Minutes()) % 60
	seconds = int(remainingDuration.Seconds()) % 60

	return
}

// DaysIn returns the number of days in a given month/year
func DaysIn(month time.Month, year int) int {
	return time.Date(year, month+1, 0, 0, 0, 0, 0, time.UTC).Day()
}
