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
      str_extract(LapTime, "\\d{2}:\\d{2}:\\d{2}\\.\\d+")
    )), "seconds")) |>
    filter(!is.na(LapTime_sec)) |>
    mutate(LapStartDate = ymd_hms(LapStartDate))
}

#' Calculate the elapsed time between session start and end for track evolution.
#'
#' @param df A data.frame of session laps with 'LapStartDate' as a column name.
add_elapsed_time <- function(df) {
  df |>
    mutate(Weekend_Mins_Elapsed = as.numeric(difftime(
      LapStartDate, min(LapStartDate, na.rm = TRUE), units = "mins"
    )))
}

#' Filters for qualifying run identification from practice runs.
#'
#' @param df A data.frame of session laps.
#'
#' @return A filtered data.frame of session laps.
filter_qualifying_laps <- function(df) {
  df |>
    group_by(Driver, Session, Stint) |>
    mutate(StintLength = n()) |>
    ungroup() |>
    filter(
      TrackStatus == 1,
      IsAccurate == "True",
      Deleted == "False",
      Compound == "SOFT",
      FreshTyre == "True",
      StintLength <= 4
    ) |>
    mutate(Driver = factor(Driver), Team = factor(Team))
}