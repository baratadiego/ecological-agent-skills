---
skill_version: 1.0.0
---

# Skill: population-viability-analysis

**Domain:** PVA · Leslie matrix · Demographic stochasticity · Extinction risk · IUCN criteria

---

## Purpose

Guides the agent through population viability analysis using deterministic matrix models and stochastic simulations. Covers construction of Leslie or Lefkovitch stage-structured matrices, computation of population growth rate (λ), sensitivity and elasticity analysis, stochastic projection with demographic and environmental variance, and estimation of extinction probability and mean time to extinction (MTE) for IUCN Red List assessment.

---

## When to Invoke

Invoke this skill when:

- The user requests a population viability analysis or extinction risk assessment
- A Leslie or Lefkovitch matrix must be built from vital rate data
- Population growth rate (λ) and its sensitivity to demographic parameters are needed
- Stochastic population projections are requested with extinction probability curves
- IUCN criteria A–E must be evaluated using modelled population trajectories

**trigger_keywords:** `PVA`, `population viability`, `extinction risk`, `minimum viable population`, `Leslie matrix`, `Lefkovitch matrix`, `population projection`, `lambda`, `demographic analysis`, `IUCN criterion`, `quasi-extinction`, `stochastic simulation`, `vital rates`, `survival rate`, `fecundity`

---

## Inputs

| Input | Format | Required |
|---|---|---|
| Vital rates table (survival, growth, fecundity by stage/age) | CSV | Required |
| Number of projection years | Integer (default: 100) | Required |
| Number of stochastic simulations | Integer (default: 1000) | Recommended |
| Quasi-extinction threshold (Ne) | Integer (default: 50) | Recommended |
| Coefficient of variation for vital rates (stochastic variance) | CSV or floats | Recommended |
| Initial population size and stage distribution | CSV or vector | Optional |

---

## Outputs

| Output | Description |
|---|---|
| `lambda_estimates.csv` | Dominant eigenvalue λ with bootstrap 95% CI |
| `sensitivity_matrix.csv` | Partial derivatives ∂λ/∂a_ij for each matrix element |
| `elasticity_matrix.csv` | Proportional sensitivity e_ij for each matrix element |
| `population_projection.png` | Deterministic N(t) trajectory over projection years |
| `extinction_probability.csv` | P(extinction) and P(quasi-extinction) by year |
| `mte_estimate.csv` | Mean time to extinction with 95% CI |
| `stochastic_trajectories.png` | Fan plot of 1000 stochastic population trajectories |
| `extinction_curve.png` | Cumulative extinction probability over time |

---

## Steps

1. **Build the projection matrix**
   Read vital rates from CSV. Confirm all survival rates are in (0, 1] and fecundity ≥ 0.
   Construct Leslie (age-structured) or Lefkovitch (stage-structured) matrix.
   If stage boundaries are ambiguous, document choice in `decision_log.md`.

2. **Compute λ and confidence interval** *(invoke `matrix_pva.R`)*
   Calculate dominant eigenvalue λ = Re(eigen(A)$values[1]).
   Bootstrap vital rates (1000 resamples) to obtain 95% CI for λ.
   If λ < 1.0: population declining. If λ < 0.95: high extinction risk.

3. **Sensitivity and elasticity analysis**
   Compute sensitivity matrix S and elasticity matrix E.
   Identify which vital rate (survival, growth, fecundity) most affects λ.
   High elasticity for adult survival → management interventions should target adults.

4. **Deterministic projection**
   Project N(t) = A^t × N(0) over `n_years`.
   If CV of vital rates > 0.30, note that deterministic projection underestimates variance.
   Plot projection with initial population size.

5. **Stochastic simulation** *(invoke `stochastic_pva.R`)*
   Draw vital rates from Beta (survival) and Poisson/Normal (fecundity) distributions
   each time step using CV from input table.
   Run `n_simulations` replicates. Track N(t) for each.
   Calculate P(N(t) < Ne) for each year to produce extinction probability curve.

6. **Compute MTE and IUCN assessment**
   Mean time to extinction = mean year of first crossing Ne across simulations.
   Classify against IUCN criteria:
   - P(extinction in 100 yr) > 50% → Critically Endangered (criterion E)
   - > 20% → Endangered; > 10% → Vulnerable.

7. **Validate and document**
   Check λ from step 2 is consistent with stochastic simulation trend.
   Record all vital rate sources, CV assumptions, and IUCN classification rationale
   in `decision_log.md`.

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| Vital rate data from < 3 years | High parametric uncertainty | Run sensitivity analysis across wide range; report P(extinction) as range, not point estimate |
| λ < 0.95 in deterministic model | Rapid deterministic decline | Calculate MTE even without stochasticity; management urgency is high |
| CV of vital rates > 0.30 | Environmental stochasticity dominates | Stochastic model is mandatory; deterministic λ is insufficient |
| N_initial < 50 | Below minimum viable population | Allee effects may apply; consider demographic stochasticity separately |
| Bootstrap CI for λ crosses 1.0 | λ not significantly different from 1 | Report both scenarios (λ > 1 and λ < 1); do not claim stability without longer monitoring |

---

## Key Decisions to Document

Record the following in `decision_log.md` after running this skill:

- Source of vital rate estimates (literature, field data, expert elicitation) and associated uncertainty
- Choice of Leslie vs. Lefkovitch structure and age/stage class boundaries
- Quasi-extinction threshold (Ne) and its biological justification
- Distribution assumptions for stochastic vital rate draws (Beta, Poisson, Normal)
- Whether IUCN criterion E classification was performed and the result

---

## Tools and Libraries

**R**
```r
suppressPackageStartupMessages(library(popbio))    # matrix PVA: lambda, sensitivity, elasticity
suppressPackageStartupMessages(library(dplyr))     # data manipulation
suppressPackageStartupMessages(library(tidyr))     # reshaping
suppressPackageStartupMessages(library(ggplot2))   # plotting trajectories and curves
suppressPackageStartupMessages(library(boot))      # bootstrapping vital rates
```

**Python**
```python
import numpy as np           # eigenvalue computation, matrix multiplication
import pandas as pd          # vital rate tables
import matplotlib.pyplot as plt  # trajectory plots
from pathlib import Path     # file system
```

---

## Resources

- [`skills/population-viability-analysis/resources/matrix-model-guide.md`](resources/matrix-model-guide.md) — Leslie vs. Lefkovitch matrices, λ computation, sensitivity and elasticity reference table
- [`skills/population-viability-analysis/resources/extinction-risk-thresholds.md`](resources/extinction-risk-thresholds.md) — IUCN criteria A–E, quasi-extinction thresholds, MVP concept and literature values
- [`skills/population-viability-analysis/resources/sensitivity-elasticity-reference.md`](resources/sensitivity-elasticity-reference.md) — Published elasticities by taxon group and management implications

---

## Notes

- **λ from a single matrix ignores temporal variation:** A single matrix built from pooled data produces a long-run average λ. If vital rates vary strongly between years (drought, disease outbreaks), the stochastic geometric mean growth rate (λ_s) will be lower than the deterministic λ.
- **Sensitivity vs. elasticity are complementary:** Sensitivity identifies which matrix element has the largest absolute effect on λ; elasticity identifies the proportional effect. For management, elasticity is more interpretable because it accounts for the natural scale of each vital rate.
- **Small-population effects are not captured by matrix models:** Inbreeding depression, Allee effects, and demographic stochasticity in very small populations (N < 20) require individual-based models (IBM) that are beyond this skill's scope.
- **Do not extrapolate beyond data range:** If only 5 years of demographic data exist, projections to 100 years carry enormous uncertainty. Report CIs from bootstrapping and note the data limitation explicitly.
- **IUCN criterion E requires peer-reviewed vital rates:** Self-collected data with < 3 years of monitoring should not be used as the sole basis for an IUCN listing under criterion E without independent validation.
