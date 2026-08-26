package handlers

import (
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"fitcoaching/utils"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type SleepS struct {
	UserRep     repository.UserRepository
	StudentRep  repository.StudentRepository
	CoachRep    repository.CoachRepository
	RelationRep repository.RelationRepository
	SleepRep    repository.SleepRepository
}

// kontrol edildi son testler front yazılınca test edilecektir
func SleepCons(userRep repository.UserRepository, studentRep repository.StudentRepository,
	coachRep repository.CoachRepository, relationRep repository.RelationRepository, sleepRep repository.SleepRepository) *SleepS {
	sleep := &SleepS{
		UserRep:     userRep,
		StudentRep:  studentRep,
		CoachRep:    coachRep,
		RelationRep: relationRep,
		SleepRep:    sleepRep,
	}
	return sleep

}

func (s *SleepS) AddSleep(c *gin.Context) {
	studentID, status := c.Get("user_id")
	if status == false {
		c.JSON(400, gin.H{"error": "could not get user_id"})
		return
	}

	studentId, ok := studentID.(uint)
	if ok == false {
		c.JSON(http.StatusBadRequest, gin.H{"error": "could not converted"})
		return
	}

	body := map[string]interface{}{}

	bindError := c.ShouldBindJSON(&body)
	if bindError != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": bindError.Error()})
		return
	}

	// CLAUDE: kontrolsüz tip dönüşümleriydi; alanlar eksikse panic atıyordu.
	bedtime, bedOk := body["bed_time"].(string)
	waketime, wakeOk := body["wake_time"].(string)
	if bedOk == false || wakeOk == false {
		banner := "bed_time ve wake_time gönderilmeli"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	bedTime, bedErr := time.Parse("2006-01-02 15:04:05", bedtime)
	wakeTime, wakeError := time.Parse("2006-01-02 15:04:05", waketime)
	if wakeError != nil {
		banner := "could not parse  wake_time"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	if bedErr != nil {
		banner := "could not parse bed_time"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	if bedTime.After(wakeTime) {
		banner := "bed_time is in the future"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	if wakeTime.Sub(bedTime) > 24*time.Hour || bedTime.Equal(wakeTime) {
		banner := "1 günden fazla uyuyamazsın"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	if bedTime.Equal(wakeTime) {
		banner := "yatak ve uyanma zamanı eşit"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	sleep := entities.Sleep{
		StudentID: studentId,
		WakeTime:  wakeTime,
		BedTime:   bedTime,
	}

	createErr := s.SleepRep.Create(sleep)
	if createErr != nil {
		banner := "internal error"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	banner := "success"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   sleep,
	})
}
func (s *SleepS) GetSleepByStudent(c *gin.Context) {
	userID, statusId := c.Get("user_id")
	if statusId == false {
		banner := "could not get user_id"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	userId, ok := userID.(uint)
	if ok == false {
		banner := "internal error"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	role, statusRole := c.Get("role")
	if statusRole == false {
		banner := "internal error"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	Role, converted := role.(entities.Role)
	if converted == false {
		banner := "internal error"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	if Role == "Coach" {

		data := map[string]int{}
		bindError := c.ShouldBindJSON(&data)
		if bindError != nil {
			banner := "enter valid data"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}
		studentID := data["student_id"]
		studentId := uint(studentID)

		status := s.RelationRep.DoesCoachHaveStudent(userId, studentId)
		if status == false {
			banner := "could not find user"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}

		sleep, dbError := s.SleepRep.FindByStudent(studentId)
		if dbError != nil {
			banner := "hata "
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}

		banner := "sleep is found"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   sleep,
		})
	}

	if Role == "Student" {
		sleep, dbError := s.SleepRep.FindByStudent(userId)
		if dbError != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}

		banner := "sleep is found"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   sleep,
		})
	}
}
