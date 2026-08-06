package entities

import "time"

type Relation struct {
	ID            uint
	StudentID     uint
	Student       User `gorm:"foreign_key:StudentID"`
	CoachID       uint
	Coach         User          `gorm:"foreign_key:CoachID"`
	Status        RequestStatus `gorm:"size:20;default:waiting"`
	RequestedTime time.Time
	DeletedTime   *time.Time
	StartedTime   *time.Time
	EndedTime     *time.Time
}
type RequestStatus string

const (
	StatusWaiting  RequestStatus = "waiting"
	StatusRejected RequestStatus = "rejected"
	StatusActive   RequestStatus = "active"
	StatusExpired  RequestStatus = "expired"
	StatusBreakUp  RequestStatus = "breakup"
)
