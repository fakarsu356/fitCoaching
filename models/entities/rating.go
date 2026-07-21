package entities

import "time"

type Rating struct {
	ID          uint
	StudentID   uint
	CoachID     uint
	Score       int    `gorm:"check:score >= 1 AND score <= 5"`
	Description string `gorm:"size:256"`
	CreateTime  time.Time	`gorm:"not null"`
}
