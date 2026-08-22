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

	dbRet := r.db.Where("status=? AND  deleted_time < ?", entities.StatusWaiting, time.Now()).Find(&expiredRequests)

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

	dbRet := r.db.Where("coach_id = ? AND status=?", coachID, entities.StatusActive).Find(&relations)
	if dbRet.Error != nil {
		return nil, dbRet.Error
	}

	for _, relation := range relations {

		var student entities.Student
		found := r.db.Preload("User").Where("user_id = ?", relation.StudentID).First(&student)
		if found.Error != nil {

			continue
		}
		students = append(students, student)
	}
	return students, nil

}
func (r *RelationRepository) FindPendingRequests(coachId uint) ([]entities.Relation, error) { //koçun requestlerini almak için

	var requests []entities.Relation
	// Preload("Student"): isteği gönderen kullanıcının adı gerekiyor, aksi
	// hâlde koç kartta yalnızca kimlik numarası görüyor.
	dbRet := r.db.Preload("Student").Where("coach_id=?", coachId).Find(&requests)
	return requests, dbRet.Error
}

func (r *RelationRepository) FindStudentsRequest(studentId uint) (entities.Relation, error) { //öğrencinin requestini almak için

	var request entities.Relation
	// CLAUDE: "date" diye kolon yok, requested_time olacak (eski hali: Order("date DESC")).
	dbRet := r.db.Where("student_id=?", studentId).Order("requested_time DESC").First(&request)
	return request, dbRet.Error
}

// CLAUDE: elemenin tamamı sorguya taşındı. Struct'a Find yapılınca GORM LIMIT 1
// ekliyor, o yüzden koçun ilk ilişkisi dışındaki öğrenciler bulunamıyordu.
// started_time kontrolü kalktı: alan NULL olabildiği için nil dereference riskliydi.
func (r *RelationRepository) DoesCoachHaveStudent(coachId uint, studentId uint) bool { // koçun bu öğrenciyle şu an aktif bir bağı olup olmadığını söyler.

	var number int64
	dbRet := r.db.Model(&entities.Relation{}).
		Where("coach_id = ? AND student_id = ? AND status = ?", coachId, studentId, entities.StatusActive).
		Count(&number)
	if dbRet.Error != nil {
		return false
	}
	return number > 0
}

// CLAUDE: Find + Go tarafı eleme yerine filtreli Count; nil started_time dereference kalktı.
func (r *RelationRepository) IsRelaitonActive(coachId uint, studentId uint) bool {
	var number int64
	dbRet := r.db.Model(&entities.Relation{}).
		Where("coach_id = ? AND student_id = ? AND status = ?", coachId, studentId, entities.StatusActive).
		Count(&number)
	if dbRet.Error != nil {
		return false
	}
	return number > 0
}

// CLAUDE: eleme sorguda yapılıyor. Struct'a Find yapıldığında GORM sorguya LIMIT 1
// eklediği için, koçun birden fazla kopmuş ilişkisi varsa yalnızca ilki
// yükleniyor ve sorulan öğrenci hiç görünmüyordu. started_time kontrolü de
// kalktı; status zaten ilişkinin başlamış olduğunu söylüyor ve alan NULL
// olabildiği için nil dereference riski taşıyordu.
func (r *RelationRepository) IsRelaitonBreakedUP(coachId uint, studentId uint) bool {
	var number int64
	dbRet := r.db.Model(&entities.Relation{}).
		Where("coach_id = ? AND student_id = ? AND status = ?", coachId, studentId, entities.StatusBreakUp).
		Count(&number)
	if dbRet.Error != nil {
		return false
	}
	return number > 0
}

func (r *RelationRepository) IsRelaitonWaiting(coachId uint, studentId uint) (*entities.Relation, error) {
	var relation entities.Relation

	dbRet := r.db.Model(entities.Relation{}).Where("coach_id=? AND student_id =? AND status = ?", coachId, studentId, entities.StatusWaiting).First(&relation)

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

	dbRet := r.db.Model(entities.Relation{}).Where("student_id = ? AND status = ?", studentId, entities.StatusActive).Find(&relation)
	if dbRet.Error != nil {
		return coach, dbRet.Error
	}
	dbRet = r.db.Model(entities.Coach{}).Where("user_id = ?", relation.CoachID).Find(&coach)

	return coach, dbRet.Error
}
