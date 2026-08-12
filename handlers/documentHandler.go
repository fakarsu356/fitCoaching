package handlers

import (
	"fitcoaching/config"
	"fitcoaching/models/entities"
	"fitcoaching/repository"
	"fitcoaching/utils"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type DocumentS struct {
	UserRep     repository.UserRepository
	StudentRep  repository.StudentRepository
	CoachRep    repository.CoachRepository
	RelationRep repository.RelationRepository
	DocumentRep repository.DocumentRepository
}

func DocumentCons(userRep repository.UserRepository, studentRep repository.StudentRepository,
	coachRep repository.CoachRepository, relationRep repository.RelationRepository, documentRep repository.DocumentRepository) *DocumentS {
	doc := &DocumentS{}
	doc.UserRep = userRep
	doc.StudentRep = studentRep
	doc.CoachRep = coachRep
	doc.RelationRep = relationRep
	doc.DocumentRep = documentRep

	return doc
}

func (d *DocumentS) AddDocument(c *gin.Context) {

	userID, getStatus := c.Get("user_id")
	if getStatus == false {
		banner := "user id could not get"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	userId := userID.(uint)

	docType := entities.DocType(c.PostForm("type"))
	if docType!=entities.CaochSertificate || docType!=entities.HealthResults||
	 docType!=entities.MealPictures|| docType!=entities.CV{
			banner := "invalid type"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	

	form, formErr := c.MultipartForm()
	if formErr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	files := form.File["files"]
	if len(files) == 0 {
		banner := "en az 1 dosya gönderilmeli"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	for _, file := range files {

		if file.Size > config.MaxFileSize {
			banner := "file size too big"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}

		bytesf, errH := file.Open()
		if errH != nil {
			banner := "file cant open"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}

		defer bytesf.Close()

		bytes, errH := io.ReadAll(bytesf)
		if errH != nil {
			banner := "dosya okunamadı"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}

		contentType := http.DetectContentType(bytes)
		if !config.AllowedTypes[contentType] {
			banner := "PDF, JPEG,JPG veya PNG kabul edilir"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}
		str := strconv.FormatUint(uint64(userId), 10)

		fileDbName := str + "_" + time.Now().String()

		keybytes := []byte(os.Getenv("TOP_SECRET"))

		hashedDoc, hashError := utils.Encrypt(bytes, keybytes)
		if hashError != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})

			return
		}

		document := entities.Document{
			UploaderID: userId,
			UniqueName: fileDbName,
			DocName:    file.Filename,
			Size:       float64(file.Size),
			Date:       time.Now(),
			Doctype:    contentType,
			File:       hashedDoc,
			Type:       docType,
		}
		docerr := d.DocumentRep.Create(&document)
		if docerr != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}
	}
	banner := "the documents are saved"
	utils.Response(c, utils.ResponseS{
		Status: true,
		Banner: &banner,
	})

}

func (d *DocumentS) GetDocument(c *gin.Context) {
	userID, getStatus := c.Get("user_id")
	if getStatus == false {
		banner := "get user id error"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	userId := userID.(uint)

	Role, roleStatus := c.Get("role")
	if roleStatus == false {
		banner := "get user role error"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})

		return
	}

	role, roleOK := Role.(entities.Role)
	if roleOK == false {
		banner := "get role error"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
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

	fileID, ok := body["file_id"].(float64)
	if ok == false {
		banner := "file id can not get"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	fileId := int(fileID)

	doc, docErr := d.DocumentRep.GetById(fileId)
	if docErr != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	uploaderId := doc.UploaderID

	uploaderRole, uperr := d.UserRep.GetRoleById(uploaderId)
	if uperr != nil {
		banner := "role couldnot find "
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	fmt.Println(uploaderRole)
	fmt.Println(role)
	if uploaderRole == "Student" && role == "Coach" {
		status := d.RelationRep.IsRelaitonActive(userId, uploaderId)
		if status != true {
			banner := "bu senin öğrencin değil"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}

		doc, docErr := d.DocumentRep.GetById(fileId)
		if docErr != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}

		keyByte := []byte(os.Getenv("TOP_SECRET"))

		temp, decryptErr := utils.Decrypt(doc.File, keyByte)
		if decryptErr != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}

		docByts := temp
		banner := ""
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   docByts,
		})
	}
	if uploaderRole == "Student" && role == "Student" {
		if uploaderId != userId {
			banner := "kendi belgene istek at"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}

		doc, docErr := d.DocumentRep.GetById(fileId)
		if docErr != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}

		keyByte := []byte(os.Getenv("TOP_SECRET"))
		fmt.Println(keyByte)
		temp, decryptErr := utils.Decrypt(doc.File, keyByte)
		if decryptErr != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}

		docByts := temp // dosyayı sadece bu blob kısmını mı döndürmek lazım tüm dosyayı mı döndürmek lazım
		banner := "success"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   docByts,
		})
	}
	if uploaderRole == "Coach" && role == "Coach" {
		if uploaderId != userId {
			banner := "kendi belgene istek at "
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}

		doc, docErr := d.DocumentRep.GetById(fileId)
		if docErr != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}

		keyByte := []byte(os.Getenv("TOP_SECRET"))

		temp, decryptErr := utils.Decrypt(doc.File, keyByte)
		if decryptErr != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   decryptErr.Error(),
			})
			return
		}

		docByts := temp
		banner := "succes"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   docByts,
		})
	}
	if uploaderRole == "Coach" && role == "Student" { // koçun verilerini görebilsin mi çocuk
		banner := "koçun verisini görüntüleyemezsin"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
	}

}

func (d *DocumentS) GetDocumentList(c *gin.Context) {
	userID, getStatus := c.Get("user_id")
	if getStatus == false {
		banner := "get user id error"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
		})
		return
	}
	userId := userID.(uint)

	role, err := d.UserRep.GetRoleById(userId)
	if err != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}
	body := map[string]interface{}{}
	bindError := c.ShouldBindJSON(&body)
	if bindError != nil {
		banner := "hata"
		utils.Response(c, utils.ResponseS{
			Status: false,
			Banner: &banner,
			Data:   nil,
		})
		return
	}

	if role == "Student" {

		docs, docErr := d.DocumentRep.FindByUploader(userId)
		if docErr != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}
		if len(docs) > 0 && docs[0].UploaderID != userId {
			banner := "kendi belgene istek at "
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}

		DocumentList := make([]DocumentListItem, 0, len(docs))

		for _, doc := range docs {
			temp := DocumentListItem{
				ID:      doc.ID,
				DocName: doc.DocName,
				DocType: doc.Doctype,
				Date:    doc.Date,
			}
			DocumentList = append(DocumentList, temp)
		}
		banner := "success"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   DocumentList,
		})
	}
	if role == "Coach" {
		studentID, okStudent := body["student_id"].(float64)
		if okStudent == false {
			banner := "student_id gönderilmeli"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}
		studentId := uint(studentID)
		status := d.RelationRep.IsRelaitonActive(userId, studentId)
		if status != true {
			banner := "there is no relation between these 2"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
			})
			return
		}
		docs, docsErr := d.DocumentRep.FindByUploader(studentId)
		if docsErr != nil {
			banner := "hata"
			utils.Response(c, utils.ResponseS{
				Status: false,
				Banner: &banner,
				Data:   nil,
			})
			return
		}

		DocumentList := make([]DocumentListItem, 0, len(docs))

		for _, doc := range docs {
			temp := DocumentListItem{
				ID:      doc.ID,
				DocName: doc.DocName,
				DocType: doc.Doctype,
				Date:    doc.Date,
			}
			DocumentList = append(DocumentList, temp)
		}
		banner := "success"
		utils.Response(c, utils.ResponseS{
			Status: true,
			Banner: &banner,
			Data:   DocumentList,
		})
	}
}

type DocumentListItem struct {
	ID      uint
	DocName string
	DocType string
	Date    time.Time
}
