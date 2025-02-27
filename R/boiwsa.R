#' Seasonal adjustment of weekly data
#'
#' Performs seasonal adjustment of weekly data. For more details on the usage of this function see the paper or the examples on Github.
#'
#' @import lubridate
#' @importFrom Hmisc yearDays
#' @importFrom stats AIC BIC lm median supsmu
#'
#' @param x Input time series as a numeric vector
#' @param dates a vector of class "Date", containing the data dates
#' @param r Defines the rate of decay of the weights. Should be between zero and one. By default is set to 0.8.
#' @param auto.ao.search Boolean. Search for additive outliers
#' @param out.threshold t-stat threshold in outlier search. By default is 3.8
#' @param ao.list Vector with user specified additive outliers in a date format
#' @param my.k_l Numeric vector defining the number of yearly and monthly trigonometric variables. If NULL, is found automatically using the information criteria. The search range is 0:36 and 0:12 with the step size of 6 for the yearly and monthly variables, respectively.
#' @param H Matrix with holiday- and trading day factors
#' @param ic Information criterion used in the automatic search for the number of trigonometric regressors. There are thee options: aic, aicc and bic. By default uses aicc
#' @param method Decomposition type: additive or multiplicative
#'
#' @return sa Seasonally adjusted series
#' @return my.k_l Number of trigonometric variables used to model the seasonal pattern
#' @return sf Estimated seasonal effects
#' @return hol.factors Estimated holiday effects
#' @return out.factors Estimated outlier effects
#' @return beta Regression coefficients for the last year
#' @return m lm object. Unweighted OLS regression on the full sample
#' @author Tim Ginker
#' @export
#' @examples
#'  # Not run
#'  # Seasonal adjustment of weekly US gasoline production
#'  \donttest{
#'  data("gasoline.data")
#'  res=boiwsa(x=gasoline.data$y,dates=gasoline.data$date)}

boiwsa=function(x,
                dates,
                r=0.8,
                auto.ao.search=TRUE,
                out.threshold=3.8,
                ao.list=NULL,
                my.k_l=NULL,
                H=NULL,
                ic="aicc",
                method="additive"){

  # rankUpdateInverse - Update the inverse of a cross product of a matrix X when adding a new column v --------------------------------------
  # X_inv The inverse (X^T X)^-1 before adding the new column
  # X_t The transpose of X, i.e. X^T
  # v The column to add
  # returns The inverse of ([X v]^T [X v])^-1



  rankUpdateInverse <- function(X_inv, X_t, v) {
    u1 <- X_t %*% v
    u2 <- X_inv %*% u1
    d <- as.numeric(1 / (t(v) %*% v - t(u1) %*% u2))
    u3 <- d * u2
    F11_inv <- X_inv + d * u2 %*% t(u2)
    XtX_inv <- rbind(cbind(F11_inv, -u3), c(-u3, d))
    return(XtX_inv)
  }

# my_ao - function that creates additive outlier variables --------------------------------------
  my_ao=function(dates,out.list) {

    # checking that the dates in out.list are in the data, and removing them if not

    out.list=out.list[out.list%in%dates]

    if (length(out.list)>0) {

      AO=matrix(0,nrow = length(dates), ncol=length(out.list))

      for (i in 1:ncol(AO)) {

        AO[dates==out.list[i],i]=1

      }

      colnames(AO)=paste0("AO ",lubridate::as_date(out.list))

    }else{AO=NULL}




    return(AO)

  }


# find_opt - function that searches for the optimal number of the Fourier variables --------------------------------------


  find_opt=function(y,dates,H=NULL,AO=NULL){

    # y - detrended dependent variable
    # H - holiday and trading day effects (as matrix)
    # AO - additive outlier variables (as matrix)


    aic0=matrix(NA,nrow=length(seq(6,42,6)),ncol=length(seq(6,18,6)))
    aicc0=matrix(NA,nrow=length(seq(6,42,6)),ncol=length(seq(6,18,6)))
    bic0=matrix(NA,nrow=length(seq(6,42,6)),ncol=length(seq(6,18,6)))

    # naming rows and columns by the number of variables

    rownames(aic0)=paste0("k = ",seq(0,36,6))
    colnames(aic0)=paste0("l = ",seq(0,12,6))

    rownames(aicc0)=paste0("k = ",seq(0,36,6))
    colnames(aicc0)=paste0("l = ",seq(0,12,6))

    rownames(bic0)=paste0("k = ",seq(0,36,6))
    colnames(bic0)=paste0("l = ",seq(0,12,6))


    for (i in 1:length(seq(6,42,6))) {

      for (j in 1:length(seq(6,18,6))) {

        X=fourier_vars(k=(i-1)*6,l=(j-1)*6,dates)

        X=cbind(X,H,AO)

        if(is.null(X)){
          m=stats::lm(y~-1)
        }else{m=stats::lm(y~X-1)}




        aic0[i,j]=stats::AIC(m)
        aicc0[i,j]=stats::AIC(m)+2*length(m$coefficients)*(length(m$coefficients)+1)/(length(m$residuals)-length(m$coefficients)-1)
        bic0[i,j]=stats::BIC(m)

      }


    }


    opt.aic=(which(aic0 == min(aic0), arr.ind = TRUE)-1)*6 # optimal number of terms
    opt.aicc=(which(aicc0 == min(aicc0), arr.ind = TRUE)-1)*6
    opt.bic=(which(bic0 == min(bic0), arr.ind = TRUE)-1)*6

    return(list(opt.aic=opt.aic,opt.aicc=opt.aicc,opt.bic=opt.bic))

  }


# fourier_vars - function that creates fourier variables --------------------------------------

  fourier_vars=function(k=1,l=1,dates){

    # k- number of yearly cycle fourier terms
    # l - number of monthly cycle fourier terms
    # dates - a vector of dates in a date format

    # creating monthly cycle variables

    if (l>0) {

      X=matrix(NA_real_,nrow = length(dates),ncol=2*l)


      Nm=as.numeric(lubridate::days_in_month(dates)) # number of days in a moth
      mt=lubridate::day(dates) # day in a month

      for (i in 1:l) {

        X[,i]=sin(2*pi*i*mt/Nm)

        X[,l+i]=cos(2*pi*i*mt/Nm)

      }


      Xm=X

      colnames(Xm)=c(paste0("S(",1:l,"/Nm",")"),paste0("C(",1:l,"/Nm",")"))
    }else{

      Xm=NULL
    }




    if (k>0) {
      # creating yearly cycle variables

      yt=lubridate::yday(dates)
      Ny=Hmisc::yearDays(dates)



      X=matrix(NA_real_,nrow = length(dates),ncol=2*k)



      for (i in 1:k) {

        X[,i]=sin(2*pi*i*yt/Ny)

        X[,k+i]=cos(2*pi*i*yt/Ny)

      }

      colnames(X)=c(paste0("S(",1:k,"/Ny",")"),paste0("C(",1:k,"/Ny",")"))

    }else{

      X=NULL
    }





    cbind(X,Xm)->X



    return(X)


  }


# find_outliers - function that searches for additive outliers --------------------------------------

  find_outliers=function(y,
                         dates,
                         out.tolerance=out.threshold,
                         my.AO.list=NULL,
                         H=NULL,
                         my.k_l=NULL){

    # y -detrended variable
    # out.tolerance - t-stat threshold
    # predefined additive outlier variables
    # my.k_l - number of yearly and monthly fourier variables


    if (is.null(my.k_l)) {

      if (is.null(my.AO.list)) {
        AO=NULL
      }else{

        AO=my_ao(dates=dates,out.list =my.AO.list )

      }

      opt=find_opt(y = y, dates = dates,H = H, AO = AO)

      my.k_l=opt$opt.aicc

    }

    if(sum(opt$opt.aicc)>0){

    X=fourier_vars(k=my.k_l[1],l=my.k_l[2],dates = dates)


    Xs=cbind(X,H,AO)

    err=y-Xs%*%solve(t(Xs)%*%Xs)%*%t(Xs)%*%y

    sig_R=1.49*stats::median(abs(err))



    f.sel.pos=NULL

    out.search.points=(1:length(dates))[!dates%in%my.AO.list]

    run=TRUE

    Xs_t <- t(Xs)
    while (run) {
      Ts <- numeric(length(out.search.points))
      ts_idx <- 1
      Xst2_inv <- solve(crossprod(Xs))
      Xst_y <- t(Xs) %*% y
      for (t in out.search.points) {

        AOt=rep(0,length(dates))

        AOt[t]=1

        Xst2_inv_t <- rankUpdateInverse(Xst2_inv, Xs_t, AOt)
        Xst_y_t <- rbind(Xst_y, t(AOt) %*% y)
        Tt <- (Xst2_inv_t %*% Xst_y_t)[ncol(Xs) + 1] / (diag(Xst2_inv_t * sig_R^2)[ncol(Xs) + 1]^0.5)
        Ts[ts_idx] <- abs(Tt)
        ts_idx <- ts_idx + 1
      }


      if (max(Ts)>=out.tolerance) {

        AOt=rep(0,length(dates))

        AOt[out.search.points[which.max(Ts)]]=1

        f.sel.pos=c(f.sel.pos,out.search.points[which.max(Ts)])

        out.search.points=out.search.points[-which.max(Ts)]

        Xs <- cbind(Xs, AOt)
        Xs_t <- t(Xs)
      }





      if (max(Ts)<out.tolerance) {
        run=FALSE
      }


    }


    # Backward deletion


    if(length(f.sel.pos)>0){

      run=TRUE

      f.sel.ao.dates=dates[f.sel.pos]

    }else{

      f.sel.ao.dates=NULL

      }



    while (run) {





      AObd=my_ao(dates=dates,out.list=lubridate::as_date(c(my.AO.list,f.sel.ao.dates)))


      Xst=cbind(X,H,AObd)

      err=y-Xst%*%solve(t(Xst)%*%Xst)%*%t(Xst)%*%y

      sig_R=1.49*stats::median(abs(err))

      Tt=abs((solve(t(Xst)%*%Xst)%*%t(Xst)%*%y)/(diag(solve((t(Xst)%*%Xst))*sig_R^2)^0.5))[(ncol(Xst)-length(f.sel.ao.dates)+1):ncol(Xst)]


      if(min(Tt)<out.tolerance){

        f.sel.ao.dates=f.sel.ao.dates[-which.min(Tt)]

      }else{

        run=FALSE
      }

      if(length(f.sel.ao.dates)==0){

        run=FALSE
      }


    }

    if(length(f.sel.ao.dates)==0){

      f.sel.ao.dates=NULL
    }else{

      f.sel.ao.dates=f.sel.ao.dates[order(f.sel.ao.dates)]
    }



    return(list(ao=f.sel.ao.dates,my.k_l=my.k_l))


    }else{

      return(list(ao=NULL,my.k_l=my.k_l))
    }



  }


# First run --------------------------------------

  if (method=="multiplicative") {
    x=log(x)
  }


  # computing initial trend estimate with Friedman's SuperSmoother

  trend.init=stats::supsmu(1:length(x),x)$y

  y=x-trend.init

  # looking for additive outliers

  if(auto.ao.search){

    auto.ao=find_outliers(y=y,dates=dates,H = H,my.AO.list = ao.list)

  }else{

    auto.ao=NULL

  }

  if (length(auto.ao$ao)>0) {

    ao.list=lubridate::as_date(c(ao.list,auto.ao$ao))
  }



  # First run of the SA procedure


  # creating outlier variables

  if (is.null(ao.list)) {
    AO=NULL

    nc.ao=0

  }else{

    AO=my_ao(dates=dates,out.list = ao.list)
    nc.ao=ncol(AO)
  }


  if (is.null(my.k_l)) {

    opt=find_opt(y = y, dates = dates,H = H, AO = AO)

    if (ic=="aicc") {
      my.k_l=opt$opt.aicc
    }

    if (ic=="aic") {
      my.k_l=opt$opt.aic
    }

    if (ic=="bic") {
      my.k_l=opt$opt.bic
    }


  }

  if(sum(my.k_l>0)){

  X=fourier_vars(k=my.k_l[1],l=my.k_l[2],dates = dates)

  Xs=cbind(X,H,AO)

  # Creating weights

  my.years=unique(lubridate::year(dates))


  Wi=array(0,dim=c(length(dates),length(dates),length(my.years)))

  w.i=rep(0,length(my.years))

  for (i in 1:length(my.years)) {

    for (j in 1:length(my.years)) {

      w.i[j]=r^(abs(j-i))



    }

    w=NULL

    for (k in 1:length(my.years)) {

      w=c(w,rep(w.i[k],sum(year(dates)==my.years[k])))

    }



    diag(Wi[,,i])=w/sum(w)

  }

  #

  sf=rep(0,length(dates))
  hol.factors=rep(0,length(dates))
  out.factors=rep(0,length(dates))


  for (i in 1:length(my.years)) {

    beta=solve(t(Xs)%*%Wi[,,i]%*%Xs)%*%t(Xs)%*%Wi[,,i]%*%y

    n.i=(lubridate::year(dates)==my.years[i])

    sf[n.i]=(Xs[,1:(length(beta)-nc.ao)]%*%beta[1:(length(beta)-nc.ao)])[n.i]

    if (!is.null(H)) {

      hol.factors[n.i]=(Xs[,(ncol(X)+1):(ncol(X)+ncol(H))]%*%beta[(ncol(X)+1):(ncol(X)+ncol(H))])[n.i]

    }

    if(nc.ao>0){

      if (!is.null(H)) {

        out.factors[n.i]=(Xs[,(ncol(X)+ncol(H)+1):ncol(Xs)]%*%as.matrix(beta[(ncol(X)+ncol(H)+1):ncol(Xs)]))[n.i]

      }else{

        out.factors[n.i]=(as.matrix(Xs[,(ncol(X)+1):ncol(Xs)])%*%as.matrix(beta[(ncol(X)+1):ncol(Xs)]))[n.i]

      }




    }else{

      out.factors=NULL
    }


  }


  if (!is.null(out.factors)) {
    seas.out.adj=x-sf-out.factors
  }else{

    seas.out.adj=x-sf

  }


# Second run --------------------------------------



  trend.init=supsmu(1:length(x),seas.out.adj)$y

  y=x-trend.init


  # creating outlier variables

  if (is.null(ao.list)) {
    AO=NULL

    nc.ao=0

  }else{

    AO=my_ao(dates=dates,out.list = ao.list)
    nc.ao=ncol(AO)
  }


  if (is.null(my.k_l)) {

    opt=find_opt(y = y, dates = dates,H = H, AO = AO)

    if (ic=="aicc") {
      my.k_l=opt$opt.aicc
    }

    if (ic=="aic") {
      my.k_l=opt$opt.aic
    }

    if (ic=="bic") {
      my.k_l=opt$opt.bic
    }


  }

  X=fourier_vars(k=my.k_l[1],l=my.k_l[2],dates = dates)

  Xs=cbind(X,H,AO)



  my.years=unique(lubridate::year(dates))


  Wi=array(0,dim=c(length(dates),length(dates),length(my.years)))

  w.i=rep(0,length(my.years))

  for (i in 1:length(my.years)) {

    for (j in 1:length(my.years)) {

      w.i[j]=r^(abs(j-i))



    }

    w=NULL

    for (k in 1:length(my.years)) {

      w=c(w,rep(w.i[k],sum(lubridate::year(dates)==my.years[k])))

    }



    diag(Wi[,,i])=w/sum(w)

  }


  sf=rep(0,length(dates))
  hol.factors=rep(0,length(dates))
  out.factors=rep(0,length(dates))


  for (i in 1:length(my.years)) {

    beta=solve(t(Xs)%*%Wi[,,i]%*%Xs)%*%t(Xs)%*%Wi[,,i]%*%y

    n.i=(lubridate::year(dates)==my.years[i])

    sf[n.i]=(Xs[,1:(length(beta)-nc.ao)]%*%beta[1:(length(beta)-nc.ao)])[n.i]

    if (!is.null(H)) {

      hol.factors[n.i]=(Xs[,(ncol(X)+1):(ncol(X)+ncol(H))]%*%beta[(ncol(X)+1):(ncol(X)+ncol(H))])[n.i]

    }

    if(nc.ao>0){

      if (!is.null(H)) {

        out.factors[n.i]=(Xs[,(ncol(X)+ncol(H)+1):ncol(Xs)]%*%as.matrix(beta[(ncol(X)+ncol(H)+1):ncol(Xs)]))[n.i]

      }else{

        out.factors[n.i]=(as.matrix(Xs[,(ncol(X)+1):ncol(Xs)])%*%as.matrix(beta[(ncol(X)+1):ncol(Xs)]))[n.i]
      }




    }else{

      out.factors=NULL
    }


  }


  if (!is.null(out.factors)) {
    seas.out.adj=x-sf-out.factors
  }else{

    seas.out.adj=x-sf

  }


  trend.fin=supsmu(1:length(x),seas.out.adj)$y


  # computing final seasonal adjusted series

  sa=x-sf

  if(method=="multiplicative"){

    sa=exp(sa)

    trend.fin=exp(trend.fin)

    sf=exp(sf)

    x=exp(x)

    out.factors=exp(out.factors)


  }

  lm.data=as.data.frame(cbind(y,Xs))

  m=lm(y~.-1,data=lm.data)

  #my.k_l=as.data.frame(my.k_l)

  #colnames(my.k_l)=c("yearly variables","monthly variables")


# Creating output --------------------------------------

  final_output=list(sa=sa,
                    my.k_l=my.k_l,
                    seasonal.factors=sf,
                    hol.factors=hol.factors,
                    out.factors=out.factors,
                    trend=trend.fin,
                    beta=beta,
                    m=m,
                    x=x,
                    dates=dates,
                    ao.list=lubridate::as_date(ao.list))

  class(final_output)="boiwsa"

  return(final_output)


  }else{

    message("Series should not be a candidate for seasonal adjustment because automatic selection found k=l=0")

    final_output=list(sa=NULL,
                      my.k_l=c(0,0),
                      seasonal.factors=NULL,
                      hol.factors=NULL,
                      out.factors=NULL,
                      trend=NULL,
                      beta=NULL,
                      m=NULL,
                      x=x,
                      dates=dates,
                      ao.list=NULL)

    class(final_output)="boiwsa"

    return(final_output)


}


}
