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

data <- read.csv(glue::glue("data/processed/all_fp_laps_{year}.csv")) |>
  filter(RoundName == target_race) |>
  parse_lap_times() |>
  add_elapsed_time()

# -----------------------------------------------------------------------------
# Qualifying simulation filter
# -----------------------------------------------------------------------------

quali_data <- filter_qualifying_laps(data, max_stint = max_stint)
stopifnot(mean(is.na(data$LapTime_sec)) < 0.1) # stop if too many dropped

# apply 107%
fastest_lap <- min(quali_data$LapTime_sec)
model_data_q <- filter(quali_data, LapTime_sec <= fastest_lap * 1.07)

# -----------------------------------------------------------------------------
# Fit Bayesian model
# -----------------------------------------------------------------------------

intercept_prior <- round(median(model_data_q$LapTime_sec, na.rm = TRUE))

fit_quali <- brm(
  LapTime_sec ~ log(Weekend_Mins_Elapsed + 1) + (1 | Team / Driver),
  data = model_data_q,
  family = gaussian(),
  prior = c(
    prior_string(paste0("normal(", intercept_prior, ", 5)"),
                 class = "Intercept"),
    prior(exponential(1), class = "sd"),
    prior(exponential(1), class = "sigma")
  ),
  chains = 4,
  iter = 4000,
  warmup = 1000,
  cores = detectCores(),
  threads = threading(max(1, floor(detectCores(
  ) / 4))),
  backend = "cmdstanr",
  stan_model_args = list(stanc_options = list("O1"))
)

# save model
event_name <- gsub(" ", "_", target_race)
dir.create("outputs", showWarnings = FALSE, recursive = TRUE)

saveRDS(fit_quali, file = paste0("outputs/fit_quali_", event_name, ".rds"))
saveRDS(model_data_q,
        file = paste0("outputs/model_data_", event_name, ".rds"))

cat("Model saved for:", target_race, "\n")