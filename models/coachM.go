package models

import (
	"fitcoaching/models/entities"
)

// CoachM frontend'e dönen koç modelidir.
// entities.Coach doğrudan döndürülmüyor: içindeki entities.User'ın json tag'i
// olmadığı için PasswordHash da serialize edilirdi.
type CoachM struct {
	UserID         uint                 `json:"user_id"`
	Username       string               `json:"username"`
	Email          string               `json:"email,omitempty"`
	Gender         entities.Genders     `json:"gender"`
	Speciality     string               `json:"speciality"`
	MaxStudents    int                  `json:"max_students"`
	ActiveStudents int                  `json:"active_students"`
	Status         entities.CoachStatus `json:"status"`
	Rating         *float64             `json:"rating,omitempty"`
	RatingCount    *float64             `json:"rating_count,omitempty"`
	CoachDoc       []entities.Document  `json:"documents,omitempty"`
}

func NewCoachM(coach entities.Coach, user entities.User, activeStudents int) CoachM {
	return CoachM{
		UserID:         coach.UserID,
		Username:       user.Username,
		Email:          user.Email,
		Gender:         user.Gender,
		Speciality:     coach.Speciality,
		MaxStudents:    coach.MaxStudents,
		ActiveStudents: activeStudents,
		Status:         coach.Status,
	}
}
