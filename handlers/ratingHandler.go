package handlers

import (
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"fitcoaching/utils"
	"time"

	"github.com/gin-gonic/gin"
)

type RatingS struct {
	UserRep     repository.UserRepository
	StudentRep  repository.StudentRepository
	CoachRep    repository.CoachRepository
	RelationRep repository.RelationRepository
	RatingRepo  repository.RatingRepository
}

func RatingCons(userRep repository.UserRepository, studentRep repository.StudentRepository, coachRep repository.CoachRepository,
	relationRep repository.RelationRepository, ratingRepo repository.RatingRepository) *RatingS {
	rating := RatingS{
		userRep,
		studentRep,
		coachRep,
		relationRep,
		ratingRepo}

	return &rating
}

// rating kontrol edildi tam front yazıldıktan sonra bakılabilir
func (r *RatingS) AddRating(c *gin.Context) {
	studentID, getStatus := c.Get("user_id")
	if getStatus != true {
		c.JSON(400, gin.H{"error": "user_id could not be found"})
		return
	}

	studentId := studentID.(uint)

	body := map[string]interface{}{}
	bindError := c.ShouldBindJSON(&body)
	if bindError != nil {
		c.JSON(400, gin.H{"error": "binding failed"})
		return
	}
	// CLAUDE
	coachID, coachOk := body["coach_id"].(float64)
	if coachOk == false {
		banner := "coach_id gönderilmeli"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	coachId := uint(coachID)

	status := r.RelationRep.IsRelaitonBreakedUP(coachId, studentId)
	if status != true {
		c.JSON(400, gin.H{"error": "the relation is not breaked up "})
		return
	}

	oldRating, dbErr := r.RatingRepo.FindByStudentAndCoach(studentId, coachId)
	if dbErr == nil || oldRating != nil {
		banner := "daha önce rating verisi girilmiş"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	// CLAUDE
	rate, rateOk := body["rate"].(float64)
	if rateOk == false {
		banner := "rate gönderilmeli"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	Rate := int(rate)

	description, ok := body["description"].(string)
	if ok != true {
		banner := "description is required"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
	}

	rating := entities.Rating{
		StudentID:   studentId,
		CoachID:     coachId,
		Score:       Rate,
		Description: description,
		CreateTime:  time.Now(),
	}
	creatErr := r.RatingRepo.Create(rating)
	if creatErr != nil {
		c.JSON(400, gin.H{"error": creatErr.Error()})
		return
	}
	c.JSON(200, gin.H{"rating": rating})
}

func (r *RatingS) GetCoachAvarage(c *gin.Context) {
	var body map[string]any // CLAUDE: koç id'si body'den gelmeli
	if err := c.ShouldBindJSON(&body); err != nil {
		banner := "hata B"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	coachID, ok := body["coach_id"].(float64)
	if !ok {
		banner := "hata Convertion"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	coachId := uint(coachID)
	studentID, exists := c.Get("user_id")
	if exists == false {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	studentId := studentID.(uint)
	relation := r.RelationRep.IsRelaitonBreakedUP(coachId, studentId)
	if relation != true {
		banner := "bu koçla bağlantınız yok "
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	avarage, avgErr := r.RatingRepo.AverageByCoach(coachId)
	if avgErr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	c.JSON(200, gin.H{"avarage": avarage})
}
