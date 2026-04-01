library(brms)
library(dplyr)
library(ggplot2)

# -----------------------------------------------------------------------------
# Args
# -----------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
# default of Spanish Grand Prix for best representation
target_race <- ifelse(length(args) > 0, args[1], "Spanish Grand Prix")
year <- ifelse(length(args) > 1, as.integer(args[2]), 2025)
update_latest <- length(args) > 2 && args[3] == "."

event_name <- gsub(" ", "_", target_race)

# -----------------------------------------------------------------------------
# Load data
# -----------------------------------------------------------------------------

fit_quali <- readRDS(paste0("outputs/fit_quali_", event_name, ".rds"))
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

# apply confidence checks
low_confidence <- as.character(
  model_data_q |>
    group_by(Driver) |>
    filter(all(confidence == "*")) |>
    distinct(Driver) |>
    pull(Driver)
)
predicted_grid$Confidence <- ""
predicted_grid <- predicted_grid |>
  mutate(Confidence = ifelse(Driver %in% low_confidence, "*", Confidence))

# plot
pdf(NULL)
plot_path <- paste0("plots/predicted_grid_", year, "_", event_name, ".png")
dir.create("plots",
           showWarnings = FALSE,
           recursive = TRUE)

# colour index
team_colours <- read.csv("data/team_colours.csv")

predicted_grid <- predicted_grid |>
  mutate(
    Gap = Predicted_Time - min(Predicted_Time),
    Gap_label = ifelse(
      Predicted_Grid_Position == 1,
      sprintf("%d:%06.3f",
              floor(min(Predicted_Time) / 60), min(Predicted_Time) %% 60),
      sprintf("+%.3f", Gap)
    )
  ) |>
  left_join(team_colours |> select(Team, Colour), by = "Team")

ggplot(predicted_grid,
       aes(x = Gap, y = reorder(Driver, -Predicted_Grid_Position))) +
  geom_col(aes(fill = Colour), width = 0.65, colour = NA) +
  geom_text(
    aes(
      label = Gap_label,
      x = ifelse(Gap > 0.35, Gap - 0.01, Gap + 0.01),
      hjust = ifelse(Gap > 0.35, 1, 0),
      colour = ifelse(Gap > 0.35, "white", "black")
    ),
    family = "mono",
    size = 3.1,
    fontface = "bold"
  ) +
  geom_text(
    aes(
      label = Confidence,
      x = ifelse(Gap > 0.35, Gap + 0.05, Gap + 0.15),
      hjust = ifelse(Gap > 0.35, 1, 0),
      colour = "black"
    ),
    family = "mono",
    size = 3.1,
    fontface = "bold"
  ) +
  scale_fill_identity() +
  scale_colour_identity() +
  labs(
    title = paste(year, target_race),
    subtitle = "Predicted Qualifying Gaps",
    caption = if (any(predicted_grid$Confidence == "*"))
      "* low confidence prediction"
    else
      NULL
  ) +
  ylab("Driver") +
  theme_minimal()

ggsave(plot_path)

if (update_latest) {
  ggsave("latest_prediction.png")
}

# save
out_path <- paste0(
  "outputs/predictions/predicted_grid_", year, "_", event_name, ".csv"
)
dir.create("outputs/predictions",
           showWarnings = FALSE,
           recursive = TRUE)
write.csv(predicted_grid, out_path, row.names = FALSE)

print(predicted_grid)
cat("\nPredictions saved to:", out_path, "\n")