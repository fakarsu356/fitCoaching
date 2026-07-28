package handlers

import (
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type MealS struct {
	UserRep     repository.UserRepository
	StudentRep  repository.StudentRepository
	CoachRep    repository.CoachRepository
	RelationRep repository.RelationRepository
	MealRep     repository.MealRepository
}

func MealCons(userRep repository.UserRepository, studentRep repository.StudentRepository,
	coachRep repository.CoachRepository, relationRep repository.RelationRepository, mealRep repository.MealRepository) *MealS {
	sleep := &MealS{
		UserRep:     userRep,
		StudentRep:  studentRep,
		CoachRep:    coachRep,
		RelationRep: relationRep,
		MealRep:     mealRep,
	}
	return sleep
}

func (w *MealS) AddMeal(c *gin.Context) {
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

	mealName := body["meal_name"].(string)
	description := body["description"].(string)
	kcal := body["kcal"].(float64)
	protein := body["protein"].(float64)
	oil := body["oil"].(float64)

	meal := entities.Meal{
		StudentID:   studentId,
		MealName:    mealName,
		Description: description,
		Kcal:        kcal,
		Protein:     protein,
		Date:        time.Now(),
		Oil:         oil}
	createErr := w.MealRep.Create(&meal)
	if createErr != nil {
		c.JSON(200, gin.H{"error": createErr.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": "the meal has been added"})
}
func (w *MealS) GetMealsByStdudent(c *gin.Context) {

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

	Role, converted := role.(string)
	if converted == false {
		c.JSON(400, gin.H{"error": "could not converted role"})
		return
	}

	data := map[string]interface{}{}

	bindError := c.ShouldBindJSON(&data)
	if bindError != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": bindError.Error()})
		return
	}

	startStr := data["start_date"].(string)
	startDate, enDerr := time.Parse("2006-01-02 15:04:05", startStr)
	if enDerr != nil {
		c.JSON(400, gin.H{"error": enDerr.Error()})
		return
	}

	endStr := data["end_date"].(string)
	endDate, starTerr := time.Parse("2006-01-02 15:04:05", endStr)
	if starTerr != nil {
		c.JSON(400, gin.H{"error": starTerr.Error()})
		return
	}
	if !startDate.Before(endDate) {
		c.JSON(400, gin.H{"error": "start date should be before end date"})
		return
	}

	if Role == "coach" {
		studentID := data["student_id"].(float64)
		studentId := uint(studentID)

		status := w.RelationRep.DoesCoachHaveStudent(userId, studentId)
		if status == false {
			c.JSON(400, gin.H{"error": "could not find coach student"})
			return
		}

		meals, dbRet := w.MealRep.GetALlMealsByDate(studentId, startDate, endDate)
		if dbRet != nil {
			c.JSON(400, gin.H{"error": dbRet.Error()})
			return
		}

		if meals[0].StudentID != studentId {
			c.JSON(400, gin.H{"error": "kendi verilerine istek at "})
			return
		}
		c.JSON(200, gin.H{"meals": meals})
	}

	if Role == "student" {

		meals, dbRet := w.MealRep.GetALlMealsByDate(userId, startDate, endDate)
		if dbRet != nil {
			c.JSON(400, gin.H{"error": dbRet.Error()})
			return
		}

		if meals[0].StudentID != userId {
			c.JSON(400, gin.H{"error": "kendi verilerine istek at "})
			return
		}
		c.JSON(200, gin.H{"meals": meals})
	}
}
func (w *MealS) GetMealSumDaily(c *gin.Context) {

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
		c.JSON(400, gin.H{"error": "could not get role"})
		return
	}

	Role, converted := role.(string)
	if converted == false {
		c.JSON(400, gin.H{"error": "could not converted role"})
		return
	}

	data := map[string]interface{}{}
	bindError := c.ShouldBindJSON(&data)
	if bindError != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": bindError.Error()})
		return
	}
	dateStr := data["start_date"].(string)
	date, enDerr := time.Parse("2006-01-02 15:04:05", dateStr)
	if enDerr != nil {
		c.JSON(400, gin.H{"error": enDerr.Error()})
		return
	}
	if !date.Before(time.Now()) {
		c.JSON(400, gin.H{"error": " date should be before now"})
		return
	}
	if Role == "coach" {
		studentID := data["student_id"].(float64)
		studentId := uint(studentID)

		status := w.RelationRep.DoesCoachHaveStudent(userId, studentId)
		if status == false {
			c.JSON(400, gin.H{"error": "could not find coach student"})
			return
		}

		meal, dbRet := w.MealRep.SumByDate(studentId, date)
		if dbRet != nil {
			c.JSON(400, gin.H{"error": dbRet.Error()})
			return
		}

		if meal.StudentID != studentId {
			c.JSON(400, gin.H{"error": "kendi verilerine istek at "})
			return
		}

		c.JSON(200, gin.H{"meals": meal})
	}

	if Role == "student" {
		meal, dbRet := w.MealRep.SumByDate(userId, date)
		if dbRet != nil {
			c.JSON(400, gin.H{"error": dbRet.Error()})
			return
		}
		if meal.StudentID != userId {
			c.JSON(400, gin.H{"error": "kendi verilerine istek at "})
			return
		}

		c.JSON(200, gin.H{"meals": meal})
	}
}

func (w *MealS) DeleteMeal(c *gin.Context) {
	studentID, statusId := c.Get("user_id")
	if statusId == false {
		c.JSON(400, gin.H{"error": "could not get user_id"})
		return
	}
	studentId, ok := studentID.(uint)
	if ok == false {
		c.JSON(400, gin.H{"error": "could not converted user_id"})
		return

	}

	data := map[string]interface{}{}

	bindError := c.ShouldBindJSON(&data)
	if bindError != nil {
		c.JSON(400, gin.H{"error": bindError.Error()})
		return
	}

	mealID := data["meal_id"].(float64)
	mealId := int(mealID)

	meal, err := w.MealRep.GetById(mealId)
	if err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	if meal.StudentID != studentId {
		c.JSON(400, gin.H{"error": "kendi verilerine istek at "})
		return
	}

	dbRet := w.MealRep.Delete(mealId)
	if dbRet != nil {
		c.JSON(400, gin.H{"error": dbRet.Error()})
		return
	}
	c.JSON(200, gin.H{"status": "deleted"})
}
