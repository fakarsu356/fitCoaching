package handlers

import (
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type AddWorkoutInput struct {
	StudentID uint           `json:"student_id"`
	Date      time.Time      `json:"date"`
	Note      string         `json:"note"`
	Sets      []entities.Set `json:"sets"`
}
type WorkoutS struct {
	UserRep     repository.UserRepository
	StudentRep  repository.StudentRepository
	CoachRep    repository.CoachRepository
	RelationRep repository.RelationRepository
	WorkoutRep  repository.WorkoutRepository
	SetRepo     repository.SetRepository
}

func WokrputCons(userRep repository.UserRepository, studentRep repository.StudentRepository, coachRep repository.CoachRepository,
	relationRep repository.RelationRepository, workoutRep repository.WorkoutRepository, setRep repository.SetRepository) *WorkoutS {
	workout := &WorkoutS{
		UserRep:     userRep,
		StudentRep:  studentRep,
		CoachRep:    coachRep,
		RelationRep: relationRep,
		WorkoutRep:  workoutRep,
		SetRepo:     setRep,
	}
	return workout

}

func (w *WorkoutS) AddWorkout(c *gin.Context) {
	coachID, exists := c.Get("user_id")
	if exists == false {
		c.JSON(http.StatusNotFound, gin.H{"error": "coach_id could not be found"})
		return
	}
	// yeni struct oluşturuldu alınan değerleri  o structtan bağla notu setleri fln düzgünce bağla
	var allData AddWorkoutInput
	err := c.ShouldBindJSON(&allData)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	fmt.Println(allData)

	studentID := allData.StudentID

	_, errStd := w.StudentRep.GetById(studentID)
	if errStd != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": errStd.Error()})
		return
	}
	coachId, ok := coachID.(uint)
	if ok == false {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "coach_id could not be converted"})
		return
	}
	status := w.RelationRep.DoesCoachHaveStudent(coachId, studentID)

	if status != true {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "bu koçun böyle öğrencisi yok "})
		return
	}

	workout := entities.Workout{
		CoachID:   coachId,
		StudentID: studentID,
		Date:      time.Now(),
		Notes:     allData.Note,
	}
	realWorkout, createError := w.WorkoutRep.Create(&workout)

	if createError != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": createError.Error()})
		return
	}

	for _, set := range allData.Sets {
		set.WorkoutID = realWorkout.ID

		setErr := w.SetRepo.Create(&set)
		if setErr != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": setErr.Error()})
			return
		}
	}

	c.JSON(http.StatusOK, realWorkout)
}

func (w *WorkoutS) GetWorkoutsByStudent(c *gin.Context) {

	data := map[string]interface{}{}

	bindError := c.ShouldBindJSON(&data)
	if bindError != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": bindError.Error()})
		return
	}
	startdate := data["start_date"].(string)
	enddate := data["end_date"].(string)
	startDate, err1 := time.Parse("2006-01-02 15:04:05", startdate)
	endDate, err2 := time.Parse("2006-01-02 15:04:05", enddate)
	if err1 != nil || err2 != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err1.Error()})
		return
	}

	userId, status := c.Get("user_id")
	if status == false {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "user_id could not be found"})
		return
	}

	userID, ok := userId.(uint)
	if ok == false {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "user_id could not be converted to uint"})
		return
	}

	role, roleStatus := c.Get("role")
	if roleStatus == false {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "role could not be found"})
		return
	}

	Role, roleErr := role.(string)
	if roleErr == false {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "role could not be converted to string"})
		return
	}

	if Role == "student" {

		workouts, worksError := w.WorkoutRep.GetWorkoutsByDate(userID, startDate, endDate)
		if worksError != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": worksError.Error()})
			return
		}
		if len(workouts) == 0 {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "no workouts found"})
			return
		}
		if workouts[0].StudentID != userID {
			c.JSON(http.StatusBadRequest, gin.H{"error": " kendine istek atabilirsin"})
			return
		}

		var realWorkouts []AddWorkoutInput
		for _, workout := range workouts {
			var realWorkout AddWorkoutInput

			sets, setsError := w.SetRepo.FindByWorkoutID(workout.ID)
			if setsError != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": setsError.Error()})
				return
			}
			realWorkout.Date = workout.Date
			realWorkout.Note = workout.Notes
			realWorkout.StudentID = workout.StudentID
			realWorkout.Sets = sets

			realWorkouts = append(realWorkouts, realWorkout)
		}
		c.JSON(http.StatusOK, realWorkouts)
	}

	if Role == "coach" {

		studentId := data["student_id"].(uint)

		status := w.RelationRep.DoesCoachHaveStudent(userID, studentId)
		if status != true {
			c.JSON(http.StatusBadRequest, gin.H{"error": "kendi öğrencine istek at"})
			return
		}

		workouts, worksError := w.WorkoutRep.GetWorkoutsByDate(studentId, startDate, endDate)
		if worksError != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": worksError.Error()})
			return
		}

		var realWorkouts []AddWorkoutInput
		for _, workout := range workouts {
			var realWorkout AddWorkoutInput

			sets, setsError := w.SetRepo.FindByWorkoutID(workout.ID)
			if setsError != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": setsError.Error()})
				return
			}
			realWorkout.Date = workout.Date
			realWorkout.Note = workout.Notes
			realWorkout.StudentID = workout.StudentID
			realWorkout.Sets = sets

			realWorkouts = append(realWorkouts, realWorkout)
		}
		c.JSON(http.StatusOK, realWorkouts)
	}
}

func (w *WorkoutS) GetWorkoutDetail(c *gin.Context) {
	userId, status := c.Get("user_id")
	if status == false {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "user_id could not be found"})
		return
	}
	userID, ok := userId.(uint)
	if ok == false {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "user_id could not be converted to uint"})
		return
	}

	role, roleStatus := c.Get("role")
	if roleStatus == false {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "role could not be found"})
		return
	}

	Role, roleErr := role.(string)
	if roleErr == false {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "role could not be converted to string"})
		return
	}

	stdIDandWorkout := map[string]interface{}{}

	bindError := c.ShouldBindJSON(&stdIDandWorkout)
	if bindError != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": bindError.Error()})
		return
	}

	studentId := stdIDandWorkout["student_id"].(float64)
	workoutId := stdIDandWorkout["workout_id"].(float64)

	studentID := uint(studentId)
	workoutID := uint(workoutId)

	if Role == "student" {
		workout, worksError := w.WorkoutRep.GetById(workoutID)
		if worksError != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": worksError.Error()})
			return
		}
		var realWorkout AddWorkoutInput
		if workout.StudentID != userID {
			c.JSON(http.StatusBadRequest, gin.H{"error": "başka öğrenciye erişemezsin"})
			return
		}
		sets, setsError := w.SetRepo.FindByWorkoutID(workout.ID)
		if setsError != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": setsError.Error()})
			return
		}

		realWorkout.Date = workout.Date
		realWorkout.Note = workout.Notes
		realWorkout.StudentID = workout.StudentID
		realWorkout.Sets = sets

		c.JSON(http.StatusOK, realWorkout)
	}

	if Role == "coach" {

		status := w.RelationRep.DoesCoachHaveStudent(userID, studentID)
		if status != true {
			c.JSON(http.StatusBadRequest, gin.H{"error": "kendi öğrencine istek at"})
			return
		}

		workout, worksError := w.WorkoutRep.GetById(workoutID)
		if worksError != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": worksError.Error()})
			return
		}
		if workout.StudentID != studentID {
			c.JSON(http.StatusBadRequest, gin.H{"error": "başka öğrenciye erişemezsin"})
			return
		}

		var realWorkout AddWorkoutInput

		sets, setsError := w.SetRepo.FindByWorkoutID(workout.ID)
		if setsError != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": setsError.Error()})
			return
		}
		realWorkout.Date = workout.Date
		realWorkout.Note = workout.Notes
		realWorkout.StudentID = workout.StudentID
		realWorkout.Sets = sets

		c.JSON(http.StatusOK, realWorkout)
	}
}

/*
{
"student_id": 15,
"date": "2026-07-24T00:00:00Z",
"note": "Göğüs ve bacak günü, iyi bir seans geçti",
{
"movement_name": "Bench Press",
"set_number": 1,
"reps": 10,
"weight_kg": 60
},
{
"movement_name": "Bench Press",
"set_number": 2,
"reps": 8,
"weight_kg": 70
},
{
"movement_name": "Bench Press",
"set_number": 3,
"reps": 6,
"weight_kg": 75
},
{
"movement_name": "Squat",
"set_number": 1,
"reps": 12,
"weight_kg": 80
},
{
"movement_name": "Squat",
"set_number": 2,
"reps": 10,
"weight_kg": 90
}

} */
