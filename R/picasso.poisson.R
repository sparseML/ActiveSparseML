picasso.poisson <- function(X, 
                          Y, 
                          lambda = NULL,
                          nlambda = NULL,
                          lambda.min.ratio = NULL,
                          lambda.min = NULL,
                          method = "l1",
                          gamma = 3,
                          standardize = TRUE,
                          prec = 1e-4,
                          max.ite = 1e4,
                          verbose = FALSE)
{
  n = nrow(X)
  d = ncol(X)
  if (!isTRUE(all(Y == floor(Y))) || !isTRUE(all(Y >= 0))) 
    stop("The response must only contain non-negative integer values for poisson regression")

  if (sum(Y) <= 0)
    stop("The response vector is an all-zero vector. The problem is ill-conditioned.")

  begt = Sys.time()
  if (verbose)
    cat("Sparse poisson regression. \n")
  if (n == 0 || d == 0) {
    cat("No data input.\n")
    return(NULL)
  }
  if (method != "l1" && method != "mcp" && method != "scad"){
    cat(" Wrong \"method\" input. \n \"method\" 
          should be one of \"l1\", \"mcp\", \"scad\".\n", 
        method,"is not supported in this version. \n")
    return(NULL)
  }

  if (standardize){
    xx = rep(0,n*d)
    xm = rep(0,d)
    xinvc.vec = rep(0,d)
    str = .C("standardize_design", as.double(X), as.double(xx), 
              as.double(xm), as.double(xinvc.vec), 
             as.integer(n), as.integer(d), PACKAGE="picasso")
    xx = matrix(unlist(str[2]), nrow=n, ncol=d, byrow=FALSE)
    xm = matrix(unlist(str[3]), nrow=1)
    xinvc.vec = unlist(str[4])
  } else {
    xinvc.vec = rep(1,d)
    xx = X
  }
  yy = Y
  avr_y = mean(yy)
  
  if (!is.null(lambda)) 
    nlambda = length(lambda)
  if (is.null(lambda)){
    if (is.null(nlambda))
      nlambda = 100

    lambda.max = max(abs(crossprod(xx,(yy-avr_y)/n)))

    if (is.null(lambda.min)){
      if (is.null(lambda.min.ratio)){
        lambda.min = 0.05*lambda.max
      } else {
        lambda.min = min(lambda.min.ratio*lambda.max, lambda.max)
      }
    }
    if (lambda.min>=lambda.max) 
      cat("lambda.min is too small. \n")
    lambda = exp(seq(log(lambda.max), log(lambda.min), length = nlambda))
  }
  if (method == "l1" || method == "mcp" || method == "scad") {
    if (method=="l1") {
      method.flag = 1
    }
    if (method == "scad") {
      method.flag = 3
      if (gamma<=2) {
        cat("gamma > 2 is required for SCAD. Set to default value 3. \n")
        gamma = 3
      }
    }
    if (method=="mcp") {
      method.flag = 2
      if (gamma<=1) {
        cat("gamma > 1 is required for MCP. Set to default value 3. \n")
        gamma = 3
      }
    }
    
    out = poisson_solver(yy, xx, lambda, nlambda, gamma, 
                n, d, max.ite, prec, verbose, 
                method.flag)
  }
  
  df = rep(0,nlambda)
  for (i in 1:nlambda)
    df[i] = sum(out$beta[[i]]!=0)
  
  est = list()
  intcpt = matrix(0, nrow=1, ncol=nlambda)
  beta1 = matrix(0, nrow=d, ncol=nlambda)
  
  if (standardize==TRUE){
    for (k in 1:nlambda){
      tmp.beta = out$beta[[k]]
      beta1[,k] = xinvc.vec*tmp.beta
      intcpt[k] = -as.numeric(xm[1,]%*%beta1[,k])+out$intcpt[k]
    }
  } else {
    for (k in 1:nlambda){
      beta1[,k]=out$beta[[k]]
      intcpt[k] = out$intcpt[k]
    }
  }
  runt = Sys.time()-begt
  est$obj = out$obj
  est$runt = out$runt
  est$beta = Matrix(beta1)
  est$intercept = intcpt
  est$lambda = lambda
  est$nlambda = nlambda
  est$df = df
  est$method = method
 
  est$ite =out$ite
  est$verbose = verbose
  est$runtime = runt
  class(est) = "poisson"
  return(est)
}

print.poisson <- function(x, ...)
{  
  cat("\n Poisson regression options summary: \n")
  cat(x$nlambda, " lambdas used:\n")
  print(signif(x$lambda,digits=3))
  cat("Regularization =", x$method, "\n")
  cat("Degree of freedom:",min(x$df),"----->",max(x$df),"\n")
  if(units.difftime(x$runtime)=="secs") unit="secs"
  if(units.difftime(x$runtime)=="mins") unit="mins"
  if(units.difftime(x$runtime)=="hours") unit="hours"
  cat("Runtime:",x$runtime," ",unit,"\n")
}

plot.poisson <- function(x, ...)
{
  matplot(x$lambda, t(x$beta), type="l", main="Regularization Path",
          xlab="Regularization Parameter", ylab="Coefficient")
}

coef.poisson <- function(object, lambda.idx = c(1:3), beta.idx = c(1:3), ...)
{
  lambda.n = length(lambda.idx)
  beta.n = length(beta.idx)
  cat("\n Values of estimated coefficients: \n")
  cat(" index     ")
  for (i in 1:lambda.n){
    cat("",formatC(lambda.idx[i], digits=5, width=10),"")
  }
  cat("\n")
  cat(" lambda    ")
  for (i in 1:lambda.n){
    cat("",formatC(object$lambda[lambda.idx[i]], digits=4, width=10),"")
  }
  cat("\n")
  cat(" intercept ")
  for (i in 1:lambda.n){
    cat("",formatC(object$intercept[i], digits=4, width=10),"")
  }
  cat("\n")
  for (i in 1:beta.n){
    cat(" beta",formatC(beta.idx[i], digits=5, width=-5))
    for (j in 1:lambda.n){
      cat("",formatC(object$beta[beta.idx[i],lambda.idx[j]],digits=4,width=10),"")
    }
    cat("\n")
  }
}

predict.poisson <- function(object, newdata, lambda.idx = c(1:3), p.pred.idx = c(1:5), ...)
{
  pred.n = nrow(newdata)
  lambda.n = length(lambda.idx)
  p.pred.n = length(p.pred.idx)
  intcpt = matrix(rep(object$intercept[,lambda.idx],pred.n), nrow=pred.n,
                  ncol=lambda.n, byrow=T)
  res = newdata%*%object$beta[,lambda.idx] + intcpt

  p.pred = res
  cat("\n Values of predicted Poisson parameter: \n")
  cat("   index   ")
  for (i in 1:lambda.n){
    cat("",formatC(lambda.idx[i], digits=5, width=10),"")
  }
  cat("\n")
  cat("   lambda  ")
  for (i in 1:lambda.n){
    cat("",formatC(object$lambda[lambda.idx[i]], digits=4, width=10),"")
  }
  cat("\n")
  for (i in 1:p.pred.n){
    cat("    Y",formatC(p.pred.idx[i], digits=5, width=-5))
    for (j in 1:lambda.n){
      cat("",formatC(p.pred[p.pred.idx[i],j], digits=4, width=10),"")
    }
    cat("\n")
  }
  return(p.pred)
}