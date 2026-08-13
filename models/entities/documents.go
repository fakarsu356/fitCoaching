package entities

import "time"

// type gibi bişey eklenip bu dosya yemek mi yoksa tahlil mi cv mi gibi bir şey yapıp ona göre db den çekebiliriz sor
type Document struct {
	ID         uint      `gorm:"primaryKey;autoIncrement"`
	UploaderID uint      `gorm:"not null;index"`
	UniqueName string    `gorm:"unique;not null"` // hashli kısım
	DocName    string    `gorm:"size:256;not null"`
	Size       float64   `gorm:"not null"`
	Date       time.Time `gorm:"not null;index"`
	Doctype    string    `gorm:"size:32;not null"`  //pdf falan fln
	File       []byte    `gorm:"type:longblob;not null"`
	Type       DocType   `gorm:"size:16;not null;check:type IN ('CV','Sertificate','LabResults','ProgressPictures','MealPictures')"`
}

type DocType string

const (
	CV               DocType = "CV"
	CaochSertificate DocType = "Sertificate"
	HealthResults    DocType = "LabResults"
	ProgressPictures DocType = "ProgressPictures"
	MealPictures     DocType = "MealPictures"
)
