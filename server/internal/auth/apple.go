package auth

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	appleKeysURL = "https://appleid.apple.com/auth/keys"
	appleIssuer  = "https://appleid.apple.com"
)

// AppleVerifier validates "Sign in with Apple" identity tokens against Apple's
// published JWKS, caching the keys for an hour.
type AppleVerifier struct {
	audiences map[string]bool
	client    *http.Client

	mu        sync.Mutex
	keys      map[string]*rsa.PublicKey
	fetchedAt time.Time
}

func NewAppleVerifier(audiences []string) *AppleVerifier {
	m := make(map[string]bool, len(audiences))
	for _, a := range audiences {
		m[a] = true
	}
	return &AppleVerifier{
		audiences: m,
		client:    &http.Client{Timeout: 10 * time.Second},
		keys:      map[string]*rsa.PublicKey{},
	}
}

type appleJWK struct {
	Kid string `json:"kid"`
	N   string `json:"n"`
	E   string `json:"e"`
	Kty string `json:"kty"`
}

func (v *AppleVerifier) refreshKeys(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, appleKeysURL, nil)
	if err != nil {
		return err
	}
	resp, err := v.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	var jwks struct {
		Keys []appleJWK `json:"keys"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&jwks); err != nil {
		return err
	}
	keys := make(map[string]*rsa.PublicKey, len(jwks.Keys))
	for _, k := range jwks.Keys {
		if k.Kty != "RSA" {
			continue
		}
		nBytes, err := base64.RawURLEncoding.DecodeString(k.N)
		if err != nil {
			continue
		}
		eBytes, err := base64.RawURLEncoding.DecodeString(k.E)
		if err != nil {
			continue
		}
		keys[k.Kid] = &rsa.PublicKey{
			N: new(big.Int).SetBytes(nBytes),
			E: int(new(big.Int).SetBytes(eBytes).Int64()),
		}
	}
	v.mu.Lock()
	v.keys = keys
	v.fetchedAt = time.Now()
	v.mu.Unlock()
	return nil
}

func (v *AppleVerifier) keyFor(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	v.mu.Lock()
	key, ok := v.keys[kid]
	stale := time.Since(v.fetchedAt) > time.Hour
	v.mu.Unlock()
	if ok && !stale {
		return key, nil
	}
	if err := v.refreshKeys(ctx); err != nil {
		if ok {
			return key, nil // fall back to a cached key on transient fetch failure
		}
		return nil, err
	}
	v.mu.Lock()
	key, ok = v.keys[kid]
	v.mu.Unlock()
	if !ok {
		return nil, errors.New("apple: unknown key id")
	}
	return key, nil
}

// Verify validates an Apple identity token and returns the stable user id (sub)
// plus the email claim if Apple included one.
func (v *AppleVerifier) Verify(ctx context.Context, idToken string) (sub string, email *string, err error) {
	claims := jwt.MapClaims{}
	_, err = jwt.ParseWithClaims(idToken, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodRSA); !ok {
			return nil, errors.New("apple: unexpected signing method")
		}
		kid, _ := t.Header["kid"].(string)
		return v.keyFor(ctx, kid)
	}, jwt.WithIssuer(appleIssuer), jwt.WithValidMethods([]string{"RS256"}))
	if err != nil {
		return "", nil, fmt.Errorf("apple: verify token: %w", err)
	}

	sub, _ = claims["sub"].(string)
	if sub == "" {
		return "", nil, errors.New("apple: missing sub")
	}
	if !v.audienceOK(claims["aud"]) {
		return "", nil, errors.New("apple: audience mismatch")
	}
	if e, ok := claims["email"].(string); ok && e != "" {
		email = &e
	}
	return sub, email, nil
}

func (v *AppleVerifier) audienceOK(aud any) bool {
	switch a := aud.(type) {
	case string:
		return v.audiences[a]
	case []any:
		for _, x := range a {
			if s, ok := x.(string); ok && v.audiences[s] {
				return true
			}
		}
	}
	return false
}
