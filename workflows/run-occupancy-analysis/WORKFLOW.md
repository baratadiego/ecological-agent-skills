# Workflow: run-occupancy-analysis

**Purpose:** Estimate species occupancy and detection probability from repeated survey data  
**Skills:** ecological-data-foundation → biostatistics-workbench → occupancy-and-detection → model-validation-and-uncertainty → reproducible-ecology-pipeline

---

## Trigger

Invoke when the user has repeated presence/absence survey data and wants to estimate occupancy while accounting for imperfect detection.

**Example prompts:**
- "Analyse camera trap data to estimate jaguar occupancy"
- "Run a single-season occupancy model for [species] using repeated point counts"
- "How does occupancy probability vary with habitat quality after accounting for detection?"

---

## Steps

### Step 1 — ecological-data-foundation
- Validate detection history matrix (sites × occasions)
- Check site and observation covariate tables
- Flag sites with all-zero histories (never detected)
- Output: `detection_history.csv`, `site_covariates.csv`, `obs_covariates.csv`

### Step 2 — biostatistics-workbench
- Check covariate distributions and standardise continuous predictors
- Assess collinearity among site and observation covariates
- Output: `covariate_summary.csv`, `collinearity_report.csv`

### Step 3 — occupancy-and-detection
- Fit null model (ψ(.), p(.))
- Fit candidate model set based on a priori hypotheses
- Goodness-of-fit: MacKenzie-Bailey χ² (parametric bootstrap)
- Model selection by AICc (or QAICc if ĉ > 1.5)
- Report ψ and p with 95% CIs
- Output: `model_selection_table.csv`, `occupancy_estimates.csv`, `gof_report.md`

### Step 4 — model-validation-and-uncertainty
- Report goodness-of-fit and ĉ
- Assess sensitivity to number of survey occasions
- Compute minimum surveys needed for target power
- Output: `validation_report.md`, `power_analysis.csv`

### Step 5 — reproducible-ecology-pipeline
- Document closure assumption justification
- Log candidate model rationale
- Capture R session and unmarked version
- Output: `parameter_manifest.yaml`, `software_environment.txt`

---

## Expected Deliverables

- Occupancy estimate (ψ) with 95% CI
- Detection estimate (p) with 95% CI
- Model selection table (AICc, ΔAIC, weights)
- Covariate effect estimates
- Goodness-of-fit results

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| GoF test fails (p < 0.05) | Violation of closure assumption or unmodelled heterogeneity | Add detection covariate; consider mixture models (heterogeneity in detection); verify closure window |
| naive_p > 0.5 but estimated p̂ < 0.1 | Multicollinearity in detection covariates inflating estimates | Check pairwise correlation among detection covariates; reduce model; use VIF screening |
| AIC-best model has ψ̂ ≈ 1.0 with high SE | Numerical convergence issue (perfect detection or near-saturation) | Simplify model; check for sites with detection at every occasion; constrain starting values |
| k (number of surveys) < 3 | Low power to separate ψ from p | Report power analysis alongside estimates; collect more survey occasions in future |
| Detection probability varies strongly by observer | Unmodelled observer effect | Include observer ID as categorical detection covariate |
| ĉ > 1.5 (overdispersion) | Extra-binomial variance; GoF indicates poor fit | Use QAICc instead of AICc for model selection; report ĉ in methods |
| All sites have detection at every occasion | 100% naive occupancy | Consider whether closure is violated or species is truly ubiquitous; occupancy model may be unnecessary |
