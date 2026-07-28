package utils

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenstr := c.GetHeader("Authorization")

		if tokenstr == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "token is empty"})
			return
		}
		token := strings.TrimPrefix(tokenstr, "Bearer ")

		claims, errT := ValidateToken(token)
		if errT != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": errT.Error()})
			return
		}

		c.Set("user_id", claims.UserID)
		c.Set("role", claims.Role)
		c.Next()
	}
}
func RequireRole(role string) gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenstr := c.GetHeader("Authorization")
		if tokenstr == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "token is empty"})
			return
		}
		token := strings.TrimPrefix(tokenstr, "Bearer ")

		claims, errT := ValidateToken(token)
		if errT != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": errT.Error()})
			return
		}
		if string(claims.Role) != role {
			fmt.Println(string(claims.Role))
			fmt.Println(role)

			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "access denied"})
			return
		}
		c.Set("user_id", claims.UserID)
		c.Set("role", claims.Role)
		c.Next()
	}
}

//token ın  o kişiye ait olmasına bak eğer o kişiye ait değilse o isteği yapamıyor
// ilk başta kayıt yaparken  bu fonksiyona middlewaere ugulanması gerekioyr mu ve bu signup işlemlerinde middleware e gerek yok
// bütün gelen istekleri logla buraya yazacan logu ona da bak
