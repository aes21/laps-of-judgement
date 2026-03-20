# laps-of-judgement
A simple F1 qualifying Bayesian inference performance predictor using data fetched from [FastF1](https://github.com/theOehrly/Fast-F1).

## Getting started

### Clone the repository
```bash
git clone https://github.com/aes21/laps-of-judgement.git
cd laps-of-judgement
```

### Installation
Install Python and R environment dependencies.

```bash
python -m pip install -r .\requiremnts.txt
Rscript -e "renv::restore()"
```

### Fetch data
Example using 2025 season data.

```bash
python python/fetch_practice_data.py --year 2025
```

### Fit model for specific event
```bash
Rscript R/model.R "Spanish Grand Prix" 2025
```

### Generate a prediction
```bash
Rscript R/predict.R "Spanish Grand Prix"
```
A plot of the qualifying gap prediction is generated in: `plots/` :

![Prediction](plots/predicted_grid_Spanish_Grand_Prix.png)
