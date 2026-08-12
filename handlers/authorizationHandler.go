package handlers

import (
	"errors"
	"fitcoaching/config"
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"fitcoaching/utils"
	"io"
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
}

func AuthCons(userRep repository.UserRepository, studentRep repository.StudentRepository,
	coachRep repository.CoachRepository, documentRep repository.DocumentRepository, tokenRep repository.TokenRepository) *Authorization {
	auth := &Authorization{}
	auth.UserRep = userRep
	auth.StudentRep = studentRep
	auth.CoachRep = coachRep
	auth.DocumentRep = documentRep
	auth.TokenRep = tokenRep

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
	gender := entities.Genders(data["gender"].(string))

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
		UserID:        realUser.ID,
		User:          *realUser,
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

	err := h.UserRep.Db.Transaction(func(tx *gorm.DB) error {

		dbR := tx.Create(&user)

		if dbR.Error != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return dbR.Error
		}

		coach := entities.Coach{
			UserID:      user.ID,
			User:        user, // butası doğrumu create edince doğru bir şekilde id li hali atanıyomu direkt
			Speciality:  speciality,
			MaxStudents: maxStudent,
			Status:      entities.Free,
		}
		dbCoach := tx.Create(&coach)
		if dbCoach.Error != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return dbCoach.Error
		}

		form, formErr := c.MultipartForm()
		if formErr != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})

			return formErr
		}
		keybytes := []byte(os.Getenv("TOP_SECRET"))

		files := form.File["certificates"]
		for _, file := range files {

			if file.Size > config.MaxFileSize {
				banner := "file size too big"
				utils.Response(c, utils.ResponseS{
					Status: false,
					Banner: &banner,
				})
				return errors.New("file size too big")
			}

			bytesf, errHH := file.Open()
			if errHH != nil {
				banner := "file cant open"
				utils.Response(c, utils.ResponseS{
					Status: false,
					Banner: &banner,
				})
				return errHH
			}

			defer bytesf.Close()

			bytes, errH := io.ReadAll(bytesf)
			if errH != nil {
				banner := "dosya okunamadı"
				utils.Response(c, utils.ResponseS{
					Status: false,
					Banner: &banner,
				})
				return errH
			}

			contentType := http.DetectContentType(bytes)
			if !config.AllowedTypes[contentType] {
				banner := "PDF, JPEG,JPG veya PNG kabul edilir"
				utils.Response(c, utils.ResponseS{
					Status: false,
					Banner: &banner,
					Data:   nil,
				})
				return errors.New("file type is not allowed")
			}
			str := strconv.FormatUint(uint64(coach.UserID), 10)

			fileDbName := str + "_" + strconv.FormatInt(time.Now().UnixNano(), 10)

			hashedDoc, hashError := utils.Encrypt(bytes, keybytes)
			if hashError != nil {
				banner := "hata"
				utils.Response(c, utils.ResponseS{
					Status: false,
					Banner: &banner,
					Data:   nil,
				})
				return hashError
			}

			document := entities.Document{
				UploaderID: coach.UserID,
				UniqueName: fileDbName,
				DocName:    file.Filename,
				Size:       float64(file.Size),
				Date:       time.Now(),
				Doctype:    contentType,
				File:       hashedDoc,
				Type:       entities.CaochSertificate,
			}
			docdb := tx.Create(&document)
			if docdb.Error != nil {
				banner := "hata"
				utils.Response(c, utils.ResponseS{
					Status: false,
					Banner: &banner,
					Data:   nil,
				})
				return docdb.Error
			}
		}

		if CV.Size > config.MaxFileSize {
			banner := "file size too big"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return errors.New("file size too big")
		}

		CVbytesf, CVerrH := CV.Open()
		if CVerrH != nil {
			banner := "file cant open"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return CVerrH
		}

		defer CVbytesf.Close()

		CVbytes, CVerrH := io.ReadAll(CVbytesf)
		if CVerrH != nil {
			banner := "dosya okunamadı"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return CVerrH
		}

		contentType := http.DetectContentType(CVbytes)
		if !config.AllowedTypes[contentType] {
			banner := "PDF, JPEG,JPG veya PNG kabul edilir"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return errors.New("file type is not allowed")
		}
		str := strconv.FormatUint(uint64(coach.UserID), 10)

		CVDbName := str + "_" + strconv.FormatInt(time.Now().UnixNano(), 10)

		hashedDoc, hashError := utils.Encrypt(CVbytes, keybytes)
		if hashError != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return hashError
		}

		CVdoc := entities.Document{
			UploaderID: coach.UserID,
			UniqueName: CVDbName,
			DocName:    CV.Filename,
			Size:       float64(CV.Size),
			Date:       time.Now(),
			Doctype:    contentType,
			File:       hashedDoc,
			Type:       entities.CV,
		}

		CVdocdb := tx.Create(&CVdoc)
		if CVdocdb.Error != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return CVdocdb.Error
		}
		return nil
	})

	if err != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
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
	}

	password, passOK := data["password"].(string)
	email, emailOk := data["email"].(string)
	if passOK != true || emailOk != true {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
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
		banner := "password is not valid"
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
