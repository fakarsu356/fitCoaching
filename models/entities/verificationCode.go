package entities

import "time"

type Code struct {
	ID        uint      `gorm:"primaryKey;not null"`
	Code      int       `gorm:"not null"`
	Email     string    `gorm:"size:64;type:varchar(64);not null"`
	Used      bool      `gorm:"default:false"`
	CreatedAt time.Time `gorm:"type:datetime;not null"`
	ExpiresAt time.Time `gorm:"type:datetime;not null"`
}
