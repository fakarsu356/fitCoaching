package entities

type Coach struct {
	UserID      uint   `gorm:"primaryKey"`
	User        User   `gorm:"foreignKey:UserID;"`
	Speciality  string `gorm:"size:64" binding:"required"`
	MaxStudents int    `gorm:"default:10"`
	Status      CoachStatus
	Gender      Gender
}

type CoachStatus string

const (
	Free CoachStatus = "free"
	Full CoachStatus = "full"
)
