package entities

import "time"

type Workout struct {
	ID           uint          `gorm:"primaryKey;auto_increment"`
	CoachID      uint          `gorm:"not null;index"`
	Coach        User          `gorm:"foreignKey:CoachID"`
	StudentID    uint          `gorm:"not null;type:int;index"`
	Student      User          `gorm:"foreignKey:StudentID"`
	Date         time.Time     `gorm:"type:datetime;not null"`
	Notes        string        `gorm:"size:200;type:text"`
	Generator    bool          `gorm:"not null;default:false"` //eğer true ise öğrenci
	SourcePlanID *uint         `gorm:"column:source_plan_id"`  //koçun gireceği antrenman verisinde burası nil olur
	Status       WorkoutStatus `gorm:"size:10;default:waiting;check:status IN ('waiting','done','rejected')"`
}
type WorkoutStatus string

const (
	WorkoutWaiting  WorkoutStatus = "waiting"
	WorkoutRejected WorkoutStatus = "rejected"
	WorkoutDone     WorkoutStatus = "done"
)
