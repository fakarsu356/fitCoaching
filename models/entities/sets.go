package entities

import "time"

type Set struct {
	ID           uint
	WorkoutID    uint    `json:"workout_id"`
	workout      Workout `gorm:"foreign_key:WorkoutID"`
	MovementName string  `gorm:"size:32" json:"movement_name"`
	SetNumber    uint    `json:"set_number"`
	Reps         uint    `json:"reps"`
	Weight       float64 `json:"weight"`
	Date         time.Time
}
