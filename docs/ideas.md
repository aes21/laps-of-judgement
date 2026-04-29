# Ideas & Roadmap

Ideas and potential extensions to this project.

## Bayesian Methods

- [ x ] **Sequential modelling**: Update the posterior after each practice session (FP1 → FP2 → FP3) rather than fitting a single model per weekend. Requires restructuring the model fitting step to accept a prior from the previous session's posterior. Investigate visualisation methods for team/driver trends of the practice days.

- [ ] **Prior analysis**: Investigate prior optimisation by building a 'testing' workflow evaluating predictions against known results.

## Time Series & Stochastic Processes

- [ ] **Track evolution**: Attempt to add track evolution (as a factor of time and weather) to model grip improvements.

- [ ] **Session progression improvements**: Refine and optimise elapsed time factoring.

- [ ] **Tyre degradation modelling**: Fit a degradation curve (lap time vs. tyre age) as part of the model, with compound and driver as hierarchical random effects.

## Method Inference

- [ ] **DAG**: Build a directed acyclic graph (DAG) of the factors that drive lap time - fuel load, tyre compound, track temperature, driver, car and use it to reason about interventions explicitly. Tools: `dagitty` or `bnlearn` in R.

- [ ] **Uncertainty Quantification & Decision Theory**: Plot the complete posterior predictive distribution per driver rather than just the point estimate and credible interval. Propagate uncertainty from the posterior through a simplified race strategy decision (e.g. pit window timing) using Monte Carlo draws. Directly analogous to simulation-based VaR calculation.

## Model Comparison & Validation

- [ ] **LOO-CV / WAIC model comparison**: Compare models of varying complexity using leave-one-out cross-validation or WAIC.