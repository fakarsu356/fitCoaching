package entities

import "time"

type Workout struct {
	ID        uint
	CoachID   uint
	StudentID uint
	Date      time.Time `gorm:"not null"`
	Notes     string    `gorm:"size:200"`
}
