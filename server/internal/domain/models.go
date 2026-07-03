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

// Media is a shared gallery item. FileURL/ThumbURL are relative API paths the
// client resolves against the base URL (fetched with the auth header).
type Media struct {
	ID         string    `json:"id"`
	Kind       string    `json:"kind"`
	Caption    *string   `json:"caption,omitempty"`
	UploaderID string    `json:"uploaderId"`
	FileURL    string    `json:"fileUrl"`
	ThumbURL   string    `json:"thumbUrl"`
	CreatedAt  time.Time `json:"createdAt"`
}
