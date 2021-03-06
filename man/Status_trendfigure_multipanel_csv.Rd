% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/risk_plot_multipanel_csv.R
\name{Status_trendfigure_multipanel_csv}
\alias{Status_trendfigure_multipanel_csv}
\title{data frame of estimated trends (wild and total spawners)}
\usage{
Status_trendfigure_multipanel_csv(
  esu,
  pops,
  total.fit,
  fracwild.fit,
  log.scale = FALSE
)
}
\arguments{
\item{esu}{The name of the ESU}

\item{pops}{The population names that will be plotted (populations with too few data are eliminated)}

\item{total.fit}{total fit returned by \code{trend_fits()}}

\item{fracwild.fit}{fracwild fit returned by \code{trend_fits()}}

\item{log.scale}{Return values on log-scale versus the original raw scale}
}
\value{
A dataframe
}
\description{
This returns a data frame that is written to a csv file. Not exported. It is used by
\code{inst/doc/report_files/esu_report.Rmd}.

It returns the smoothed total spawners estimate and the
smoothed wild spawners estimate which is
"smoothed total estimate x smoothed fracwild estimate".
The wild spawner estimate is only shown from 1 year before and one year after
the last actual fracwild estimate (in the data file). This is done so that
the wild estimate does not over-extend the fracwild data. Fracwild estimates can
be interpolated for missing years, but would not be appropriate to extend much before
or past actual observed (or expert) fracwild data.

For the smoothed total estimates, information from all populations (via a non-diagonal
year-to-year variance matrix) is used to estimate missing values and to account for
observation error in the total spawner count. Because data from all populations are used,
estimates can be made even for missing years at the beginning of the time series if there
is data for those early years in other populations.
}
\seealso{
\code{\link{Status_trendfigure_multipanel}}
}
\author{
Eli Holmes, NOAA, Seattle, USA.  eli(dot)holmes(at)noaa(dot)gov
}
\keyword{report}
