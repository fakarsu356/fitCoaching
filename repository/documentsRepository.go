package repository

import (
	"fitcoaching/models/entities"

	"gorm.io/gorm"
)

type DocumentRepository struct {
	db *gorm.DB
}

func DocumentCons(db *gorm.DB) DocumentRepository {
	return DocumentRepository{db: db}
}
func (r *DocumentRepository) Create(document *entities.Document) error {

	return r.db.Create(&document).Error

}

func (r *DocumentRepository) Update(document entities.Document) error {

	return r.db.Model(&document).Updates(&document).Error
}

func (r *DocumentRepository) Delete(id int) error {
	return r.db.Delete(&entities.Document{}, id).Error

}

func (r *DocumentRepository) GetById(id int) (entities.Document, error) {
	var document entities.Document
	dbReturn := r.db.First(&document, id)

	return document, dbReturn.Error

}
func (r *DocumentRepository) FindByUploader(uploaderID uint) ([]entities.Document, error) {
	var documents []entities.Document

	dbRet := r.db.Where("uploader_id=?", uploaderID).Find(&documents)
	return documents, dbRet.Error

}

func (r *DocumentRepository) FindByUploaderAndType(uploaderID uint, docType entities.DocType) ([]entities.Document, error) {
	var documents []entities.Document

	dbRet := r.db.Where("uploader_id=? AND doc_type=? ", uploaderID, docType).Find(&documents)
	return documents, dbRet.Error

}
