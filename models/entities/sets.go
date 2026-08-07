package entities

import "time"

type Set struct {
	ID           uint      `gorm:"primaryKey;not null"`
	WorkoutID    uint      `gorm:"not null"`
	Workout      Workout   `gorm:"foreignKey:WorkoutID"`
	MovementName string    `gorm:"size:32"`
	SetNumber    uint      `gorm:"not null"`
	Reps         uint      `gorm:"check:reps >= 0 AND reps <= 50;type:int"`
	Weight       float64   `gorm:"not null;check:weight >= 0 AND weight <= 1000"`
	Date         time.Time `gorm:"type:datetime"`
}
