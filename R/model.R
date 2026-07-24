library(brms)
library(cmdstanr)
library(lubridate)
library(parallel)
library(dplyr)

# utility functions
source("R/utils.R")

# -----------------------------------------------------------------------------
# Args
# -----------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
# default of Spanish Grand Prix for best representation
target_race <- ifelse(length(args) > 0, args[1], "Spanish Grand Prix")
year <- ifelse(length(args) > 1, as.integer(args[2]), 2025)
max_stint <- ifelse(length(args) > 2, as.integer(args[3]), 6)

# -----------------------------------------------------------------------------
# Load data
# -----------------------------------------------------------------------------

data <- read.csv(glue::glue("data/processed/all_p_laps_{year}.csv")) |>
  filter(RoundName == target_race) |>
  parse_lap_times() |>
  add_elapsed_time()

# -----------------------------------------------------------------------------
# Qualifying simulation filter
# -----------------------------------------------------------------------------

sprint_flag <- unique(as.logical(data$isSprint))

constructor_offset <- calculate_constructor_offset(year)

quali_data <- filter_qualifying_laps(data, max_stint, is_sprint = sprint_flag)
stopifnot(mean(is.na(data$LapTime_sec)) < 0.1) # stop if too many dropped

# apply 107%
fastest_lap <- min(quali_data$LapTime_sec)
model_data_q <- filter(quali_data, LapTime_sec <= fastest_lap * 1.07)

# merge constructor offset
model_data_q <- model_data_q |>
  left_join(constructor_offset |> select(Team, PctOffset), by = "Team")

# -----------------------------------------------------------------------------
# Fit Bayesian model
# -----------------------------------------------------------------------------

fit_quali <- fit_model(data = model_data_q, is_sprint = sprint_flag)

# save model
event_name <- gsub(" ", "_", target_race)
dir.create("outputs", showWarnings = FALSE, recursive = TRUE)

saveRDS(fit_quali, file = paste0("outputs/fit_quali_", event_name, ".rds"))
saveRDS(model_data_q,
        file = paste0("outputs/model_data_", event_name, ".rds"))

cat("Model saved for:", target_race, "\n")