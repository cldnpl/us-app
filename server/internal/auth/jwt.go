package auth

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// AccessClaims are the claims embedded in a short-lived access token.
type AccessClaims struct {
	jwt.RegisteredClaims
}

// IssueAccessToken mints an HS256 access token for the given user id.
func IssueAccessToken(secret []byte, userID string, ttl time.Duration) (string, error) {
	now := time.Now()
	claims := AccessClaims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			Issuer:    "us-api",
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(secret)
}

// VerifyAccessToken validates a token and returns its subject (user id).
func VerifyAccessToken(secret []byte, tokenStr string) (string, error) {
	claims := &AccessClaims{}
	token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return secret, nil
	})
	if err != nil {
		return "", err
	}
	if !token.Valid || claims.Subject == "" {
		return "", errors.New("invalid token")
	}
	return claims.Subject, nil
}
