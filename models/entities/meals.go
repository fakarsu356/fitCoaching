package entities

import "time"

type Meal struct {
	ID          uint
	StudentID   uint
	MealName    string  `gorm:"size:32;not null"`
	Description string  `gorm:"size:128"`
	Kcal        float64 `gorm:"not null"`
	Protein     float64
	Date        time.Time
	Oil         float64
}
