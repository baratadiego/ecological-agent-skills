# Workflow: run-population-viability

**Purpose:** Project population trajectories and estimate extinction risk using matrix population models
**Skills:** ecological-data-foundation → biostatistics-workbench → population-viability-analysis → model-validation-and-uncertainty → reproducible-ecology-pipeline

---

## Trigger

Invoke when the user wants to project population growth, estimate extinction probability, compute lambda/elasticity, or evaluate a species against IUCN Criterion E.

**Example prompts:**
- "Run a PVA for African elephants using a Lefkovitch matrix"
- "Estimate extinction probability for [species] over the next 100 years"
- "Compute lambda and elasticity for a population with 4 life stages"

---

## Steps

### Step 1 — ecological-data-foundation
- Validate vital rate data (survival and fecundity per stage or age class)
- Check demographic data sources (mark-recapture, census, literature)
- Flag missing stages or implausible rates (survival > 1, negative fecundity)
- Output: `vital_rates_clean.csv`, `demographic_sources.md`, `qa_report.md`

### Step 2 — biostatistics-workbench
- Assess variance in vital rate estimates
- Compute coefficient of variation (CV) for each rate
- Check for temporal autocorrelation in demographic time series (if available)
- Output: `vital_rate_summary.csv`, `cv_report.csv`

### Step 3 — population-viability-analysis
- Construct Leslie (age-based) or Lefkovitch (stage-based) projection matrix
- Compute deterministic lambda, stable stage distribution, reproductive value
- Compute sensitivity and elasticity matrices
- Run stochastic PVA (Monte Carlo, >= 1000 simulations):
  - Beta distribution for survival rates
  - Lognormal distribution for fecundity rates
  - Optional: catastrophe scenarios, density dependence
- Estimate extinction probability at quasi-extinction threshold
- Classify against IUCN Criterion E thresholds
- Output: `lambda_summary.csv`, `elasticity_matrix.csv`, `pva_trajectories.csv`, `extinction_curve.csv`, `iucn_criterion_e.md`

### Step 4 — model-validation-and-uncertainty
- Sensitivity analysis: vary vital rates +/- 10% individually
- Compare deterministic vs stochastic lambda
- Assess effect of catastrophe frequency on extinction risk
- Report confidence intervals on extinction probability
- Output: `sensitivity_report.md`, `validation_report.md`

### Step 5 — reproducible-ecology-pipeline
- Document vital rate sources with citations
- Log matrix structure and parameterisation choices
- Record simulation parameters (n_sims, time horizon, quasi-extinction threshold)
- Output: `parameter_manifest.yaml`, `decision_log.md`, `reproducibility_checklist.md`

---

## Expected Deliverables

- Projection matrix with lambda, sensitivity, and elasticity
- Stochastic PVA trajectories (median + 95% CI)
- Extinction probability curve over time horizon
- IUCN Criterion E classification
- Elasticity-based management recommendations
- Reproducibility package

---

## Minimum Data Requirements

- Vital rates (survival + fecundity) for >= 2 life stages
- Initial population size or stage distribution
- Quasi-extinction threshold (default: 50 individuals)
- Time horizon (default: 100 years)

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| Deterministic lambda < 1.0 | Population declining without stochasticity | Report decline rate; identify which vital rate has highest elasticity for management |
| CV of any vital rate > 0.3 | High demographic stochasticity | Use stochastic PVA as primary result; do not rely on deterministic lambda alone |
| Extinction probability > 0.10 in 100 years | Meets IUCN Criterion E (Vulnerable threshold) | Report IUCN classification; identify management levers via elasticity analysis |
| Elasticity concentrated in one rate (> 0.6) | Population growth dominated by single vital rate | Focus conservation action on that rate; run targeted management scenarios |
| Catastrophe probability unknown | Cannot parameterise rare events | Run scenarios at 0%, 5%, 10% catastrophe frequency; report range |
| n_stages < 3 with available data for more | Matrix oversimplified | Expand matrix to match available data resolution; justify aggregation if used |
| Stochastic lambda >> deterministic lambda | Possible parameterisation error or Jensen's inequality effect | Verify distribution choices; report both values and explain discrepancy |
