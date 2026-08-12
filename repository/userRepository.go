package repository

import (
	"fitcoaching/models/entities"

	"gorm.io/gorm"
)

type UserRepository struct {
	Db *gorm.DB
}

func UserCons(db *gorm.DB) UserRepository {
	return UserRepository{Db: db}
}
func (r *UserRepository) Create(user *entities.User) (*entities.User, error) {
	err := r.Db.Create(user).Error
	return user, err

}

func (r *UserRepository) Update(user entities.User) error {

	return r.Db.Model(&user).Updates(&user).Error
}

func (r *UserRepository) Delete(id int) error {
	return r.Db.Delete(&entities.User{}, id).Error

}

func (r *UserRepository) GetById(id uint) (entities.User, error) {
	var user entities.User
	dbReturn := r.Db.First(&user, id)

	return user, dbReturn.Error
}
func (r *UserRepository) Findemail(email string) (string, error) {

	var Email string
	dbRet := r.Db.Where("email=?", email).First(Email)
	return Email, dbRet.Error

}
func (r *UserRepository) HashedPassword(id int) (string, error) {
	var user entities.User
	dbRet := r.Db.Where("id=?", id).Find(&user)
	return user.PasswordHash, dbRet.Error

}
func (r *UserRepository) FindByUsername(name string) (entities.User, error) {
	var user entities.User
	dbRet := r.Db.Where("username=?", name).Find(&user)
	return user, dbRet.Error

}
func (r *UserRepository) FindByEmail(email string) (entities.User, error) {
	var user entities.User
	dbRet := r.Db.Where("email= ?", email).First(&user)
	return user, dbRet.Error
}
func (r *UserRepository) GetRoleById(id uint) (entities.Role, error) {
	var user entities.User
	dbRet := r.Db.Where("id= ?", id).First(&user)
	return user.Role, dbRet.Error
}
