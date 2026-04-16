# Ideas & Roadmap

Ideas and potential extensions to this project.

## Bayesian Methods

### Sequential Bayesian updating
Update the posterior after each practice session (FP1 → FP2 → FP3) rather than fitting a single model per weekend. Requires restructuring the model fitting step to accept a prior from the previous session's posterior.

### Prior sensitivity analysis
Systematically vary the priors and quantify how predictions shift as a result.

## Time Series & Stochastic Processes

### Track evolution as a latent variable
Plan to model track rubber improvement as a latent state rather than a fixed elapsed-time term.

### Gaussian Process regression for session progression
Model lap time as a GP over elapsed session time, allowing a more flexible and principled treatment of track evolution.

### Season-long car performance tracking
Extend the model across a full season to track how each constructor's relative pace evolves round-to-round.

## Causal Inference

### Causal DAG for lap time
Build a directed acyclic graph (DAG) of the factors that drive lap time — fuel load, tyre compound, track temperature, driver, car — and use it to reason about interventions explicitly.
- Tools: `dagitty` or `bnlearn` in R.

### Weather as a natural experiment
Use sessions with mixed or wet conditions as a natural experiment to practice difference-in-differences or regression discontinuity designs.

## Uncertainty Quantification & Decision Theory

### Full posterior predictive visualisation
Plot the complete posterior predictive distribution per driver rather than just the point estimate and credible interval.

### Monte Carlo race strategy simulation
Propagate uncertainty from the posterior through a simplified race strategy decision (e.g. pit window timing) using Monte Carlo draws. Directly analogous to simulation-based VaR calculation.

## Model Comparison & Validation

### LOO-CV / WAIC model comparison
Compare models of varying complexity using leave-one-out cross-validation or WAIC.

### Tyre degradation modelling
Fit a degradation curve (lap time vs. tyre age) as part of the model, with compound and driver as hierarchical random effects. Conceptually maps to decay and mean-reversion models.