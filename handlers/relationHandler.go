package handlers

import (
	"fitcoaching/repository"
	"net/http"

	"github.com/gin-gonic/gin"
)

type Relation struct {
	UserRep     repository.UserRepository
	StudentRep  repository.StudentRepository
	CoachRep    repository.CoachRepository
	DocumentRep repository.DocumentRepository
	RelationRep repository.RelationRepository
}

func RelationHandler(userRep repository.UserRepository, studentRep repository.StudentRepository, coachRep repository.CoachRepository,
	documentRep repository.DocumentRepository, relationRep repository.RelationRepository) *Relation {
	relation := &Relation{}
	relation.UserRep = userRep
	relation.StudentRep = studentRep
	relation.CoachRep = coachRep
	relation.DocumentRep = documentRep
	relation.RelationRep = relationRep

	return relation
}

func (r *Relation) GetCoaches(c *gin.Context) {

	coaches, err := r.CoachRep.GetAllFrees()

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, coaches)

}

func (r *Relation) SendRequest(c *gin.Context) {

}
