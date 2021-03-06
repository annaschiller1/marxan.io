# marxan.io upload

library(shiny)
library(sp)
library(maptools)
library(PBSmapping)
library(foreign)
library(sqldf)
library(vegan)
library(labdsv)
library(xtable)
library(foreach)
library(doMC)
library(rhandsontable)
library(iptools)
library(png)
library(rjson)

# Set the file size limit for uploads here in megabytes
iMegabytes <- 500
options(shiny.maxRequestSize = iMegabytes*1024^2)

registerDoMC(iRepsPerCore)  # the number of CPU cores

Logged = FALSE;
load(file=paste0(sShinyPath,"/passwd.Rdata"))
PASSWORD <- passwd

#x__ <<- 1
#y__ <<- 1
iAspectX <<- 1
iAspectY <<- 1

shinyServer(function(input, output, session, clientData) {

  # user encryption of data files

  #system(paste0("touch ",sAppDir,"/restart.txt"))
  
  observe({
      sUserIP <<- as.character(input$ipid)
  })
  
  source(paste0(sAppDir,"/authenticate.R"),  local = TRUE)

  source(paste0(sAppDir,"/prepare_param_test.R"),  local = TRUE)
  source(paste0(sAppDir,"/ingest_marxan_data.R"),  local = TRUE)
  source(paste0(sAppDir,"/server_pre_marxan.R"),  local = TRUE)

  observe({
    if (USER$Logged == TRUE)
    {
        # render the user interface
        source(paste0(sAppDir,"/render_ui.R"),  local = TRUE)
    } # if
  }) # observe
  
  observe({
    if (USER$Logged == TRUE)
    {
        sDatabase <<- input$uploadname
    }
  }) # observe
  
  output$contents <- renderTable({
    # input$file1 is the zip file containing the Marxan database.
    # summarytable lists info gleaned from parsing the Marxan database.

    inFile <- input$file1

    if (is.null(inFile))
      return(NULL)

    file.copy(as.character(inFile$datapath),paste0(sUserSession,"/",as.character(inFile$name)),overwrite=TRUE)

    ptm <- proc.time()
    ParseResult <- ParseMarxanZip(paste0(sUserSession,"/",as.character(inFile$name)),sUserSession,sShinyUserPath,sShinyDataPath,sUserName)
    iElapsed <- (proc.time() - ptm)[3]
    summarytable <- rbind(c("name",as.character(inFile$name)),
                          c("size",paste0(as.character(inFile$size)," bytes")),
                          c("elapsed",paste0(as.character(iElapsed)," seconds")),
                          c("type",as.character(inFile$type))) #,
                          #c("datapath",as.character(inFile$datapath)))
    ReadParseErrors(ParseResult)
    if (is.null(Warnings))
    {
        summarytable <- rbind(summarytable,c("Warnings",0))
    } else {
        summarytable <- rbind(summarytable,c("Warnings",length(Warnings)))
        for (i in 1:length(Warnings))
        {
            summarytable <- rbind(summarytable,c("Warning",as.character(Warnings[i])))
        }
    }
    if (is.null(Errors))
    {
        summarytable <- rbind(summarytable,c("Errors",0))
    } else {
        summarytable <- rbind(summarytable,c("Errors",length(Errors)))
        for (i in 1:length(Errors))
        {
            summarytable <- rbind(summarytable,c("Error",as.character(Errors[i])))
        }
    }
    updateTextInput(session, "uploadname",value = SafeDbName(basename(file_path_sans_ext(inFile$name)),sShinyUserPath,sUserName))

    as.data.frame(summarytable)
  })

  acceptclicked <- reactive({

      cat("acceptclicked\n")

      if (USER$Logged == TRUE)
      if (!is.null(input$acceptupload))
      if (input$acceptupload > 0)
      {
          AppendLogFile(paste0("input$acceptupload start ",input$acceptupload))

          cat(paste0("click acceptupload ",input$acceptupload,"\n"))

          # validate accept

          # add this database to list of databases
          sDatabasePath <- paste0(sUserHome,"/",sDatabase)
          cat(paste0("sDatabasePath ",sDatabasePath,"\n"))
          # create directory
          if (!file.exists(sDatabasePath))
          {
              AddDatabase(sDatabasePath)

              # trigger a refresh of the relevant UI components
              updateSelectInput(session, "database",choices = c(list.dirs(sUserHome)))
              return(1)
          } else {
              # duplicate database name detected
              return(2)
          }

          AppendLogFile(paste0("input$acceptupload end ",input$acceptupload))

      } else {
          return(0)
      }
  })
  
  output$feedbackupload = renderText({
      if (acceptclicked() == 1)
      {
         sprintf("Accepted")
      } else {
          if (acceptclicked() == 2)
          {
             sprintf("Duplicate Database Name")
          } else {
              sprintf("")
          }
      }
  })

  output$usermessage = renderText({
      if (USER$Logged == TRUE)
      {
          sprintf(paste0("Welcome ",sUserName))
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
      if (UserGeoIP == "unknown")
      {
          sText <- paste0("Login from ",sUserHostname)
      } else {
          sText <- paste0("Login from ",sUserHostname," ",UserGeoIP$city)
      }
      sText
  })

  observe({
      if (USER$Logged == TRUE)
      {
          # User has logged in. Record details about the HTTP session.
          query <- parseQueryString(session$clientData$url_search)
          if (UserGeoIP == "unknown")
          {
              sText <- paste0("fingerprint: ", input$fingerprint,"\n",
                              "ip: ", sUserIP,"\n",
                              "userhostname: ",sUserHostname,"\n",
                              "protocol: ", session$clientData$url_protocol, "\n",
                              "hostname: ", session$clientData$url_hostname, "\n",
                              "pathname: ", session$clientData$url_pathname, "\n",
                              "port: ",     session$clientData$url_port,     "\n",
                              "search: ",   session$clientData$url_search,   "\n",
                              "queries: ",paste(names(query), query, sep = "=", collapse=", "),"\n",
                              "country_code: ","unknown","\n",
                              "country_name: ","unknown","\n",
                              "region_code: ","unknown","\n",
                              "region_name: ","unknown","\n",
                              "city: ","unknown","\n",
                              "latitude: ","unknown","\n",
                              "longitude: ","unknown")
          } else {
              sText <- paste0("fingerprint: ", input$fingerprint,"\n",
                              "ip: ", sUserIP,"\n",
                              "userhostname: ",sUserHostname,"\n",
                              "protocol: ", session$clientData$url_protocol, "\n",
                              "hostname: ", session$clientData$url_hostname, "\n",
                              "pathname: ", session$clientData$url_pathname, "\n",
                              "port: ",     session$clientData$url_port,     "\n",
                              "search: ",   session$clientData$url_search,   "\n",
                              "queries: ",paste(names(query), query, sep = "=", collapse=", "),"\n",
                              "country_code: ",UserGeoIP$country_code,"\n",
                              "country_name: ",UserGeoIP$country_name,"\n",
                              "region_code: ",UserGeoIP$region_code,"\n",
                              "region_name: ",UserGeoIP$region_name,"\n",
                              "city: ",UserGeoIP$city,"\n",
                              "latitude: ",UserGeoIP$latitude,"\n",
                              "longitude: ",UserGeoIP$longitude)
          }
                          
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
              if (UserLastGeoIP == "unknown")
              {
                  sMessage <- paste0("Last login ",as.character(LastLoginDate)," from ",sUserLastHostname)
              } else {
                  sMessage <- paste0("Last login ",as.character(LastLoginDate)," from ",sUserLastHostname," ",UserLastGeoIP$city)
              }
          } else {
              sMessage <- "First login"
          }
          
          LastLoginDate <- date()
          #UserGeoIP <- freegeoip(sUserIP)
          sUserLastIP <- sUserIP
          sUserLastHostname <- sUserHostname
          UserLastGeoIP <- UserGeoIP
          save(LastLoginDate,sUserLastIP,sUserLastHostname,UserLastGeoIP,file=sLastLogin)
          
          sMessage
      }
  })
  
})
