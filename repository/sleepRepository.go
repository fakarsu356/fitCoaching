package repository

import (
	"fitcoaching/models/entities"

	"gorm.io/gorm"
)

type SleepRepository struct {
	db *gorm.DB
}

func SleepCons(db *gorm.DB) *SleepRepository {
	return &SleepRepository{db: db}
}

func (r *SleepRepository) Create(sleep entities.Sleep) error {

	return r.db.Create(&sleep).Error

}

func (r *SleepRepository) Update(sleep entities.Sleep) error {

	return r.db.Model(&sleep).Updates(&sleep).Error
}

func (r *SleepRepository) Delete(id int) error {
	return r.db.Delete(&entities.Sleep{}, id).Error

}

func (r *SleepRepository) GetById(id int) (entities.Sleep, error) {
	var sleep entities.Sleep
	dbReturn := r.db.First(&sleep, id)

	return sleep, dbReturn.Error
}

func (r *SleepRepository) FindByStudent(studentID uint) ([]entities.Sleep, error) {
	var sleeps []entities.Sleep

	dbRet := r.db.Where("student_id = ?", studentID).Find(&sleeps)

	return sleeps, dbRet.Error
}
