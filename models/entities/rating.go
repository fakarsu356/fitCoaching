package entities

import "time"

type Rating struct {
	ID          uint      `gorm:"primaryKey;not null"`
	StudentID   uint      `gorm:"not null;index"`
	CoachID     uint      `gorm:"not null;index"`
	Score       int       `gorm:"check:score >= 1 AND score <= 5"`
	Description string    `gorm:"size:256"`
	CreateTime  time.Time `gorm:"not null;type:datetime"`
}
