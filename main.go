package main

import (
	"fitcoaching/config"
	"fitcoaching/handlers"
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"fitcoaching/utils"
	"fmt"

	"github.com/gin-gonic/gin"
	"github.com/robfig/cron/v3"
)

func main() {

	db := config.ConnectDatabase()
	db.AutoMigrate(
		&entities.User{},
		&entities.Coach{},
		&entities.Student{},
		&entities.Workout{},
		&entities.Set{},
		&entities.Meal{},
		&entities.Sleep{},
		&entities.Document{},
		&entities.Relation{},
		&entities.Rating{},
		&entities.RefreshToken{},
	)

	userRepo := repository.UserCons(db)
	coachRepo := repository.CoachCons(db)
	studentRepo := repository.StudentCons(db)
	relationRepo := repository.RelationCons(db)
	workoutRepo := repository.WorkoutCons(db)
	setRepo := repository.SetCons(db)
	sleepRepo := repository.SleepCons(db)
	ratingRepo := repository.RatingCons(db)
	mealRepo := repository.MealCons(db)
	documentRepo := repository.DocumentCons(db)
	refreshTokenRepo := repository.RefreshTokenCons(db)

	authandler := handlers.AuthCons(userRepo, studentRepo, coachRepo, documentRepo, refreshTokenRepo)
	relationHandler := handlers.RelationCons(userRepo, studentRepo, coachRepo, documentRepo, relationRepo)
	workoutHandler := handlers.WokrputCons(userRepo, studentRepo, coachRepo, relationRepo, workoutRepo, setRepo)
	mealHandler := handlers.MealCons(userRepo, studentRepo, coachRepo, relationRepo, mealRepo)
	sleepHandler := handlers.SleepCons(userRepo, studentRepo, coachRepo, relationRepo, sleepRepo)
	ratingHandler := handlers.RatingCons(userRepo, studentRepo, coachRepo, relationRepo, ratingRepo)
	documentHandler := handlers.DocumentCons(userRepo, studentRepo, coachRepo, relationRepo, documentRepo)

	c := cron.New()
	c.AddFunc("0 1 * * *", func() {
		relations, err := relationRepo.FindExpiredRequests()
		if err != nil {
			fmt.Println(err, "cronda_hata")
			return
		}

		for _, relation := range relations {
			relation.Status = entities.StatusExpired
			fmt.Println(relation.Status)
			updatErr := relationRepo.Update(&relation)
			if updatErr != nil {
				fmt.Println(updatErr)
				return

			}
		}
		fmt.Println(relations[0].Status)
	})
	c.Start()

	router := gin.Default()

	router.MaxMultipartMemory = 10 << 2

	router.POST("/register/coach", authandler.KayitCoach)
	router.POST("/register/student", authandler.KayitStudent)
	router.POST("/register/login", authandler.LogIn)
	router.POST("/refresh", authandler.RefreshAccessToken)

	router.POST("/coaches", utils.RequireRole("Student"), relationHandler.GetCoaches)
	router.POST("/relations/request", utils.RequireRole("Student"), relationHandler.SendRequest)
	router.POST("/relations/pending", utils.RequireRole("Coach"), relationHandler.GetPendingRequests)
	router.POST("/relations/accept", utils.RequireRole("Coach"), relationHandler.ApproveRequest)
	router.POST("/relations/reject", utils.RequireRole("Coach"), relationHandler.RejectRequest)
	router.POST("/relations/myStudents", utils.RequireRole("Coach"), relationHandler.GetMyStudents)
	router.POST("/relations/leave", utils.RequireRole("Student"), relationHandler.LeaveCoach)

	router.POST("/workout/workoutAdd", utils.RequireRole("Coach"), workoutHandler.AddWorkout)
	router.POST("/workout/workouts", utils.AuthMiddleware(), workoutHandler.GetWorkoutsByStudent)
	router.POST("/workout/workout", utils.AuthMiddleware(), workoutHandler.GetWorkoutDetail)

	router.POST("/meal/addMeal", utils.RequireRole("Student"), mealHandler.AddMeal)
	router.POST("/meal/dailyMeals", utils.AuthMiddleware(), mealHandler.GetMealSumDaily)
	router.POST("/meal/getMeals", utils.AuthMiddleware(), mealHandler.GetStudentsMealsByDate)
	router.POST("/meal/deleteMeal", utils.RequireRole("Student"), mealHandler.DeleteMeal)

	router.POST("/sleep/addSleep", utils.RequireRole("Student"), sleepHandler.AddSleep)
	router.POST("/sleep/getSleep", utils.AuthMiddleware(), sleepHandler.GetSleepByStudent)

	router.POST("/rate/addRating", utils.RequireRole("Student"), ratingHandler.AddRating)
	router.POST("/rate/getAvarage", utils.RequireRole("Student"), ratingHandler.GetCoachAvarage)

	router.POST("/document/addDocuments", utils.AuthMiddleware(), documentHandler.AddDocument)
	router.POST("/document/getDocumentList", utils.AuthMiddleware(), documentHandler.GetDocumentList)
	router.POST("/document/getDocument", utils.AuthMiddleware(), documentHandler.GetDocument)

	router.Run(":8080")
}
