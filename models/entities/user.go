package entities

import (
	"time"
)

type User struct {
	ID           uint      `gorm:"primaryKey;autoIncrement"`
	Username     string    `gorm:"size:32;not null"`
	PasswordHash string    `gorm:"not null;size:128"`
	Email        string    `gorm:"size:100;unique;not null"`
	Role         Role      `gorm:"size:8;not null"`
	CreatedAt    time.Time `gorm:"type:datetime;not null"`
	Gender       Genders   `gorm:"check:gender IN ('Male','Female');not null"`
}
type Role string

const (
	StudentR Role = "Student"
	CoachR   Role = "Coach"
)

type Genders string

const (
	female Genders = "Female"
	male   Genders = "Male"
)
