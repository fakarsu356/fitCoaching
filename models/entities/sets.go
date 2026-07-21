package entities

type Set struct {
	ID           uint
	WorkoutID    uint
	MovementName string `gorm:"size:32"`
	SetNumber    uint
	Reps         uint
	Weight       float32
}
