package repository

import (
	"fitcoaching/models/entities"

	"gorm.io/gorm"
)

type StudentRepository struct {
	db *gorm.DB
}

func StudentCons(db *gorm.DB) StudentRepository {

	return StudentRepository{db: db}
}
func (r *StudentRepository) Create(student *entities.Student) error {

	// student zaten pointer; &student ile **Student gönderilirse GORM
	// "unsupported data type" hatası veriyor.
	return r.db.Create(student).Error
}

func (r *StudentRepository) Update(student entities.Student) error {

	return r.db.Model(&student).Updates(&student).Error
}

func (r *StudentRepository) Delete(id int) error {
	return r.db.Delete(&entities.Student{}, id).Error

}
func (r *StudentRepository) GetById(id uint) (entities.Student, error) {
	var student entities.Student
	dbRet := r.db.Find(&student, id)
	return student, dbRet.Error
}

func (r *StudentRepository) GetCoachsStudents(id uint) ([]entities.Coach, error) {

	coaches := []entities.Coach{}
	dbReturn := r.db.Model(&entities.Coach{}).Where("user_id=?", id).Find(&coaches)
	return coaches, dbReturn.Error

}
func (r *StudentRepository) GetByUserID(userID uint) (entities.User, error) {

	user := entities.User{}
	dbReturn := r.db.First(&user, userID)
	return user, dbReturn.Error
}
func (r *StudentRepository) GetLastCoach(studentId uint) (entities.Coach, error) {
	rel := entities.Relation{}
	coach := entities.Coach{}
	dbRet := r.db.Model(&entities.Relation{}).Where("student_id = ? AND  status = ?", studentId, entities.StatusBreakUp).Order(" ended_time DESC").First(&rel)
	if dbRet.Error != nil {
		return coach, dbRet.Error
	}
	coachId := rel.CoachID
	dbRet = r.db.Model(&entities.Coach{}).Where("user_id = ?", coachId).First(&coach)

	return coach, dbRet.Error
}

// CLAUDE: mevcut GetById'ye dokunulmadı — o Find kullanıyor ve kayıt
// bulunamayınca hata döndürmüyor; workoutHandler.go:84 ve :176 buna yaslanmış.
func (r *StudentRepository) GetByIdWithUser(id uint) (entities.Student, error) {
	var student entities.Student
	dbRet := r.db.Preload("User").First(&student, id)
	return student, dbRet.Error
}
