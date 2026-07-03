package middleware

import (
	"net/http"
	"sync"
	"time"

	"golang.org/x/time/rate"
)

type visitor struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

// RateLimiter is a simple in-memory per-key token-bucket limiter. Keys are
// typically client IPs, but any string (e.g. a user id) can be used.
type RateLimiter struct {
	mu       sync.Mutex
	visitors map[string]*visitor
	rate     rate.Limit
	burst    int
}

// NewRateLimiter allows `perSecond` requests with the given burst.
func NewRateLimiter(perSecond float64, burst int) *RateLimiter {
	rl := &RateLimiter{
		visitors: make(map[string]*visitor),
		rate:     rate.Limit(perSecond),
		burst:    burst,
	}
	go rl.cleanupLoop()
	return rl
}

func (rl *RateLimiter) limiterFor(key string) *rate.Limiter {
	rl.mu.Lock()
	defer rl.mu.Unlock()
	v, ok := rl.visitors[key]
	if !ok {
		lim := rate.NewLimiter(rl.rate, rl.burst)
		rl.visitors[key] = &visitor{limiter: lim, lastSeen: time.Now()}
		return lim
	}
	v.lastSeen = time.Now()
	return v.limiter
}

func (rl *RateLimiter) cleanupLoop() {
	for {
		time.Sleep(time.Minute)
		rl.mu.Lock()
		for key, v := range rl.visitors {
			if time.Since(v.lastSeen) > 3*time.Minute {
				delete(rl.visitors, key)
			}
		}
		rl.mu.Unlock()
	}
}

// Allow reports whether an action for the given key may proceed.
func (rl *RateLimiter) Allow(key string) bool {
	return rl.limiterFor(key).Allow()
}

// ByIP is HTTP middleware that limits requests by client IP address.
func (rl *RateLimiter) ByIP(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !rl.Allow(r.RemoteAddr) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusTooManyRequests)
			_, _ = w.Write([]byte(`{"error":"rate limited","code":"rate_limited"}`))
			return
		}
		next.ServeHTTP(w, r)
	})
}
