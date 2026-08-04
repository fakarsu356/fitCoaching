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

	bedtime := body["bed_time"].(string)
	waketime := body["wake_time"].(string)

	bedTime, bedErr := time.Parse("2006-01-02 15:04:05", bedtime)
	wakeTime, wakeError := time.Parse("2006-01-02 15:04:05", waketime)
	if wakeError != nil {
		c.JSON(400, gin.H{"error": "could not parse  wake_time"})
		return
	}
	if bedErr != nil {
		c.JSON(400, gin.H{"error": "could not parse bed_time"})
		return
	}
	if bedTime.After(wakeTime) {
		c.JSON(400, gin.H{"error": "bed_time is in the future"})
		return
	}

	sleep := entities.Sleep{
		StudentID: studentId,
		WakeTime:  wakeTime,
		BedTime:   bedTime,
	}
	createErr := s.SleepRep.Create(sleep)
	if createErr != nil {
		c.JSON(400, gin.H{"error": createErr.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"sleep": sleep})
}
func (s *SleepS) GetSleepByStudent(c *gin.Context) {
	userID, statusId := c.Get("user_id")
	if statusId == false {
		c.JSON(400, gin.H{"error": "could not get user_id"})
		return
	}

	userId, ok := userID.(uint)
	if ok == false {
		c.JSON(400, gin.H{"error": "could not converted user_id"})
		return
	}

	role, statusRole := c.Get("role")
	if statusRole == false {
		c.JSON(400, gin.H{"error": "could not get user_id"})
		return
	}

	Role, converted := role.(entities.Role)
	if converted == false {
		c.JSON(400, gin.H{"error": "could not converted role"})
		return
	}

	if Role == "Coach" {

		data := map[string]int{}
		bindError := c.ShouldBindJSON(&data)
		if bindError != nil {
			banner := "enter valid data "
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
			c.JSON(400, gin.H{"error": dbError.Error()})
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
			c.JSON(400, gin.H{"error": dbError.Error()})
			return
		}

		c.JSON(200, gin.H{"sleep": sleep})
	}
}
