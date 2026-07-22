package entities

import (
	"time"
)

type User struct {
	ID              uint   `gorm:"primaryKey;autoIncrement"`
	Username        string `gorm:"size:32;not null"`
	PasswordHash    string `gorm:"not null"`
	PasswordConfirm string `gorm:"-"`
	Email           string `gorm:"size:100;unique;not null"`
	Role            Role   `gorm:"size:16;not null"`
	CreatedAt       time.Time
}
type Role string

const (
	StudentR Role = "Student"
	CoachR   Role = "Coach"
)

/*@startuml FitCoaching_ERD
skinparam linetype ortho
hide circle

entity "USERS" as users {
  * id : int <<PK>>
  --<<<<<
  username : string
  password_hash : string
  role : string
  email : string
}

entity "STUDENT " as student_profiles {
  * user_id : int <<PK, FK>>
  --
  age : int
  body_weight_kg : float
  body_fat_percentage : float
}

entity "COACH " as coach_profiles {
  * user_id : int <<PK, FK>>
  --
  specialty : string
  max_students : int
  price : decimal
}

entity "DOCUMENTS" as documents {
  * id : int <<PK>>
  --
  user_id : int <<FK>>
  document_type : string
  original_name : string
  file_type : string
  size_bytes : int
  file_blob : blob
  uploaded_at : datetime
}

entity "COACH_STUDENT " as relations {
  * id : int <<PK>>
  --
  student_id : int <<FK>>
  coach_id : int <<FK>>
  status : string
  requested_at : datetime
  expires_at : datetime
  started_at : datetime
  ended_at : datetime
}

entity "WORKOUTS" as workouts {
  * id : int <<PK>>
  --
  coach_id : int <<FK>>
  student_id : int <<FK>>
  date : date
}

entity "WORKOUT_SETS" as workout_sets {
  * id : int <<PK>>
  --
  workout_id : int <<FK>>
  movement_name : string
  set_number : int
  reps : int
  weight_kg : float
}

entity "MEALS" as nutrition_logs {
  * id : int <<PK>>
  --
  student_id : int <<FK>>
  meal_name : string
  description : string
  kcal : int
  protein_g : int
  oil_amount_ml : float
  date : date
}

entity "SLEEP " as sleep_logs {
  * id : int <<PK>>
  --
  student_id : int <<FK>>
  bed_time : time
  wake_time : time
  date : date
}

entity "RATINGS" as ratings {
  * id : int <<PK>>
  --
  student_id : int <<FK>>
  coach_id : int <<FK>>
  score : int
  created_at : datetime
}

users ||--o| student_profiles
users ||--o| coach_profiles
users ||--o{ documents
users ||--o{ relations : "student_id"
users ||--o{ relations : "coach_id"
users ||--o{ workouts : "student_id"
users ||--o{ workouts : "coach_id"
workouts ||--o{ workout_sets
users ||--o{ nutrition_logs
users ||--o{ sleep_logs
users ||--o{ ratings : "student_id"
users ||--o{ ratings : "coach_id"

@enduml */
