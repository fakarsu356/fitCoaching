package config

import (
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"os"
	"sync"
	"time"

	"github.com/resend/resend-go/v3"
)

const (
	// Kodun geçerlilik süresi.
	CodeLifetime = 5 * time.Minute
	// Aynı adrese iki kod arasında beklenmesi gereken süre.
	ResendCooldown = 60 * time.Second
)

// Aynı adrese çok sık kod istendiğinde döner.
var ErrTooSoon = errors.New("verification code was requested too recently")

type VerificationData struct {
	Code      string
	ExpiresAt time.Time
	LastSent  time.Time
}

var (
	mu                sync.RWMutex
	VerificationCodes = make(map[string]VerificationData)
)

// user id email otp status kullanıldımı success se true olcak  created tut expires tut
func SendEmail(email string) error {
	code, codeErr := GenerateCode()
	if codeErr != nil {
		return codeErr
	}

	// Kaydı mail gönderilmeden ÖNCE yaz: aynı anda gelen isteklerin hepsinin
	// bekleme kontrolünü geçmesini engeller. Sadece okuyup sonra yazsaydık
	// 100 eşzamanlı istek 100 mail gönderirdi.
	now := time.Now()
	mu.Lock()
	prev, exists := VerificationCodes[email]
	if exists && now.Sub(prev.LastSent) < ResendCooldown {
		mu.Unlock()
		return ErrTooSoon
	}
	VerificationCodes[email] = VerificationData{
		Code:      code,
		ExpiresAt: now.Add(CodeLifetime),
		LastSent:  now,
	}
	mu.Unlock()

	apiKey := os.Getenv("RESEND_API_KEY")

	client := resend.NewClient(apiKey)

	params := &resend.SendEmailRequest{
		From:    "onboarding@resend.dev",
		To:      []string{email},
		Subject: "Verification Code:" + code,
		Html:    "<p>Congrats on sending your <strong>first email</strong>!</p>",
	}
	_, err := client.Emails.Send(params)
	if err != nil {
		// Mail gitmedi: ayırdığımız kaydı geri al ki kullanıcı beklemeden
		// tekrar deneyebilsin. Bu arada yeni bir kod yazılmışsa dokunma.
		mu.Lock()
		if current, ok := VerificationCodes[email]; ok && current.Code == code {
			delete(VerificationCodes, email)
		}
		mu.Unlock()
		return err
	}

	return nil
}

func VerifyEmail(email, code string) bool {
	mu.Lock()
	defer mu.Unlock()

	data, ok := VerificationCodes[email]
	if !ok {
		return false
	}
	if data.ExpiresAt.Before(time.Now()) {
		delete(VerificationCodes, email)
		return false
	}
	if data.Code != code {
		return false
	}

	delete(VerificationCodes, email)

	return true
}

func GenerateCode() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(900000))
	if err != nil {
		return "", err
	}

	code := n.Int64() + 100000

	return fmt.Sprintf("%06d", code), nil
}
