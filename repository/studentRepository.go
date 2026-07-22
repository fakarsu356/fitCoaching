package repository

import (
	"fitcoaching/models/entities"

	"gorm.io/gorm"
)

type StudentRepository struct {
	db *gorm.DB
}

func StudentCons(db *gorm.DB) *StudentRepository {

	return &StudentRepository{db: db}
}
func (r *StudentRepository) Create(student *entities.Student) error {

	return r.db.Create(&student).Error
}

func (r *StudentRepository) Update(student entities.Student) error {

	return r.db.Model(&student).Updates(&student).Error
}

func (r *StudentRepository) Delete(id int) error {
	return r.db.Delete(&entities.Student{}, id).Error

}
func (r *StudentRepository) GetById(id int) (entities.Student,error) {
var student entities.Student
	dbRet:= r.db.Find(&student, id)
	return student,dbRet.Error
}

func (r *StudentRepository) GetByCoachID(id int) ([]entities.Coach, error) {

	coaches := []entities.Coach{}
	dbReturn := r.db.Model(&entities.Coach{}).Where("UserID=?", id).Find(&coaches)
	return coaches, dbReturn.Error

}
func (r *StudentRepository) GetByUserID(userID uint) (entities.User, error) {

	user := entities.User{}
	dbReturn := r.db.First(&user,userID)
	return user, dbReturn.Error
}
