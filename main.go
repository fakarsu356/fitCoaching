package main

import (
	"fitcoaching/config"
	"fitcoaching/handlers"
	"fitcoaching/models/entities"
	"fitcoaching/repository"

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
	/*
		workoutRepo := repository.WorkoutCons(db)
		setRepo := repository.SetCons(db)
		sleepRepo := repository.SleepCons(db)
		ratingRepo := repository.RatingCons(db)
		mealRepo := repository.MealCons(db)
	*/

	documentRepo := repository.DocumentCons(db)

	authandler := handlers.AuthHandler(*userRepo, *studentRepo, *coachRepo, *documentRepo)
	relationHandler := handlers.RelationHandler(*userRepo, *studentRepo, *coachRepo, *documentRepo, *relationRepo)

	router := gin.Default()
	router.MaxMultipartMemory = 10 << 20 // 10 MB

	router.POST("/register/coach", authandler.KayitCoach)
	router.POST("/register/student", authandler.KayitStudent)
	router.POST("/register/login", authandler.LogIn)

	router.POST("/coaches", relationHandler.GetCoaches)
	router.POST("/relations/leave ", relationHandler.GetCoaches)
	router.POST("/relations/request")
	router.POST("/relations/pending")
	router.POST("/relations/accept")
	router.POST("/relations/reject")
	router.POST("/relations/my-coach")

	router.Run(":8080")
}
