package entities

import "time"

type Sleep struct {
	ID         uint
	StudentID uint 
	BedTime   time.Time `gorm:"type:time"`
	WakeTime  time.Time `gorm:"type:time"`
}