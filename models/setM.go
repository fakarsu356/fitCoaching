package models

import "time"

type SetM struct {
	ID           uint      `json:"id"`
	WorkoutID    uint      `json:"workout_id"`
	MovementName string    `json:"movement_name"`
	SetNumber    uint      `json:"set_number"`
	Reps         uint      `json:"reps"`
	Weight       float64   `json:"weight"`
	Date         time.Time `json:"date"`
}
