package handlers

import (
	"fitcoaching/config"
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"fitcoaching/utils"
	"io"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

type Authorization struct {
	UserRep     repository.UserRepository
	StudentRep  repository.StudentRepository
	CoachRep    repository.CoachRepository
	DocumentRep repository.DocumentRepository
}

func AuthHandler(userRep repository.UserRepository, studentRep repository.StudentRepository,
	coachRep repository.CoachRepository, documentRep repository.DocumentRepository) *Authorization {
	auth := &Authorization{}
	auth.UserRep = userRep
	auth.StudentRep = studentRep
	auth.CoachRep = coachRep
	auth.DocumentRep = documentRep

	return auth
}

func (h *Authorization) KayitStudent(c *gin.Context) {

	data := map[string]interface{}{}
	c.ShouldBindJSON(&data)
	username := data["name"].(string)
	password := data["password"].(string)
	passwordH := data["validatePassword"].(string)
	email := data["email"].(string)
	age := int(data["age"].(float64))
	bodyFatPercentage := data["bodyFatPercentage"].(float64)
	bodyWeight := data["bodyWeight"].(float64)
	bodyHeight := data["bodyHeight"].(float64)
	gender := entities.Gender(data["gender"].(string))

	if username == "" || password == "" || passwordH == "" || email == "" || age == 0 || bodyFatPercentage == 0 || bodyWeight == 0 || bodyHeight == 0 || gender == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "all places are required"})
		return
	}
	// e mail i kontrol et
	_, err1 := h.UserRep.Findemail(email)
	if err1 == nil { // burayı sor
		c.JSON(http.StatusBadRequest, " hata ")
		return
	}
	errM := utils.ValidateEmail(email)
	if errM != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "email is not valid"})
		return
	}

	// 2 şifre eşleşiyomu kontrol et
	if password != passwordH {
		c.JSON(http.StatusBadRequest, gin.H{"error": "şifreler eşleşmiyor "})
		return
	}

	// öğrenci ile ilgili kontroller
	if age > 50 || age < 10 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "doğru değer gir "})
		return
	}
	if bodyFatPercentage < 1.00 || bodyFatPercentage > 50.00 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "doğru değer gir "})
		return
	}
	if bodyWeight > 200 || bodyWeight < 10 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "doğru değer gir "})
		return
	}
	if bodyHeight > 250 || bodyHeight < 50 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "doğru değer gir "})
		return
	}

	// şifre standartlara uygun mu kontrol et
	if utils.ValidatePassword(password) != nil {
		c.JSON(http.StatusBadRequest, utils.ValidatePassword(password).Error())
		return
	}
	hashedBytes, hashErr := utils.PasswordHash(password)
	if hashErr != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "hashlenemedi"}) // c.JSON(http.StatusBadRequest, gin.H{"error": "hashlenemedi"})  bu 2 sinin farkı ne

		return
	}
	password = string(hashedBytes)

	user := entities.User{
		Username:     username,
		PasswordHash: password,
		Email:        email,
		Role:         entities.StudentR,
		CreatedAt:    time.Now(),
	}
	realUser, errU := h.UserRep.Create(&user)
	if errU != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": errU.Error()})
		return
	}
	student := entities.Student{
		UserID:        realUser.ID,
		User:          *realUser,
		Age:           uint(age),
		BodyWeight:    bodyWeight,
		FatPercentage: bodyFatPercentage,
		Gender:        entities.Gender(gender),
		BodyHeight:    bodyHeight,
	}
	errS := h.StudentRep.Create(&student)
	if errS != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": errS.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "kayıt başarılı"})
}

func (h *Authorization) KayitCoach(c *gin.Context) {

	username := c.PostForm("username")
	password := c.PostForm("password")
	passwordConfirm := c.PostForm("password_confirm")
	email := c.PostForm("email")
	maxStudentStr := c.PostForm("max_students")
	speciality := c.PostForm("speciality")
	gender := c.PostForm("gender")

	maxStudent, errConv := strconv.Atoi(maxStudentStr)
	if errConv != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "string dönüştürülemedi "})
		return
	}

	if username == "" || password == "" || passwordConfirm == "" || email == "" || maxStudent == 0 || gender == "" || speciality == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "all places are required"})
		return
	}
	// 2 şifre eşleşiyomu kontrol et
	if passwordConfirm != password {
		c.JSON(http.StatusBadRequest, "şifreler eşleşmiyor")
		return
	}
	// şifre standartlara uygun mu kontrol et
	if utils.ValidatePassword(password) != nil {
		c.JSON(http.StatusBadRequest, utils.ValidatePassword(password).Error())
		return
	}

	hashedBytes, hashErr := utils.PasswordHash(password)
	if hashErr != nil {
		c.JSON(http.StatusBadRequest, "hashlenemedi") // c.JSON(http.StatusBadRequest, gin.H{"error": "hashlenemedi"})  bu 2 sinin farkı ne
		return
	}
	// e mail i kontrol et
	errE := utils.ValidateEmail(email)
	if errE != nil {
		c.JSON(http.StatusBadRequest, " email is not valid")
		return
	}
	_, err1 := h.UserRep.Findemail(email)
	if err1 == nil {
		c.JSON(http.StatusBadRequest, "smn already registered with this email")
		return
	}

	// max student kontrolü

	if maxStudent < 0 || maxStudent > 20 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "geçersiz kontenjan değeri"})
		return
	}

	user := entities.User{
		Username:        username,
		PasswordHash:    string(hashedBytes),
		PasswordConfirm: "",
		Email:           email,
		Role:            entities.CoachR,
		CreatedAt:       time.Now(),
	}
	realUser, errR := h.UserRep.Create(&user)

	if errR != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": errR.Error()})
		return
	}

	coach := entities.Coach{
		UserID:      realUser.ID,
		User:        *realUser,
		Speciality:  speciality,
		MaxStudents: maxStudent,
		Status:      entities.Free,
		Gender:      entities.Gender(gender),
	}
	errCoach := h.CoachRep.Create(&coach)
	if errCoach != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": errCoach.Error()})
		return
	}
	// bu formun işlemleri
	log.Printf("İşlemler devam ediyor")

	form, errF := c.MultipartForm()
	if errF != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "form okunamadı"})
		return
	}

	filesH := form.File["files"] // frontta ki map e atanan fileları getirir
	for _, fileH := range filesH {

		if fileH.Size > config.MaxFileSize {
			c.JSON(http.StatusBadRequest, gin.H{"error": "dosya büyük maksimum 5MB"})
			return
		}
		file, errH := fileH.Open()
		if errH != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "file cant open"})
			return
		}
		defer file.Close()

		//dökümanı okumak için gerekli şeyler
		fileBytes, errD := io.ReadAll(file) //readall belgedeki tüm byteları okuyor ama read kullansak belli bir değere kadar byteokicak

		if errD != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "dosya okunamadı"})
			return
		}

		contentType := http.DetectContentType(fileBytes)
		if !config.AllowedTypes[contentType] {
			c.JSON(http.StatusBadRequest, gin.H{"error": "sadece PDF, JPEG veya PNG kabul edilir"})
			return
		}
		str := strconv.FormatUint(uint64(realUser.ID), 10)

		fileDbName := str + "_" + time.Now().String()

		document := entities.Document{
			UploaderID: realUser.ID,
			UniqueName: fileDbName,
			DocName:    fileH.Filename,
			Size:       float64(fileH.Size),
			Date:       time.Now(),
			DocType:    contentType,
			File:       fileBytes,
		}

		errDoc := h.DocumentRep.Create(&document)
		if errDoc != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "oluşturulamadı doküman"})
			return
		}
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Succesfully registered"})
}

func (h *Authorization) LogIn(c *gin.Context) {
	data := map[string]interface{}{}
	c.ShouldBindJSON(&data)

	password := data["password"].(string)
	email := data["email"].(string)

	errMail := utils.ValidateEmail(email)
	if errMail != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "mail is not valid  "})
		return
	}
	errPassord := utils.ValidatePassword(password)
	if errPassord != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "password is not valid"})
		return
	}

	dbUser, dbErr := h.UserRep.FindByEmail(email)
	if dbErr != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "hata var ama mailden mi şifreden mi bilinmiyor "})
		return
	}

	errB := bcrypt.CompareHashAndPassword([]byte(dbUser.PasswordHash), []byte(password))
	if errB != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "hata var "})
		return
	}

	// token kısmı
	token, tokenError := utils.GenerateToken(dbUser.ID, dbUser.Role)
	if tokenError != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "token could not create"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "token created", "token": token, "role": dbUser.Role})

}
