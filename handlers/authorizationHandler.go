package handlers

import (
	"errors"
	"fitcoaching/config"
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"fitcoaching/service"
	"fitcoaching/utils"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type Authorization struct {
	UserRep     repository.UserRepository
	StudentRep  repository.StudentRepository
	CoachRep    repository.CoachRepository
	DocumentRep repository.DocumentRepository
	TokenRep    repository.TokenRepository
	CodeRep     repository.VerificationCodeRepository
}

func AuthCons(userRep repository.UserRepository, studentRep repository.StudentRepository,
	coachRep repository.CoachRepository, documentRep repository.DocumentRepository,
	tokenRep repository.TokenRepository, codeRep repository.VerificationCodeRepository) *Authorization {
	auth := &Authorization{}
	auth.UserRep = userRep
	auth.StudentRep = studentRep
	auth.CoachRep = coachRep
	auth.DocumentRep = documentRep
	auth.TokenRep = tokenRep
	auth.CodeRep = codeRep

	return auth
}

func (h *Authorization) SendEMail(c *gin.Context) {
	body := map[string]interface{}{}
	bindErr := c.ShouldBindJSON(&body)
	if bindErr != nil {
		utils.Response(c, utils.ResponseS{
			Status: false,
		})
		return
	}
	email, ok := body["email"].(string)
	if ok == false || email == "" || len(email) > 254 { // RFC 5321 sınırı
		banner := "email is not valid"
		utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
		return
	}
	// user_id istenmiyor: bu uç kayıt öncesinde çağrılıyor, ortada kullanıcı
	// yok. Kod ile kayıt isteği `email` üzerinden eşleştiriliyor.
	validateErr := utils.ValidateEmail(email)
	if validateErr != nil {
		banner := "email is not valid"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	_, dbRet := h.UserRep.FindByEmail(email)
	if dbRet == nil {
		banner := "user already registered"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	code, sendErr := service.SendEmail(email)

	if sendErr != nil {
		log.Printf("SendEMail failed (email=%s): %v", email, sendErr)
		// Boş banner istemcide "Bir hata oluştu, tekrar deneyin" yedek metnine
		// düşüyordu; kullanıcı ne yapacağını bilemiyordu.
		banner := "doğrulama kodu gönderilemedi, birazdan tekrar dene"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	intCode, err := strconv.Atoi(code)
	if err != nil {
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: nil,
		})
		return
	}
	expired := time.Now().Add(5 * time.Minute)
	Code := entities.Code{
		Code:      intCode,
		Email:     email,
		Used:      false,
		CreatedAt: time.Now(),
		ExpiresAt: expired,
	}

	creatErr := h.CodeRep.Create(&Code)
	if creatErr != nil {
		banner := " could not create "
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	banner := "email is sent"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
	})
}
func (h *Authorization) KayitStudent(c *gin.Context) {

	data := map[string]interface{}{}
	bindErr := c.ShouldBindJSON(&data)
	if bindErr != nil {
		utils.Response(c, utils.ResponseS{
			Status: false,
		})
		return
	}
	// Alanlar `ok` ile okunuyor: eksik gelen bir anahtarda type assertion panik
	// atıyordu, istek 500'e düşüyordu. Şimdi düzgün bir hata cevabı dönüyor.
	username, usernameOk := data["name"].(string)
	password, passwordOk := data["password"].(string)
	passwordH, passwordHOk := data["validatePassword"].(string)
	email, emailOk := data["email"].(string)
	ageF, ageOk := data["age"].(float64)
	bodyWeight, bodyWeightOk := data["bodyWeight"].(float64)
	bodyHeight, bodyHeightOk := data["bodyHeight"].(float64)
	genderS, genderOk := data["gender"].(string)
	code, codeOk := data["code"].(string)

	if !usernameOk || !passwordOk || !passwordHOk || !emailOk || !ageOk ||
		!bodyWeightOk || !bodyHeightOk || !genderOk || !codeOk {
		banner := "eksik veya hatalı alan gönderildi"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	// Tek zorunlu olmayan alan; gelmezse 0 kalır.
	// DİKKAT: aşağıdaki `:240` aralık kontrolü 0'ı da reddediyor, yani alan
	// pratikte zorunlu. İstemci "boş bırakabilirsin" diyor, ikisi çelişiyor.
	bodyFatPercentage, _ := data["bodyFatPercentage"].(float64)

	age := int(ageF)
	gender := entities.Genders(genderS)

	if username == "" || password == "" || passwordH == "" || email == "" || age == 0 || bodyWeight == 0 || bodyHeight == 0 || gender == "" {
		banner := "all places are required"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	// e mail i kontrol et
	_, err1 := h.UserRep.Findemail(email)
	if err1 == nil { // burayı sor
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	errM := utils.ValidateEmail(email)
	if errM != nil {
		banner := "email is not valid"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	intCode, convErr := strconv.Atoi(code)
	if convErr != nil {
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: nil,
		})
		return
	}
	realcode, codeErr := h.CodeRep.FindByEmail(email)
	if codeErr != nil {
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: nil,
		})
		return
	}
	if realcode.Code != intCode || realcode.ExpiresAt.Before(time.Now()) {
		banner := " is not valid"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	// 2 şifre eşleşiyomu kontrol et
	if password != passwordH {
		banner := "şifreler eşleşmiyor"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	// öğrenci ile ilgili kontroller
	if age > 50 || age < 10 {
		banner := "doğru değer gir"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	if bodyFatPercentage < 1.00 || bodyFatPercentage > 50.00 {
		banner := "doğru değer gir"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	if bodyWeight > 200 || bodyWeight < 10 {
		banner := "doğru değer gir"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	if bodyHeight > 250 || bodyHeight < 50 {
		banner := "doğru değer gir"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	// şifre standartlara uygun mu kontrol et
	if utils.ValidatePassword(password) != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	hashedBytes, hashErr := utils.PasswordHash(password)
	if hashErr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	password = string(hashedBytes)

	user := entities.User{
		Username:     username,
		PasswordHash: password,
		Email:        email,
		Role:         entities.StudentR,
		CreatedAt:    time.Now(),
		Gender:       entities.Genders(gender),
	}
	realUser, errU := h.UserRep.Create(&user)
	if errU != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	student := entities.Student{
		// User alanı bilerek boş: dolu gönderilirse GORM ilişkili User'ı
		// users tablosuna bir daha yazmaya çalışıyor; UserID yeterli.
		// ? user ı kaldır burdaki eşleştirmeyi kendi mi yapıyor gorm user ile
		UserID:        realUser.ID,
		Age:           uint(age),
		BodyWeight:    bodyWeight,
		FatPercentage: bodyFatPercentage,
		BodyHeight:    bodyHeight,
	}
	errS := h.StudentRep.Create(&student)
	if errS != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	// Kod ancak kayıt tamamlandıktan sonra yakılıyor: doğrulamadan hemen sonra
	// işaretlenseydi, aşağıdaki kontrollerden birine takılan kullanıcı formu
	// düzeltip tekrar denerken yeni kod istemek zorunda kalırdı.
	if usedErr := h.CodeRep.MarkUsed(realcode.ID); usedErr != nil {
		// Kayıt başarılı; kullanıcıya hata dönmenin anlamı yok, sadece iz bırak.
		log.Printf("MarkUsed failed (email=%s, code_id=%d): %v", email, realcode.ID, usedErr)
	}

	banner := "successfully registered"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   nil,
	})
}

func (h *Authorization) KayitCoach(c *gin.Context) {

	username := c.PostForm("username")
	password := c.PostForm("password")
	passwordConfirm := c.PostForm("password_confirm")
	email := c.PostForm("email")
	maxStudentStr := c.PostForm("max_students")
	speciality := c.PostForm("speciality")
	gender := c.PostForm("gender")
	CV, CVerr := c.FormFile("CV")
	code := c.PostForm("code")

	if CVerr != nil {
		banner := "cv is not valid"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	maxStudent, errConv := strconv.Atoi(maxStudentStr)
	if errConv != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	if username == "" || password == "" || passwordConfirm == "" || email == "" || maxStudent == 0 || gender == "" || speciality == "" {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	if passwordConfirm != password {
		banner := "şifreler eşleşmiyor"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	if utils.ValidatePassword(password) != nil {
		banner := "password is not valid"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	hashedBytes, hashErr := utils.PasswordHash(password)
	if hashErr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	errE := utils.ValidateEmail(email)
	if errE != nil {
		banner := "email is not valid "
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	_, err1 := h.UserRep.Findemail(email)
	if err1 == nil {
		banner := "smn already registered with this email"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	if maxStudent < 0 || maxStudent > 20 {
		banner := "geçersiz kontenjan değeri"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	user := entities.User{
		Username:     username,
		PasswordHash: string(hashedBytes),
		Email:        email,
		Role:         entities.CoachR,
		CreatedAt:    time.Now(),
		Gender:       entities.Genders(gender),
	}
	intCode, convErr := strconv.Atoi(code)
	if convErr != nil {
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: nil,
		})
		return
	}
	realcode, codeErr := h.CodeRep.FindByEmail(email)
	if codeErr != nil {
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: nil,
		})
		return
	}
	if realcode.Code != intCode || realcode.ExpiresAt.Before(time.Now()) {
		banner := " is not valid"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	errTransaction := h.UserRep.Db.Transaction(func(tx *gorm.DB) error {

		dbR := tx.Create(&user)

		if dbR.Error != nil {

			return dbR.Error
		}

		coach := entities.Coach{
			UserID: user.ID,
			//		User:        user, // burası doğrumu create edince doğru bir şekilde id li hali atanıyomu direkt *düzenleme: burda user ı db kendi kednine ilişkilendiriyor
			Speciality:  speciality,
			MaxStudents: maxStudent,
			Status:      entities.Free,
		}
		dbCoach := tx.Create(&coach)
		if dbCoach.Error != nil {

			return dbCoach.Error
		}

		form, formErr := c.MultipartForm()
		if formErr != nil {
			return formErr
		}
		keybytes := []byte(os.Getenv("TOP_SECRET"))

		files := form.File["certificates"]
		for _, file := range files {

			if file.Size > config.MaxFileSize {

				return errors.New("file size too big")
			}

			bytesf, errHH := file.Open()
			if errHH != nil {
				return errHH
			}

			defer bytesf.Close()

			bytes, errH := io.ReadAll(bytesf)
			if errH != nil {
				return errH
			}

			contentType := http.DetectContentType(bytes)
			if !config.AllowedTypes[contentType] {
				return errors.New("file type is not allowed")
			}
			str := strconv.FormatUint(uint64(coach.UserID), 10)

			fileDbName := str + "_" + strconv.FormatInt(time.Now().UnixNano(), 10)

			hashedDoc, hashError := utils.Encrypt(bytes, keybytes)
			if hashError != nil {

				return hashError
			}

			document := entities.Document{
				UploaderID: coach.UserID,
				UniqueName: fileDbName,
				DocName:    file.Filename,
				Size:       float64(file.Size),
				Date:       time.Now(),
				DocType:    contentType,
				File:       hashedDoc,
				Type:       entities.CaochSertificate,
			}
			docdb := tx.Create(&document)
			if docdb.Error != nil {

				return docdb.Error
			}
		}

		if CV.Size > config.MaxFileSize {

			return errors.New("file size too big")
		}

		CVbytesf, CVerrH := CV.Open()
		if CVerrH != nil {

			return CVerrH
		}

		defer CVbytesf.Close()

		CVbytes, CVerrH := io.ReadAll(CVbytesf)
		if CVerrH != nil {

			return CVerrH
		}

		contentType := http.DetectContentType(CVbytes)
		if !config.AllowedTypes[contentType] {

			return errors.New("file type is not allowed")
		}
		str := strconv.FormatUint(uint64(coach.UserID), 10)

		CVDbName := str + "_" + strconv.FormatInt(time.Now().UnixNano(), 10)

		hashedDoc, hashError := utils.Encrypt(CVbytes, keybytes)
		if hashError != nil {

			return hashError
		}

		CVdoc := entities.Document{
			UploaderID: coach.UserID,
			UniqueName: CVDbName,
			DocName:    CV.Filename,
			Size:       float64(CV.Size),
			Date:       time.Now(),
			DocType:    contentType,
			File:       hashedDoc,
			Type:       entities.CV,
		}

		CVdocdb := tx.Create(&CVdoc)
		if CVdocdb.Error != nil {

			return CVdocdb.Error
		}
		return nil
	})

	if errTransaction != nil {
		log.Printf("KayitCoach transaction failed (email=%s): %v", email, errTransaction)
		banner := "documents could not created "
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	// Kod ancak kayıt işlemi (transaction) başarılı bittikten sonra yakılıyor;
	// belge yüklemede geri alınan bir kayıt kodu da harcamasın.
	if usedErr := h.CodeRep.MarkUsed(realcode.ID); usedErr != nil {
		log.Printf("MarkUsed failed (email=%s, code_id=%d): %v", email, realcode.ID, usedErr)
	}

	banner := "Successfully registered"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   nil,
	})

}

func (h *Authorization) LogIn(c *gin.Context) {

	data := map[string]interface{}{}
	bindErr := c.ShouldBindJSON(&data)
	if bindErr != nil {
		utils.Response(c, utils.ResponseS{})
		return
	}

	password, passOK := data["password"].(string)
	email, emailOk := data["email"].(string)
	if passOK != true || emailOk != true {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	errMail := utils.ValidateEmail(email)
	if errMail != nil {
		banner := "mail is not valid"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	errPassord := utils.ValidatePassword(password)
	if errPassord != nil {
		banner := "email veya şifre hatalı"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	dbUser, dbErr := h.UserRep.FindByEmail(email)
	if dbErr != nil {
		banner := "email bulunamadı"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	errB := bcrypt.CompareHashAndPassword([]byte(dbUser.PasswordHash), []byte(password))
	if errB != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	// token kısmı
	str, RtokenError := utils.GenerateRefreshToken()
	if RtokenError != nil {
		banner := "token could not create"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	refreshToken := entities.RefreshToken{
		UserID:    dbUser.ID,
		Token:     str,
		ExpiresAt: time.Now().Add(30 * 24 * time.Hour), // 30 gün
	}
	refErr := h.TokenRep.Create(&refreshToken)
	if refErr != nil {
		banner := "internal err"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	accesstoken, AtokenError := utils.GenerateAccessToken(dbUser.ID, dbUser.Role)
	if AtokenError != nil {
		banner := "token could not create"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	utils.Response(c, utils.ResponseS{
		Status: true,
		Data:   gin.H{"message": "tokens are  created", "accesstoken": accesstoken, "refreshtoken": refreshToken.Token, "role": dbUser.Role},
	})

}
func (h *Authorization) RefreshAccessToken(c *gin.Context) {
	body := map[string]interface{}{}

	bindErr := c.ShouldBindJSON(&body)
	if bindErr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	refreshToken := body["refreshtoken"]
	refreshTokenString, ok := refreshToken.(string)
	if ok != true {
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: nil,
		})
		return
	}

	compRefToken, tokErr := h.TokenRep.FindByToken(refreshTokenString)
	if tokErr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	if compRefToken.ExpiresAt.Before(time.Now()) {
		banner := "try to login again"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	user, err := h.UserRep.GetById(compRefToken.UserID)
	if err != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	newAccessToken, err := utils.GenerateAccessToken(user.ID, user.Role)
	if err != nil {
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: nil,
		})
		return
	}

	banner := "success"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   newAccessToken,
	})

}
