library(dplyr)
library(lubridate)
library(stringr)

#' Format fastf1 lap time format into readable seconds.
#'
#' @param df A data.frame of session laps with 'LapTime' as a column name.
#'
#' @return A data.frame with LapTime_sec for readable lap time values.
parse_lap_times <- function(df) {
  df |>
    mutate(LapTime_sec = as.numeric(as.duration(hms(
      str_extract(.data$LapTime, "\\d{2}:\\d{2}:\\d{2}\\.\\d+")
    )), "seconds")) |>
    filter(!is.na(.data$LapTime_sec)) |>
    mutate(LapStartDate = ymd_hms(.data$LapStartDate))
}

#' Calculate the elapsed time between session start and end for track evolution.
#'
#' @param df A data.frame of session laps with 'LapStartDate' as a column name.
add_elapsed_time <- function(df) {
  df |>
    mutate(Weekend_Mins_Elapsed = as.numeric(difftime(
      .data$LapStartDate, min(.data$LapStartDate, na.rm = TRUE), units = "mins"
    )))
}

#' Filters for qualifying run identification from practice runs.
#'
#' @param df A data.frame of session laps.
#' @param compound Qualifying tyre compound (defaults to 'SOFT').
#' @param max_stint Maximum stint length (defaults to '6').
#'
#' @return A filtered data.frame of session laps.
filter_qualifying_laps <- function(df, compound = "SOFT", max_stint = 6) {
  df |>
    group_by(.data$Driver, .data$Session, .data$Stint) |>
    mutate(StintLength = n()) |>
    ungroup() |>
    filter(
      .data$TrackStatus == 1,
      .data$IsAccurate == "True",
      .data$Compound == compound,
      .data$FreshTyre == "True",
      .data$StintLength <= max_stint
    ) |>
    mutate(Driver = factor(.data$Driver), Team = factor(.data$Team))
}
