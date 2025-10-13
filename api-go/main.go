package main

import (
	"log"
	"net/http"

	"github.com/esersahin/datetime-api-go/client"
	"github.com/esersahin/datetime-api-go/handlers"
	"github.com/esersahin/datetime-api-go/middleware"
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
	// Initialize C# API client with circuit breaker
	csharpClient := client.NewCSharpAPIClient()
	log.Printf("🔌 C# API client initialized with circuit breaker")

	// Initialize rate limiter
	rateLimiter := middleware.NewRateLimiter()
	globalRateLimit := middleware.RateLimitMiddleware(rateLimiter, 150.0, 150) // 150 req/sec
	csharpAPIRateLimit := middleware.PerEndpointRateLimitMiddleware(rateLimiter, "csharp-api-calls", 30.0, 30) // 30 req/sec

	// Health check endpoint
	http.HandleFunc("/health", chainMiddleware(handlers.HealthHandler, corsMiddleware, loggingMiddleware))

	// Timezone converter endpoint
	http.Handle("/api/timezone/convert", globalRateLimit(chainMiddleware(handlers.TimezoneConvertHandler, corsMiddleware, loggingMiddleware)))

	// Time calculator endpoint
	http.Handle("/api/time/calculate", globalRateLimit(chainMiddleware(handlers.TimeCalculatorHandler, corsMiddleware, loggingMiddleware)))

	// World clock endpoints
	http.Handle("/api/worldclock", globalRateLimit(chainMiddleware(handlers.WorldClockHandler, corsMiddleware, loggingMiddleware)))
	http.Handle("/api/worldclock/city", globalRateLimit(chainMiddleware(handlers.WorldClockCityHandler, corsMiddleware, loggingMiddleware)))

	// Countdown/timer endpoint
	http.Handle("/api/countdown", globalRateLimit(chainMiddleware(handlers.CountdownHandler, corsMiddleware, loggingMiddleware)))

	// Business days calculator endpoint
	http.Handle("/api/businessdays", globalRateLimit(chainMiddleware(handlers.BusinessDaysHandler, corsMiddleware, loggingMiddleware)))

	// NEW: Service-to-service communication endpoint (with rate limiting)
	http.Handle("/api/csharp-datetime", csharpAPIRateLimit(globalRateLimit(chainMiddleware(handlers.CSharpDateTimeHandler(csharpClient), corsMiddleware, loggingMiddleware))))

	// NEW: Resiliency status endpoint
	http.HandleFunc("/api/resiliency-status", chainMiddleware(handlers.ResiliencyStatusHandler(csharpClient), corsMiddleware, loggingMiddleware))

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
	log.Printf("   GET  /api/csharp-datetime - Call C# API (with circuit breaker & retry)")
	log.Printf("   GET  /api/resiliency-status - Get resiliency configuration status")
	log.Printf("🛡️  Resiliency features enabled:")
	log.Printf("   ✅ Circuit Breaker (5 failures → 30s break)")
	log.Printf("   ✅ Retry Policy (3 attempts with exponential backoff)")
	log.Printf("   ✅ Rate Limiting (Global: 150 req/sec, C# API: 30 req/sec)")

	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatalf("❌ Server failed to start: %v", err)
	}
}
