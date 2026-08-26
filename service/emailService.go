package service

import (
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"mime"
	"net/smtp"
	"os"
	"strings"
)

// Aynı adrese çok sık kod istendiğinde döner.
var ErrTooSoon = errors.New("verification code was requested too recently")

// user id email otp status kullanıldımı success se true olcak  created tut expires tut
func SendEmail(email string) (string, error) {

	code, codeErr := GenerateCode()
	if codeErr != nil {
		return "", codeErr
	}

	from := os.Getenv("SMTP_USER")
	// Google uygulama şifresini boşluklu gösteriyor ("abcd efgh ..."),
	// olduğu gibi yapıştırılabilsin diye boşlukları atıyoruz.
	pass := strings.ReplaceAll(os.Getenv("SMTP_PASSWORD"), " ", "")
	if from == "" || pass == "" {
		return "", errors.New("SMTP_USER or SMTP_PASSWORD is not set")
	}

	host := os.Getenv("SMTP_HOST")
	if host == "" {
		host = "smtp.gmail.com"
	}
	port := os.Getenv("SMTP_PORT")
	if port == "" {
		port = "587"
	}

	// Başlıklar CRLF ile ayrılmak zorunda; konudaki Türkçe karakterler için
	// RFC 2047 kodlaması gerekiyor, yoksa istemcide bozuk görünüyor.
	headers := []string{
		"From: FitCoaching <" + from + ">",
		"To: " + email,
		"Subject: " + mime.QEncoding.Encode("utf-8", "FitCoaching doğrulama kodun: "+code),
		"MIME-Version: 1.0",
		`Content-Type: text/html; charset="UTF-8"`,
	}
	msg := strings.Join(headers, "\r\n") + "\r\n\r\n" + verificationHTML(code)

	auth := smtp.PlainAuth("", from, pass, host)
	// 587 + SendMail = otomatik STARTTLS.
	err := smtp.SendMail(host+":587", auth, from, []string{email}, []byte(msg))
	if err != nil {
		return "", err
	}

	return code, nil
}

// CLAUDE: doğrulama e-postasının gövdesi.
// Tablo tabanlı ve satır içi stilli: Gmail/Outlook <style> bloğunu ve flex/grid
// düzeni atıyor, e-postalarda tek güvenilir yol bu. Renkler uygulamanın
// temasından — yeşil #16A34A, açık zemin #F8F9FA, metin #212529.
func verificationHTML(code string) string {
	return `<!DOCTYPE html>
<html lang="tr">
<body style="margin:0;padding:0;background-color:#F8F9FA;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#F8F9FA;padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background-color:#FFFFFF;border:1px solid #E9ECEF;border-radius:12px;overflow:hidden;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;">
          <tr>
            <td style="background-color:#16A34A;padding:20px 28px;">
              <span style="color:#FFFFFF;font-size:18px;font-weight:700;letter-spacing:0.3px;">FitCoaching</span>
            </td>
          </tr>
          <tr>
            <td style="padding:28px;">
              <p style="margin:0 0 6px 0;font-size:17px;font-weight:600;color:#212529;">Doğrulama kodun hazır</p>
              <p style="margin:0 0 20px 0;font-size:14px;line-height:22px;color:#6C757D;">
                Kaydını tamamlamak için aşağıdaki kodu uygulamaya gir.
              </p>

              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#E8F6EE;border:1px solid #16A34A;border-radius:10px;">
                <tr>
                  <td align="center" style="padding:18px 12px;">
                    <span style="font-family:'Courier New',Courier,monospace;font-size:32px;font-weight:700;letter-spacing:8px;color:#15803D;">` + code + `</span>
                  </td>
                </tr>
              </table>

              <p style="margin:20px 0 0 0;font-size:13px;line-height:20px;color:#6C757D;">
                Kod <strong style="color:#212529;">5 dakika</strong> geçerli. Süre dolarsa uygulamadan yeni kod isteyebilirsin.
              </p>
            </td>
          </tr>
          <tr>
            <td style="border-top:1px solid #E9ECEF;padding:16px 28px;background-color:#F8F9FA;">
              <p style="margin:0;font-size:12px;line-height:18px;color:#ADB5BD;">
                Bu isteği sen yapmadıysan bu e-postayı yok sayabilirsin; hesabında hiçbir şey değişmez.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`
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
