package handlers

import (
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"fitcoaching/utils"
	"fmt"
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

// burayada resim için bir alan

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
		banner := "could not get user_id"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	studentId, ok := studentID.(uint)
	if ok == false {
		banner := "could not converted"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	body := map[string]interface{}{}

	bindError := c.ShouldBindJSON(&body)
	if bindError != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	// CLAUDE: kontrolsüz tip dönüşümleriydi; alan eksikse ya da tipi tutmuyorsa
	// handler panic atıp 500 dönüyordu.
	mealName, mealNameOk := body["meal_name"].(string)
	description, descriptionOk := body["description"].(string)
	kcal, kcalOk := body["kcal"].(float64)
	protein, proteinOk := body["protein"].(float64)
	oil, oilOk := body["oil"].(float64)
	if mealNameOk == false || descriptionOk == false || kcalOk == false || proteinOk == false || oilOk == false {
		banner := "meal_name, description, kcal, protein ve oil gönderilmeli"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	karb, _ := body["karb"].(float64)
	lif, _ := body["lif"].(float64)

	meal := entities.Meal{
		StudentID:   studentId,
		MealName:    mealName,
		Description: description,
		Kcal:        kcal,
		Protein:     protein,
		Date:        time.Now(),
		Oil:         oil,
		Karb:        karb,
		Lif:         lif}
	createErr := w.MealRep.Create(&meal)
	if createErr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	banner := "meal is added"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   nil,
	})
}
func (w *MealS) GetStudentsMealsByDate(c *gin.Context) {

	userID, statusId := c.Get("user_id")
	if statusId == false {
		banner := "could not get user_id"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	userId, ok := userID.(uint)
	if ok == false {
		banner := "could not converted user_id"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	role, statusRole := c.Get("role")
	if statusRole == false {
		banner := "could not get user_id"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	Role, converted := role.(entities.Role)
	if converted == false {
		banner := "could not converted role"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	data := map[string]interface{}{}

	bindError := c.ShouldBindJSON(&data)
	if bindError != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	// CLAUDE
	startStr, startOk := data["start_date"].(string)
	if startOk == false {
		banner := "start_date gönderilmeli"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	startDate, enDerr := time.Parse("2006-01-02 15:04:05", startStr)
	if enDerr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	// CLAUDE
	endStr, endOk := data["end_date"].(string)
	if endOk == false {
		banner := "end_date gönderilmeli"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	endDate, starTerr := time.Parse("2006-01-02 15:04:05", endStr)
	if starTerr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	if !startDate.Before(endDate) {
		banner := "start date should be before end date"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	if Role == "Coach" {
		// CLAUDE
		studentID, studentOk := data["student_id"].(float64)
		if studentOk == false {
			banner := "student_id gönderilmeli"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}
		studentId := uint(studentID)

		status := w.RelationRep.DoesCoachHaveStudent(userId, studentId)
		if status == false {
			banner := "could not find coach student"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}

		meals, dbRet := w.MealRep.GetALlMealsByDate(studentId, startDate, endDate)
		if dbRet != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}

		if len(meals) > 0 && meals[0].StudentID != studentId {
			banner := "kendi verilerine istek at"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}
		banner := "success"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   meals,
		})
	}

	if Role == "Student" {

		meals, dbRet := w.MealRep.GetALlMealsByDate(userId, startDate, endDate)
		if dbRet != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}
		fmt.Println("success")
		banner := "success"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   meals,
		})
	}
}
func (w *MealS) GetMealSumDaily(c *gin.Context) {

	userID, statusId := c.Get("user_id")
	if statusId == false {
		c.JSON(400, gin.H{"error": "could not get user_id"})
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	userId, ok := userID.(uint)
	if ok == false {
		c.JSON(400, gin.H{"error": "could not converted user_id"})
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	role, statusRole := c.Get("role")
	if statusRole == false {
		c.JSON(400, gin.H{"error": "could not get role"})
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	Role, converted := role.(entities.Role)
	if converted == false {
		c.JSON(400, gin.H{"error": "could not converted role"})
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	data := map[string]interface{}{}
	bindError := c.ShouldBindJSON(&data)
	if bindError != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": bindError.Error()})
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	// CLAUDE
	dateStr, dateOk := data["start_date"].(string)
	if dateOk == false {
		banner := "start_date gönderilmeli"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	date, enDerr := time.Parse("2006-01-02 15:04:05", dateStr)
	if enDerr != nil {
		c.JSON(400, gin.H{"error": enDerr.Error()})
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	if !date.Before(time.Now()) {
		c.JSON(400, gin.H{"error": " date should be before now"})
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	if Role == "Coach" {
		// CLAUDE
		studentID, studentOk := data["student_id"].(float64)
		if studentOk == false {
			banner := "student_id gönderilmeli"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}
		studentId := uint(studentID)

		status := w.RelationRep.DoesCoachHaveStudent(userId, studentId)
		if status == false {
			c.JSON(400, gin.H{"error": "could not find coach student"})
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}

		meal, dbRet := w.MealRep.SumByDate(studentId, date)
		if dbRet != nil {
			c.JSON(400, gin.H{"error": dbRet.Error()})
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}

		if meal.StudentID != studentId {
			c.JSON(400, gin.H{"error": "kendi verilerine istek at "})
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}

		banner := "success"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   meal,
		})
		return
	}

	if Role == "Student" {
		meal, dbRet := w.MealRep.SumByDate(userId, date)
		if dbRet != nil {
			c.JSON(400, gin.H{"error": dbRet.Error()})
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}
		if meal.StudentID != userId {
			banner := "kendi verilerine istek at"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}

		banner := "success"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   meal,
		})
	}
}

func (w *MealS) DeleteMeal(c *gin.Context) {
	studentID, statusId := c.Get("user_id")
	if statusId == false {
		c.JSON(400, gin.H{"error": "could not get user_id"})
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	studentId, ok := studentID.(uint)
	if ok == false {
		c.JSON(400, gin.H{"error": "could not converted user_id"})
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return

	}

	data := map[string]interface{}{}

	bindError := c.ShouldBindJSON(&data)
	if bindError != nil {
		c.JSON(400, gin.H{"error": bindError.Error()})
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	mealID, okMeal := data["meal_id"].(float64)
	if okMeal == false {
		banner := "meal_id gönderilmeli"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	mealId := int(mealID)

	meal, err := w.MealRep.GetById(mealId)
	if err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	if meal.StudentID != studentId {
		c.JSON(400, gin.H{"error": "kendi verilerine istek at "})
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	dbRet := w.MealRep.Delete(mealId)
	if dbRet != nil {
		c.JSON(400, gin.H{"error": dbRet.Error()})
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	banner := "deleted"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   nil,
	})
}
