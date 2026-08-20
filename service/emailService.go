package service

import (
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"os"
	"github.com/resend/resend-go/v3"
)

// Aynı adrese çok sık kod istendiğinde döner.
var ErrTooSoon = errors.New("verification code was requested too recently")


// user id email otp status kullanıldımı success se true olcak  created tut expires tut
func SendEmail(email string) (string , error) {

	code, codeErr := GenerateCode()
	if codeErr != nil {
		return "",codeErr
	}

	apiKey := os.Getenv("RESEND_API_KEY")
	if apiKey == "" {
		// Anahtar yoksa Resend 401 dönüyor ve hata "email could not send"
		// olarak görünüyordu; sebebi burada açıkça söyleniyor.
		return "", errors.New("RESEND_API_KEY is not set")
	}

	client := resend.NewClient(apiKey)

	params := &resend.SendEmailRequest{
		From: "FitCoaching <onboarding@resend.dev>",
		To:   []string{email},
		// Kod gövdeye taşındı: konuda duruyordu, gövdede ise Resend'in örnek
		// metni ("Congrats on sending your first email!") vardı.
		Subject: "FitCoaching doğrulama kodun",
		Html: "<p>Doğrulama kodun: <strong style=\"font-size:20px\">" + code +
			"</strong></p><p>Kod 5 dakika geçerli. Bu isteği sen yapmadıysan " +
			"bu e-postayı yok sayabilirsin.</p>",
		Text: "Dogrulama kodun: " + code + "\nKod 5 dakika gecerli.",
	}
	_, err := client.Emails.Send(params)
	if err != nil {
		return "", err
	}

	return code, nil
}

func GenerateCode() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(900000))
	if err != nil {
		return "", err
	}

	code := n.Int64() + 100000

	return fmt.Sprintf("%06d", code), nil
}

// handler da bu code expired mı ona bak code u silme dursun
