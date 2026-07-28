package handlers

import (
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"net/http"
	"strconv"
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

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, coaches)

	// enes abi bunda bişey demişti hepsini döndürme diye bunu sor nasıl olacağını
}

func (r *RelationS) SendRequest(c *gin.Context) {
	// öğrencinin koçu var mı kontrol et
	// öğrencinin bekleyen requesti var mı kontrol et
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
		c.JSON(http.StatusNotFound, gin.H{"error": "no error "})
		return
	}

	coachId := c.PostForm("coach_id")
	coachID, errConv := strconv.Atoi(coachId)
	if errConv != nil {
		c.JSON(400, gin.H{"error": "coach_id not found"})
		return
	}
	deleteT := time.Now().Add(24 * time.Hour)
	relation := entities.Relation{
		StudentID:     userID,
		CoachID:       uint(coachID),
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
	relation, errR := r.RelationRep.FindCoachRelationFromCoachId(realCoachId)

	if errR != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": errR.Error()})
		return
	}
	if realCoachId != relation.CoachID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "coach_id does not match"})
	}
	relation.Status = entities.StatusApproved
	relation.StartedTime = time.Now()

	dbError := r.RelationRep.Update(relation)
	if dbError != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": dbError.Error()})
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
	relation, errR := r.RelationRep.FindCoachRelationFromCoachId(realCoachId)

	if errR != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": errR.Error()})
		return
	}
	var zeroTime time.Time
	timeD := time.Now()
	relation.Status = entities.StatusRejected
	relation.StartedTime = zeroTime
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
		c.JSON(http.StatusNotFound, gin.H{"error": "coach_id couldnot converted"})
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
