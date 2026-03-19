library(brms)
library(dplyr)

# -----------------------------------------------------------------------------
# Args
# -----------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
# default of Spanish Grand Prix for best representation
target_race <- ifelse(length(args) > 0, args[1], "Spanish Grand Prix")

event_name <- gsub(" ", "_", target_race)

# -----------------------------------------------------------------------------
# Load data
# -----------------------------------------------------------------------------

fit_quali <- readRDS(paste0("outputs/fit_quali_",   event_name, ".rds"))
model_data_q <- readRDS(paste0("outputs/model_data_", event_name, ".rds"))

# get drivers
driver_teams <- model_data_q |> select(Driver, Team) |> distinct()

# set new data
new_quali_data <- data.frame(
  Driver = driver_teams$Driver,
  Team = driver_teams$Team,
  Weekend_Mins_Elapsed = max(model_data_q$Weekend_Mins_Elapsed, na.rm = TRUE)
)

# -----------------------------------------------------------------------------
# Make prediction
# -----------------------------------------------------------------------------

simulated_quali_laps <- posterior_predict(
  fit_quali,
  newdata = new_quali_data,
  allow_new_levels = TRUE
)

# generate a predicted grid data.frame
predicted_grid <- data.frame(
  Driver = new_quali_data$Driver,
  Team = new_quali_data$Team,
  Predicted_Time = apply(simulated_quali_laps, 2, quantile, probs = 0.05)
) |>
  arrange(Predicted_Time) |>
  mutate(Predicted_Grid_Position = row_number())

# save
out_path <- paste0("outputs/predictions/predicted_grid_", event_name, ".csv")
dir.create("outputs/predictions", showWarnings = FALSE, recursive = TRUE)
write.csv(predicted_grid, out_path, row.names = FALSE)

print(predicted_grid)
cat("\nPredictions saved to:", out_path, "\n")