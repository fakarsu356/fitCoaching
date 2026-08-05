package repository

import (
	"fitcoaching/models/entities"
	"time"

	"gorm.io/gorm"
)

type WorkoutRepository struct {
	db *gorm.DB
}

func WorkoutCons(db *gorm.DB) WorkoutRepository {
	return WorkoutRepository{db: db}
}
func (r *WorkoutRepository) Create(workout *entities.Workout) (*entities.Workout, error) {

	return workout, r.db.Create(&workout).Error
}

func (r *WorkoutRepository) Update(workout *entities.Workout) error {

	return r.db.Model(&workout).Updates(&workout).Error
}

func (r *WorkoutRepository) Delete(id int) error {

	return r.db.Delete(&entities.Workout{}, id).Error
}

func (r *WorkoutRepository) GetById(id uint) (entities.Workout, error) {
	var workout entities.Workout
	dbReturn := r.db.First(&workout, id)

	return workout, dbReturn.Error
}

func (r *WorkoutRepository) GetStudentsWorkkout(studentId uint) (entities.Workout, error) {
	var workout entities.Workout
	dbReturn := r.db.Model(entities.Workout{}).Where("student_id = ? AND status=? AND generator =?", studentId, entities.WorkoutWaiting, false).Order("date asc").First(&workout)
	return workout, dbReturn.Error
}

func (r *WorkoutRepository) FindByCoachAndStudent(coachID, studentID uint) ([]entities.Workout, error) {
	var workouts []entities.Workout
	dbReturn := r.db.Where("student_id = ? AND coach_id=?", studentID, coachID).Find(&workouts)
	return workouts, dbReturn.Error
} // koç izolasyonu kontrolüyle birlikte, belirli bir öğrencinin antrenmanlarını getirme

func (r *WorkoutRepository) GetWorkoutsByDate(studentID uint, startData time.Time, endDate time.Time) ([]entities.Workout, error) {
	var workouts []entities.Workout
	dbRet := r.db.Where("student_id = ? AND start_date <= ? AND end_date >= ?", studentID, startData, endDate).Find(&workouts)
	return workouts, dbRet.Error
}
func (r *WorkoutRepository) GetWorkoutsByCoach(coachId uint) ([]entities.Workout, error) {
	var workouts []entities.Workout
	dbReturn := r.db.Where("coach_id=?", coachId).Limit(30).Find(&workouts)
	return workouts, dbReturn.Error
}
