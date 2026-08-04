package repository

import (
	"fitcoaching/models/entities"

	"gorm.io/gorm"
)

type RatingRepository struct {
	db *gorm.DB
}

func RatingCons(db *gorm.DB) RatingRepository {
	return RatingRepository{db: db}
}
func (r *RatingRepository) Create(rating entities.Rating) error {

	return r.db.Create(&rating).Error

}

func (r *RatingRepository) Update(rating entities.Rating) error {

	return r.db.Model(&rating).Updates(&rating).Error
}

func (r *RatingRepository) Delete(id int) error {
	return r.db.Delete(&entities.Rating{}, id).Error

}

func (r *RatingRepository) GetById(id int) (entities.Rating, error) {
	var rating entities.Rating
	dbReturn := r.db.First(&rating, id)

	return rating, dbReturn.Error

}

func (r *RatingRepository) FindByStudentAndCoach(studentID, coachID uint) (*entities.Rating, error) {
	var rating entities.Rating
	dbRet := r.db.Where("student_id = ? AND coach = ?", studentID, coachID).First(&rating)
	return &rating, dbRet.Error
} // bu öğrenci bu koça daha önce puan vermiş mi" kontrolü

func (r *RatingRepository) AverageByCoach(coachID uint) (float64, error) {
	var ratings []entities.Rating
	dbRet := r.db.Model(entities.Rating{}).Where(" coach_id = ?", coachID).Find(&ratings)
	var totalPuan int
	temp := 0
	for _, puan := range ratings {
		totalPuan = totalPuan + puan.Score
		temp++
	}
	if temp == 0 {
		return -1, dbRet.Error
	}
	avrg := totalPuan / temp
	return float64(avrg), dbRet.Error
}
