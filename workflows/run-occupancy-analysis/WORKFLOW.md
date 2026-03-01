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
