package repository

import (
	"fitcoaching/models/entities"

	"gorm.io/gorm"
)

type WorkoutRepository struct {
	db *gorm.DB
}

func WorkoutCons(db *gorm.DB) *WorkoutRepository {
	return &WorkoutRepository{db: db}
}
func (r *WorkoutRepository) Create(workout entities.Workout) error {

	return r.db.Create(&workout).Error
}

func (r *WorkoutRepository) Update(workout entities.Workout) error {

	return r.db.Model(&workout).Updates(&workout).Error
}

func (r *WorkoutRepository) Delete(id int) error {
	return r.db.Delete(&entities.Workout{}, id).Error
}

func (r *WorkoutRepository) GetById(id int) (entities.Workout, error) {
	var workout entities.Workout
	dbReturn := r.db.First(&workout, id)

	return workout, dbReturn.Error
}

func (r *WorkoutRepository) FindByStudent(studentID uint) ([]entities.Workout, error) {
	var workouts []entities.Workout
dbReturn := r.db.Where("student_id = ?", studentID).Find(&workouts)
	return workouts, dbReturn.Error
} // öğrencinin antrenman geçmişini listeleme

func (r *WorkoutRepository) FindByCoachAndStudent(coachID, studentID uint) ([]entities.Workout, error) {
	var workouts []entities.Workout
dbReturn := r.db.Where("student_id = ? AND coach_id=?", studentID,coachID).Find(&workouts)
	return workouts, dbReturn.Error
} // koç izolasyonu kontrolüyle birlikte, belirli bir öğrencinin antrenmanlarını getirme
