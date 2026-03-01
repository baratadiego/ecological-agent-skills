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
