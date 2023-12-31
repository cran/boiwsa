% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/my_rosh.R
\name{my_rosh}
\alias{my_rosh}
\title{Internal function for a specific application}
\usage{
my_rosh(dates, holiday.dates, start = -11, end = 12)
}
\arguments{
\item{dates}{a vector of class "Date", containing the data dates}

\item{holiday.dates}{a vector of class "Date", containing the occurrences of the holiday. It can be generated with as.Date().}

\item{start}{-11 for rosh, 3 for pesach}

\item{end}{12 for rosh, -1 for pesach}
}
\value{
rosh holiday variable
}
\description{
Creates a dummy moving holiday variable for the weekly number of initial registrations at the Employment Service in Israel.
}
\examples{

# Creating moving holiday dummy variable for Israeli Rosh Hashanah
data(gasoline.data)
data(holiday_dates_il) # dates of Israeli Rosh Hashanah and Pesach
movehol=my_rosh(gasoline.data$date,holiday.dates = holiday_dates_il$rosh)

}
