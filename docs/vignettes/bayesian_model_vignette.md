Bayesian statistics model methodology
================
Compiled: 2026-07-28

This vignette highlights the reasoning and methodology used to generate
qualifying predictions using a probabilistic Bayesian hierarchical
model.

### Data Processing Strategy

Practice session (FP1, FP2 and FP3) data for the given year and round is
collected via `FastF1` (`python/get_data.py`).

This data is collated and filtered for the target event, lap times
reformatted to be represented in seconds, and, based on the time the lap
was recorded, an additional `Weekend_Mins_Elapsed` column is added to
record track improvement.

``` r
# Set the default argument parameters
target_race <- "Spanish Grand Prix"
year <- 2025
max_stint <- 6

# Load in the lap time data
data <- read.csv(glue::glue(here::here("data/processed/all_p_laps_{year}.csv"))) |>
  filter(RoundName == target_race) |>
  parse_lap_times() |>
  add_elapsed_time()
```

<details>

<summary>

Data contains one row per practice lap for the specified round.
</summary>

***Spanish Grand Prix 2025 Data***

| Time | Driver | DriverNumber | LapTime | LapNumber | Stint | PitOutTime | PitInTime | Sector1Time | Sector2Time | Sector3Time | Sector1SessionTime | Sector2SessionTime | Sector3SessionTime | SpeedI1 | SpeedI2 | SpeedFL | SpeedST | IsPersonalBest | Compound | TyreLife | FreshTyre | Team | LapStartTime | LapStartDate | TrackStatus | Position | Deleted | DeletedReason | FastF1Generated | IsAccurate | RoundName | Session | isSprint | LapTime_sec | Weekend_Mins_Elapsed |
|:---|:---|---:|:---|---:|---:|:---|:---|:---|:---|:---|:---|:---|:---|---:|---:|---:|---:|:---|:---|---:|:---|:---|:---|:---|---:|:---|:---|:---|:---|:---|:---|:---|:---|---:|---:|
| 0 days 00:19:38.127000 | VER | 1 | 0 days 00:01:16.802000 | 2 | 1 |  |  | 0 days 00:00:22.782000 | 0 days 00:00:30.530000 | 0 days 00:00:23.490000 | 0 days 00:18:44.107000 | 0 days 00:19:14.637000 | 0 days 00:19:38.127000 | 284 | 291 | 285 | 323 | True | HARD | 2 | True | Red Bull Racing | 0 days 00:18:21.325000 | 2025-05-30 11:35:07 | 1 | NA | NA | NA | False | True | Spanish Grand Prix | FP1 | False | 76.802 | 3.071 |
| 0 days 00:21:53.120000 | VER | 1 | 0 days 00:02:14.993000 | 3 | 1 |  |  | 0 days 00:00:50.693000 | 0 days 00:00:57.385000 | 0 days 00:00:26.915000 | 0 days 00:20:28.820000 | 0 days 00:21:26.205000 | 0 days 00:21:53.120000 | 106 | 191 | 287 | 108 | False | HARD | 3 | True | Red Bull Racing | 0 days 00:19:38.127000 | 2025-05-30 11:36:24 | 1 | NA | NA | NA | False | True | Spanish Grand Prix | FP1 | False | 134.993 | 4.351 |
| 0 days 00:23:08.925000 | VER | 1 | 0 days 00:01:15.805000 | 4 | 1 |  |  | 0 days 00:00:22.270000 | 0 days 00:00:30.384000 | 0 days 00:00:23.151000 | 0 days 00:22:15.390000 | 0 days 00:22:45.774000 | 0 days 00:23:08.925000 | 288 | 306 | 287 | 323 | True | HARD | 4 | True | Red Bull Racing | 0 days 00:21:53.120000 | 2025-05-30 11:38:39 | 1 | NA | NA | NA | False | True | Spanish Grand Prix | FP1 | False | 75.805 | 6.601 |
| 0 days 00:25:30.152000 | VER | 1 | 0 days 00:02:21.227000 | 5 | 1 |  | 0 days 00:25:27.453000 | 0 days 00:00:44.629000 | 0 days 00:00:56.076000 | 0 days 00:00:40.522000 | 0 days 00:23:53.554000 | 0 days 00:24:49.630000 | 0 days 00:25:30.152000 | 130 | 155 | NA | 119 | False | HARD | 5 | True | Red Bull Racing | 0 days 00:23:08.925000 | 2025-05-30 11:39:55 | 1 | NA | NA | NA | False | False | Spanish Grand Prix | FP1 | False | 141.227 | 7.864 |
| 0 days 00:27:42.570000 | VER | 1 | 0 days 00:02:12.418000 | 6 | 2 | 0 days 00:25:43.995000 |  | 0 days 00:00:51.475000 | 0 days 00:00:48.210000 | 0 days 00:00:32.733000 | 0 days 00:26:21.627000 | 0 days 00:27:09.837000 | 0 days 00:27:42.570000 | 140 | 234 | 288 | 147 | False | HARD | 6 | False | Red Bull Racing | 0 days 00:25:30.152000 | 2025-05-30 11:42:16 | 1 | NA | NA | NA | False | False | Spanish Grand Prix | FP1 | False | 132.418 | 10.218 |

</details>

### Filtering the practice session data

Practice laps are filtered to retain only those representative of a
low-fuel, single-lap “qualifying” effort. Laps on used tyres, in-laps,
out-laps, and those affected by traffic or yellow flags are removed. A
maximum stint length of `max_stint` laps is applied to exclude long run
data, and the 107% rule drops any remaining outliers that would distort
the prior.

To improve the context of the prediction, a constructor offset
(`PctOffset`) - a season-wide percentage offset of each respective team
to the fastest constructor (based on the fastest lap time of each
weekend) - is also added to the model’s input data.

> NOTE: To improve the accuracy of the qualifying simulation by
> increasing accepted lap times, sprint format weekend filtering
> approaches differ to include all laps from each driver’s fastest
> stint, regardless of compound or length (discussed further below).

``` r
# Set sprint flag
sprint_flag <- unique(as.logical(data$isSprint))

# Filter for representative lap times
quali_data <- filter_qualifying_laps(data, max_stint, is_sprint = sprint_flag)
stopifnot(mean(is.na(data$LapTime_sec)) < 0.1)

# Apply 107%
fastest_lap <- min(quali_data$LapTime_sec)
model_data_q <- filter(quali_data, LapTime_sec <= fastest_lap * 1.07)

model_data_q <- model_data_q |>
  left_join(constructor_offset |> select(Team, PctOffset), by = "Team")
```

### Bayesian forecasting model construction

``` r
# Fit the Bayesian model
fit_quali <- fit_model(data = model_data_q, is_sprint = sprint_flag)
```

The distribution of lap times in the model input data (`model_data_q`)
adopts a normal distribution due to the filtering selection, as opposed
to the typical right-skew of all lap time data.

<img src="bayesian_model_vignette_files/figure-gfm/distribution-1.png" alt="" width="75%" style="display: block; margin: auto;" />

As a result, the Bayesian inference forecasting model utilises a
Gaussian (`family = gaussian()`) distribution.

#### Forecasting model

The model currently employs two different approaches to standard and
sprint weekend formats to account for the limited lap data that is
collected.

``` r
function (data, is_sprint = FALSE) 
{
    intercept_prior <- round(median(data$LapTime_sec, na.rm = TRUE))
    pct_offset_scale <- intercept_prior/100
    pct_offset_prior <- prior_string(paste0("normal(", round(pct_offset_scale, 
        2), ", ", round(pct_offset_scale/2, 2), ")"), class = "b", 
        coef = "PctOffset")
    if (is_sprint) {
        model_formula <- bf(LapTime_sec | weights(Weighting) ~ 
            log(Weekend_Mins_Elapsed + 1) + Compound + PctOffset + 
                (1 | Team) + (1 | Driver), sigma ~ log(LapCount))
        model_priors <- c(prior_string(paste0("normal(", intercept_prior, 
            ", 5)"), class = "Intercept"), prior(student_t(3, 
            0, 2), class = "sd"), prior(normal(0, 1), class = "b", 
            dpar = "sigma"), pct_offset_prior)
        if ("MEDIUM" %in% unique(data$Compound)) {
            model_priors <- c(model_priors, prior(normal(0.5, 
                0.3), class = "b", coef = "CompoundMEDIUM"))
        }
        if ("HARD" %in% unique(data$Compound)) {
            model_priors <- c(model_priors, prior(normal(1, 0.3), 
                class = "b", coef = "CompoundHARD"))
        }
    }
    else {
        model_formula <- bf(LapTime_sec ~ log(Weekend_Mins_Elapsed + 
            1) + Driver + PctOffset + (1 | Team))
        model_priors <- c(prior_string(paste0("normal(", intercept_prior, 
            ", 5)"), class = "Intercept"), prior(student_t(3, 
            0, 2), class = "sd"), prior(exponential(1), class = "sigma"), 
            pct_offset_prior)
    }
    brm(formula = model_formula, data = data, family = gaussian(), 
        prior = model_priors, chains = 4, iter = 4000, warmup = 1000, 
        cores = detectCores(), threads = threading(max(1, floor(detectCores()/4))), 
        backend = "cmdstanr", stan_model_args = list(stanc_options = list("O1")))
}
```

#### Core model construction

The core foundation of the model accounts for lap times (in seconds)
with consideration for track evolution and the relative team
performance:

$$LapTime \sim \log(Weekend\_Mins\_Elapsed + 1) + PctOffset + \dots$$
Track evolution captured by `log(Weekend_Mins_Elapsed + 1)` attempts to
capture the non-linear trend of the track “rubbering-in” as the weekend
progresses.

#### Handling weekend formats

On standard weekends, where lap data can be pulled from all practice
sessions, the model applies a fixed `Driver` effect. This prevents the
model from heavily shrinking true driver pace towards the grid’s mean,
presenting a more accurate representation of their true pace. The
`(1 | Team)` term allows for partial pooling at the constructor level,
capturing the baseline performance of the different teams and allowing
for shared variance between teammates.

During sprint weekends, only lap time data from a single practice
session (FP1) can be drawn. As a result, the typical filtered approach
(discussed above) results in extremely sparse input data, often missing
many drivers for the model to consider.

To compensate, the model expands its input, and so the model requires
additional considerations:

- `(1 | Driver)` and `(1 | Team)` are modelled as group-level (random)
  intercepts to enforce partial pooling - allowing for limited lap data
  across the grid to loosely converge on a global mean.

- To include more general runs, the sprint input data includes mixed
  tyre running as a fixed `Compound` effect. The impact of mixed tyre
  running is also factored by modelling tyre degradation differences
  over a stint. Modelling the residual standard deviation ($\sigma$)
  against the log of the lap count: $$\sigma \sim \log(LapCount)$$
  allows the model to factor the increased variance as the stint
  increases.

- A `weights(Weighting)` argument is applied to the formula to
  down-weight less reliable laps or stints so sparse data does not
  disproportionately skew the overall simulation.

#### Priors and Regularisation

The model intercept is centred at the median collected lap time
(`normal(intercept_prior, 5)`) providing an informative but weakly
regularising prior that prevents prediction of physically impossible lap
times.

The `PctOffset` prior is derived from the track-specific intercept to
ensure the season-long constructor deficit scales proportionally to the
lap time duration (`intercept_prior / 100`).

As previously stated, sprint weekend formats permit multiple tyre stints
within the input data. In these cases, a physical constraint -
`normal(0.5, 0.3)` for Medium and `normal(1.0, 0.3)` Hard compounds,
respectively - are applied to represent the expected lap time delta
relative to the Soft.

The standard deviation (`prior(student_t(3, 0, 2), class = "sd")`) for
group-level effects adopts a heavy-tailed distribution. This approach
allows the model to remain flexible and capture weekend-specific
deviations of a constructor’s pace against the expected historical
baseline (defined by the strong, regularising `PctOffset`).

Diagnostic evaluation confirms the intended behaviour of this strategy.
The vast majority of driver fixed effects and team random effects
exhibit robust posteriors, showing little sensitivity to either the
priors or the likelihood.

***Prior Sensitivity Diagnostics***

| variable | prior | likelihood | diagnosis |
|:---|---:|---:|:---|
| b_Intercept | 0.0279980 | 0.0372166 | \- |
| b_logWeekend_Mins_ElapsedP1 | 0.0036424 | 0.1201005 | \- |
| b_DriverALO | 0.0238017 | 0.0840650 | \- |
| b_DriverANT | 0.0312885 | 0.0417968 | \- |
| b_DriverBEA | 0.0372015 | 0.0311784 | \- |
| b_DriverBOR | 0.0229960 | 0.0331278 | \- |
| b_DriverCOL | 0.0267757 | 0.0702216 | \- |
| b_DriverGAS | 0.0264948 | 0.0673541 | \- |
| b_DriverHAD | 0.0226692 | 0.0440750 | \- |
| b_DriverHAM | 0.0235524 | 0.0423113 | \- |
| b_DriverHIR | 0.0380969 | 0.0333448 | \- |
| b_DriverHUL | 0.0233434 | 0.0329127 | \- |
| b_DriverLAW | 0.0228163 | 0.0410576 | \- |
| b_DriverLEC | 0.0235054 | 0.0425976 | \- |
| b_DriverNOR | 0.0285566 | 0.0517479 | \- |
| b_DriverOCO | 0.0363729 | 0.0307309 | \- |
| b_DriverPIA | 0.0287845 | 0.0465329 | \- |
| b_DriverRUS | 0.0313607 | 0.0425467 | \- |
| b_DriverSAI | 0.0055903 | 0.1799793 | \- |
| b_DriverSTR | 0.0240801 | 0.0801802 | \- |
| b_DriverTSU | 0.0280089 | 0.1072568 | \- |
| b_DriverVER | 0.0276251 | 0.1064764 | \- |
| b_PctOffset | 0.0805458 | 0.0367468 | potential strong prior / weak likelihood |
| sd_Team\_\_Intercept | 0.1082407 | 0.1062946 | potential prior-data conflict |
| sigma | 0.0127421 | 0.6358386 | \- |
| Intercept | 0.0177736 | 0.1154031 | \- |
| r_Team\[Alpine,Intercept\] | 0.0259039 | 0.0857941 | \- |
| r_Team\[Aston.Martin,Intercept\] | 0.0254107 | 0.0836116 | \- |
| r_Team\[Ferrari,Intercept\] | 0.0217237 | 0.0257845 | \- |
| r_Team\[Haas.F1.Team,Intercept\] | 0.0438221 | 0.0479657 | \- |
| r_Team\[Kick.Sauber,Intercept\] | 0.0271154 | 0.0519769 | \- |
| r_Team\[McLaren,Intercept\] | 0.0240661 | 0.0318159 | \- |
| r_Team\[Mercedes,Intercept\] | 0.0313605 | 0.0387786 | \- |
| r_Team\[Racing.Bulls,Intercept\] | 0.0216517 | 0.0546137 | \- |
| r_Team\[Red.Bull.Racing,Intercept\] | 0.0258506 | 0.0909589 | \- |
| r_Team\[Williams,Intercept\] | 0.0294176 | 0.0462919 | \- |

Strong prior / weak likelihood for `b_PctOffset` confirms the prior is
applying tight constraints on the lap time data based on the historic
baseline to prevent overfitting. A prior-data conflict flag on
`sd_Team__Intercept` is expected in hierarchical models with a limited
number of groups that subsequently struggles to define population-level
variance, causing a heavy reliance on the flexibility of the `student_t`
prior.

Finally, residual variance is constrained using an `expontential(1)`
prior, to reflect the fact that lap-to-lap variance is expected to be
small for peak qualifying laps. As discussed, sprint weekend formats
remodel this variance as a function of the lap count, with an
uninformative normal prior, allowing uncertainty to scale dynamically
with the limited available data.

### Generating qualifying predictions

To generate a point prediction for the qualifying grid, we sample from
the posterior predictive distribution using a simulated dataset
representative of peak track conditions with the `Weekend_Mins_Elapsed`
to its maximum observed value, capturing the fully “rubbered-in” circuit
at the climax of the session.

The final predicted lap time is extracted from the 5th percentile of the
posterior distribution (1st percentile for sprints). Because qualifying
pace fundamentally demands extracting the absolute theoretical limit of
the car rather than an average effort, isolating the 5th percentile
targets the fastest edge of a driver’s predicted performance capability.

<img src="bayesian_model_vignette_files/figure-gfm/plots-1.png" alt="" width="100%" style="display: block; margin: auto;" />
