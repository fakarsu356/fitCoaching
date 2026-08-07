package entities

type Student struct {
	UserID        uint    `gorm:"primaryKey;not null"`
	User          User    `gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE;"`
	Age           uint    `gorm:"check:age >= 5 AND age <= 50;not null"`
	BodyWeight    float64 `gorm:"check:body_weight > 0.0 AND body_weight < 300.0;not null"`
	FatPercentage float64 `gorm:"check:fat_percentage > 0.0 AND fat_percentage < 50.0;not null"`
	BodyHeight    float64 `gorm:"check:body_height > 0.0 AND body_height < 250.00;not null"`
}
