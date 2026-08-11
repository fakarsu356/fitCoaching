	package handlers

	import (
		"fitcoaching/models"
		"fitcoaching/models/entities"
		"fitcoaching/repository"
		"fitcoaching/utils"
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
			return
		}

		var setsM []models.SetM

		for _, set := range sets {
			setM := models.SetM{
				ID:           set.ID,
				WorkoutID:    workout.ID,
				MovementName: set.MovementName,
				Date:         set.Date,
				SetNumber:    set.SetNumber,
				Reps:         set.Reps,
				Weight:       set.Weight,
			}
			setsM = append(setsM, setM)
		}

		workoutM := models.WorkoutM{
			ID:           workout.ID,
			Notes:        workout.Notes,
			Status:       workout.Status,
			Sets:         setsM,
			SourcePlanID: workout.SourcePlanID,
			CoachID:      workout.CoachID,
			StudentID:    workout.StudentID,
			Date:         workout.Date,
			Generator:    false,
		}
		banner := "success"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   workoutM,
		})
		return
	}

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
			set.ID = 0
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

		workoutID, ok := body["workout_id"].(float64)
		if ok == false {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
		}
		workoutId := uint(workoutID)

		studentID, okS := body["student_id"].(float64)
		if okS == false {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
		}
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
		workoutM := models.WorkoutM{
			ID:           workoutCreated.ID,
			StudentID:    studentId,
			Date:         workoutCreated.Date,
			Notes:        workoutCreated.Notes,
			Status:       entities.WorkoutWaiting,
			Generator:    workoutCreated.Generator,
			SourcePlanID: workoutCreated.SourcePlanID,
		}
		sets, setsErr := w.SetRepo.FindByWorkoutID(workoutId)
		if setsErr != nil {
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: nil,
			})
			return
		}
		var setsM []models.SetM

		if !w.RelationRep.DoesCoachHaveStudent(coachId, studentId) {
			banner := "bu öğrenci sana bağlı değil"
			utils.Response(c, utils.ResponseS{Status: false, Banner: &banner})
			return
		}

		for _, set := range sets {
			var setM models.SetM
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
			setM.ID = set.ID
			setM.WorkoutID = set.WorkoutID
			setM.MovementName = set.MovementName
			setM.Reps = set.Reps
			setM.Date = set.Date
			setM.Weight = set.Weight
			setM.SetNumber = set.SetNumber
			setsM = append(setsM, setM)
		}
		workoutM.Sets = setsM
		banner := "success"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   workoutM,
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
		var data []models.WorkoutM
		for _, workout := range workouts {
			var datum models.WorkoutM

			sets, setsErr := w.SetRepo.FindByWorkoutID(workout.ID)
			if setsErr != nil {
				utils.Response(c, utils.ResponseS{
					Status: false,
					Banner: nil,
				})
				return
			}
			var setsM []models.SetM
			for _, set := range sets {
				var setM models.SetM
				setM.ID = set.ID
				setM.WorkoutID = workout.ID
				setM.SetNumber = set.SetNumber
				setM.Weight = set.Weight
				setM.Date = set.Date
				setM.Reps = set.Reps
				setM.MovementName = set.MovementName

				setsM = append(setsM, setM)
			}
			datum.ID = workout.ID
			datum.Date = workout.Date
			datum.Sets = setsM
			datum.Generator = false
			datum.Status = entities.WorkoutWaiting
			datum.StudentID = workout.StudentID
			datum.Notes = workout.Notes
			data = append(data, datum)
		}
		banner := "success"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   data,
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

			var realWorkouts []models.WorkoutM
			for _, workout := range workouts {
				var realWorkout models.WorkoutM

				sets, setsError := w.SetRepo.FindByWorkoutID(workout.ID)
				if setsError != nil {
					utils.Response(c, utils.ResponseS{
						Status: false,
						Banner: nil,
					})
					return
				}
				realWorkout.Date = workout.Date
				realWorkout.Notes = workout.Notes
				realWorkout.StudentID = workout.StudentID
				realWorkout.ID = workout.ID
				realWorkout.Status = workout.Status
				var setsM []models.SetM
				for _, set := range sets {
					var setM models.SetM
					setM.ID = set.ID
					setM.WorkoutID = workout.ID
					setM.SetNumber = set.SetNumber
					setM.Weight = set.Weight
					setM.Date = set.Date
					setM.Reps = set.Reps
					setM.MovementName = set.MovementName

					setsM = append(setsM, setM)
				}
				realWorkout.Sets = setsM
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
				utils.Response(c, utils.ResponseS{
					Status: false,
					Banner: nil,
				})
			}

			var realWorkouts []models.WorkoutM
			for _, workout := range workouts {
				var realWorkout models.WorkoutM

				sets, setsError := w.SetRepo.FindByWorkoutID(workout.ID)
				if setsError != nil {
					utils.Response(c, utils.ResponseS{
						Status: false,
						Banner: nil,
					})
					return
				}
				realWorkout.Date = workout.Date
				realWorkout.Notes = workout.Notes
				realWorkout.StudentID = workout.StudentID
				realWorkout.ID = workout.ID
				realWorkout.Status = workout.Status
				var setsM []models.SetM
				for _, set := range sets {
					var setM models.SetM
					setM.ID = set.ID
					setM.WorkoutID = workout.ID
					setM.SetNumber = set.SetNumber
					setM.Weight = set.Weight
					setM.Date = set.Date
					setM.Reps = set.Reps
					setM.MovementName = set.MovementName

					setsM = append(setsM, setM)
				}
				realWorkout.Sets = setsM
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

		body := map[string]interface{}{}

		bindError := c.ShouldBindJSON(&body)
		if bindError != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}

		studentId, ok := body["student_id"].(float64)
		workoutId, okW := body["workout_id"].(float64)
		if okW == false || ok == false {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
		}

		studentID := uint(studentId)
		workoutID := uint(workoutId)

		if Role == "Student" {
			workout, worksError := w.WorkoutRep.GetById(workoutID)
			if worksError != nil {
				banner := "hata"
				utils.Response(c, utils.ResponseS{
					Status: false,
					Banner: &banner,
				})
				return
			}
			var realWorkout models.WorkoutM
			if workout.StudentID != userID {
				banner := "kendi antrenmanın değil "
				utils.Response(c, utils.ResponseS{
					Status: false,
					Banner: &banner,
				})
				return
			}

			sets, setsError := w.SetRepo.FindByWorkoutID(workout.ID)
			if setsError != nil {
				banner := "hata"
				utils.Response(c, utils.ResponseS{
					Status: false,
					Banner: &banner,
				})
				return
			}

			realWorkout.Date = workout.Date
			realWorkout.Notes = workout.Notes
			realWorkout.StudentID = workout.StudentID
			realWorkout.ID = workoutID
			realWorkout.Status = entities.WorkoutDone
			realWorkout.SourcePlanID = workout.SourcePlanID
			realWorkout.Generator = workout.Generator
			realWorkout.CoachID = workout.CoachID

			var setsM []models.SetM
			for _, set := range sets {
				var setM models.SetM
				setM.ID = set.ID
				setM.WorkoutID = workout.ID
				setM.SetNumber = set.SetNumber
				setM.Weight = set.Weight
				setM.Date = set.Date
				setM.Reps = set.Reps
				setM.MovementName = set.MovementName

				setsM = append(setsM, setM)
			}
			realWorkout.Sets = setsM

			banner := "success"
			utils.Response(c, utils.ResponseS{
				Status: true,
				Banner: &banner,
				Data:   realWorkout,
			})
			return
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

			var realWorkout models.WorkoutM

			sets, setsError := w.SetRepo.FindByWorkoutID(workout.ID)
			if setsError != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": setsError.Error()})
				return
			}
			realWorkout.Date = workout.Date
			realWorkout.Notes = workout.Notes
			realWorkout.StudentID = workout.StudentID
			realWorkout.ID = workoutID
			realWorkout.Status = entities.WorkoutDone
			realWorkout.SourcePlanID = workout.SourcePlanID
			realWorkout.Generator = workout.Generator
			realWorkout.CoachID = workout.CoachID

			var setsM []models.SetM
			for _, set := range sets {
				var setM models.SetM
				setM.ID = set.ID
				setM.WorkoutID = workout.ID
				setM.SetNumber = set.SetNumber
				setM.Weight = set.Weight
				setM.Date = set.Date
				setM.Reps = set.Reps
				setM.MovementName = set.MovementName

				setsM = append(setsM, setM)
			}
			realWorkout.Sets = setsM

			banner := "success"
			utils.Response(c, utils.ResponseS{
				Status: true,
				Banner: &banner,
				Data:   realWorkout,
			})
			return
		}
	}
