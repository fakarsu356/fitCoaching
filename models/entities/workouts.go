package entities

import "time"

type Workout struct {
	ID           uint // auto increment  // type foreign
	CoachID      uint
	Co           User `gorm:"foreignkey:id"`
	StudentID    uint
	Date         time.Time
	Notes        string        `gorm:"size:200"`
	Generator    bool          //eğer true ise öğrenci
	SourcePlanID *uint         //koçun gireceği antrenman verisinde burası nil olur
	Status       WorkoutStatus `gorm:"size:10;default:waiting"`
}
type WorkoutStatus string

const (
	WorkoutWaiting  WorkoutStatus = "waiting"
	WorkoutRejected WorkoutStatus = "rejected"
	WorkoutDone     WorkoutStatus = "done"
)
