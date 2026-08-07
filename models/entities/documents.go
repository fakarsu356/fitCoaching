package entities

import "time"

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
