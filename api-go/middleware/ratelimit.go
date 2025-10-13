package middleware

import (
	"net/http"
	"sync"

	"golang.org/x/time/rate"
)

// RateLimiter holds rate limiters per endpoint
type RateLimiter struct {
	limiters map[string]*rate.Limiter
	mu       sync.RWMutex
}

// NewRateLimiter creates a new rate limiter
func NewRateLimiter() *RateLimiter {
	return &RateLimiter{
		limiters: make(map[string]*rate.Limiter),
	}
}

// GetLimiter returns the rate limiter for a given key (or creates one)
func (rl *RateLimiter) GetLimiter(key string, r rate.Limit, b int) *rate.Limiter {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	limiter, exists := rl.limiters[key]
	if !exists {
		limiter = rate.NewLimiter(r, b)
		rl.limiters[key] = limiter
	}

	return limiter
}

// RateLimitMiddleware creates a rate limiting middleware
func RateLimitMiddleware(rl *RateLimiter, requestsPerSecond float64, burst int) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			limiter := rl.GetLimiter("global", rate.Limit(requestsPerSecond), burst)

			if !limiter.Allow() {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusTooManyRequests)
				w.Write([]byte(`{"error":"Rate limit exceeded","message":"Too many requests. Please try again later."}`))
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// PerEndpointRateLimitMiddleware creates per-endpoint rate limiting
func PerEndpointRateLimitMiddleware(rl *RateLimiter, endpoint string, requestsPerSecond float64, burst int) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			limiter := rl.GetLimiter(endpoint, rate.Limit(requestsPerSecond), burst)

			if !limiter.Allow() {
				reservation := limiter.Reserve()
				retryAfter := reservation.Delay()
				reservation.Cancel()

				w.Header().Set("Content-Type", "application/json")
				w.Header().Set("Retry-After", retryAfter.String())
				w.WriteHeader(http.StatusTooManyRequests)
				w.Write([]byte(`{"error":"Rate limit exceeded","message":"Too many requests for this endpoint. Please try again later."}`))
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
