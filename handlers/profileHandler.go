package handlers

import (
	"fitcoaching/models"
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"fitcoaching/utils"
	"os"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

type Profile struct {
	UserRep     repository.UserRepository
	StudentRep  repository.StudentRepository
	CoachRep    repository.CoachRepository
	RelationRep repository.RelationRepository
	DocumentRep repository.DocumentRepository
	RatingRep   repository.RatingRepository
}

func ProfileCons(userRep repository.UserRepository, studentRep repository.StudentRepository, coachRep repository.CoachRepository,
	relationRep repository.RelationRepository, documentRep repository.DocumentRepository, ratingRep repository.RatingRepository) *Profile {
	prof := &Profile{}
	prof.UserRep = userRep
	prof.StudentRep = studentRep
	prof.CoachRep = coachRep
	prof.RelationRep = relationRep
	prof.DocumentRep = documentRep
	prof.RatingRep = ratingRep

	return prof
}

func (p *Profile) CoachProfile(c *gin.Context) {

	body := map[string]interface{}{}

	bindErr := c.ShouldBindBodyWithJSON(&body)
	if bindErr != nil {
		banner := "coach_id is required"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	coachID, ok := body["coach_id"].(float64)
	if !ok {
		banner := "coach_id is required"
		utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
		return
	}
	coachId := uint(coachID)

	coach, coacherr := p.CoachRep.GetById(coachId)
	if coacherr != nil {
		banner := "coach not found "
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	files, docErr := p.DocumentRep.FindByUploaderAndType(coachId, entities.CaochSertificate)
	if docErr != nil {
		banner := "couldn not find the files"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	keyByte := []byte(os.Getenv("TOP_SECRET"))
	for i, file := range files {
		temp, decryptErr := utils.Decrypt(file.File, keyByte)
		if decryptErr != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   decryptErr.Error(),
			})
			return
		}
		files[i].File = temp // buile file.File=temp bu ikisinin farkı ne olabilir
	}
	numberOfStudents := p.RelationRep.GetCoachsStudents(coachId)

	rate, raterr := p.RatingRep.AverageByCoach(coachId)
	if raterr != nil {
		banner := "internal error"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	ratings := float64(p.RatingRep.NumbersOfRate(coachId))
	coachP := models.CoachM{
		UserID:         coachId,
		Username:       coach.User.Username,
		Gender:         coach.User.Gender,
		Speciality:     coach.Speciality,
		MaxStudents:    coach.MaxStudents,
		ActiveStudents: numberOfStudents,
		Status:         coach.Status,
		Rating:         &rate,
		RatingCount:    &ratings,
		CoachDoc:       files,
		Email:          coach.User.Email,
	}
	banner := "success"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   coachP,
	})
}

func (p *Profile) ResetPassword(c *gin.Context) {

	body := map[string]interface{}{}

	bindErr := c.ShouldBindBodyWithJSON(&body)
	if bindErr != nil {
		banner := "şifre bilgileri gönderilmeli" // CLAUDE
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	// CLAUDE: kimlik gövdeden değil token'dan alınıyor; gövdedeki user_id'ye
	// güvenilirse bir kullanıcı başkasının id'sini gönderebiliyordu.
	ctxUserID, getStatus := c.Get("user_id") // CLAUDE
	if getStatus == false {                  // CLAUDE
		banner := "user id could not get" // CLAUDE
		utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
		return
	}
	userId := ctxUserID.(uint) // CLAUDE

	user, coacherr := p.UserRep.GetById(userId)
	if coacherr != nil {
		banner := "kullanıcı bulunamadı" // CLAUDE
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	newPassword, newok := body["password"].(string)
	oldPassword, oldOk := body["old_password"].(string)
	if newok != true || oldOk != true {
		banner := "mevcut ve yeni şifre gönderilmeli" // CLAUDE
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	errB := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(oldPassword))
	if errB != nil {
		banner := "mevcut şifren hatalı" // CLAUDE
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	// CLAUDE: kural metni atılıp yerine "hata" dönüyordu; kullanıcı hangi
	// kuralı çiğnediğini göremiyordu.
	if validateErr := utils.ValidatePassword(newPassword); validateErr != nil {
		banner := validateErr.Error() // CLAUDE
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	hashedBytes, hashErr := utils.PasswordHash(newPassword)
	if hashErr != nil {
		banner := "şifre kaydedilemedi" // CLAUDE
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	passwordHashed := string(hashedBytes)

	user.PasswordHash = passwordHashed
	// CLAUDE: Update'in hatası kontrol edilmiyordu; kayıt başarısız olsa bile
	// kullanıcıya "success" dönüyordu.
	if updateErr := p.UserRep.Update(user); updateErr != nil { // CLAUDE
		banner := "şifre kaydedilemedi" // CLAUDE
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	banner := "success"
	// CLAUDE: Data'da düz şifre dönüyordu (loglara/istemci belleğine düşüyordu).
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
	})
}

// CLAUDE: StudentProfile öğrencinin kendi profilini döndürür. Kimlik token'dan
// alınıyor; gövdede student_id beklenmiyor ki bir öğrenci başkasının
// bilgilerini çekemesin.
func (p *Profile) StudentProfile(c *gin.Context) {

	ctxUserID, getStatus := c.Get("user_id")
	if getStatus == false {
		banner := "user id could not get"
		utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
		return
	}
	userId := ctxUserID.(uint)

	student, studentErr := p.StudentRep.GetByIdWithUser(userId)
	if studentErr != nil {
		banner := "öğrenci bulunamadı"
		utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
		return
	}

	banner := "success"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   models.NewStudentM(student),
	})
}

// CLAUDE: UpdateStudent kilo ve yağ oranını günceller. Yaş, boy ve cinsiyet
// kayıt sırasında belirleniyor, burada değiştirilmiyor. Gönderilmeyen alan
// olduğu gibi kalır.
func (p *Profile) UpdateStudent(c *gin.Context) {

	ctxUserID, getStatus := c.Get("user_id")
	if getStatus == false {
		banner := "user id could not get"
		utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
		return
	}
	userId := ctxUserID.(uint)

	body := map[string]interface{}{}
	if bindErr := c.ShouldBindBodyWithJSON(&body); bindErr != nil {
		banner := "geçersiz istek"
		utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
		return
	}

	student, studentErr := p.StudentRep.GetByIdWithUser(userId)
	if studentErr != nil {
		banner := "öğrenci bulunamadı"
		utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
		return
	}

	// Kısıtlar entities.Student içindeki gorm check'leriyle birebir aynı.
	if weight, ok := body["body_weight"].(float64); ok {
		if weight <= 0 || weight >= 300 {
			banner := "kilo 0 ile 300 arasında olmalı"
			utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
			return
		}
		student.BodyWeight = weight
	}

	if fat, ok := body["fat_percentage"].(float64); ok {
		if fat <= 0 || fat >= 50 {
			banner := "yağ oranı 0 ile 50 arasında olmalı"
			utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
			return
		}
		student.FatPercentage = fat
	}

	if updateErr := p.StudentRep.Update(student); updateErr != nil {
		banner := "kayıt güncellenemedi"
		utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
		return
	}

	banner := "success"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   models.NewStudentM(student),
	})
}
