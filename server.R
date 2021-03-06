library(shiny)
library(magicaxis)
#library(lomb)
#library(ggplot2)
# use the below options code if you wish to increase the file input limit, in this example file input limit is increased from 5MB to 9MB
# options(shiny.maxRequestSize = 9*1024^2)
source('periodoframe.R')
source("periodograms.R")
source('functions.R',local=TRUE)
options(shiny.maxRequestSize=30*1024^2) 
Nmax.plots <- 50
count0 <- 0
instruments <- c('HARPS','SOHPIE','HARPN','AAT','KECK','APF','PFS')
tol <- 1e-16
#trend <- FALSE
data.files <- list.files(path='data',full.name=FALSE)

shinyServer(function(input, output, session){
####select from list
    output$about <- renderUI({HTML(paste("
<html>
<head>
<style>
p {
    text-indent: 25px;
}
</style>
</head>
<body>
<br />
<p>Agatha is the name of my wife's most favorite crime novelist, Agatha Christie. Similar to the investigations of various crimes in the detective novels, the Agatha algorithm is to find the weak signals embedded in correlated noise.

This web app is based on the code in GitHub: <a href='https://github.com/phillippro/agatha'>https://github.com/phillippro/agatha</a>. If you use this web app in your work, please cite 'Feng F., Tuomi M., Jones H. R. A., 2017, Agatha: disentangling periodic signals from correlated noise in a periodogram framework, MNRAS in press'. This paper is put on <a href='https://arxiv.org/abs/1705.03089'>arxiv</a>.</p>

<p>Agatha has the following features:</p>
<ul>
  <li>Fit the time-correlated noise using the moving average model</li>
  <li>Compare noise models to select the Goldilocks noise model (Feng et al. 2016, MNRAS, 461, 2440; available <a href='https://arxiv.org/abs/1606.05196'>here</a>)</li>
  <li>Optimize the frequency-dependent linear trend simultaneously with sinusoids and noise components</li>
  <li>Account for wavelength-dependent noise by fitting a set of linear functions of the difference between radial velocities (or other wavelength-dependent proxies for non-RV data sets) measured at different wavelengths</li>
  <li>Assess the significance of signals using the BIC-estimated Bayes factor</li>
  <li>Produce the so-called \"moving/2D periodogram\" to visualize the change of signals with time thus visually testing the consistency of signals.</li>
</ul>

<p>
Agatha is based on the Bayes factor periodogram (BFP) and the marginalized likelihood periodogram (MLP). The BFP is calculated by maximizing the likelihood of a combination of sinusoids, linear functions of time and noisy proxies, and the moving average model. The Bayes factor for a given frequency is derived from the maximum likelihood by approximating the Bayes factor using the Bayes Information Criterion (BIC). The MLP is calculated by marginalizing the likelihood over the amplitudes of sinusoids and the parameters in a linear function of time. Before calculating MLP, the best-fitted noise model is subtracted from the data.
</p>

<p>
The BFP and MLP can be compared with the Lomb-Scargle periodogram (LS), the generalized LS (GLS), the GLS with floating trend (GLST) and the Bayesian GLS (BGLS). All periodograms can be computed for the sub-dataset within a moving time window to form 2D periodograms, which are also called 'moving periodograms'. Moving periodograms are used to check the consistency of signals in time. The user should adjust the 'visualization parameters' to optimize the visualization of signals in moving periodograms.
</p>
</body>
</html>
"))})

  output$files <- renderUI({
    if(is.null(input$uptype)) return()
    if(input$uptype=='list'){
        selectizeInput('target','Select data files from the list',
                  choices=gsub('\\..+','',gsub('_TERRA.+','',list.files('data',
                                    full.names=FALSE))),multiple=TRUE)
    }else if(input$uptype=='upload'){
        fileInput('files', 'Choose files', multiple=TRUE)
#selectizeInput('Nf','Number of files to upload',choices=1:10,selected=1,multiple=FALSE)
    }
  })

    output$uptext <- renderUI({
        if(is.null(input$uptype)) return()
        if(input$uptype=='upload'){
            helpText("The file name should be 'star_instrument.fmt' where 'fmt' could be any plain text format. It is better to name the columns. Otherwise, the app will treat the data as radial velocity data. The first three columns should be observation times, observables (interpreted as RVs here) and measurement uncertainties, while the other columns are noise proxies.")
        }
    })

 output$nI.max <- renderUI({
      if(is.null(input$proxy.type)) return()
      if(input$proxy.type=='cum'){
          selectInput("ni.max",'Maximum number of noise proxies',choices = 0:NI.max()[input$comp.target],selected = min(3,NI.max()[input$comp.target]))
      }
  })

    NI.max <- reactive({
        if(is.null(data())) return()
        val <- c()
        for(i in 1:length(data())){
            val <- c(val,ncol(data()[[i]])-3)
        }
        names(val) <- names(data())
        return(val)
    })

    output$per.type.seq <- renderUI({
        if(is.null(input$sequence)) return()
        if(!input$sequence) return()
        selectInput("per.type.seq",'Periodogram used to find additional signals',choices=input$per.type,selected=NULL,multiple=FALSE)
    })

 output$Nsig.max <- renderUI({
        if(is.null(input$sequence)) return()
        if(input$sequence) sliderInput("Nsig.max", "Maximum number of signals", min = 2, max = 10,value=3,step=1)
    })

  output$nma <- renderUI({
    if(is.null(Ntarget())) return()
    if(any(input$per.type=='MLP' | input$per.type=='BFP')){
        lapply(1:Ntarget(), function(i){
            selectizeInput(paste0("Nma",i),paste('Number of MA components for',input$per.target[i]),choices = 0:10,selected = 0,multiple=FALSE)
        })
    }
  })

  output$nma2 <- renderUI({
    if(is.null(Ntarget2())) return()
    if(any(input$per.type2=='MLP' | input$per.type2=='BFP')){
        lapply(1:Ntarget2(), function(i){
            selectizeInput(paste0("Nma2.",i),paste('Number of MA components for',input$per.target2[i]),choices = 0:10,selected = 0,multiple=FALSE)
        })
    }
  })

    output$per.target <- renderUI({
        if(is.null(data())) return()
        selectizeInput("per.target",'Data sets',choices=names(data()),selected=names(data())[1],multiple=TRUE)
    })

    Ntarget <- reactive({
        if(is.null(input$per.target)) return()
        length(input$per.target)
    })

    output$per.target2 <- renderUI({
        if(is.null(data())) return()
        selectizeInput("per.target2",'Data sets',choices=names(data()),selected=names(data())[1],multiple=TRUE)
    })

    Ntarget2 <- reactive({
        length(input$per.target2)
    })

    output$per.type <- renderUI({
        if(is.null(Ntarget())) return()
        if(Ntarget()>1){
            selectInput("per.type",'Periodogram type',
                        choices=c('MLP'),selected="MLP",multiple=TRUE)
        }else{
            selectInput("per.type",'Periodogram type',
                        choices=c('BFP','MLP','GLST','BGLS','GLS','LS'),selected="BFP",multiple=TRUE)
        }
    })

    output$per.type2 <- renderUI({
        if(is.null(Ntarget2())) return()
        if(Ntarget2()>1){
            selectInput("per.type2",'Periodogram type', choices='MLP',selected="MLP",multiple=FALSE)
        }else{
            selectInput("per.type2",'Periodogram type',
                        choices=c('BFP','MLP','GLST','BGLS','GLS','LS'),selected="MLP",multiple=TRUE)
        }
    })

    output$text2D <- renderText({
        "<font color=\"DarkSlateGray\"><b>To make 2D periodograms, the time series should be properly sampled and each time window should contain at least a few data points, e.g. 100 data points over a time span beyond 200 time units. </b></font>"
    })

    output$Inds <- renderUI({
        if(is.null(input$per.type) | is.null(data()) | is.null(Ntarget())) return()
#        if(all(NI.max()==0)) return()
        if(input$per.type!='BFP' & input$per.type!='MLP') return()
        lapply(1:Ntarget(),function(i){
            selectInput(paste0('Inds',i),paste('Noise proxies for',input$per.target[i]),choices = 0:NI.max()[input$per.target[i]],selected = 0,multiple=TRUE)
        })
    })

    output$Inds2 <- renderUI({
        if(is.null(data()) | is.null(input$per.target2)) return()
        lapply(1:Ntarget2(),function(i){
            selectInput(paste0("Inds2.",i),paste('Noise proxies for',input$per.target2[i]),choices = 0:NI.max()[input$per.target2[i]],selected = 0,multiple=TRUE)
        })
    })

    output$prange2 <- renderUI({
        if(is.null(input$Dt) | is.null(data()) | is.null(input$per.target2)) return()
        Dt <- signif(tspan()*as.numeric(input$Dt),3)
        fmin <- 1/Dt
        logpmin <- -1
        logpmax <- signif(log10(Dt),2)
        sliderInput("prange2","Period range in base-10 log scale",min = logpmin,max = logpmax,value = c(0.1,logpmax),step=0.1)
    })

    output$proxy.text <- renderUI({
      helpText("If 'cumulative' is selected, the noise proxies would be arranged in decreasing order of the Pearson correlation coefficients between proxies and RVs. Then proxies would be compared cumulatively from the basic number up to the maximum number of proxies. If 'group' is selected, the proxies would not be rearranged, and would be compared in groups, which are determined by the basic number of proxies and group division numbers. For example, if the basic number is 4 and division numbers are 6,11,19, models with proxies of {1-4}, {1-6}, {1-4, 7-11}, {1-4, 12-19} would be compared. If 'manual' is selected, the user should manually input the groups of proxies for comparison. Note that '0' means no proxy. ")
  })

    output$comp.target <- renderUI({
        if(is.null(data())) return()
        selectizeInput("comp.target",'Data sets',choices=names(data()),selected=names(data())[1],multiple=FALSE)
    })

  output$proxy.type <- renderUI({
      if(is.null(NI.max())) return()
      if(any(NI.max()[input$comp.target]>0)){
          radioButtons("proxy.type",'Type of proxy comparison',c("Cumulative"="cum","Group"='group','Manual'='man'))
      }else{
          output$warn <- renderText({'No indices available for comparison!'})
          verbatimTextOutput("warn")
      }
  })

  output$nI.basic <- renderUI({
      if(is.null(input$proxy.type)) return()
      if(NI.max()[input$comp.target]>0 & input$proxy.type!='man'){
#input$proxy.type=='cum'
          selectInput("NI0",'Basic number of noise proxies',choices = 0:NI.max()[input$comp.target],selected = 0)#NI.max())
      }
  })

    output$Nman <- renderUI({
        if(is.null(input$proxy.type)) return()
        if(input$proxy.type=='man' & NI.max()[input$comp.target]>0){
#            sliderInput("Nman",'Number of proxy groups',min=1,max=NI.max(),value=1,step=1)
            selectizeInput("Nman",'Number of proxy groups',choices=1:6,selected=1,multiple=FALSE)
        }
    })

    output$nI.man <- renderUI({
        if(is.null(input$proxy.type) | is.null(input$Nman)) return()
        if(input$proxy.type=='man' & NI.max()[input$comp.target]>0){
            lapply(1:as.integer(input$Nman), function(i) {
                selectInput(paste0("NI.man",i),paste0('proxy group ',i),
                            choices=0:NI.max()[input$comp.target],multiple = TRUE)
            })
        }
    })

  output$nI.comp <- renderUI({
    if(is.null(input$proxy.type) | is.null(input$NI0)) return()
    if(input$proxy.type=='group' & NI.max()[input$comp.target]>as.integer(input$NI0)){
      selectInput("NI.group",'Group division numbers',
                  choices=(as.integer(input$NI0)+1):NI.max()[input$comp.target],multiple = TRUE )
    }
  })

  target.list <- reactive({
    f1 <- gsub('_TERRA.+','',list.files('data',full.names=FALSE))
    gsub('.dat','',f1)
  })

  target <- reactive({
    if(is.null(input$target) & is.null(input$files)) return()
    if(input$uptype=='list'){
      return(input$target)
    }else if(input$uptype=='upload'){
        fname <- unlist(lapply(1:length(input$files),function(j){ input$files[j]$name}))
        f <- gsub('.([[:alpha:]]+)$','',fname)
        f <- gsub('_TERRA','',f)
        return(f)
    }
  })

  instr <- reactive({
      gsub('.+_','',target())
  })

  # added "session" because updateSelectInput requires it
  data <- eventReactive(input$show,{
    ins <- instr()
    #input$show
    if(input$uptype=='upload'){
        if(length(instr())>0){
            tmp <- list(NA)
            df <- rep(tmp,length(input$files[,1]))
            ns <- c()
            for(i in 1:length(input$files[,1])){
                data.path <- input$files[[i,'datapath']]
                ns <- c(ns,input$files[[i,'name']])
                tab <- read.table(data.path,nrows=1)
                if(class(tab[1,1])=='factor'){
                    tab <- read.table(data.path,header=TRUE,check.names=FALSE)
                }else{
                    tab <- read.table(data.path)
                }
                inds <- sort(tab[,1],index.return=TRUE)$ix
                tab <- tab[inds,]
                if(any(diff(tab[,1])==0)){
                    ind <- which(diff(tab[,1])==0)
                    tab <- tab[-ind,]
                }
                ind <- c()
                for(j in 1:ncol(tab)){
                    if(sd(tab[,j])!=0) ind <- c(ind,j)
                }
                df[[i]] <- tab[,ind]
                cat('ins=',ins,'\n')
                if(is.null(tab)){
                    if(ncol(df[[i]])==6 & ins[i]=='HARPS'){
                        colnames(df[[i]])=c('Time','RV','eRV','BIS','FWHM','S-index')#harps
                    }else if(ncol(df[[i]])==7 & ins[i]=='KECK'){
                        colnames(df[[i]])=c('Time','RV','eRV','S-index','H-alpha','Photon Count','ObservationTimes')#new keck
                    }else if(ncol(df[[i]])==6 & ins[i]=='KECK'){
                        colnames(df[[i]])=c('Time','RV','eRV','S-index','Photon Count','ObservationTimes')#old keck
                    }else if(ncol(df[[i]])==3){
                        colnames(df[[i]])=c('Time','RV','eRV')#other
                    }else{
                        colnames(df[[i]])=c('Time','RV','eRV',paste0('proxy',1:(ncol(df[[i]])-3)))#other
                    }
                }
            }
            names(df) <- target()
        }
    }else if(input$uptype=='list'){
        if(is.null(input$target)) return()
        tmp <- list(NA)
        df <- rep(tmp,length(input$target))
        names(df) <- input$target
        for(i in 1:length(input$target)){
            target <- input$target[i]
            star <- gsub('_.+','',target)
            dir  <- 'data/'
            ind <- grep(target,data.files)
            file <- data.files[ind[1]]
            f0 <- paste0(dir,file)
            if(!file.exists(f0)){
                f0 <- paste0(dir,target,'.dat')
            }
            tab <- read.table(f0,nrows=1)
            if(class(tab[1,1])=='factor'){
                tab <- read.table(f0,header=TRUE,check.names=FALSE)
            }else{
                tab <- read.table(f0)
            }
#            cat('colnames(tab)=',colnames(tab),'\n')
            inds <- sort(tab[,1],index.return=TRUE)$ix
            tab <- tab[inds,]
            if(any(diff(tab[,1])==0)){
                ind <- which(diff(tab[,1])==0)
                tab <- tab[-ind,]
            }
            ind <- c()
            for(j in 1:ncol(tab)){
                if(sd(tab[,j])!=0) ind <- c(ind,j)
            }
            df[[i]] <- tab[,ind]
        }
    }
    return(df)
})

    observeEvent(input$show,{
        lapply(1:length(data()),function(j)
            output[[paste0('data.out',j)]] <- downloadHandler(
                filename = function() {
                    f1 <- gsub(" ",'_',Sys.time())
                    f2 <- gsub(":",'-',f1)
                    paste('data_',names(data())[j], f2, '.txt', sep='')
                },
                content = function(file) {
                    write.table(data()[[j]], file,quote=FALSE,row.names=FALSE)#FALSE,col.names=FALSE
                }
            )
               )
    })


    observeEvent(input$show,{
        output$download.data <- renderUI({
                lapply(1:length(data()),function(j){
                    downloadButton(paste0('data.out',j), paste('Download',names(data())[j]))
                })
            })
    })

    observeEvent(input$show,{
        output$tab <- renderUI({
            if(is.null(data())) return()
                isolate({
                    tabs <- lapply(1:length(target()),function(i){
                        output[[paste0('f',target()[i])]] <- renderDataTable(data()[[i]])
                        tabPanel(target()[i],dataTableOutput(paste0('f',target()[i])))
                    })
                    do.call(tabsetPanel, tabs)
                })
        })
    })

###variable names
  ns <- reactive({
    nam <- c()
    for(i in 1:length(instr())){
      names <- colnames(data()[[i]])
      names <- names[-c(1,3)]#e.g. 'Time' and 'eRV' for RV data
      names <- c(names,'Window Function')
#      nam <- c(nam,paste(names(data())[i],names,sep=':'))
      nam <- c(nam,names)
    }
    return(unique(nam))
  })

###variable names dependent on per.target
    ns.1D <- reactive({
        if(is.null(input$per.target) & is.null(input$per.target2)) return()
        nam <- c()
        if(length(input$per.target)>0){
            tar <- input$per.target
        }
#        if(length(input$per.target2)>0){
#            tar <- input$per.target2
#        }
        for(i in 1:length(input$per.target)){
            names <- colnames(data()[[tar[i]]])
#            cat('names=',names,'\n')
            names <- names[-c(1,3)]#e.g. 'Time' and 'eRV' for RV data
#            cat('names=',names,'\n')
            names <- c(names,'Window Function')
                                        #      nam <- c(nam,paste(names(data())[i],names,sep=':'))
            nam <- c(nam,names)
        }
        return(unique(nam))
    })

  ns.wt <- reactive({
      nam <- c()
      lab <- c()
      for(i in 1:length(data())){
        labs <- names <- colnames(data()[[i]])
        labs[grep('RV',names)] <- 'RV [m/s]'
        labs[grep('Time',names)] <- 'Time [JD-2400000]'
        labs[!grepl(paste(names[1:3],collapse='|'),names)] <- paste('Normalized',labs[!grepl(paste(names[1:3],collapse='|'),names)])
        nam <- c(nam,paste(names(data())[i],names,sep=':'))
        lab <- c(lab,paste(names(data())[i],labs,sep=':'))
      }
    return(list(name=nam,label=lab))
  })

    output$scatter.target <- renderUI({
        if(is.null(data())) return()
        selectizeInput("scatter.target",'Data sets',choices=names(data()),selected=names(data())[1],multiple=FALSE)
    })

    output$xs <- renderUI({
        if(is.null(data()) | is.null(input$scatter.target)) return()
        names <- ns.wt()$name
        nam <- names[grep(input$scatter.target,names)]
        selectizeInput("xs", "Choose x axis",
                       choices  = nam,
                       selected = nam[1],multiple=FALSE)
    })


    output$ys <- renderUI({
        if(is.null(data()) | is.null(input$scatter.target)) return()
        names <- ns.wt()$name
        nam <- names[grepl(input$scatter.target,names)]
        selectizeInput("ys", "Choose y axis",
                       choices  = nam,
                       selected = nam[2],multiple=FALSE)
    })

    scatterInput <- function(){
        i <- 1
        tar <- gsub(':.+','',input$xs[i])
        vars <- colnames(data()[[tar]])
        instrument <- gsub(':.+','',input$xs[i])
        indx <- which(input$xs==ns.wt()$name)
        x <- gsub('.+:','',ns.wt()$label[indx])
        indy <- which(input$ys==ns.wt()$name)
        y <- gsub('.+:','',ns.wt()$label[indy])
        varx <- data()[[instrument]][,gsub('.+:','',input$xs[i])]
        vary <- data()[[instrument]][,gsub('.+:','',input$ys[i])]
        names <- vars[1:3]
        if(!grepl(paste0(names,collapse='|'),input$xs[i])) varx <- scale(varx)
        if(!grepl(paste0(names,collapse='|'),input$ys[i])) vary <- scale(vary)
        plot(varx,vary,xlab=x,ylab=y,pch=20,cex=0.5)
        ey <- data()[[tar]][,3]
        xname <- gsub('.+:','',input$xs[i])
        yname <- gsub('.+:','',input$ys[i])
        if(xname==vars[1] & yname==vars[2]){
            arrows(varx,vary-ey,varx,vary+ey,length=0.03,angle=90,code=3)
        }
    }

    observeEvent(input$scatter,{
        output$sca <- renderPlot({
            isolate({
                par(mfrow=c(length(input$xs),1),cex=1,cex.axis=1.5,cex.lab=1.5,mar=c(5,5,1,1))
                scatterInput()
            })
        })
    })

    observeEvent(input$scatter,{
        output$scatter <- renderUI({
            height <- 400*ceiling(length(input$xs)/2)
            plotOutput("sca", width = "400px", height = height)
        })
    })

    output$download.scatter <- downloadHandler(
        filename = function() {
            f1 <- gsub(" ",'_',Sys.time())
            f2 <- gsub(":",'-',f1)
            paste0("scatter_",input$scatter.target,'_',f2,".pdf")
        },
        content = function(file) {
            pdf(file,4,4)
            par(mar=c(5,5,1,1))
            scatterInput()
            dev.off()
        })

    observeEvent(input$scatter,{
        output$download.scatter.button <- renderUI({
            downloadButton('download.scatter', 'Download scatter plot')
        })
    })

    output$var <- renderUI({
        if(is.null(input$per.type)) return()
        if(!any(grepl('MLP',input$per.type)) & !any(grepl('BFP',input$per.type))){
            selectInput("yvar", "Choose observables", choices  = ns.1D(),selected = ns.1D()[1],multiple=TRUE)
        }else{
            selectInput("yvar", "Choose observables",
                        choices  = ns.1D()[1],
                        selected = ns.1D()[1],multiple=FALSE)
        }
    })

  output$var2 <- renderUI({
      if(is.null(input$per.type2)) return()
      selectInput("yvar2", "Choose observables",
                        choices  = ns()[1],
                        selected = ns()[1],multiple=FALSE)
  })

  output$helpvar <- renderUI({
    if(is.null(input$yvar)) return()
    helpText("If the BFP is selected, only 'RV' is available for selection. The meaning of variables are as follows: 'all'--the periodograms of all variables,
            'RVs'--periodograms of RVs, 'Indices'-- periodograms of Indices,
             'Instrument:Variable'--individual variables")
  })

  periodogram.var <- reactive({
    if(is.null(input$yvar)) return()
    vars <- input$yvar[input$yvar!='all' & input$yvar!='RVs' & input$yvar!='Indices']
    return(unique(vars))
})

  periodogram.var2 <-  reactive({
    if(is.null(input$yvar2)) return()
    vars <- c()
    if(any(input$yvar2!='Indices' & input$yvar2!='all' & input$yvar2!='RVs')){
        vars <- c(vars,input$yvar2[input$yvar2!='all' & input$yvar2!='RVs' & input$yvar2!='Indices'])
    }
    return(unique(vars))
  })

    prange <- reactive({
        if(is.null(input$prange)) return()
        as.numeric(10^input$prange)
    })

    prange2 <- reactive({
        if(is.null(input$prange2)) return()
        as.numeric(10^input$prange2)
    })

  per.par <- reactive({
      vals <- list(ns=ns(),ofac=input$ofac,frange=1/prange()[2:1],per.type=input$per.type,per.target=input$per.target)
      if(any(input$per.type=='MLP' | input$per.type=='BFP')){
          Nmas <- c()
          Inds <- list()
          for(i in 1:Ntarget()){
              inds <- as.integer(input[[paste0('Inds',i)]])
              if(all(inds==0)){
                  Inds <- c(Inds,list(inds))
              }else{
                  Inds <- c(Inds,list(inds[inds!=0]))
              }
              Nmas <- c(Nmas,as.integer(input[[paste0('Nma',i)]]))
          }
          vals <- c(vals,Nmas=list(Nmas),Inds=list(Inds))
      }else{
          vals <- c(vals,Nmas=0,Inds=0)
      }
      if(input$sequence){
          vals <- c(vals,Nmas=0,Inds=0,per.type.seq=input$per.type.seq, Nsig.max=as.integer(input$Nsig.max))
      }
      return(vals)
  })

  per.par2 <- reactive({
      vals <- list(ns=ns(),ofac=input$ofac2,frange=1/prange2()[2:1],per.type=input$per.type2,per.target=input$per.target2)
      if(any(input$per.type2=='MLP'|input$per.type2=='BFP')){
          Nmas <- c()
          Inds <- list()
          for(i in 1:Ntarget2()){
              inds <- as.integer(input[[paste0('Inds2.',i)]])
              if(all(inds==0)){
                  Inds <- c(Inds,list(inds))
              }else{
                  Inds <- c(Inds,list(inds[inds!=0]))
              }
              Nmas <- c(Nmas,as.integer(input[[paste0('Nma2.',i)]]))
          }
          vals <- c(vals,Nmas=list(Nmas),Inds=list(Inds))
      }else{
          vals <- c(vals,Nmas=0,Inds=0)
      }
      vals <- c(vals,Dt=signif(tspan()*as.numeric(input$Dt),3),Nbin=as.integer(input$Nbin),alpha=as.integer(input$alpha),scale=input$scale,pmin.zoom=input$range.zoom[1],pmax.zoom=input$range.zoom[2],show.signal=input$show.signal)
      return(vals)
  })

    model.selection <- eventReactive(input$compare,{
                                        #      instrument <- instr()[input]#gsub(':.+','',ns()[1])
        tab <- data()[[input$comp.target]]
        if(!is.null(input$NI0)){
            Nbasic <- as.integer(input$NI0)
        }else{
            Nbasic <- 0
        }
        if(!is.null(input$proxy.type)){
            if(input$proxy.type=='group'){
                groups <- input$NI.group
                proxy.type <- 'group'
                ni <- NI.max()[input$comp.target]
            }else if(input$proxy.type=='man'){
                groups <- list()
                cat('names(input)=',names(input),'\n')
                for(i in 1:as.integer(input$Nman)){
                    inds <- as.integer(input[[paste0('NI.man',i)]])
                    if(!all(inds==0)){
                        inds <- inds[inds>0]
                    }
                    groups[[i]] <- inds
                }
                cat('names(groups)=',names(groups),'\n')
                cat('length(groups)=',length(groups),'\n')
                proxy.type <- 'man'
                ni <- NI.max()[input$comp.target]
            }else{
                groups <- NULL
                proxy.type <- 'cum'
                ni <- as.integer(input$ni.max)
            }
        }else{
            groups <- NULL
            proxy.type <- 'cum'
            ni <- 0
        }
        out <- calcBF(data=tab,Nbasic=Nbasic,
                      proxy.type=proxy.type,
                      Nma.max=as.integer(input$Nma.max),
                      groups=groups,Nproxy=ni)
        col.names <- c()
        for(j in 1:length(out$Nmas)){
            if(out$Nmas[j]==0){
                col.names <- c(col.names,'white noise')
            }else{
                col.names <- c(col.names,paste0('MA(',out$Nmas[j],')'))
            }
        }
        row.names <- c()
        for(j in 1:length(out$Inds)){
            if(all(out$Inds[[j]]==0)){
                row.names <- c(row.names,'no proxy')
            }else{
                row.names <- c(row.names,paste0('proxies: ',paste(out$Inds[[j]],collapse=',')))
            }
        }
        logBF <- data.frame(round(out$logBF,digit=1))
        colnames(logBF) <- col.names
        rownames(logBF) <- row.names
#        cat('colnames(logBF)=',colnames(logBF),'\n')
#        cat('rownames(logBF)=',rownames(logBF),'\n')
        logBF.download <- logBF
        colnames(logBF.download) <- paste0('MA',out$Nmas)
        rnames <- c()
        for(j in 1:nrow(logBF)){
            rnames <- c(rnames,paste0('proxy',paste(out$Inds[[j]],collapse='-')))
        }
        rownames(logBF.download) <- NULL#rnames
        return(list(logBF=logBF,out=out,logBF.download=logBF.download))
    })

  observeEvent(input$compare,{
      output$BFtab <- renderUI({
          output$table <- renderTable({model.selection()$logBF},digits=1,caption = "Logarithmic BIC-estimated Bayes factor",rownames=TRUE,colnames=TRUE,
                                      caption.placement = getOption("xtable.caption.placement", "top"),
                                      caption.width = getOption("xtable.caption.width", NULL))
          tableOutput('table')
      })
  })

  output$download.logBF <- downloadHandler(
      filename = function(){
          f1 <- gsub(" ",'_',Sys.time())
          f2 <- gsub(":",'-',f1)
          paste('logBF_',input$comp.target,'_', f2, '.txt', sep='')
      },
      content = function(file) {
          write.table(round(model.selection()$logBF.download,digit=1), file,quote=FALSE,row.names=FALSE)
      }
  )

  output$download.logBF.table <- renderUI({
      if(is.null(model.selection())) return()
#      downloadLink('download.logBF', 'Download the Bayes Factor table')
      downloadButton('download.logBF', 'Download the Bayes Factor table')
  })

  output$optNoise <- renderUI({
      if(is.null(input$compare)) return()
      if(input$compare>0){
          output$noise.opt <- renderText({
              Nma.opt <- model.selection()$out$Nma.opt
              Inds.opt <- model.selection()$out$Inds.opt
              if(Nma.opt==0){
                  t1 <- 'white noise'
              }else{
                  t1 <- paste0('MA(',Nma.opt,')')
              }
              if(all(Inds.opt==0)){
                  t2 <- 'Optimal proxies: no proxy'
              }else{
                  t2 <- paste0('Optimal proxies: ',paste(Inds.opt,collapse=','))
              }
              text1 <- paste0('Optimal noise model: ',t1)
              text2 <- t2
              HTML(paste(text1, text2, sep = '<br/>'))
          })
          htmlOutput('noise.opt')
      }
  })

output$color <- renderUI({
    if(is.null(MP.data()) | is.null(Ntarget2())) return()
    if(Ntarget2()>1){
            ts <- c()
            for(j in 1:Ntarget2()){
                cols <- c('black','red','blue','green','orange','brown','cyan','pink')
                ts <- c(ts,paste0(cols[j],': Noise-subtracted ',input$per.target2[j]))
            }
            out <- paste(ts,collapse='<br/><br/>')
            h5(HTML(paste0('<br/>',out)))
#        htmlOutput('encode')
    }
})

  Nper <- eventReactive(input$plot1D,{
    if(is.null(input$per.type)) return()
    Nvar <- length(periodogram.var())
    Nplots <- 0
    pars <- per.par()
    Nplots <- Nplots+length(input$per.type)
    Nplots <- max(1,Nplots)*Nvar
    return(Nplots)
  })

  Nper2 <- eventReactive(input$plot2D,{
    if(is.null(input$per.type2)) return()
    Nvar <- length(periodogram.var2())
    Nplots <- 0
    pars <- per.par2()
    Nplots <- Nplots+length(input$per.type2)
    Nplots <- max(1,Nplots)*Nvar
    return(Nplots)
  })

  tvper <- reactive({
    if(is.null(data())) return()
    logic <- c()
    for(j in 1:length(data())){
      trv <- data()[[j]][,1]
      if(length(trv)>100 & (max(trv)-min(trv))>1000){
        logic <- c(logic,TRUE)
      }else{
        logic <- c(logic,FALSE)
      }
    }
    return(logic)
  })
    
    tspan <- reactive({
        if(is.null(data()) | is.null(input$per.target2)) return()
        ts.min <- ts.max <- c()
        for(i in 1:length(input$per.target2)){
            tmp <- data()[[input$per.target2[i]]][,1]
            ts.min <- c(ts.min,min(tmp))
            ts.max <- c(ts.max,max(tmp))
        }
        tmin <- min(ts.min)
        tmax <- max(ts.max)
        dt <- tmax-tmin
        return(dt)
    })

  output$Dt <- renderUI({
#      cat('input$plot2D=',input$plot2D,'\n')
      if(!is.null(data())){
          sliderInput('Dt','Moving time window [in unit of the whole time span]',
                  min=0.01,max=0.99,value=0.5,step=0.01)
#          sliderInput("Dt", "Moving time window", min = 100, max = ,value=min(1000,round(tmax-tmin)),step=100)
      }
  })

   output$textDt <- renderUI({
        if(is.null(input$Dt)) return()
        helpText(paste0("The time window is ",signif(tspan()*as.numeric(input$Dt),3)," time unit. The user should adjust it to guarantee the existence of a few data points in the time window for each moving step."))
    })

  output$Nbin <- renderUI({
      if(!is.null(data())){
          selectizeInput('Nbin','Number of moving steps',
                  choices=c(2,5,10,20,50,100,200,500),selected=10,multiple=FALSE)
#          sliderInput("Nbin", "Number of moving steps", min = 5, max = 500,value=10)
      }
  })

  output$alpha <- renderUI({
      if(!is.null(data())){
          sliderInput('alpha','Truncate the color bar to optimize visualization', min = 0, max = 10,value=5,step=0.1)
      }
  })

  output$zoom <- renderUI({
      if(is.null(input$prange2)) return()
      pr <- 10^as.numeric(input$prange2)
      pmin <- pr[1]-pr[1]%%0.1
      pmax <- pr[2]-pr[2]%%0.1
      plow <- pmin
      pup <- pmin+0.1*(pmax-pmin)
      pup <- pup-pup%%0.1
      sliderInput('range.zoom','Zoom-in period range', min = pmin, max = pmax,value=c(plow,pup),step=0.1)
  })

  per1D.data <- eventReactive(input$plot1D,{
          calc.1Dper(Nmax.plots, periodogram.var(),per.par(),data())
  })

    output$per1D.data <- downloadHandler(
        filename = function() {
            paste0(per1D.data()$fname,'.txt')
#            f1 <- gsub(" ",'_',Sys.time())
#            f2 <- gsub(":",'-',f1)
#            paste('periodogram1D_', f2, '.txt', sep='')
        },
        content = function(file) {
            tab <- per1D.data()$per.data
            write.table(tab, file,quote=FALSE,row.names=FALSE)#FALSE,col.names=FALSE
        }
    )

    output$download.per1D.data <- renderUI({
        if(is.null(per1D.data())) return()
        downloadButton('per1D.data', 'Download data of periodograms')
    })

    output$per1D.figure <- downloadHandler(
        filename = function() {
            paste0(per1D.data()$fname,'.pdf')
 #           f1 <- gsub(" ",'_',Sys.time())
 #           f2 <- gsub(":",'-',f1)
 #           paste('periodogram1D_', f2, '.pdf', sep='')
        },
      content = function(file) {
        pdf(file,8,8)
        per1D.plot(per1D.data()$per.data,per1D.data()$tits,per1D.data()$pers,per1D.data()$levels,ylabs=per1D.data()$ylabs,download=TRUE)
        dev.off()
      })

    output$plot.single <- renderUI({
        if(is.null(input$down.type) | is.null(per1D.data())) return()
        if(input$down.type=='individual'){
            selectizeInput('per1D.name','Select periodogram',
                  choices=per1D.data()$tits,multiple=FALSE)
        }
    })

    output$per1D.single <- downloadHandler(
        filename = function() {
#            f1 <- gsub(" ",'_',Sys.time())
#            f2 <- gsub(":",'-',f1)
#            paste('periodogram1D_individual_', f2, '.pdf', sep='')
            ind <- which(input$per1D.name==per1D.data()$tits)
            paste0(per1D.data()$fs[ind],'.pdf')
        },
      content = function(file) {
        pdf(file,4,4)
        par(mar=c(5,5,1,1))
        ind <- which(input$per1D.name==per1D.data()$tits)
        per1D.plot(per1D.data()$per.data,per1D.data()$tits,per1D.data()$pers,per1D.data()$levels,per1D.data()$ylabs,download=TRUE,index=ind)
        dev.off()
      })

    output$download.per1D.plot <- renderUI({
        if(is.null(per1D.data())) return()
        if(input$down.type=='all'){
            downloadButton('per1D.figure', 'Download periodograms')
        }else{
            downloadButton('per1D.single', 'Download periodograms')
        }
    })

    output$help.per1D <- renderUI({
        if(is.null(per1D.data())) return()
        helpText("The column names are 'P' and 'type:Observable:power', where 'name' is the periodogram type, 'P' is period, and 'power' is the periodogram power which could be logarithmic marginalized likelihood (logML; for MLP and BGLS) or Bayes factor (logBF; for BFP) or power (for other periodograms). ")
    })

    output$per <- renderPlot({
        if(is.null(per1D.data())) return()
        per1D.plot(per1D.data()$per.data,per1D.data()$tits,per1D.data()$pers,per1D.data()$levels,per1D.data()$ylabs)
    })

    output$plot.1Dper <- renderUI({
        plotOutput("per", width = "750px", height = 400*ceiling(Nmax.plots/2))
    })

  MP.data <- eventReactive(input$data.update,{
      per2D.data(periodogram.var2(),per.par2(),data())
  })

    output$MP.data <- downloadHandler(
        filename = function() {
#            f1 <- gsub(" ",'_',Sys.time())
#            f2 <- gsub(":",'-',f1)
#            paste('periodogram2D_', f2, '.txt', sep='')
            paste0(MP.data()$fname,'.txt')
        },
        content = function(file) {
            tmp <- MP.data()
            if(nrow(tmp$zz)==length(tmp$xx)){
                tab <- cbind(tmp$xx,tmp$zz)
                tab <- t(rbind(c(NA,tmp$yy),tab))
            }else{
                tab <- rbind(tmp$xx,tmp$zz)
                tab <- cbind(c(NA,tmp$yy),tab)
            }
            write.table(tab, file,quote=FALSE,row.names=FALSE,col.names=FALSE)#FALSE,col.names=FALSE
        }
    )

    output$download.MP.data <- renderUI({
        if(is.null(MP.data())) return()
        downloadButton('MP.data', 'Download data of 2D periodogram')
    })

  observeEvent(input$plot2D,{
      output$per2 <- renderPlot({
          isolate({
              plotMP(MP.data(),per.par2())
          })
      })
  })

    observeEvent(input$plot2D,{
        output$plot.2Dper <- renderUI({
            plotOutput("per2", width = "600px", height = "600px")
        })
    })

    output$per2D.figure <- downloadHandler(
        filename = function() {
#            f1 <- gsub(" ",'_',Sys.time())
#            f2 <- gsub(":",'-',f1)
#            paste('periodogram2D_', f2, '.pdf', sep='')
            paste0(MP.data()$fname,'_scale',input$scale,'_Dt',signif(tspan()*as.numeric(input$Dt),3),'d.pdf')
        },
        content = function(file) {
            pdf(file,8,8)
            plotMP(MP.data(),per.par2())
            dev.off()
        })

    output$download.per2D.plot <- renderUI({
        if(is.null(MP.data())) return()
        downloadButton('per2D.figure', 'Download 2D periodogram')
    })

})
