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

// Milestone is a dated relationship event (first date, anniversary, …).
type Milestone struct {
	ID    string    `json:"id"`
	Title string    `json:"title"`
	Date  time.Time `json:"date"`
	Kind  string    `json:"kind"`
}

// Reunion is a future date to count down to (great for long distance).
type Reunion struct {
	ID         string    `json:"id"`
	Title      string    `json:"title"`
	TargetDate time.Time `json:"targetDate"`
}

// PartnerLocation is the partner's opt-in shared location, or {sharing:false}.
type PartnerLocation struct {
	Sharing     bool       `json:"sharing"`
	Lat         *float64   `json:"lat,omitempty"`
	Lng         *float64   `json:"lng,omitempty"`
	Mode        *string    `json:"mode,omitempty"`
	PartnerName *string    `json:"partnerName,omitempty"`
	UpdatedAt   *time.Time `json:"updatedAt,omitempty"`
}

// PartnerPregnancy is the partner's opt-in shared due date, or {sharing:false}.
// Week, trimester, and countdown are derived on the client.
type PartnerPregnancy struct {
	Sharing     bool       `json:"sharing"`
	DueDate     *time.Time `json:"dueDate,omitempty"`
	PartnerName *string    `json:"partnerName,omitempty"`
	UpdatedAt   *time.Time `json:"updatedAt,omitempty"`
}

// PartnerCycle is the partner's opt-in shared cycle summary, or {sharing:false}.
// Deliberately coarse: a phase, and optionally a day count — never symptoms.
type PartnerCycle struct {
	Sharing      bool       `json:"sharing"`
	Phase        *string    `json:"phase,omitempty"`
	CycleDay     *int       `json:"cycleDay,omitempty"`
	PeriodInDays *int       `json:"periodInDays,omitempty"`
	Note         *string    `json:"note,omitempty"`
	PartnerName  *string    `json:"partnerName,omitempty"`
	UpdatedAt    *time.Time `json:"updatedAt,omitempty"`
}
