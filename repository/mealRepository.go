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
	dayStart := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	dayEnd := dayStart.Add(24 * time.Hour)
	dbReturn := r.db.Where("student_id=? AND date >= ? AND date < ?", studentID, dayStart, dayEnd).Find(&meals)
	var Oil float64
	var Kcal float64
	var Protein float64
	var Karb float64
	var Lif float64
	for _, meal := range meals {
		Kcal = Kcal + meal.Kcal
		Oil = Oil + meal.Oil
		Protein = Protein + meal.Protein
		Karb = Karb + meal.Karb
		Lif = Lif + meal.Lif
	}
	meal := entities.Meal{
		StudentID:   studentID,
		MealName:    "",
		Description: "",
		Kcal:        Kcal,
		Oil:         Oil,
		Protein:     Protein,
		Karb:        Karb,
		Lif:         Lif,
		Date:        date,
	}

	return meal, dbReturn.Error

}

// her bir kayıta bakmak saçma olabilir oyüzden her günün bir ortalamsı dönülüyor
// biraz saçma oldu
// Aralıktaki öğünleri tek tek döndürür; günlük toplam için SumByDate kullanılır.
// Öğün id'si silme işlemi için gerektiğinden burada gruplama yapılmaz.
func (r *MealRepository) GetALlMealsByDate(studentID uint, startDate time.Time, endDate time.Time) ([]entities.Meal, error) {
	meals := make([]entities.Meal, 0)
	dbReturn := r.db.Model(&entities.Meal{}).
		Where("student_id = ? AND date BETWEEN ? AND ?", studentID, startDate, endDate).
		Order("date DESC").
		Find(&meals)
	return meals, dbReturn.Error
}

// enes abiye bu seçmeli dersleri göster hangilerini seçmeliyim diye
