package entities

import "time"

type Relation struct {
	ID            uint          `gorm:"primaryKey;not null"`
	StudentID     uint          `gorm:"not null;index"`
	Student       User          `gorm:"foreignKey:StudentID"`
	CoachID       uint          `gorm:"not null;index"`
	Coach         User          `gorm:"foreignKey:CoachID"`
	Status        RequestStatus `gorm:"check:status IN ('waiting','rejected','active','expired','breakup');size:20;default:waiting"`
	RequestedTime time.Time     `gorm:"type:datetime"`
	DeletedTime   *time.Time    `gorm:"type:datetime"`
	StartedTime   *time.Time    `gorm:"type:datetime"`
	EndedTime     *time.Time    `gorm:"type:datetime"`
}
type RequestStatus string

const (
	StatusWaiting  RequestStatus = "waiting"
	StatusRejected RequestStatus = "rejected"
	StatusActive   RequestStatus = "active"
	StatusExpired  RequestStatus = "expired"
	StatusBreakUp  RequestStatus = "breakup"
)
