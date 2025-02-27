% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/generic_functions.R
\name{predict.boiwsa}
\alias{predict.boiwsa}
\title{Predict}
\usage{
\method{predict}{boiwsa}(object, ...)
}
\arguments{
\item{object}{An object of class \code{boiwsa}.}

\item{...}{Additional arguments:
\itemize{
\item \code{n.ahead}: Number of periods for forecasting (required).
\item \code{level}: Confidence level for prediction intervals. By default is set to c(80, 95).
\item \code{new_H}: Matrix with future holiday- and trading day factors.
\item \code{arima.options}: List of \code{forecast::Arima} arguments for custom modeling.
}}
}
\value{
A list containing the forecast values and ARIMA fit.
}
\description{
S3 method for 'boiwsa' class. Returns forecasts and other information using a combination of nonseasonal
auto.arima and estimates from boiwsa.
}
