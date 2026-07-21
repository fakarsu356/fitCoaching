package entities

type Student struct {
	UserID        uint    `gorm:"primaryKey"`
	User          User    `gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE;"`
	Age           uint    `gorm:"not null"`
	BodyWeight    float32 `gorm:"not null"`
	FatPercentage float32 `gorm:"not null"`
	Gender        gender  `gorm:"not null"`
	BodyHeight    float32 `gorm:"not null"`
}

type Gender string

const (
	female Gender = "female"
	male   Gender = "Male"
)
