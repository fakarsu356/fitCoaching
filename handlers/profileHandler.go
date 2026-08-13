package handlers

import (
	"fitcoaching/models"
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"fitcoaching/utils"
	"os"

	"github.com/gin-gonic/gin"
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
	}
	banner := "success"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   coachP,
	})
}
