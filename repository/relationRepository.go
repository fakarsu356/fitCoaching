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
func (r *RelationRepository) CoachsStudents(coachID uint) (int64, error) { // koçun öğrencilerini bulmak için
	var relation []entities.Relation
	dbRet := r.db.Model(&entities.Relation{}).Where("coach_id=? AND status=?", coachID, entities.StatusActive).Find(&relation)
	return int64(len(relation)), dbRet.Error
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
func (r *RelationRepository) FindCoachRelationFromStudentId(studentID uint) (*entities.Relation, error) { // öğrencinin güncel koçunu bulma
	var active entities.Relation
	dbRet := r.db.Model(&entities.Relation{}).Where("student_id=? AND status = ?", studentID, entities.StatusActive).First(&active)

	return &active, dbRet.Error
}
func (r *RelationRepository) FindCoachRelationFromCoachId(coachID uint) (*entities.Relation, error) { // koçun id si ile o relation ı getiriyor
	var active entities.Relation
	dbRet := r.db.Model(&entities.Relation{}).Where("coach_id=? AND status = ?", coachID, entities.StatusActive).First(&active)

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

func (r *RelationRepository) DoesCoachHaveStudent(coachId uint, studentId uint) bool {
	var relation entities.Relation
	dbRet := r.db.Model(entities.Relation{}).Where("coach_id=?", coachId).Find(&relation)
	if dbRet.Error != nil {
		return false
	}
	if relation.StudentID != studentId {
		return false
	}
	var t time.Time

	if !relation.StartedTime.Before(time.Now()) || relation.EndedTime != t {
		return false

	}
	return true

}
