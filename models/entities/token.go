package entities

import "time"

type RefreshToken struct {
	ID        uint
	UserID    uint
	Token     string
	ExpiresAt time.Time
}
