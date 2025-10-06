package main

import (
	"log"
	"net/http"

	"github.com/esersahin/datetime-api-go/handlers"
)

// corsMiddleware adds CORS headers to all responses
func corsMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		// Handle preflight requests
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next(w, r)
	}
}

// loggingMiddleware logs all incoming requests
func loggingMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s %s", r.Method, r.URL.Path, r.RemoteAddr)
		next(w, r)
	}
}

// chainMiddleware chains multiple middlewares
func chainMiddleware(handler http.HandlerFunc, middlewares ...func(http.HandlerFunc) http.HandlerFunc) http.HandlerFunc {
	for i := len(middlewares) - 1; i >= 0; i-- {
		handler = middlewares[i](handler)
	}
	return handler
}

func main() {
	// Health check endpoint
	http.HandleFunc("/health", chainMiddleware(handlers.HealthHandler, corsMiddleware, loggingMiddleware))

	// Timezone converter endpoint
	http.HandleFunc("/api/timezone/convert", chainMiddleware(handlers.TimezoneConvertHandler, corsMiddleware, loggingMiddleware))

	// Time calculator endpoint
	http.HandleFunc("/api/time/calculate", chainMiddleware(handlers.TimeCalculatorHandler, corsMiddleware, loggingMiddleware))

	// World clock endpoints
	http.HandleFunc("/api/worldclock", chainMiddleware(handlers.WorldClockHandler, corsMiddleware, loggingMiddleware))
	http.HandleFunc("/api/worldclock/city", chainMiddleware(handlers.WorldClockCityHandler, corsMiddleware, loggingMiddleware))

	// Countdown/timer endpoint
	http.HandleFunc("/api/countdown", chainMiddleware(handlers.CountdownHandler, corsMiddleware, loggingMiddleware))

	// Business days calculator endpoint
	http.HandleFunc("/api/businessdays", chainMiddleware(handlers.BusinessDaysHandler, corsMiddleware, loggingMiddleware))

	port := ":8080"
	log.Printf("🚀 DateTime API Server starting on port %s", port)
	log.Printf("📍 Available endpoints:")
	log.Printf("   GET  /health - Health check")
	log.Printf("   POST /api/timezone/convert - Convert time between timezones")
	log.Printf("   POST /api/time/calculate - Calculate time differences or add/subtract time")
	log.Printf("   GET  /api/worldclock - Get current time in major world cities")
	log.Printf("   GET  /api/worldclock/city?timezone=<tz> - Get time for specific timezone")
	log.Printf("   POST /api/countdown - Calculate countdown to target time")
	log.Printf("   POST /api/businessdays - Calculate business days")

	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatalf("❌ Server failed to start: %v", err)
	}
}
