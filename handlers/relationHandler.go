package handlers

import (
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"fitcoaching/utils"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type RelationS struct {
	UserRep     repository.UserRepository
	StudentRep  repository.StudentRepository
	CoachRep    repository.CoachRepository
	DocumentRep repository.DocumentRepository
	RelationRep repository.RelationRepository
}

func RelationCons(userRep repository.UserRepository, studentRep repository.StudentRepository, coachRep repository.CoachRepository,
	documentRep repository.DocumentRepository, relationRep repository.RelationRepository) *RelationS {
	relation := &RelationS{}
	relation.UserRep = userRep
	relation.StudentRep = studentRep
	relation.CoachRep = coachRep
	relation.DocumentRep = documentRep
	relation.RelationRep = relationRep

	return relation
}

func (r *RelationS) GetCoaches(c *gin.Context) {

	coaches, err := r.CoachRep.GetAllFrees()
	filteredCoaches := make([]entities.Coach, 0)
	if err != nil {
		banner := "could not get the coaches"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	for _, coach := range coaches {
		if coach.MaxStudents > r.RelationRep.GetCoachsStudents(coach.UserID) {
			filteredCoaches = append(filteredCoaches, coach)
		}
	}
	banner := "success"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   filteredCoaches,
	})

	// enes abi bunda bişey demişti hepsini döndürme diye bunu sor nasıl olacağını
}

func (r *RelationS) SendRequest(c *gin.Context) {
	// öğrencinin koçu var mı kontrol et
	// öğrencinin bekleyen requesti var mı kontrol et
	//koçun size ı max mı
	// öğrenci uygunsa request i gönder koça
	userIDValue, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "user_id not found"})
		return
	}
	userID, ok := userIDValue.(uint)
	if !ok {
		c.JSON(http.StatusNotFound, gin.H{"error": "user_id not found"})
		return
	}
	_, errDB := r.RelationRep.FindCoachRelationFromStudentId(userID)
	if errDB == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "student have a coach"})
		return
	}

	_, errC := r.RelationRep.FindStudentRequest(userID)
	if errC == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "zaten 1 isteğin var  "})
		return
	}
	body := map[string]interface{}{}
	bindErr := c.ShouldBindJSON(&body)
	if bindErr != nil {
		banner := "make a valid operation"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	coachID := body["coach_id"].(float64)
	coachId := uint(coachID)
	coach, dbErrCoach := r.CoachRep.GetById(coachId)
	if dbErrCoach != nil {
		banner := "make a valid operation"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	if coach.MaxStudents <= r.RelationRep.GetCoachsStudents(coachId) {
		banner := "kapasitene ulaştın"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	deleteT := time.Now().Add(24 * time.Hour)
	relation := entities.Relation{
		StudentID:     userID,
		CoachID:       coachId,
		RequestedTime: time.Now(),
		Status:        entities.StatusWaiting,
		DeletedTime:   &deleteT,
	}
	errRel := r.RelationRep.Create(&relation)
	if errRel != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": errRel.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"Relation": relation})
}

// bunlarde koçun isteği görmemesi gibi bir durumu handlelamıyoruz galiba ona dikkat et
// koçun kapasite full mu ona bak
// date expired mı ona bak
func (r *RelationS) ApproveRequest(c *gin.Context) {

	userID, found := c.Get("user_id")
	if false == found {
		c.JSON(http.StatusNotFound, gin.H{"error": "user_id not found"})
		return
	}
	realCoachId, ok := userID.(uint)
	if ok == false {
		c.JSON(http.StatusNotFound, gin.H{"error": "user_id could not converted"})
		return
	}
	body := map[string]interface{}{}
	bindErr := c.ShouldBindJSON(&body)
	if bindErr != nil {
		banner := "make a valid operation"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	studentID := body["student_id"].(float64)
	studentId := uint(studentID)

	relation, dbErr := r.RelationRep.IsRelaitonWaiting(realCoachId, studentId)
	if dbErr != nil || relation == nil {
		banner := "db hatası"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	deletedTime := *relation.DeletedTime
	if deletedTime.Before(time.Now()) {
		banenr := "öğrenci isteğinin süresi doldu"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banenr,
		})
		return
	}
	coaches, dbErrC := r.StudentRep.GetCoachsStudents(realCoachId)
	if dbErrC != nil {
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: nil,
		})
		return
	}
	coach, dbErrC := r.CoachRep.GetById(realCoachId)
	if dbErrC != nil {
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: nil,
		})
		return
	}
	if len(coaches) >= coach.MaxStudents {
		banner := "kapasitenizden fazla öğrenci var"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	relation.Status = entities.StatusActive
	now := time.Now()
	relation.StartedTime = &now

	dbError := r.RelationRep.Update(relation)
	if dbError != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": dbError.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"relation": relation})

}
func (r *RelationS) RejectRequest(c *gin.Context) {

	userID, found := c.Get("user_id")
	if false == found {
		c.JSON(http.StatusNotFound, gin.H{"error": "user_id not found"})
		return
	}

	realCoachId, ok := userID.(uint)
	if ok == false {
		c.JSON(http.StatusNotFound, gin.H{"error": "user_id could not converted"})
		return
	}
	body := map[string]interface{}{}
	bindError := c.ShouldBindJSON(&body)
	if bindError != nil {
		banner := "make a valid operation"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	studentID := body["student_id"].(float64)
	studentId := uint(studentID)

	relation, dbErr := r.RelationRep.IsRelaitonWaiting(realCoachId, studentId)
	if dbErr != nil || relation == nil {
		banner := "db hatası"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	timeD := time.Now()
	relation.Status = entities.StatusRejected
	relation.StartedTime = nil
	relation.DeletedTime = &timeD
	dbError := r.RelationRep.Update(relation)
	if dbError != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": dbError.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"relation": "relation reset"})

}

func (r *RelationS) GetPendingRequests(c *gin.Context) {
	coachIDstr, exists := c.Get("user_id")
	if exists == false {
		c.JSON(http.StatusNotFound, gin.H{"error": "user_id not found"})
		return
	}
	coachId, ok := coachIDstr.(uint)
	if ok == false {
		c.JSON(http.StatusNotFound, gin.H{"error": "coach_id couldnot converted"})
		return
	}
	requests, errdb := r.RelationRep.FindPendingRequests(coachId)
	if errdb != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": errdb.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"PendingRequests": requests})
}

func (r *RelationS) GetMyStudents(c *gin.Context) {
	coachIDstr, exists := c.Get("user_id")
	if exists == false {
		c.JSON(http.StatusNotFound, gin.H{"error": "user_id not found"})
		return
	}
	coachId, ok := coachIDstr.(uint)
	if ok == false {
		c.JSON(http.StatusNotFound, gin.H{"error": "coach_id could not converted"})
		return
	}
	students, err := r.RelationRep.FindActiveByCoach(coachId)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"Students": students})
}

func (r *RelationS) GetMyCoach(c *gin.Context) {
	studentIDstr, exists := c.Get("user_id")

	if exists == false {
		c.JSON(http.StatusNotFound, gin.H{"error": "user_id not found"})
		return
	}
	studentId, ok := studentIDstr.(uint)
	if ok == false {
		c.JSON(http.StatusNotFound, gin.H{"error": "coach_id couldnot converted"})
		return
	}

	relation, errRel := r.RelationRep.FindCoachRelationFromStudentId(studentId)
	if errRel != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": errRel.Error()})
		return
	}
	if relation.StudentID != studentId {
		c.JSON(http.StatusBadRequest, gin.H{"error": "istekleri kendin için at "})
		return
	}

	coach, errCoach := r.CoachRep.GetById(relation.CoachID)
	if errCoach != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": errCoach.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"Coach": coach})
}

// coachla öğrenci işlişkisi var mı bak
// active mi ilişki ona bak eğer active se breakup a çevir
func (r *RelationS) LeaveCoach(c *gin.Context) {
	studentID, exists := c.Get("user_id")
	if exists == false {
		c.JSON(http.StatusNotFound, gin.H{"error": "user_id not found"})
		return
	}
	studentId, ok := studentID.(uint)
	if ok == false {
		c.JSON(http.StatusNotFound, gin.H{"error": "student_id couldnot converted"})
		return
	}

	body := map[string]interface{}{}
	bindErr := c.ShouldBindJSON(&body)
	if bindErr != nil {
		banner := "could not get the infos"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	coachID, okC := body["coach_id"].(float64)
	if okC == false {
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: nil,
		})
		return
	}
	coachId := uint(coachID)

	relStatus := r.RelationRep.IsRelaitonActive(coachId, studentId)
	if relStatus != true {
		c.JSON(http.StatusBadRequest, gin.H{"error": "koçla bağlantın yok "})
		return
	}

	relation, errR := r.RelationRep.FindCoachRelationFromStudentId(studentId)
	if errR != nil {
		banner := "bağlantı bulunamadı"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	relation.Status = entities.StatusBreakUp
	now := time.Now()
	relation.EndedTime = &now
	updateErr := r.RelationRep.Update(relation)
	if updateErr != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": updateErr.Error()})
		return
	}
	banner := "succesfully breaked up"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
	})

}

// bunu addRating e ekleyebiliriz her koçu
func (r *RelationS) GetPastCoach(c *gin.Context) {
	studentID, getStatus := c.Get("user_id")
	if getStatus == false {
		banner := "could not converted"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	studentId, ok := studentID.(uint)
	if ok == false {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	coach, dbError := r.StudentRep.GetLastCoach(studentId)
	if dbError != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}

	relStatus := r.RelationRep.IsRelaitonBreakedUP(coach.UserID, studentId)
	if relStatus != true {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	banner := "succes"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
		Data:   coach,
	})
}
