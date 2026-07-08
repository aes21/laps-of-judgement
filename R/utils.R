library(brms)
library(dplyr)
library(lubridate)
library(parallel)
library(stringr)
library(tidyr)

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
#'
#' @return A data.frame with Weekend_Mins_Elapsed for track evolution.
add_elapsed_time <- function(df) {
  df |>
    mutate(Weekend_Mins_Elapsed = as.numeric(difftime(
      .data$LapStartDate, min(.data$LapStartDate, na.rm = TRUE), units = "mins"
    )))
}

#' Format fastf1 lap time format into readable seconds.
#'
#' @param year Session year.
#'
#' @return A data.frame of season constructor pace offsets.
calculate_constructor_offset <- function(year = 2025) {
  if (file.exists(glue::glue("data/processed/all_q_laps_{year}.csv"))) {
    read.csv(glue::glue("data/processed/all_q_laps_{year}.csv")) |>
      parse_lap_times() |>
      group_by(.data$RoundName, .data$Team) |>
      summarise(BestLap = min(.data$LapTime_sec, na.rm = TRUE),
                .groups = "drop") |>
      group_by(.data$Team) |>
      summarise(SeasonTotal_sec = sum(.data$BestLap, na.rm = TRUE),
                .groups = "drop") |>
      mutate(PctOffset = (.data$SeasonTotal_sec - min(.data$SeasonTotal_sec)) /
               min(.data$SeasonTotal_sec) * 100) |>
      select(.data$Team, .data$PctOffset) |>
      arrange(.data$PctOffset)
  } else {
    stop("No qualifying data for the ", year, " season found.")
  }
}

#' Filters for qualifying run identification from practice runs.
#'
#' @param df A data.frame of session laps.
#' @param max_stint Maximum stint length (defaults to '6').
#' @param is_sprint Indicates whether the weekend format is a sprint.
#'
#' @return A filtered data.frame of session laps.
filter_qualifying_laps <- function(df, max_stint = 6, is_sprint = FALSE) {
  # resolve missing data
  df <- df |>
    mutate(Team = na_if(.data$Team, "")) |>
    group_by(.data$Driver) |>
    fill(.data$Team, .direction = "downup") |>
    ungroup()

  if (anyNA(df$Team)) {
    warn_drivers <- df |>
      filter(is.na(.data$Team)) |>
      distinct(.data$Driver) |>
      pull(.data$Driver)
    warning("Dropping drivers with missing Team identifiers: ",
            paste(warn_drivers, collapse = ", "))

    df <- df |>
      filter(!is.na(.data$Team))
  }

  # pre-processing of lap data
  df <- df |>
    group_by(.data$Driver, .data$Session, .data$Stint) |>
    mutate(StintLength = n()) |>
    ungroup() |>
    filter(
      .data$TrackStatus == 1,
      .data$IsAccurate == "True",
    )

  if (is_sprint) {
    # enlarge data input by selecting the fastest stint
    df <- df |>
      filter(.data$Stint == .data$Stint[which.min(.data$LapTime_sec)],
             .by = .data$Driver)
  } else {
    # only select qualifying runs
    df <- df |>
      filter(.data$Compound == "SOFT", .data$FreshTyre == "True")
  }

  # define column factors
  df <- df |>
    mutate(
      confidence = if_else(.data$StintLength <= max_stint, "", "*"),
      Driver = factor(.data$Driver),
      Team = factor(.data$Team)
    )

  if (is_sprint) {
    df <- df |>
      mutate(
        Compound = factor(.data$Compound, levels = c("SOFT", "MEDIUM", "HARD")),
        LapCount = n(),
        Weighting = sqrt(.data$LapCount) / sqrt(max(.data$LapCount)),
        .by = .data$Driver
      )
  } else {
    df <- df |>
      filter(
        .data$StintLength <= max_stint |
          (!any(.data$StintLength <= max_stint) &
             .data$StintLength == min(.data$StintLength))
      )
  }

  df
}

#' Fit the qualifying model.
#'
#' @param data Lap time data used as model input.
#' @param is_sprint Indicates whether the weekend format is a sprint.
#'
#' @return A brmsfit object.
fit_model <- function(data, is_sprint = FALSE) {
  intercept_prior <- round(median(data$LapTime_sec, na.rm = TRUE))

  # Expected seconds-per-percentage-point of constructor offset:
  # a team X% off the season pace should lose ~X% of a lap.
  pct_offset_scale <- intercept_prior / 100

  pct_offset_prior <- prior_string(
    paste0("normal(", round(pct_offset_scale, 2), ", ",
           round(pct_offset_scale / 2, 2), ")"),
    class = "b", coef = "PctOffset"
  )

  if (is_sprint) {
    model_formula <- bf(
      LapTime_sec | weights(Weighting) ~
        log(Weekend_Mins_Elapsed + 1) + Compound + PctOffset +
          (1 | Team) + (1 | Driver),
      sigma ~ log(LapCount)
    )

    model_priors <- c(
      prior_string(paste0("normal(", intercept_prior, ", 5)"),
                   class = "Intercept"),
      prior(exponential(1), class = "sd"),
      prior(normal(0, 1), class = "b", dpar = "sigma"),
      pct_offset_prior
    )

    if ("MEDIUM" %in% unique(data$Compound)) {
      model_priors <- c(model_priors, prior(normal(0.5, 0.3), class = "b",
                                            coef = "CompoundMEDIUM"))
    }
    if ("HARD" %in% unique(data$Compound)) {
      model_priors <- c(model_priors, prior(normal(1.0, 0.3), class = "b",
                                            coef = "CompoundHARD"))
    }

  } else {
    model_formula <- bf(
      LapTime_sec ~ log(Weekend_Mins_Elapsed + 1) + Driver + PctOffset +
        (1 | Team)
    )

    model_priors <- c(
      prior_string(paste0("normal(", intercept_prior, ", 5)"),
                   class = "Intercept"),
      prior(exponential(1), class = "sd"),
      prior(exponential(1), class = "sigma"),
      pct_offset_prior
    )
  }

  brm(
    formula = model_formula,
    data = data,
    family = gaussian(),
    prior = model_priors,
    chains = 4,
    iter = 4000,
    warmup = 1000,
    cores = detectCores(),
    threads = threading(max(1, floor(detectCores() / 4))),
    backend = "cmdstanr",
    stan_model_args = list(stanc_options = list("O1"))
  )
}