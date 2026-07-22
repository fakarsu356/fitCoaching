package utils

import (
	"errors"
	"net/mail"
	"os"
	"regexp"

	"github.com/golang-jwt/jwt/v5"
)

func ValidateEmail(email string) error {
	_, err := mail.ParseAddress(email)
	return err
}

func ValidatePassword(password string) error {
	if len(password) < 6 {
		return errors.New("şifre en az 6 karakter olmalı")
	}

	hasLower, _ := regexp.MatchString(`[a-z]`, password)
	if !hasLower {
		return errors.New("şifre en az 1 küçük harf içermeli")
	}

	hasDigit, _ := regexp.MatchString(`[0-9]`, password)
	if !hasDigit {
		return errors.New("şifre en az 1 rakam içermeli")
	}

	hasSpecial, _ := regexp.MatchString(`[!@#$%^&*]`, password)
	if !hasSpecial {
		return errors.New("şifre en az 1 özel karakter içermeli")
	}

	return nil
}

func ValidateToken(tokenStr string) (jwt.MapClaims, error) {

	token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
		return []byte(os.Getenv("JWT_SECRET")), nil
	})
	if err != nil || !token.Valid {
		return nil, errors.New("geçersiz token")
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, errors.New("claims okunamadı")
	}

	return claims, nil
}
