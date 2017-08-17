# Estimation of Computation Time befure running with all the data.
# author: marc.agenis@gmail.com
# see markdown for details: https://gitlab.com/agenis/computation-time/blob/master/README.md

CompuTimeEstimate = function(whole.data, custom.function, max.time=10, min.size=2^4, sample.factors=FALSE, factor.col=NULL, base.sizes=2, plot=FALSE, replicates=1){
  
  require(boot)
  require(lubridate)
  
  # user's data size
  N = nrow(whole.data)
  
  # Random sampling function with option to sample across a factor variable (to be implemented) - argument factor.col must be the column number
  rhead = function(data, rows=7) {
    if(is.null(dim(data))) 
      return(data[base::sample(NROW(data), rows) ])

      return(data[base::sample(NROW(data), rows), ])  
  }  

  # initialize
  default.sample.sizes <- rep(base.sizes^(1:20), each=replicates)
  sample.sizes         <- default.sample.sizes[default.sample.sizes>=min.size & default.sample.sizes<=N]
  record.times         <- NULL
  computation.time     <- 0
  i                    <- 0
  
  # Loop while increasing the difficulty each time, until limit is reached. We stop one iteration after the limit, hopefully not too far...
  while( (computation.time < max.time/base.sizes/replicates) & (i < length(sample.sizes))  ){
    i                <- i+1
    sampled.data     <- rhead(whole.data, sample.sizes[i])
    computation.time <- system.time(custom.function(sampled.data))[3]
    record.times     <- c(record.times, computation.time)
  }
  
  # Fit several model forms of the relationship between size and time
  to.model  <- data.frame('size'=head(sample.sizes, length(record.times)), 'time'=record.times)
  fit.ct    <- glm(time~1,          data=to.model); to.model['fit.ct'] = fitted(fit.ct)
  fit.li    <- glm(time~size,       data=to.model); to.model['fit.li'] = fitted(fit.li)
  fit.qu    <- glm(time~I(size^2),  data=to.model); to.model['fit.qu'] = fitted(fit.qu)
  fit.cu    <- glm(time~I(size^3),  data=to.model); to.model['fit.cu'] = fitted(fit.cu)
  fit.sq    <- glm(time~sqrt(size), data=to.model); to.model['fit.sq'] = fitted(fit.sq)
  # fit.ex  <- glm(log(time)~size,  data=to.model); to.model['fit.ex'] = exp(fitted(fit.ex))
  model.list <- list('constant'=fit.ct, 'linear'=fit.li, 'quadratic'=fit.qu, 'cubic'=fit.cu, 'square.root'=fit.sq) 
  
  # Plot the output of the different models (optional)
  if (plot) {
    require(ggplot2); require(reshape2)
    to.plot <- reshape2::melt(to.model, id.vars="size", variable.name="model", value.name="time")
    g <- ggplot(to.plot[to.plot$model!="time", ]) + aes(x=size, y=time, color=model) + geom_point() + geom_line()  + 
      geom_point(data=to.plot[to.plot$model=="time", ], aes(x=size, y=time), color="black", size=2, alpha=0.7)
    print(g)
  }
  
  # get the best!
  benchmark <- lapply(model.list, function(x) boot::cv.glm(to.model, x)$delta[2])
  print(paste0("Computation time is best fitted by a ", toupper(names(which.min(benchmark))), " model"))
  
  # prediction of time for whole data (with specific case of exponential model)
  estimated.time <- predict(model.list[[which.min(benchmark)]], newdata=data.frame('size'=N))
  if (which.min(benchmark)==6) estimated.time=exp(estimated.time)
  print("Estimated computation time for the whole data: ")
  print(lubridate::seconds_to_period(round(estimated.time, 2)))
  
  sign.test = tail(anova(model.list[[which.min(benchmark)]], test="F")$Pr, 1)
  if ( is.na(sign.test) | sign.test > 0.01 ) message("warning: best model is not statistically significant. Increase max.time or replicates")
  
}


