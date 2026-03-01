# Workflow: assess-ecological-impact

**Purpose:** Quantify the ecological effect of a disturbance or land-use change  
**Skills:** ecological-data-foundation → geoprocessing-for-ecology → ecological-impact-assessment → biostatistics-workbench → model-validation-and-uncertainty → reproducible-ecology-pipeline

---

## Trigger

Invoke when the user wants to evaluate the impact of a disturbance (deforestation, fire, infrastructure, agriculture) on ecological indicators.

**Example prompts:**
- "Assess the impact of the road construction on bird richness using BACI"
- "Quantify habitat loss and fragmentation from sugarcane expansion"
- "Evaluate the effect of the 2020 fire on forest carbon stocks"

---

## Steps

### Step 1 — ecological-data-foundation
- Validate ecological indicator data (species richness, abundance, biomass, NDVI)
- Confirm site-level metadata (control/impact designation, pre/post dates)
- Output: `data_clean.csv`, `qa_report.md`

### Step 2 — geoprocessing-for-ecology
- Clip land cover and pressure layers to study area
- Compute distance from disturbance for gradient analysis
- Extract spatial covariates at site locations
- Output: `points_with_env.csv`, `pressure_layers/`

### Step 3 — ecological-impact-assessment
- Run BACI mixed model
- Compute landscape fragmentation metrics (pre/post)
- Build composite pressure index
- Output: `baci_results.csv`, `fragmentation_metrics.csv`, `pressure_index.tif`

### Step 4 — biostatistics-workbench
- Validate BACI model assumptions (residual diagnostics)
- Compute effect sizes and CIs for the BACI interaction
- Perform post-hoc tests if multiple indicators
- Output: `assumption_diagnostics/`, `effect_sizes.csv`

### Step 5 — model-validation-and-uncertainty
- Report performance of BACI model (R², calibration)
- Assess sensitivity to control site selection
- Output: `validation_report.md`, `sensitivity_report.md`

### Step 6 — reproducible-ecology-pipeline
- Log all decisions and parameters
- Complete reproducibility checklist
- Output: `parameter_manifest.yaml`, `decision_log.md`

---

## Expected Deliverables

- BACI interaction estimate with 95% CI
- Landscape fragmentation change metrics
- Pressure map
- Impact classification (none / minor / moderate / major / critical)
