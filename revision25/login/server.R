# marxan.io

library(shiny)
library(iptools)

Logged = FALSE;
load(file=paste0(sShinyPath,"/passwd.Rdata"))
PASSWORD <- passwd

shinyServer(function(input, output, session, clientData) {

  source(paste0(sAppDir,"/login.R"),  local = TRUE)
  source(paste0(sShinySourcePath,"/server_pre_marxan.R"),  local = TRUE)

  observe({
    #if (USER$Logged == TRUE)
    {
        if (USER$Logged == TRUE)
        {
            InitialiseUserSession()
            #iLogout <<- 0
        }
        # user authenticated - render the user interface
        output$sidebarui <- renderUI({
          if (USER$Logged == TRUE)
          {
          sidebarPanel(
              textOutput("usermessage"),
              br(),
              textOutput("userLocation"),
              textOutput("lastLogin"),
              br(),
              a("Run Marxan", href=paste0("http://marxan.io/rshiny/apps/",sUserName,"/",sMarxanApp,"/?session=",sUserSessionKey), target="_blank"),
              br(),
              br(),
              #a("Run MarZone", href=paste0("http://marxan.io/rshiny/apps/",sUserName,"/",sMarZoneApp,"/?session=",sUserSessionKey), target="_blank"),
              #br(),
              #br(),
              a("Upload a dataset", href=paste0("http://marxan.io/rshiny/apps/",sUserName,"/",sUploadApp,"/?session=",sUserSessionKey), target="_blank"),
              br()#,
              #br(),
              #actionButton("logout","Logout")
          ) # sidebarPanel
          }
        }) # renderUI
    } # if
  }) # observe
  
  observe({
      if (USER$Logged == TRUE)
      {
          if (!is.null(input$logout))
          {
          cat(paste0("input$logout ",input$logout," iLogout ",iLogout,"\n"))

          if (input$logout > iLogout)
          {
              iLogout <<- input$logout
              # user clicked logout
              cat(paste0("click logout ",input$logout," iLogout ",iLogout,"\n"))
              LogoutSession()
          }
          }
      }
  })
  
  output$usermessage = renderText({
      if (USER$Logged == TRUE)
      {
          sprintf(paste0("Hello ",sUserName))
      } else {
          sprintf("")
      }
  })

  observe({
      sUserIP <<- as.character(input$ipid)
      UserGeoIP <<- freegeoip(sUserIP)
      Hostname <- ip_to_hostname(sUserIP)
      sUserHostname <<- Hostname[[1]]
  })

  output$userLocation <- renderText({
      paste0("Login from ",sUserHostname)
  })

  observe({
      if (USER$Logged == TRUE)
      {
          # User has logged in. Record details about the HTTP session.
          query <- parseQueryString(session$clientData$url_search)
          sText <- paste0("fingerprint: ", input$fingerprint,"\n",
                          "ip: ", sUserIP,"\n",
                          "userhostname: ",sUserHostname,"\n",
                          "protocol: ", session$clientData$url_protocol, "\n",
                          "hostname: ", session$clientData$url_hostname, "\n",
                          "pathname: ", session$clientData$url_pathname, "\n",
                          "port: ",     session$clientData$url_port,     "\n",
                          "search: ",   session$clientData$url_search,   "\n",
                          "queries: ",paste(names(query), query, sep = "=", collapse=", "),"\n")
                          
          AppendLogFile(sText)
          cat(paste0(sText,"\n"))
      }
  })
  
  output$lastLogin <- renderText({
      if (USER$Logged == TRUE)
      {
          sLastLogin <- paste0(sUserHome,"/lastLogin.Rdata")
          if (file.exists(sLastLogin))
          {
              load(file=sLastLogin)
              sMessage <- paste0("Last login ",as.character(LastLoginDate)," from ",sUserLastHostname)
          } else {
              sMessage <- "First login"
          }
          
          LastLoginDate <- date()
          sUserLastIP <- sUserIP
          sUserLastHostname <- sUserHostname
          UserLastGeoIP <- UserGeoIP
          save(LastLoginDate,sUserLastIP,sUserLastHostname,UserLastGeoIP,file=sLastLogin)
          
          sMessage
      }
  })
  
})
