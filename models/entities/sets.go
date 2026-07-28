package entities

import "time"

type Set struct {
	ID           uint
	WorkoutID    uint
	MovementName string `gorm:"size:32"`
	SetNumber    uint
	Reps         uint
	Weight       float64
	Date         time.Time
}
