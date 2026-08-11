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
	DocType    string    `gorm:"size:32;not null"`
	File       []byte    `gorm:"type:longblob;not null"`
}
