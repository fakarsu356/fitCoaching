package repository

import (
	"fitcoaching/models/entities"

	"gorm.io/gorm"
)

type VerificationCodeRepository struct {
	db *gorm.DB
}

func VerificationCodeCons(db *gorm.DB) VerificationCodeRepository {
	return VerificationCodeRepository{db: db}
}
func (r *VerificationCodeRepository) Create(verificationCode *entities.Code) error {

	return r.db.Create(verificationCode).Error

}

func (r *VerificationCodeRepository) Update(verificationCode entities.Code) error {

	return r.db.Model(&verificationCode).Updates(&verificationCode).Error
}

func (r *VerificationCodeRepository) Delete(id int) error {
	return r.db.Delete(&entities.Code{}, id).Error

}

func (r *VerificationCodeRepository) GetById(id int) (entities.Code, error) {
	var verificationCode entities.Code
	dbReturn := r.db.First(&verificationCode, id)

	return verificationCode, dbReturn.Error

}
// Adrese gönderilmiş, henüz kullanılmamış en son kodu döndürür.
// Kullanılmışları eleme burada yapılıyor: aksi hâlde en son kod kullanılmışsa
// sorgu onu getirir ve kullanıcı bir öncekiyle de doğrulama yapamazdı.
func (r *VerificationCodeRepository) FindByEmail(email string) (entities.Code, error) {
	var Code entities.Code

	dbRet := r.db.Model(entities.Code{}).Where("email = ? AND used = ?", email, false).Order("created_at DESC").First(&Code)
	return Code, dbRet.Error

}

// Doğrulanan kodu kullanılmış olarak işaretler; aynı kod ikinci kez kabul
// edilmesin diye kayıt tamamlandıktan hemen sonra çağrılır.
func (r *VerificationCodeRepository) MarkUsed(id uint) error {
	return r.db.Model(&entities.Code{}).Where("id = ?", id).Update("used", true).Error
}

