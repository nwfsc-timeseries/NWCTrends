#' Fit a MARSS model and store in a list
#'
#' Fis a MARSS model to data from each ESUs treating each population as a
#' subpopulation. The structure of the variance-covariance matrix, the U matrix, the
#' Z matrix, and the R matrix can be specified. If you want to fit a specific model,
#' then pass in model as a list as per a MARSS model. The populations in the ESU
#'  with < min.years
#'  of data points are not used in the fitting and no states are estimated for those.
#'
#' If model=NULL then a set of all possible models is fit. This takes awhile but will
#' allow one to use AIC to compare the model set. wild=TRUE means to do the fit on
#' fracwild*total versus on the total spawners.
#' logit.fw says whether to fit to logit of fracwild or to the percentages.
#'
#' This function produces a states estimate and a fracwild fit;
#'
#' @param datalist The list output by data_detup()
#' @param ouputfile The name of the RData file to save the results to.
#' @param wild wild=TRUE means to do the fit on fracwild*total versus on the total spawners.
#' @param model If null, a set of models is fit. Otherwise pass in a model specified as a list in MARSS format.
#' @param logit.fw If TRUE fit to logit of fracwild instead of the raw percentages.
#' @param min.years Only populations with at least min.years will be used in the fitting.
#'
#' @return A list with three items:
#' \describe{
#'   \item{fits}{A list with the fits for each ESUs included.}
#'   \item{aic.table}{If there are multiple models fit, then the AIC will be returned.}
#'   \item{best.model}{If there are multiple models fit, then the best model is returned.}
#' }
#' @author
#' Eli Holmes, NOAA, Seattle, USA.  eli(dot)holmes(at)noaa(dot)gov
#' @keywords report

trend_fits <- function(datalist,
                       outputfile,
                       wild = TRUE,
                       model = NULL,
                       logit.fw = TRUE,
                       min.years = 5) {

  matdat.spawners <- datalist$matdat.spawners
  matdat.wildspawners <- datalist$matdat.wildspawners
  matdat.fracwild <- datalist$matdat.fracwild
  
  if (!wild) {
    good <- !(apply(matdat.spawners, 1, function(x) {
      sum(!is.na(x))
    }) < min.years)
    matdat.long.spawners <- matdat.spawners[good, , drop = FALSE]
    fw <- matdat.fracwild[good, , drop = FALSE]
    pops.long.spawners <- datalist[["metadat"]]$name[good]
    esus.long.spawners <- datalist[["metadat"]]$ESU[good]
    esus.sub <- esus.long.spawners
    pops.sub <- pops.long.spawners
    kemdat <- log(matdat.long.spawners)
    logitfw <- log(fw / (1 - fw))
    logitfw[logitfw < -5] <- -5
    logitfw[logitfw > 5] <- 5
    rownames(logitfw) <- rownames(kemdat)
    rownames(fw) <- rownames(kemdat)
  } else {
    good <- !(apply(matdat.wildspawners, 1, function(x) {
      sum(!is.na(x))
    }) < min.years)
    matdat.long.wildspawners <- matdat.wildspawners[good, ]
    pops.long.wildspawners <- datalist[["metadat"]]$name[good]
    esus.long.wildspawners <- datalist[["metadat"]]$ESU[good]
    esus.sub <- esus.long.wildspawners
    pops.sub <- pops.long.wildspawners
    kemdat <- log(matdat.long.wildspawners)
  }

  nesus <- length(unique(esus.sub))

  # This will hold the fits for each ESU
  fits <- list()

  for (this.esu.num in 1:nesus) {

    # set up data for esu
    this.esu.name <- unique(esus.sub)[this.esu.num]
    tmpdat <- kemdat[esus.sub == this.esu.name, , drop = FALSE]
    first.n.spawner.data <- min(which(apply(tmpdat,2,function(x){!all(is.na(x))})))
    last.n.spawner.data <- max(which(apply(tmpdat,2,function(x){!all(is.na(x))})))
    tmpdat <- tmpdat[ , first.n.spawner.data:last.n.spawner.data, drop=FALSE]
    if (!wild) {
      tmplogitfw <- logitfw[esus.sub == this.esu.name, first.n.spawner.data:last.n.spawner.data, drop = FALSE]
      tmpfw <- fw[esus.sub == this.esu.name, first.n.spawner.data:last.n.spawner.data, drop = FALSE]
    }
    n <- dim(tmpdat)[1]

    fits[[this.esu.name]] <- list()
    modn <- 1

    cat("\n", this.esu.name, "\n")

    if (is.null(model)) { # Then run the full set of possible models
      model <- list()

      # get the run timing for each pop
      runs <- unique(datalist[["metadat"]]$Run)
      this.pop.names <- rownames(tmpdat)
      no.run <- sapply(this.pop.names, function(x) {
        !any(stringr::str_detect(x, runs))
      })
      this.pop.names[no.run] <- paste(this.pop.names[no.run], "No-run")
      runs <- c(runs, "No-run")
      this.pop.runs <- rep(NA, n) # vector with run for each pop
      for (this.run in runs) {
        tmp <- stringr::str_detect(this.pop.names, this.run)
        this.pop.runs[tmp] <- this.run
      }
      # set up a Q by run matrix
      Q.by.run <- matrix(list(0), n, n)
      for (this.run in runs) {
        tmp <- stringr::str_detect(this.pop.names, this.run)
        Q.by.run[tmp, tmp] <- paste(this.run, "cov", sep = ".")
        for (j in runs[!(runs == this.esu.name)]) {
          tmp2 <- stringr::str_detect(this.pop.names, j)
          Q.by.run[tmp, tmp2] <- paste(this.run, j, "cov", sep = ".")
          Q.by.run[tmp2, tmp] <- paste(this.run, j, "cov", sep = ".")
        }
        diag(Q.by.run)[tmp] <- this.esu.name
      }

      for (r in c("diagonal and unequal", "diagonal and equal")) {
        for (u in c("equal", "unequal")) {
          model[[modn]] <- list(Z = matrix(1, n, 1), U = u, R = r, Q = "unconstrained")
          modn <- modn + 1
          model[[modn]] <- list(Z = "identity", U = u, R = r, Q = "equalvarcov")
          modn <- modn + 1
          model[[modn]] <- list(Z = "identity", U = u, R = r, Q = "unconstrained")
          modn <- modn + 1
          model[[modn]] <- list(Z = "identity", U = u, R = r, Q = Q.by.run)
          modn <- modn + 1
          model[[modn]] <- list(Z = as.factor(this.pop.runs), U = u, R = r, Q = "unconstrained")
          modn <- modn + 1
          model[[modn]] <- list(Z = as.factor(this.pop.runs), U = u, R = r, Q = "equalvarcov")
          modn <- modn + 1
        }
      }
    } else {
      if (!is.list(model[[1]])) model <- list(model = model)
    }

    for (i in 1:length(model)) {
      cat(i, " ")
      # hard code in the average Q for Ozette
      model.list <- model[[i]]
      if (this.esu.name == "Ozette Lake Sockeye Salmon ESU") model.list$Q <- matrix(0.2)
      kem <- MARSS::MARSS(tmpdat, model = model.list, silent = TRUE)
      fits[[this.esu.name]][[i]] <- list(model = model.list, fit = kem)
      modn <- modn + 1
    }

    if (!wild) {
      okdat <- apply(tmplogitfw, 1, function(x) {
        !all(is.na(x))
      })
      stateslogitfw <- tmplogitfw
      statesfw <- tmpfw
      if (any(okdat)) {
        if (logit.fw) {
          fwdat <- tmplogitfw[okdat, , drop = FALSE]
        } else {
          fwdat <- tmpfw[okdat, , drop = FALSE]
        }
        tmpn <- dim(fwdat)[1]

        # Run MARSS to get a smoothed estimate of the fracwild with
        # missing data filled in
        kem <- MARSS::MARSS(fwdat, model = list(U = matrix(0, tmpn, 1), Q = diag(1, tmpn), R = diag(1, tmpn)), control = list(minit = 100), silent = TRUE)
        if (logit.fw) {
          stateslogitfw[okdat, ] <- kem$states
          fracwild.states <- exp(stateslogitfw) / (1 + exp(stateslogitfw))
          fracwild.raw <- exp(tmplogitfw) / (1 + exp(tmplogitfw))
        } else {
          statesfw[okdat, ] <- kem$states
          fracwild.states <- statesfw
          fracwild.raw <- tmpfw
        }
      } else {
        # No fracwild info for ESU; all NAs
        fracwild.states <- statesfw
        fracwild.raw <- tmpfw
        kem <- NA
      }
      fits[[this.esu.name]][["fwlogitfit"]] <- list(fit = kem, fracwild.states = fracwild.states, fracwild.raw = fracwild.raw)
    }
  }

  save(fits, datalist, file = outputfile)

  if (!wild) {
    n.models <- length(fits[[1]]) - 1 # fracwild is not a model
  } else {
    n.models <- length(fits[[1]])
  }
  nesus <- length(fits)

  # make the AICc table
  aic.table <- list()
  for (j in 1:nesus) {
    i <- names(fits)[j]
    fit <- fits[[i]][[1]]$fit
    model <- fits[[i]][[1]]$model
    if (!is.matrix(model$Q)) {
      Q.type <- model$Q
    } else {
      Q.type <- "corr by run type"
    }
    if (is.null(fit$num.params)) fit$num.params <- length(coef(fit, type = "vector"))
    if (is.null(fit$AIC)) fit$AIC <- -2 * fit$logLik + 2 * fit$num.params
    if (is.null(fit$AICc)) fit$AICc <- fit$AIC + 2 * fit$num.params * (fit$num.params + 1) / (sum(!is.na(fit$model$data)) - fit$num.params - 1)
    tmp <- data.frame(model = 1, m = dim(fit$states)[1], n = dim(fit$model$data)[1], Q = Q.type, R = model$R, U = model$U, LL = fit$logLik, AICc = fit$AICc, k = fit$num.params, converg = fit$convergence)
    if (n.models == 1) next
    for (modn in 2:n.models) {
      fit <- fits[[i]][[modn]]$fit
      model <- fits[[i]][[modn]]$model
      if (is.null(fit$num.params)) fit$num.params <- length(coef(fit, type = "vector"))
      if (is.null(fit$AIC)) fit$AIC <- -2 * fit$logLik + 2 * fit$num.params
      if (is.null(fit$AICc)) fit$AICc <- fit$AIC + 2 * fit$num.params * (fit$num.params + 1) / (sum(!is.na(fit$model$data)) - fit$num.params - 1)
      if (!is.matrix(model$Q)) {
        Q.type <- model$Q
      } else {
        Q.type <- "corr by run type"
      }
      tmp <- rbind(tmp, data.frame(model = modn, m = dim(fit$states)[1], n = dim(fit$model$data)[1], Q = Q.type, R = model$R, U = model$U, LL = fit$logLik, AICc = fit$AICc, k = fit$num.params, converg = fit$convergence))
    }
    tmp$delAICc <- tmp$AICc - min(tmp$AICc)
    aic.table[[i]] <- tmp[order(tmp$delAICc), ]
  }

  best.model <- c()
  for (i in 1:nesus) {
    if (n.models == 1) next
    best.model <- rbind(best.model, aic.table[[i]][1, ])
  }

  save(fits, datalist, aic.table, best.model, file = outputfile)

  return(list(fits = fits, aic.table = aic.table, best.model = best.model))
}
