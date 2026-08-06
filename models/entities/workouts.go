package entities

import "time"

type Workout struct {
	ID           uint `gorm:"primary_key"` //default
	CoachID      uint `json:"coach_id"`
	Coach        User `gorm:"foreignKey:CoachID"`
	StudentID    uint `json:"student_id"`
	Student      User `gorm:"foreignKey:StudentID"`
	Date         time.Time
	Notes        string        `gorm:"size:200" json:"notes"`
	Generator    bool          //eğer true ise öğrenci
	SourcePlanID *uint         `json:"source_plan_id"` //koçun gireceği antrenman verisinde burası nil olur
	Status       WorkoutStatus `gorm:"size:10;default:waiting"`
}
type WorkoutStatus string

const (
	WorkoutWaiting  WorkoutStatus = "waiting"
	WorkoutRejected WorkoutStatus = "rejected"
	WorkoutDone     WorkoutStatus = "done"
)
