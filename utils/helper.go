package utils

import (
	"errors"
	"net/mail"
	"regexp"
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

	hasSpecial, _ := regexp.MatchString(`[.!@#$%^&*]`, password)
	if !hasSpecial {
		return errors.New("şifre en az 1 özel karakter içermeli")
	}

	return nil
}
