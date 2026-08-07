package entities

import "time"

type RefreshToken struct {
	ID        uint      `gorm:"primaryKey;auto_increment"`
	UserID    uint      `gorm:"not null;index"`
	User      User      `gorm:"foreignKey:UserID"`
	Token     string    `gorm:"not null;unique"`
	ExpiresAt time.Time `gorm:"type:datetime;not null"`
}
