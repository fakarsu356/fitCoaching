package repository

import (
	"fitcoaching/models/entities"
	"time"

	"gorm.io/gorm"
)

type MealRepository struct {
	db *gorm.DB
}

func MealCons(db *gorm.DB) *MealRepository {
	return &MealRepository{db: db}
}
func (r *MealRepository) Create(meal entities.Meal) error {

	return r.db.Create(&meal).Error

}

func (r *MealRepository) Update(meal entities.Meal) error {

	return r.db.Model(&meal).Updates(&meal).Error
}

func (r *MealRepository) Delete(id int) error {
	return r.db.Delete(&entities.Meal{}, id).Error

}

func (r *MealRepository) GetById(id int) (entities.Meal, error) {
	var meal entities.Meal          
	dbReturn := r.db.First(&meal, id)
	return meal, dbReturn.Error
}
func (r *MealRepository) FindByStudentAndDate(studentID uint, date time.Time) ([]entities.Meal, error) {
	var meals []entities.Meal
	dbReturn := r.db.Where("student_id=? AND date=?", studentID, date).Find(&meals)
	return meals, dbReturn.Error

}
func (r *MealRepository) SumByDate(studentID uint, date time.Time) (totalKcal uint, totalProtein float64, totalOil float64, err error) {
	var meals []entities.Meal
	dbReturn := r.db.Where("student_id=? AND date=?", studentID, date).Find(&meals)
	var Oil float64
	var Kcal uint
	var Protein float64
	for _, meal := range meals {
		Kcal = Kcal + meal.Kcal
		Oil = Oil + meal.Oil
		Protein = Protein + meal.Protein
	}

	return Kcal, Protein, Oil, dbReturn.Error

}
