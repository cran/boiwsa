% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot_spec.R
\name{plot_spec}
\alias{plot_spec}
\title{Original and SA data AR spectrum}
\usage{
plot_spec(x)
}
\arguments{
\item{x}{boiwsa results}
}
\value{
AR spectrum plot
}
\description{
AR spectrum of the (detrended) original and seasonally adjusted data. Computed using \code{\link[stats:spec.ar]{stats::spec.ar()}} with order set to 60.
}
\examples{
\donttest{
# Not run
# Seasonal adjustment of weekly US gasoline production
res=boiwsa(x=gasoline.data$y,dates=gasoline.data$date)
plot_spec(res)}

}
