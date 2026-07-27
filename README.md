# laps-of-judgement
A Bayesian hierarchical model for predicting F1 qualifying performace. For evaluation of the current model, see the [scoring](docs/vignettes/scoring_model_vignette.md).

![Latest](latest_prediction.png)

<details>
<summary>What do these predictions mean?</summary>

The bars display the gaps of drivers to the fastest predicted lap time (according to their individual 5th percentile of posterior simulations). Drivers marked with `*` had insufficient practice data to provide a high-confident prediction. The heatmap marks each driver's mostly likely position based on their probability across the posterior simulations.

</details>

## How it works
Uses free practice session lap time data fetched from [FastF1](https://github.com/theOehrly/Fast-F1) to generate a **probabilistic forecast of qualifying times** before qualifying.

### Key points
- Representative lap times are filtered for green flag running, stints on the softest compound, fresh tyres and under 4 laps of total stint length.
- The model accounts for track evolution across the elapsed session time term.
- Random intercepts are nested by constructor and driver, allowing the model to share statistical strength across the field, while still estimating individual driver pace offsets.
- The posterior predictive distribution over each driver's lap time is used to generate the quailfying gap forecasts.
- Low confidence predictions (i.e. not enough available data) are indicated by an asterisk.

## Getting started

### Prerequisites

- Python (3.14.3)
- R (4.5.2) - use [`renv`](https://rstudio.github.io/renv/) for package installation

### Clone the repository
```bash
git clone https://github.com/aes21/laps-of-judgement.git
cd laps-of-judgement
```

### Installation
Install Python and R environment dependencies.

```bash
python -m pip install -r .\requirements.txt
Rscript -e "renv::restore()"
```

### Fetch data
Example using 2025 season data.

```bash
python python/get_data.py --year 2025
```

You only need to run this line once for a given year, the subsequently created `data` directory will contain the cached data required to complete the rest of the workflow for any given event of that season.

> [!WARNING]
> FastF1 only holds practice data beyond the 2018 season. Currently, `SOFT` is considered the qualifying tyre to align with the 2019 rule change.

### Fit model for specific event
```bash
Rscript R/model.R "Spanish Grand Prix" 2025
```

### Generate a prediction
```bash
Rscript R/predict.R "Spanish Grand Prix" 2025
```

### Evaluate the prediction
For predicted sessions that have already been completed, the simulation can be evaluated against the known finishing results. You must retrieve the relevant season qualifying lap data before evalutating the model's predictions.

```bash
python python/get_data.py --session_type Q --year 2025
Rscript R/model.R "Spanish Grand Prix" 2025
Rscript R/predict.R "Spanish Grand Prix" 2025
```
A plot of the simulated qualifying gaps and prediction evaluations are generated in the `plots/` directory:

<table>
  <tr>
    <td><img src="plots/predicted_grid_2025_Spanish_Grand_Prix.png" width="400"/></td>
    <td><img src="plots/evaluated_grid_2025_Spanish_Grand_Prix.png" width="400"/></td>
  </tr>
</table>

For a deeper discussion of the methods used, and evaluation of the model's effectiveness, see the [documentation](docs/) directory.
