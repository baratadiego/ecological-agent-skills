# Workflow: run-sdm-study

**Purpose:** End-to-end species distribution modeling study  
**Skills:** ecological-data-foundation → geoprocessing-for-ecology → predictive-modeling-best-practices → species-distribution-modeling → model-validation-and-uncertainty → reproducible-ecology-pipeline

---

## Trigger

Invoke when the user wants to model species distributions, predict habitat suitability, or project distributions under alternative scenarios.

**Example prompts:**
- "Run an SDM for Panthera onca in the Amazon"
- "Build a habitat suitability model for [species] using WorldClim predictors"
- "Project the distribution of [species] under SSP2-4.5 by 2050"

---

## Steps

### Step 1 — ecological-data-foundation
- Ingest and validate occurrence records
- Apply coordinate cleaning (CoordinateCleaner flags)
- Validate taxonomy against GBIF Backbone
- Output: `data_clean.csv`, `qa_report.md`

### Step 2 — geoprocessing-for-ecology
- Define study area / calibration area (M area)
- Reproject predictors to project CRS
- Clip and mask rasters to study area
- Extract predictor values at occurrence and background points
- Output: `predictors_stack.tif`, `points_with_env.csv`

### Step 3 — predictive-modeling-best-practices
- Assess collinearity; remove redundant predictors
- Define spatial CV block structure
- Design tuning grid for each algorithm
- Output: `cv_strategy.md`, `selected_predictors.txt`, `collinearity_report.csv`

### Step 4 — species-distribution-modeling
- Apply spatial thinning to occurrences
- Sample background points within M area
- Fit ≥3 algorithms with tuned hyperparameters
- Build weighted ensemble
- Project to current and scenario conditions
- Mask extrapolation areas (MESS)
- Output: `suitability_current.tif`, `suitability_binary.tif`, `suitability_scenarios/`, `variable_importance.csv`

### Step 5 — model-validation-and-uncertainty
- Compute AUC, TSS, Boyce index on spatial CV folds and independent test set
- Assess calibration
- Compute ensemble SD (uncertainty map)
- Run sensitivity analysis on top predictors
- Output: `performance_metrics.csv`, `uncertainty_map.tif`, `validation_report.md`

### Step 6 — reproducible-ecology-pipeline
- Capture software environment
- Finalise parameter manifest
- Complete reproducibility checklist
- Archive outputs and parameter file
- Output: `reproducibility_checklist.md`, `parameter_manifest.yaml`, `decision_log.md`

---

## Expected Deliverables

- Continuous and binary suitability maps (current + scenarios)
- Model performance table
- Variable importance and response curves
- Uncertainty map
- Reproducibility package (code + parameters + checksums)

---

## Minimum Data Requirements

- ≥ 30 cleaned occurrence records after thinning (≥ 100 recommended)
- ≥ 3 environmental predictors, ≤ 10 after collinearity reduction
- Study area polygon

---

## Reporting Standard

Follow the **ODMAP protocol** (Zurell et al. 2020) for methods reporting.

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| AUC < 0.70 after calibration | Model has no predictive power | Revise predictor set; increase calibration effort (extend RM × FC grid); verify coordinate quality |
| n_occurrences < 30 after thinning | Insufficient data for reliable SDM | Document and do not publish SDM results; consider target-group background or literature review only |
| MOP = 0 in > 40% of projected area | Severe extrapolation beyond calibration data | Restrict interpretation to calibration area; add explicit caveat in abstract and figure caption |
| delta_AICc < 2 for multiple models | Model selection uncertainty | Report ensemble of all equivalent models; do not pick a single "best" model arbitrarily |
| MESS < 0 in core suitable area | Novel environmental combinations in projection | Flag in figure caption; consider masking MESS < 0 pixels in main figure |
| Selected RM is at grid boundary (0.5 or 6) | Grid too narrow; optimal value outside range | Extend RM grid in that direction and re-run calibration |
| Training AUC >> block CV AUC (gap > 0.15) | Spatial autocorrelation inflating training AUC | Report block CV AUC as primary metric; do not report training AUC as validation |
