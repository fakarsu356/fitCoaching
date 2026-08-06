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

type AddWorkoutInput struct {
	WorkoutID    uint                   `json:"workout_id,omitempty"`
	StudentID    uint                   `json:"student_id"`
	Date         time.Time              `json:"date"`
	Note         string                 `json:"note"`
	Generator    bool                   `json:"generator,omitempty"`      // eğer true ise öğrenci
	SourcePlanID *uint                  `json:"source_plan_id,omitempty"` // öğrencinin hangi planı yapacağını belirler  koç için nil
	Sets         []entities.Set         `json:"sets"`
	Status       entities.WorkoutStatus `json:"status"`
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
	// koç antrenmanlrı dizsin sonra ama düzenleyebilsin o antrenmanları çocuğada her ilk oluşturulan antrenman gösterilsin
	//koç eski antrenmanları kopyalayıp yeniden atayabilsin
	// koç ekranda atadığı antrenmanları götcek çocuuğn yaptıklarını da görebilcek hala bekleyenleri de görebilcek

}
func (w *WorkoutS) AddWorkoutCoach(c *gin.Context) {
	coachID, statusUser := c.Get("user_id")
	if statusUser != true {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	var allData AddWorkoutInput
	err := c.ShouldBindJSON(&allData)
	if err != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   err.Error(),
		})
		return
	}

	coachId, userOk := coachID.(uint)
	if !userOk {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	studentId := allData.StudentID
	_, errStd := w.StudentRep.GetById(studentId)
	if errStd != nil {
		banner := "böyle bir öğrenci kayıtlı değil "
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	status := w.RelationRep.DoesCoachHaveStudent(coachId, studentId)
	if status != true {
		banner := "bu koçun böyle öğrencisi yok"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	workout := entities.Workout{
		CoachID:   coachId,
		StudentID: studentId,
		Date:      time.Now(),
		Notes:     allData.Note,
		Status:    entities.WorkoutWaiting,
		Generator: false, // eğer false ise koç
	}
	realWorkout, createErr := w.WorkoutRep.Create(&workout)
	if createErr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   createErr.Error(),
		})
		return
	}
	if allData.Sets != nil {
		for _, set := range allData.Sets {
			set.WorkoutID = realWorkout.ID
			set.Date = time.Now()
			setErr := w.SetRepo.Create(&set)
			if setErr != nil {
				banner := "hata"
				utils.Response(c, utils.ResponseS{
					Status: false,
					Banner: &banner,
					Data:   setErr.Error(),
				})
				return
			}
		}
	}
	banner := "success"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   realWorkout,
	})
}

// add wokrout kısmında hoca set ve hareketleri gircek hareket sayılarını çocuk gircek.
func (w *WorkoutS) GetTodayPlan(c *gin.Context) {

	studentID, exists := c.Get("user_id")
	if exists == false {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	studentId, ok := studentID.(uint)
	if ok == false {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	_, errStd := w.StudentRep.GetById(studentId)
	if errStd != nil {
		banner := "böyle bir öğrenci kayıtlı değil "
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	workout, dbErr := w.WorkoutRep.GetStudentsWorkkout(studentId)
	if dbErr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	sets, setsErr := w.SetRepo.FindByWorkoutID(workout.ID)
	if setsErr != nil {
		banner := "setler bulunamadı"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	if sets == nil {
		banner := "banner record not found"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
	}

	var totalWorkout AddWorkoutInput

	totalWorkout.StudentID = workout.StudentID
	totalWorkout.Note = workout.Notes
	totalWorkout.Status = entities.WorkoutDone
	totalWorkout.Sets = sets
	banner := "success"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   totalWorkout,
	})
	return
}

// json çıktısında koç un alanı çkııyor koç user diye bir alan eklediğimiz için onu ne yapalım
func (w *WorkoutS) SaveStudentsWorkout(c *gin.Context) {

	var totalWorkout AddWorkoutInput
	bindErr := c.ShouldBind(&totalWorkout)
	if bindErr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	if totalWorkout.SourcePlanID == nil {
		banner := "SourcePlanID dolu olmalıdır"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	studentID, status := c.Get("user_id")
	studentId, ok := studentID.(uint)
	if ok == false || status == false {
		banner := "internal hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	workoutDb, workErr := w.WorkoutRep.GetById(*totalWorkout.SourcePlanID)
	if workErr != nil {
		banner := "kayıt bulunamadı"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	if workoutDb.StudentID != studentId {
		banner := "unauthorized"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	if totalWorkout.StudentID != studentId {
		banner := "kendine istek at"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	coach, coachErr := w.RelationRep.GetCoachFromStudenId(studentId)
	if coachErr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	workout := entities.Workout{
		CoachID:      coach.UserID,
		StudentID:    studentId,
		Date:         time.Now(),
		Notes:        totalWorkout.Note,
		Generator:    true,
		SourcePlanID: totalWorkout.SourcePlanID,
		Status:       entities.WorkoutDone,
	}

	createdWorkout, createErr := w.WorkoutRep.Create(&workout)
	if createErr != nil {
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: nil,
		})
		return
	}

	for i, set := range totalWorkout.Sets {
		set.WorkoutID = createdWorkout.ID
		set.Date = time.Now()
		setErr := w.SetRepo.Create(&set)

		if setErr != nil {
			banner := "setlerin bir kısmı oluşturulamdı"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   any(i),
			})
			return
		}
	}

	workoutId := *totalWorkout.SourcePlanID

	coachWorkout, errWorkout := w.WorkoutRep.GetById(workoutId)
	if errWorkout != nil {
		banner := "kayıt bulunamadı"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	coachWorkout.Status = entities.WorkoutDone

	updateErr := w.WorkoutRep.Update(&coachWorkout)
	if updateErr != nil {
		banner := "hata"
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
		Data:   createdWorkout,
	})
}
func (w *WorkoutS) CopyWorkout(c *gin.Context) {
	coachID, status := c.Get("user_id")
	if status == false {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	coachId, status := coachID.(uint)
	if status == false {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	body := map[string]interface{}{}
	err := c.ShouldBindJSON(&body)
	if err != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	workoutID := body["workout_id"].(float64)
	workoutId := uint(workoutID)

	studentID := body["student_id"].(float64)
	studentId := uint(studentID)

	workoutCopied, wErr := w.WorkoutRep.GetById(workoutId)

	if wErr != nil {
		banner := "kayıt bulunamadı"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	if workoutCopied.CoachID != coachId {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	workoutCopied.Status = entities.WorkoutWaiting

	workoutCopied.StudentID = studentId

	workoutCopied.Date = time.Now()
	workoutCopied.ID = 0
	workoutCreated, createErr := w.WorkoutRep.Create(&workoutCopied)
	if createErr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	sets, setsErr := w.SetRepo.FindByWorkoutID(workoutId)
	if setsErr != nil {
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: nil,
		})
		return
	}

	for _, set := range sets {
		set.ID = 0
		set.WorkoutID = workoutCreated.ID
		set.Date = time.Now()
		setErr := w.SetRepo.Create(&set)
		if setErr != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}
	}
	banner := "success"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   workoutCreated,
	})
}
func (w *WorkoutS) UpdateWorkout(c *gin.Context) {
	coachID, status := c.Get("user_id")
	coachId, ok := coachID.(uint)
	if ok == false || status == false {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	var body AddWorkoutInput
	bindErr := c.ShouldBindJSON(&body)
	if bindErr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	existing, err := w.WorkoutRep.GetById(body.WorkoutID)
	if err != nil {
		banner := "antrenman bulunamadı"
		utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
		return
	}

	if existing.CoachID != coachId {
		banner := "bu antrenman sana ait değil"
		utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
		return
	}

	if existing.Status != entities.WorkoutWaiting {
		banner := "öğrenci zaten yaptı antrenmanı düzenlenemez"
		utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
		return
	}
	if !w.RelationRep.DoesCoachHaveStudent(coachId, body.StudentID) {
		banner := "bu öğrenci sana bağlı değil"
		utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
		return
	}
	existing.StudentID = body.StudentID
	existing.Date = time.Now()
	existing.Notes = body.Note

	updateErr := w.WorkoutRep.Update(&existing)
	if updateErr != nil {
		banner := "kayıt oluşturulamadı"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	sets, setsErr := w.SetRepo.FindByWorkoutID(body.WorkoutID)
	if setsErr != nil {
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: nil,
		})
		return
	}

	for _, set := range sets {
		delErr := w.SetRepo.Delete(set)
		if delErr != nil {
			banner := "record not found"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}
	}

	for _, set := range body.Sets {
		set.WorkoutID = body.WorkoutID
		set.Date = time.Now()

		createrr := w.SetRepo.Create(&set)
		if createrr != nil {
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: nil,
				Data:   createrr.Error(),
			})
			return
		}
	}
	banner := "workout updated"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
	})
}
func (w *WorkoutS) GetCoachWorkouts(c *gin.Context) {
	coachID, status := c.Get("user_id")
	coachId, ok := coachID.(uint)
	if ok == false || status == false {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	workouts, dbErr := w.WorkoutRep.GetWorkoutsByCoach(coachId)
	if dbErr != nil {
		banner := "records are not found"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	var alldata []AddWorkoutInput
	for _, workout := range workouts {
		var datum AddWorkoutInput
		sets, setsErr := w.SetRepo.FindByWorkoutID(workout.ID)
		if setsErr != nil {
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: nil,
			})
			return
		}
		datum.WorkoutID = workout.ID
		datum.Date = workout.Date
		datum.Sets = sets
		datum.Generator = false
		datum.Status = entities.WorkoutWaiting
		datum.StudentID = workout.StudentID
		datum.Note = workout.Notes

		alldata = append(alldata, datum)
	}
	banner := "success"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   alldata,
	})
}

func (w *WorkoutS) GetWorkoutsByDate(c *gin.Context) {

	data := map[string]interface{}{}

	bindError := c.ShouldBindJSON(&data)
	if bindError != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	startdate := data["start_date"].(string)
	enddate := data["end_date"].(string)

	startDate, err1 := time.Parse("2006-01-02 15:04:05", startdate)
	endDate, err2 := time.Parse("2006-01-02 15:04:05", enddate)
	if err1 != nil || err2 != nil {
		banner := "time error"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	userId, status := c.Get("user_id")
	if status == false {
		banner := "user_id could not be found"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	userID, ok := userId.(uint)
	if ok == false {
		banner := "user_id could not be converted to uint"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	role, roleStatus := c.Get("role")
	if roleStatus == false {
		banner := "role could not be found"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	Role, roleErr := role.(entities.Role)
	if roleErr == false {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "role could not be converted to string"})
		return
	}

	if Role == "Student" {

		workouts, worksError := w.WorkoutRep.GetWorkoutsByDate(userID, startDate, endDate)
		if worksError != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": worksError.Error()})
			return
		}
		if len(workouts) == 0 {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "no workouts found"})
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
			realWorkout.WorkoutID = workout.ID
			realWorkout.Status = workout.Status
			realWorkouts = append(realWorkouts, realWorkout)
		}
		banner := "success"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   realWorkouts,
		})

	}

	if Role == "Coach" {

		studentID, statusIdConv := data["student_id"].(float64)
		if statusIdConv == false {
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: nil,
			})
			return
		}
		studentId := uint(studentID)

		statusDb := w.RelationRep.DoesCoachHaveStudent(userID, studentId)
		if statusDb != true {
			banner := "kendi öğrencine istek at"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}

		workouts, worksError := w.WorkoutRep.GetWorkoutsByDate(studentId, startDate, endDate)
		if worksError != nil {
			banner := "zamanları doğru girin"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}
		fmt.Println(workouts)
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
			realWorkout.WorkoutID = workout.ID
			realWorkout.Status = workout.Status
			realWorkouts = append(realWorkouts, realWorkout)
		}
		banner := "success"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   realWorkouts,
		})
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

	Role, roleErr := role.(entities.Role)
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

	if Role == "Student" {
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

	if Role == "Coach" {

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
