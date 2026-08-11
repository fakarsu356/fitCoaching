package models

import (
	"fitcoaching/models/entities"
	"time"
)

type WorkoutM struct {
	ID           uint                   `json:"id"`
	CoachID      uint                   `json:"coach_id"`
	StudentID    uint                   `json:"student_id"`
	Date         time.Time              `json:"date"`
	Notes        string                 `json:"notes"`
	Status       entities.WorkoutStatus `json:"status"`
	Generator    bool                   `json:"generator"`
	SourcePlanID *uint                  `json:"source_plan_id,omitempty"`
	Sets         []SetM                 `json:"sets"`
}
