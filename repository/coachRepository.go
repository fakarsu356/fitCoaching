package repository

import (
	"fitcoaching/models/entities"

	"gorm.io/gorm"
)

type CoachRepository struct {
	db *gorm.DB
}

func CoachCons(db *gorm.DB) CoachRepository {
	return CoachRepository{db: db}
}
func (r *CoachRepository) Create(coach *entities.Coach) error {

	return r.db.Create(&coach).Error

}

func (r *CoachRepository) Update(coach *entities.Coach) error {

	return r.db.Model(&coach).Updates(&coach).Error
}

func (r *CoachRepository) Delete(id int) error {
	return r.db.Delete(&entities.Coach{}, id).Error

}
func (r *CoachRepository) GetById(id uint) (entities.Coach, error) {
	var coach entities.Coach
	dbReturn := r.db.First(&coach, id)

	return coach, dbReturn.Error

}
func (r *CoachRepository) GetActiveCoaches() ([]entities.Coach, error) {
	coaches := []entities.Coach{}
	dbReturn := r.db.Model(&entities.Coach{}).Where("status = ?", entities.Free).Find(&coaches)
	return coaches, dbReturn.Error
}
func (r *CoachRepository) FindByUserID(userID uint) (*entities.Coach, error) {
	var coach entities.Coach
	dbReturn := r.db.Where("user_id=?", userID).Find(coach)

	return &coach, dbReturn.Error
}
func (r *CoachRepository) GetAllFrees() ([]entities.Coach, error) {

	coaches := make([]entities.Coach, 0)
	dbRet := r.db.Preload("User").Where("status = ?", entities.Free).Find(&coaches)

	return coaches, dbRet.Error

}
