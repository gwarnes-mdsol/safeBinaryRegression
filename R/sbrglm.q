glm <- function (formula, family = gaussian, data, weights, subset,
  na.action, start = NULL, etastart, mustart, offset, control = list(...),
  model = TRUE, method = "glm.fit", x = FALSE, y = TRUE, contrasts = NULL, ...,
  separation = c("find", "test"), action=c("error", "warning") )
{
  call <- match.call()
  separation <- match.arg(separation)
  action <- match.arg(action)

  if(action=="error")
    action <- stop
  else
    action <- warning

  if (is.character(family))
    family <- get(family, mode = "function", envir = parent.frame())
  if (is.function(family))
    family <- family()
  if (is.null(family$family)) {
    print(family)
    stop("'family' not recognized")
  }
  if (missing(data))
    data <- environment(formula)
  mf <- match.call(expand.dots = FALSE)
  m <- match(c("formula", "data", "subset", "weights", "na.action",
    "etastart", "mustart", "offset"), names(mf), 0)
  mf <- mf[c(1, m)]
  mf$drop.unused.levels <- TRUE
  mf[[1]] <- as.name("model.frame")
  mf <- eval(mf, parent.frame())
  switch(method, model.frame = return(mf), glm.fit = 1, stop("invalid 'method': ", method))
  mt <- attr(mf, "terms")
  Y <- model.response(mf, "any")
  if (length(dim(Y)) == 1) {
    nm <- rownames(Y)
    dim(Y) <- NULL
    if (!is.null(nm))
      names(Y) <- nm
  }
  X <- if (!is.empty.model(mt))
    model.matrix(mt, mf, contrasts)
  else matrix(, NROW(Y), 0)
  weights <- as.vector(model.weights(mf))
  if (!is.null(weights) && !is.numeric(weights))
    stop("'weights' must be a numeric vector")
  offset <- as.vector(model.offset(mf))
  if (!is.null(weights) && any(weights < 0))
    stop("negative weights not allowed")
  if (!is.null(offset)) {
    if (length(offset) == 1)
      offset <- rep(offset, NROW(Y))
    else if (length(offset) != NROW(Y))
      stop(gettextf("number of offsets is %d should equal %d (number of observations)",
        length(offset), NROW(Y)), domain = NA)
  }
  mustart <- model.extract(mf, "mustart")
  etastart <- model.extract(mf, "etastart")

  if(casefold(family$family) == "binomial" && length(unique(Y)) == 2) {
    if(separation == "test") {
      separation <- separator(X, Y, purpose = "test")$separation
      #separation <- separationTest(X, Y)
      if(separation)
        action("Separation exists among the sample points.\n\tThis model cannot be fit by maximum likelihood.")
    }
    if(separation == "find") {
      separation <- separator(X, Y, purpose = "find")$beta
      #separation <- separationDirection(X, Y)
      separating.terms <- dimnames(X)[[2]][abs(separation) > 1e-09]
      if(length(separating.terms))
        action(paste("The following terms are causing separation among the sample points:",
          paste(separating.terms, collapse = ", ")))
    }
  }

  ## Call the original stats::glm function as if it was the originally called function
  call <- match.call(expand.dots=TRUE)
  call$separation <- NULL
  call$action     <- NULL
  call[[1L]] <- quote(stats::glm)
  eval(call, parent.frame())
}

