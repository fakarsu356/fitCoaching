package entities

import "time"

type Document struct {
	ID         uint
	UploaderID uint
	UniqueName string `gorm:"unique_name"` // hashli kısım
	DocName    string `gorm:"size:64"`
	Size       float64
	Date       time.Time `gorm:"not null"`
	DocType    string    `gorm:"doc_type"`
	File       []byte    `gorm:"type:longblob"`	
}
