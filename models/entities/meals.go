package entities

import "time"

type Meal struct {
	ID          uint      `gorm:"primaryKey;not null"`
	StudentID   uint      `gorm:"not null;index"`
	MealName    string    `gorm:"size:32;not null"`
	Description string    `gorm:"size:128"`
	Kcal        float64   `gorm:"not null;type:decimal(10,2)"`
	Protein     float64   `gorm:"not null;type:decimal(10,2)"`
	Date        time.Time `gorm:"type:datetime;not null"`
	Oil         float64   `gorm:"not null;type:decimal(10,2)"`
	// Karb ve Lif sonradan eklendi; eski kayıtlarda boş kalabilsin diye
	// not null verilmedi, okunduklarında 0 gelirler.
	Karb float64 `gorm:"type:decimal(10,2)"`
	Lif  float64 `gorm:"type:decimal(10,2)"`
}
