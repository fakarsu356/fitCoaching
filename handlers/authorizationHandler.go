package handlers

import (
	"fitcoaching/config"
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"fitcoaching/utils"
	"io"
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
	role := entities.Role(data["role"].(string))
	age := data["age"].(int)
	bodyFatPercentage := data["bodyFatPercentage"].(float32)
	bodyWeight := data["bodyWeight"].(float32)
	bodyHeight := data["bodyHeight"].(float32)
	gender := entities.Gender(data["gender"].(string))

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
	if age>50 && age<10{
		c.JSON(http.StatusBadRequest, gin.H{"error": "doğru değer gir "})
		return
	}
	if bodyFatPercentage>1 && bodyFatPercentage<50 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "doğru değer gir "})
		return
	}
	if bodyWeight<200 && bodyWeight >10{
		c.JSON(http.StatusBadRequest, gin.H{"error": "doğru değer gir "})
		return
	}
	if bodyHeight<250 && bodyHeight >50{
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
		Role:         role,
	}
	if user, err := h.UserRep.Create(&user); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	var student entities.Student
	studen
		c.JSON(http.StatusCreated, gin.H{"message": "kayıt başarılı"})
}

func (h *Authorization) KayitCoach(c *gin.Context) {
	var coach entities.Coach
	username := c.PostForm("username")
	email := c.PostForm("email")
	password := c.PostForm("password")
	passwordConfirm := c.PostForm("password_confirm")
	maxStudent := c.PostForm("max_students")
	specialty := c.PostForm("specialty")

	coach.User.Username = username
	coach.User.Email = email
	coach.User.PasswordHash = password
	coach.User.PasswordConfirm = passwordConfirm
	coach.Specialty = specialty

	// max student kontrolü
	maxStudents, errS := strconv.Atoi(maxStudent)
	if errS != nil || maxStudents < 0 || maxStudents > 20 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "geçersiz kontenjan değeri"})
		return
	}
	coach.MaxStudents = maxStudents
	// e mail i kontrol et
	_, err1 := h.UserRep.Findemail(email)
	if err1 == nil {
		c.JSON(http.StatusBadRequest, "smn already registered with this email")
		return
	}

	// 2 şifre eşleşiyomu kontrol et
	if passwordConfirm != password {
		c.JSON(http.StatusBadRequest, "şifreler eşleşmiyor")
		return
	}
	// şifre standartlara uygun mu kontrol et
	if ValidatePassword(password) != nil {
		c.JSON(http.StatusBadRequest, ValidatePassword(password).Error())
		return
	}

	hashedBytes, hashErr := utils.PasswordHash(password)
	if hashErr != nil {
		c.JSON(http.StatusBadRequest, "hashlenemedi") // c.JSON(http.StatusBadRequest, gin.H{"error": "hashlenemedi"})  bu 2 sinin farkı ne

		return
	}

	coach.User.PasswordHash = string(hashedBytes)

	if errC := h.CoachRep.Create(&coach); errC != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": errC.Error()})
		return
	}

	// bu formun işlemleri

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

		document := entities.Document{
			UploaderID: coach.User.ID,  //ai buraya delirdi neden sor
			UniqueName: fileH.Filename, //enes abiye sor buraya ne yapcaz diye structı goster doğrumu diye
			DocName:    fileH.Filename,
			Size:       float32(fileH.Size),
			Date:       time.Now(),
			DocType:    contentType,
			File:       fileBytes,
		}

		h.DocumentRep.Create(&document)
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Succesfully registered"})
}

func (h *Authorization) LogIn(c *gin.Context) { // burayıbaştan yaz buranın mimariis farklı farklı şekilde kontrol ediliyor
	var user entities.User // doğrumu burası ai logininptut kullan dedi
	err := c.ShouldBind(&user)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "kullanıcı bulunamadı"})
		return
	}

	dbUser, dbErr := h.UserRep.FindByUsername(user.Username)
	if dbErr != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "userrepo dan gelmedi user"})
		return
	}

	errB := bcrypt.CompareHashAndPassword([]byte(dbUser.PasswordHash), []byte(user.PasswordHash))
	if errB != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "kullanıcı adı veya şifre hatalı"})
		return
	}

	// token kısmı

}
