package main

import (
	"fitcoaching/config"
	"fitcoaching/handlers"
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"fitcoaching/utils"

	"github.com/gin-gonic/gin"
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
	)

	userRepo := repository.UserCons(db)
	coachRepo := repository.CoachCons(db)
	studentRepo := repository.StudentCons(db)
	relationRepo := repository.RelationCons(db)

	workoutRepo := repository.WorkoutCons(db)
	setRepo := repository.SetCons(db)

	sleepRepo := repository.SleepCons(db)
	/*ratingRepo := repository.RatingCons(db) */

	mealRepo := repository.MealCons(db)
	documentRepo := repository.DocumentCons(db)

	authandler := handlers.AuthHandler(userRepo, studentRepo, coachRepo, documentRepo)
	relationHandler := handlers.RelationCons(userRepo, studentRepo, coachRepo, documentRepo, relationRepo)

	workoutHandler := handlers.WokrputCons(userRepo, studentRepo, coachRepo, relationRepo, workoutRepo, setRepo)
	mealHandler := handlers.MealCons(userRepo, studentRepo, coachRepo, relationRepo, mealRepo)
	sleepHandler := handlers.SleepCons(userRepo, studentRepo, coachRepo, relationRepo, sleepRepo)
	router := gin.Default()
	router.MaxMultipartMemory = 10 << 20

	router.POST("/register/coach", authandler.KayitCoach)
	router.POST("/register/student", authandler.KayitStudent)
	router.POST("/register/login", authandler.LogIn)

	router.POST("/coaches", utils.RequireRole("Student"), relationHandler.GetCoaches)
	// İlişki Rotaları (Sadece giriş yapmış kullanıcılar)
	router.POST("/relations/request", utils.RequireRole("Student"), relationHandler.SendRequest)
	router.POST("/relations/pending", utils.RequireRole("Coach"), relationHandler.GetPendingRequests)
	router.POST("/relations/accept", utils.RequireRole("Coach"), relationHandler.ApproveRequest)
	router.POST("/relations/reject", utils.RequireRole("Coach"), relationHandler.RejectRequest)
	router.POST("/relations/myStudents", utils.RequireRole("Coach"), relationHandler.GetMyStudents)

	router.POST("/workout/workoutAdd", utils.RequireRole("Coach"), workoutHandler.AddWorkout)
	router.POST("/workout/workouts", workoutHandler.GetWorkoutsByStudent)
	router.POST("/workout/workout", workoutHandler.GetWorkoutDetail)

	router.POST("/meal/addMeal", utils.RequireRole("Student"), mealHandler.AddMeal)
	router.POST("/meal/dailyMeals", mealHandler.GetMealSumDaily)
	router.POST("/meal/getMeals", mealHandler.GetMealsByStdudent)
	router.POST("/meal/deleteMeal", utils.RequireRole("Student"), mealHandler.DeleteMeal)

	router.POST("/sleep/addSleep", utils.RequireRole("Student"), sleepHandler.AddSleep)

	router.Run(":8080")
}
