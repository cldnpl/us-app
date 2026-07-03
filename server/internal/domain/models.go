package domain

import "time"

// User is a single account. Email/AvatarPath/Birthday are optional.
type User struct {
	ID          string     `json:"id"`
	Email       *string    `json:"email,omitempty"`
	DisplayName string     `json:"displayName"`
	AvatarPath  *string    `json:"avatarPath,omitempty"`
	Birthday    *time.Time `json:"birthday,omitempty"`
	CreatedAt   time.Time  `json:"createdAt"`
}

// Couple links exactly two users together.
type Couple struct {
	ID        string     `json:"id"`
	StartDate *time.Time `json:"startDate,omitempty"`
	Status    string     `json:"status"`
	CreatedAt time.Time  `json:"createdAt"`
	Members   []User     `json:"members,omitempty"`
}

// Device is a registered push target for a user.
type Device struct {
	ID          string    `json:"id"`
	Platform    string    `json:"platform"`
	Environment string    `json:"environment"`
	CreatedAt   time.Time `json:"createdAt"`
}

// MissYouEvent records one "miss you" tap.
type MissYouEvent struct {
	ID        string    `json:"id"`
	SenderID  string    `json:"senderId"`
	Kind      string    `json:"kind"`
	CreatedAt time.Time `json:"createdAt"`
}
