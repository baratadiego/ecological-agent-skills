# Workflow: run-camera-trap-occupancy

**Purpose:** Process camera trap data into detection histories and estimate occupancy with imperfect detection
**Skills:** ecological-data-foundation → camera-trap-processing → occupancy-and-detection → model-validation-and-uncertainty → reproducible-ecology-pipeline

---

## Trigger

Invoke when the user has camera trap image records and wants to estimate species occupancy accounting for imperfect detection.

**Example prompts:**
- "Process my camera trap data and estimate jaguar occupancy in the study area"
- "Build detection histories from camera trap records and run an occupancy model"
- "Estimate puma occupancy from camera trap surveys across 40 stations"

---

## Steps

### Step 1 — ecological-data-foundation
- Validate camera station metadata (GPS coordinates, deployment/retrieval dates)
- Clean species identification records; resolve taxonomy
- Flag stations with incomplete deployment periods
- Output: `stations_clean.csv`, `records_clean.csv`, `qa_report.md`

### Step 2 — camera-trap-processing
- Define independence threshold (default 30 min; adjust per taxon)
- Generate record table with independent detection events
- Build camera operation matrix (active/inactive per station per day)
- Construct detection history matrix (sites x occasions)
- Compute trap effort summary and RAI (relative abundance index)
- Output: `record_table.csv`, `detection_history.csv`, `camera_operation.csv`, `trap_effort.csv`

### Step 3 — occupancy-and-detection
- Fit null model psi(.), p(.)
- Fit candidate models with site covariates (habitat, elevation, distance to water) and detection covariates (effort, season, camera model)
- Goodness-of-fit: MacKenzie-Bailey chi-squared (parametric bootstrap)
- Model selection by AICc (or QAICc if c-hat > 1.5)
- Report psi and p with 95% CIs
- Output: `model_selection_table.csv`, `occupancy_estimates.csv`, `gof_report.md`

### Step 4 — model-validation-and-uncertainty
- Report goodness-of-fit and c-hat
- Assess sensitivity to independence threshold choice
- Compute minimum surveys needed for target detection power
- Output: `validation_report.md`, `power_analysis.csv`

### Step 5 — reproducible-ecology-pipeline
- Document independence threshold justification
- Log candidate model rationale and closure assumption
- Capture software environment (R/camtrapR/unmarked versions)
- Output: `parameter_manifest.yaml`, `decision_log.md`, `reproducibility_checklist.md`

---

## Expected Deliverables

- Detection history matrix (sites x occasions)
- Camera operation and trap effort summaries
- Occupancy estimate (psi) with 95% CI
- Detection estimate (p) with 95% CI
- Model selection table (AICc, delta-AIC, weights)
- Covariate effect estimates
- Reproducibility package

---

## Minimum Data Requirements

- >= 20 camera stations with >= 3 survey occasions each
- Station metadata with GPS coordinates and deployment dates
- Species identification for target species
- >= 5 independent detections of target species across stations

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| RAI = 0 for target species | Species not detected at any station | Cannot fit occupancy model; report non-detection; consider expanding survey effort |
| < 5 detections across all stations | Extremely low detection rate | Occupancy estimates will be unreliable; report with strong caveats; consider pooling occasions |
| Independence threshold changes results by > 20% | Sensitivity to threshold choice | Report results at multiple thresholds (15, 30, 60 min); justify final choice in decision log |
| Camera operation < 70% of planned effort | High station failure rate | Exclude stations with < 14 active days; report effective vs planned effort |
| GoF test fails (p < 0.05) | Closure violation or unmodelled heterogeneity | Shorten occasion length to reduce closure violations; add detection covariates |
| Naive occupancy = 1.0 | Species detected at every station | Occupancy model unnecessary; report naive occupancy; focus on abundance or activity patterns |
