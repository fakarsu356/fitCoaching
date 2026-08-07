package entities

import "time"

type Sleep struct {
	ID        uint      `gorm:"primaryKey;not null"`
	StudentID uint      `gorm:"not null;index"`
	BedTime   time.Time `gorm:"type:datetime;not null"`
	WakeTime  time.Time `gorm:"type:datetime;not null"`
}
