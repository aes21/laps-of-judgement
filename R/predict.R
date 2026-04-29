library(brms)
library(dplyr)
library(ggplot2)

# utility functions
source("R/utils.R")

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

# check for missing drivers
dropped_levels <- setdiff(levels(new_quali_data$Driver),
                          levels(fit_quali$data$Driver))

# remove missing drivers
new_quali_data <- new_quali_data |>
  filter(!Driver %in% dropped_levels) |>
  mutate(Driver = droplevels(Driver))

# simulate times
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
low_confidence <- as.character(model_data_q |>
                                 group_by(Driver) |>
                                 filter(all(confidence == "*")) |>
                                 distinct(Driver) |>
                                 pull(Driver))
predicted_grid$Confidence <- ""
predicted_grid <- predicted_grid |>
  mutate(Confidence = ifelse(Driver %in% low_confidence, "*", Confidence))

# plot
pdf(NULL)
plot_path <- paste0("plots/predicted_grid_", year, "_", event_name, ".png")
dir.create("plots", showWarnings = FALSE, recursive = TRUE)

# colour index
team_colours <- read.csv(paste0("data/team_colours_", year, ".csv"))

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

p1 <- ggplot(predicted_grid,
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

ggsave(plot_path, plot = p1)

if (update_latest) {
  ggsave("latest_prediction.png")
}

# save
out_path <- paste0("outputs/predictions/predicted_grid_",
                   year,
                   "_",
                   event_name,
                   ".csv")
dir.create("outputs/predictions",
           showWarnings = FALSE,
           recursive = TRUE)
write.csv(predicted_grid, out_path, row.names = FALSE)

print(predicted_grid)
cat("\nPredictions saved to:", out_path, "\n")

# -----------------------------------------------------------------------------
# Evaluate prediction
# -----------------------------------------------------------------------------

# only proceed if qualifying results have been retrieved
if (file.exists(glue::glue("data/processed/all_q_laps_{year}.csv"))) {
  q_data <- read.csv(glue::glue("data/processed/all_q_laps_{year}.csv")) |>
    filter(RoundName == target_race) |>
    parse_lap_times() |>
    add_elapsed_time() |>
    select(Driver, Team, LapTime_sec) |>
    group_by(Driver) |>
    slice_min(LapTime_sec, n = 1) |>
    ungroup() |>
    arrange(LapTime_sec) |>
    left_join(team_colours |> select(Team, Colour), by = "Team")

  if (nrow(q_data) != 0) {
    # calculate summary stats for prediction accuracy
    colnames(simulated_quali_laps) <- new_quali_data$Driver
    pred_summaries <- apply(simulated_quali_laps, 2, function(x) {
      tibble(
        Pred_Mean = mean(x),
        Pred_Median = median(x),
        Predicted_Time = quantile(x, 0.05),
        Lower_95 = quantile(x, 0.025),
        Upper_95 = quantile(x, 0.975)
      )
    }) |>
      bind_rows(.id = "Driver")

    # merge and compute PIT scores
    evaluation_data <- q_data |>
      inner_join(pred_summaries, by = "Driver") |>
      rowwise() |>
      mutate(PIT_Value = mean(simulated_quali_laps[, Driver] <= LapTime_sec)) |>
      ungroup()

    # plot
    eval_path <- paste0("plots/evaluated_grid_", year, "_", event_name, ".png")
    dir.create("plots", showWarnings = FALSE, recursive = TRUE)

    p2 <- ggplot(evaluation_data, aes(x = reorder(Driver, -LapTime_sec))) +
      geom_linerange(aes(
        ymin = Lower_95,
        ymax = Upper_95,
        colour = Colour
      ),
      linewidth = 3) +
      geom_point(aes(y = Pred_Mean, fill = "Mean"),
                 shape = 21,
                 size = 3) +
      geom_point(
        aes(y = Predicted_Time, fill = "Predicted"),
        shape = 22,
        size = 3
      ) +
      geom_point(aes(y = LapTime_sec, fill = "Actual"),
                 shape = 23,
                 size = 3) +
      geom_text(
        aes(y = Inf, label = sprintf("PIT: %.2f", PIT_Value)),
        hjust = 0.1,
        size = 3,
        colour = "black",
      ) +
      scale_fill_manual(
        name = NULL,
        values = c(
          "Mean" = "white",
          "Predicted" = "grey50",
          "Actual" = "black"
        )
      ) +
      scale_colour_identity() +
      coord_flip(clip = "off") +
      labs(
        title = paste(year, target_race),
        subtitle = "Predicted vs. Actual Qualifying Times",
        caption = "95% Credible Interval Error Bars",
        x = "Driver",
        y = "Lap Time (seconds)"
      ) +
      theme_minimal() +
      theme(
        legend.position = "bottom",
        plot.margin = margin(
          t = 5,
          r = 40,
          b = 5,
          l = 5,
          unit = "pt"
        )
      )

    ggsave(eval_path, plot = p2)

    # save
    eval_out_path <- paste0("outputs/predictions/evaluated_grid_",
                            year,
                            "_",
                            event_name,
                            ".csv")
    dir.create("outputs/predictions",
               showWarnings = FALSE,
               recursive = TRUE)
    write.csv(evaluation_data, eval_out_path, row.names = FALSE)

    cat("\nPrediction evaluation saved to:", eval_out_path, "\n")
  } else {
    cat("Collect qualifying data from this season to evaluate the simulations.")
  }
}