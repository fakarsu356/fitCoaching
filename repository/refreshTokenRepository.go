package repository

import (
	"fitcoaching/models/entities"

	"gorm.io/gorm"
)

type TokenRepository struct {
	db *gorm.DB
}

func RefreshTokenCons(db *gorm.DB) TokenRepository {
	return TokenRepository{db: db}
}

func (r *TokenRepository) Create(token *entities.RefreshToken) error {

	return r.db.Create(token).Error
}

func (r *TokenRepository) FindByToken(token string) (entities.RefreshToken, error) {
	var RefreshData entities.RefreshToken
	dbRet := r.db.Model(&entities.RefreshToken{}).Where("token = ?", token).First(&RefreshData)
	return RefreshData, dbRet.Error
}

func (r *TokenRepository) DeleteByUserID(userID uint) error {
	dbRet := r.db.Model(&entities.RefreshToken{}).Where("user_id = ?", userID).Delete(&entities.RefreshToken{})
	return dbRet.Error
}
