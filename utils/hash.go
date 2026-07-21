package utils

import( 
	"golang.org/x/crypto/bcrypt"
)
func PasswordHash(password string)([]byte,error){

hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)

return hashedPassword,err
}