package entities

type Coach struct {
	UserID      uint        `gorm:"primaryKey;not null"`
	User        User        `gorm:"foreignKey:UserID;not null"`
	Speciality  string      `gorm:"size:64;type:varchar(64);not null"`
	MaxStudents int         `gorm:"default:10;check:max_students < 20;not null"`
	Status      CoachStatus `gorm:"default:free;check:status IN ('full','free')"`
}

type CoachStatus string

const (
	Free CoachStatus = "free"
	Full CoachStatus = "full"
)
