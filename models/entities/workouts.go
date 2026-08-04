package entities

import "time"

type Workout struct {
	ID        uint
	CoachID   uint
	StudentID uint
	Date      time.Time
	Notes     string `gorm:"size:200"`
	Generator bool   //eğer true ise öğrenci
}
