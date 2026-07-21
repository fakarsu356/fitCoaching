package repository

import (
	"fitcoaching/models/entities"

	"gorm.io/gorm"
)

type UserRepository struct {
	db *gorm.DB
}

func UserCons(db *gorm.DB) *UserRepository {
	return &UserRepository{db: db}
}
func (r *UserRepository) Create(user *entities.User)(*entities.User, error) {
	err:=r.db.Create(user).Error
	return user, err

}

func (r *UserRepository) Update(user entities.User) error {

	return r.db.Model(&user).Updates(&user).Error
}

func (r *UserRepository) Delete(id int) error {
	return r.db.Delete(&entities.User{}, id).Error

}

func (r *UserRepository) GetById(id int) ( entities.User ,error) {
var user entities.User
	 dbReturn := r.db.First(&user,id)
	  
	 return  user,dbReturn.Error

}
func (r *UserRepository) Findemail(email string) (string,error){

	var Email string
	dbRet:=r.db.Where("email=?",email).First(Email)
		return Email,dbRet.Error
	
}
func (r *UserRepository) HashedPassword(id int) (string,error){
var user entities.User
	dbRet:=r.db.Where("id=?",id).Find(&user)
		return user.PasswordHash,dbRet.Error
	
}
func (r *UserRepository) FindByUsername(name string) (entities.User,error){
var user entities.User
	dbRet:=r.db.Where("username=?",name).Find(&user)
		return user,dbRet.Error
	
}
