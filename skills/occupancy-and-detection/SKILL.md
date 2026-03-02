---
skill_version: 1.0.0
---

# Skill: occupancy-and-detection

**Domain:** Occupancy models · Imperfect detection · Replicate surveys  
**Phase:** 3 — Specialist  
**Used by:** run-occupancy-analysis

---

## Purpose

Guides the agent through the design and analysis of occupancy studies that account for imperfect detection. Covers single-season and dynamic occupancy models, covariate specification, goodness-of-fit testing, and result interpretation.

---

## When to Invoke

- Species were surveyed at multiple sites with repeated visits
- Detection probability is likely < 1 and must be estimated separately from occupancy
- The goal is to estimate ψ (occupancy) and p (detection) and their covariates
- Designing a new monitoring protocol where detection needs to be modelled

---

## Inputs

| Input | Format | Required |
|-------|--------|----------|
| Detection history matrix (sites × occasions) | CSV (1/0/NA) | Yes |
| Site-level covariates (ψ covariates) | CSV | Recommended |
| Observation-level covariates (p covariates) | CSV or 3D array | Recommended |
| Number of seasons (for dynamic models) | Integer | Conditional |

---

## Outputs

| Output | Description |
|--------|-------------|
| `occupancy_estimates.csv` | ψ estimates per site (if site-level) |
| `detection_estimates.csv` | p estimates per occasion |
| `model_selection_table.csv` | AIC table for all candidate models |
| `covariate_effects.csv` | Beta coefficients with 95% CIs |
| `gof_report.md` | MacKenzie-Bailey χ² goodness-of-fit |
| `occupancy_map.tif` | Predicted occupancy surface (if spatial) |

---

## Steps

### 1. Assess Study Design
- Confirm: multiple sites, multiple repeat surveys per site within a season
- Confirm: population is closed within season (single-season) or document seasons
- Calculate naive occupancy (proportion of sites with ≥1 detection) as a baseline
- Report detection rates per occasion

### 2. Format the Detection History
- Rows = sites, columns = survey occasions
- Values: 1 (detected), 0 (surveyed, not detected), NA (not surveyed)
- Standardise continuous covariates (mean = 0, SD = 1)

### 3. Define Candidate Models
- Build candidate model set based on a priori ecological hypotheses
- Include a null model (ψ(.), p(.)) as baseline
- Typical covariate hypotheses for ψ: habitat quality, elevation, disturbance index
- Typical covariate hypotheses for p: observer, time of day, weather, survey effort
- Avoid all-subsets model selection; limit to ≤ K candidates (K = sample size / 10)

### 4. Fit Models
- Use maximum likelihood (unmarked package) or Bayesian (JAGS/Stan) estimation
- For single-season: `occu(~p_covariates ~psi_covariates)`
- For dynamic (multi-season): specify colonisation (γ) and extinction (ε) parameters
- Check for convergence warnings

### 5. Goodness-of-Fit
- Apply MacKenzie-Bailey χ² test (parametric bootstrap, n = 1000 iterations)
- Report ĉ (overdispersion factor); if ĉ > 1.5, use QAICc instead of AICc
- Visualise observed vs expected detection frequencies

### 6. Model Selection
- Rank by AICc (or QAICc)
- Report ΔAIC and Akaike weights
- If top models are within ΔAIC < 2, use model averaging

### 7. Interpret Results
- Report ψ with 95% CI on the probability scale
- Report p with 95% CI; discuss implications for survey design
- Report covariate effects as odds ratios or backtransformed probabilities
- Compute minimum number of surveys needed to confirm absence (given estimated p)

---

## Key Decisions to Document

- Closure assumption justification
- Candidate model set rationale
- Goodness-of-fit result and action taken (e.g., use QAICc)
- Model averaging vs. best-model inference

---

## Tools and Libraries

**R:** `unmarked`, `RPresence`, `PRESENCE`, `jagsUI`, `rstan`  
**Python:** `pyoccupancy` (limited), interface to JAGS via `pyjags`

---

## Resources

- `resources/occupancy-study-design.md` — required replicates for target power
- `resources/detection-history-format.md` — how to format the input matrix
- `examples/` — worked single-season and dynamic occupancy examples

---

## Notes

- At least 3 repeat surveys per site are recommended for reliable p estimation
- Spatial replication (many sites) is more important than temporal replication per site
- Dynamic models require careful closure assumption per season
