package models

import (
	"time"

	"fitcoaching/models/entities"
)

// StudentM frontend'e dönen öğrenci modelidir.
// entities.Student doğrudan döndürülmüyor: içindeki entities.User'ın json
// tag'i olmadığı için PasswordHash da serialize edilirdi.
type StudentM struct {
	UserID        uint             `json:"user_id"`
	Username      string           `json:"username"`
	Email         string           `json:"email,omitempty"`
	Gender        entities.Genders `json:"gender,omitempty"`
	Age           uint             `json:"age"`
	BodyWeight    float64          `json:"body_weight"`
	FatPercentage float64          `json:"fat_percentage"`
	BodyHeight    float64          `json:"body_height"`
}

func NewStudentM(student entities.Student) StudentM {
	return StudentM{
		UserID:        student.UserID,
		Username:      student.User.Username,
		Email:         student.User.Email,
		Gender:        student.User.Gender,
		Age:           student.Age,
		BodyWeight:    student.BodyWeight,
		FatPercentage: student.FatPercentage,
		BodyHeight:    student.BodyHeight,
	}
}

// PendingRequestM koça gelen bağlanma isteğidir.
//
// İsteği gönderen öğrencinin adı da taşınıyor: koç kartta yalnızca kimlik
// numarası görüyordu, kimin isteğini onayladığını bilemiyordu.
type PendingRequestM struct {
	ID            uint                   `json:"id"`
	StudentID     uint                   `json:"student_id"`
	StudentName   string                 `json:"student_name"`
	StudentEmail  string                 `json:"student_email,omitempty"`
	Status        entities.RequestStatus `json:"status"`
	RequestedTime time.Time              `json:"requested_time"`
	DeletedTime   *time.Time             `json:"deleted_time,omitempty"`
}

func NewPendingRequestM(relation entities.Relation) PendingRequestM {
	return PendingRequestM{
		ID:            relation.ID,
		StudentID:     relation.StudentID,
		StudentName:   relation.Student.Username,
		StudentEmail:  relation.Student.Email,
		Status:        relation.Status,
		RequestedTime: relation.RequestedTime,
		DeletedTime:   relation.DeletedTime,
	}
}
