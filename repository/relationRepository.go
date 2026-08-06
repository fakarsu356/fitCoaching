package repository

import (
	"fitcoaching/models/entities"
	"time"

	"gorm.io/gorm"
)

type RelationRepository struct {
	db *gorm.DB
}

func RelationCons(db *gorm.DB) RelationRepository {
	return RelationRepository{db: db}
}
func (r *RelationRepository) Create(relation *entities.Relation) error {

	return r.db.Create(&relation).Error

}

func (r *RelationRepository) Update(relation *entities.Relation) error {

	return r.db.Model(&relation).Updates(&relation).Error
}

func (r *RelationRepository) Delete(id int) error {
	return r.db.Delete(&entities.Relation{}, id).Error

}

func (r *RelationRepository) GetById(id int) (entities.Relation, error) {
	var relation entities.Relation
	dbReturn := r.db.First(&relation, id)

	return relation, dbReturn.Error

}
func (r *RelationRepository) FindExpiredRequests() ([]entities.Relation, error) {

	var expiredRequests []entities.Relation

	dbRet := r.db.Where("status=? AND expires_at < ?", entities.StatusWaiting, time.Now()).Find(&expiredRequests)

	return expiredRequests, dbRet.Error
}

func (r *RelationRepository) FindStudentRequest(studentID uint) (*entities.Relation, error) { // öğrencinin aktif bir isteği var mı bir koça
	var pendingStudent entities.Relation

	dbRet := r.db.Model(&entities.Relation{}).Where("student_id=? AND status=?", studentID, entities.StatusWaiting).First(&pendingStudent)

	return &pendingStudent, dbRet.Error
}
func (r *RelationRepository) FindCoachRelationFromStudentId(studentID uint) (*entities.Relation, error) { // öğrencinin güncel relationını  bulma
	var active entities.Relation
	dbRet := r.db.Model(&entities.Relation{}).Where("student_id=? AND status = ?", studentID, entities.StatusActive).First(&active)

	return &active, dbRet.Error
}
func (r *RelationRepository) FindActiveByCoach(coachID uint) ([]entities.Student, error) { // koçun aktif öğrencilerini getiriyor
	var relations []entities.Relation
	var students []entities.Student
	var student entities.Student
	dbRet := r.db.Where("coach_id = ? AND status=?", coachID, entities.StatusActive).Find(&relations)
	for _, relation := range relations {
		studentId := relation.StudentID
		r.db.Model(entities.Student{}).Where("student = ?", studentId).Find(&student)
		students = append(students, student)
	}
	return students, dbRet.Error

}

func (r *RelationRepository) FindPendingRequests(coachId uint) ([]entities.Relation, error) {

	var pendingRequests []entities.Relation
	dbRet := r.db.Where("coach_id=?", coachId).Find(&pendingRequests)
	return pendingRequests, dbRet.Error
}

// default time.Time nesnesi ne
func (r *RelationRepository) DoesCoachHaveStudent(coachId uint, studentId uint) bool {
	var relation entities.Relation
	dbRet := r.db.Model(entities.Relation{}).Where("coach_id=?", coachId).Find(&relation)
	if dbRet.Error != nil {
		return false
	}
	if relation.StudentID != studentId {
		return false
	}

	if !relation.StartedTime.Before(time.Now()) {
		return false

	}
	return true

}
func (r *RelationRepository) IsRelaitonActive(coachId uint, studentId uint) bool {
	var relation entities.Relation
	dbRet := r.db.Model(entities.Relation{}).Where("coach_id=? AND student_id=? AND status = ?", coachId, studentId, entities.StatusActive).Find(&relation)
	if dbRet.Error != nil {
		return false
	}
	if relation.StudentID != studentId {
		return false
	}

	if !relation.StartedTime.Before(time.Now()) {
		return false

	}
	return true

}
func (r *RelationRepository) IsRelaitonBreakedUP(coachId uint, studentId uint) bool {
	var relation entities.Relation
	dbRet := r.db.Model(entities.Relation{}).Where("coach_id=? AND status = ?", coachId, entities.StatusBreakUp).Find(&relation)
	if dbRet.Error != nil {
		return false
	}
	if relation.StudentID != studentId {
		return false
	}

	if !relation.StartedTime.Before(time.Now()) {
		return false

	}
	return true
}

func (r *RelationRepository) IsRelaitonWaiting(coachId uint, studentId uint) (*entities.Relation, error) {
	var relation entities.Relation

	dbRet := r.db.Model(entities.Relation{}).Where("coach_id=? AND status = ? ", coachId, entities.StatusWaiting).First(&relation)

	return &relation, dbRet.Error
}
func (r *RelationRepository) GetCoachsStudents(coachId uint) int {
	var number int64
	r.db.Model(entities.Relation{}).Where("coach_id = ? AND status = ?", coachId, entities.StatusActive).Count(&number)
	return int(number)
}
func (r *RelationRepository) GetCoachFromStudenId(studentId uint) (entities.Coach, error) {
	var relation entities.Relation
	var coach entities.Coach

	dbRet := r.db.Model(entities.Relation{}).Where("student_id = ?", studentId).Find(&relation)
	if dbRet.Error != nil {
		return coach, dbRet.Error
	}
	dbRet = r.db.Model(entities.Coach{}).Where("user_id = ?", relation.CoachID).Find(&coach)

	return coach, dbRet.Error
}
