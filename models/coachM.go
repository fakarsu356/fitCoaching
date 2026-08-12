package models

import "fitcoaching/models/entities"

// CoachM frontend'e dönen koç modelidir.
// entities.Coach doğrudan döndürülmüyor: içindeki entities.User'ın json tag'i
// olmadığı için PasswordHash da serialize edilirdi.
type CoachM struct {
	UserID         uint   `json:"user_id"`
	Username       string `json:"username"`
	Email          string `json:"email"`
	Gender         string `json:"gender"`
	Speciality     string `json:"speciality"`
	MaxStudents    int    `json:"max_students"`
	ActiveStudents int    `json:"active_students"`
	Status         string `json:"status"`
}

func NewCoachM(coach entities.Coach, user entities.User, activeStudents int) CoachM {
	return CoachM{
		UserID:         coach.UserID,
		Username:       user.Username,
		Email:          user.Email,
		Gender:         string(user.Gender),
		Speciality:     coach.Speciality,
		MaxStudents:    coach.MaxStudents,
		ActiveStudents: activeStudents,
		Status:         string(coach.Status),
	}
}
