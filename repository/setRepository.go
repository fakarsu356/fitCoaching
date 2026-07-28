package repository

import (
	"fitcoaching/models/entities"

	"gorm.io/gorm"
)

type SetRepository struct {
	db *gorm.DB
}

func SetCons(db *gorm.DB) SetRepository {
	return SetRepository{db: db}
}
func (r *SetRepository) Create(set *entities.Set) error {

	return r.db.Create(&set).Error

}

func (r *SetRepository) Update(set entities.Set) error {

	return r.db.Model(&set).Updates(&set).Error
}

func (r *SetRepository) Delete(id int) error {
	return r.db.Delete(&entities.Set{}, id).Error

}

func (r *SetRepository) GetById(id int) (entities.Set, error) {
	var set entities.Set
	dbReturn := r.db.First(&set, id)

	return set, dbReturn.Error

}
func (r *SetRepository) FindByWorkoutID(workoutID uint) ([]entities.Set, error) {
	var sets []entities.Set

	dbRet := r.db.Where("workout_id=?", workoutID).Find(&sets)

	return sets, dbRet.Error

}
