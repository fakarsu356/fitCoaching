package main

import (
	"fitcoaching/config"
	"fitcoaching/models/entities"
	/*"fitcoaching/repository"*/)

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
/*	userRepo := repository.UserCons(db)
	coachRepo := repository.CoachCons(db)
	studentRepo := repository.StudentCons(db)
	workoutRepo := repository.WorkoutCons(db)
	setRepo := repository.SetCons(db)
	sleepRepo := repository.SleepCons(db)
	ratingRepo := repository.RatingCons(db)
	mealRepo := repository.MealCons(db)
	relationRepo := repository.RelationCons(db)
	documentRepo := repository.DocumentCons(db)
	
	
	
	
	
	
POST /register/student  → JSON gönderiyor
POST /register/coach    → FormData gönderiyor (dosya var)

router.MaxMultipartMemory = 10 << 20   // 10 MB */

}
