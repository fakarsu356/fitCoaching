package entities

type Coach struct {
	UserID      uint   `gorm:"primaryKey"`
	User        User   `gorm:"foreignKey:UserID;"`
	Specialty   string `gorm:"size:64"      binding:"required"`
	MaxStudents int   `gorm:"default:10"`
	Status      CoachStatus
}

type CoachStatus string

const (
	Free CoachStatus = "free"
	Full CoachStatus = "full"
)
