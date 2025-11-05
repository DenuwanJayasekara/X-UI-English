package controller

import (
	"net/http"
	"time"
	"x-ui/logger"
	"x-ui/web/global"
	"x-ui/web/service"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

type ServerController struct {
	BaseController

	serverService service.ServerService

	lastStatus        *service.Status
	lastGetStatusTime time.Time

	lastVersions        []string
	lastGetVersionsTime time.Time
}

func NewServerController(g *gin.RouterGroup) *ServerController {
	a := &ServerController{
		lastGetStatusTime: time.Now(),
	}
	a.initRouter(g)
	a.startTask()
	return a
}

func (a *ServerController) initRouter(g *gin.RouterGroup) {
	g = g.Group("/server")

	g.Use(a.checkLogin)
	g.POST("/status", a.status)
	g.POST("/getXrayVersion", a.getXrayVersion)
	g.POST("/installXray/:version", a.installXray)
	g.GET("/logs/ws", a.xrayLogsWebSocket)
}

func (a *ServerController) refreshStatus() {
	a.lastStatus = a.serverService.GetStatus(a.lastStatus)
}

func (a *ServerController) startTask() {
	webServer := global.GetWebServer()
	c := webServer.GetCron()
	c.AddFunc("@every 2s", func() {
		now := time.Now()
		if now.Sub(a.lastGetStatusTime) > time.Minute*3 {
			return
		}
		a.refreshStatus()
	})
}

func (a *ServerController) status(c *gin.Context) {
	a.lastGetStatusTime = time.Now()

	jsonObj(c, a.lastStatus, nil)
}

func (a *ServerController) getXrayVersion(c *gin.Context) {
	now := time.Now()
	if now.Sub(a.lastGetVersionsTime) <= time.Minute {
		jsonObj(c, a.lastVersions, nil)
		return
	}

	versions, err := a.serverService.GetXrayVersions()
	if err != nil {
		jsonMsg(c, "Get version", err)
		return
	}

	a.lastVersions = versions
	a.lastGetVersionsTime = time.Now()

	jsonObj(c, versions, nil)
}

func (a *ServerController) installXray(c *gin.Context) {
	version := c.Param("version")
	err := a.serverService.UpdateXray(version)
	jsonMsg(c, "Install xray", err)
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func (a *ServerController) xrayLogsWebSocket(c *gin.Context) {
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		logger.Error("websocket upgrade failed:", err)
		return
	}
	defer conn.Close()

	xrayService := service.XrayService{}
	process := xrayService.GetXrayProcess()
	if process == nil || !process.IsRunning() {
		conn.WriteMessage(websocket.TextMessage, []byte("Xray is not running\n"))
		return
	}

	logger.Info("WebSocket connection established for xray logs streaming")
	
	lines := process.GetLines()
	lastSize := lines.Len()
	
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			currentSize := lines.Len()
			if currentSize > lastSize {
				// Get new lines
				newLines := process.GetNewLines(lastSize)
				for _, line := range newLines {
					err := conn.WriteMessage(websocket.TextMessage, []byte(line+"\n"))
					if err != nil {
						logger.Warning("websocket write error:", err)
						return
					}
				}
				lastSize = currentSize
			}
		case <-c.Request.Context().Done():
			logger.Info("WebSocket connection closed")
			return
		}
	}
}
