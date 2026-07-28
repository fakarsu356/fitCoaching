package repository

import (
	"fitcoaching/models/entities"
	"time"

	"gorm.io/gorm"
)

type MealRepository struct {
	db *gorm.DB
}

func MealCons(db *gorm.DB) MealRepository {
	return MealRepository{db: db}
}
func (r *MealRepository) Create(meal *entities.Meal) error {

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
func (r *MealRepository) SumByDate(studentID uint, date time.Time) (entities.Meal, error) {
	var meals []entities.Meal
	dbReturn := r.db.Where("student_id=? AND date=?", studentID, date).Find(&meals)
	var Oil float64
	var Kcal float64
	var Protein float64
	for _, meal := range meals {
		Kcal = Kcal + meal.Kcal
		Oil = Oil + meal.Oil
		Protein = Protein + meal.Protein
	}
	meal := entities.Meal{
		StudentID:   studentID,
		MealName:    "",
		Description: "",
		Kcal:        Kcal,
		Oil:         Oil,
		Protein:     Protein,
		Date:        date,
	}

	return meal, dbReturn.Error

}

// her bir kayıta bakmak saçma olabilir oyüzden her günün bir ortalamsı dönülüyor
// biraz saçma oldu
func (r *MealRepository) GetALlMealsByDate(studentID uint, startDate time.Time, endDate time.Time) ([]entities.Meal, error) {
	var meals []entities.Meal
	dbReturn := r.db.Select("date, SUM(student_id) as studentID SUM(kcal) as Kcal, SUM(protein) as Protein, SUM(oil) as Oil").
		Where("student_id = ? AND date BETWEEN ? AND ?", studentID, startDate, endDate).
		Group("date").Scan(&meals)
	studentId := int(studentID)
	for _, meal := range meals {
		meal.StudentID = uint(studentId / len(meals))
	}
	return meals, dbReturn.Error
}

// enes abiye bu seçmeli dersleri göster hangilerini seçmeliyim diye
