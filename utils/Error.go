package utils

import (
	"runtime"

	"github.com/gin-gonic/gin"
)

type ResponseS struct {
	Status bool    `json:"status"`
	Banner *string `json:"banner,omitempty"`
	Data   any     `json:"data,omitempty"` // buraya bak yıldız olmadan nil gönderilebilir mi başına yıldız koymadan omitempty kullanılabilir mi
	Line   int     `json:"line"`
}

func Response(c *gin.Context, response ResponseS) {
	_, _, line, _ := runtime.Caller(1)

	c.JSON(200, ResponseS{
		Status: response.Status,
		Banner: response.Banner,
		Data:   response.Data,
		Line:   line,
	})
}
