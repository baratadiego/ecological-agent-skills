---
name: species-distribution-modeling
description: "Runs the complete species distribution modeling (SDM/ENM) pipeline: occurrence preparation, model fitting (MaxEnt, ensemble), thresholding, projection under climate scenarios, and interpretation. Use this skill when the user mentions habitat suitability, niche modeling, MaxEnt, biomod2, potential distribution, range maps, suitable area mapping, climate projections, invasion risk, range shift analysis, suitability mapping, ENM, ecological niche model, or calibration area definition."
skill_version: 1.0.0
---

# Skill: species-distribution-modeling

**Domain:** SDM · ENM · MaxEnt · Ensemble · Projection  
**Phase:** 2 — Modeling  
**Used by:** run-sdm-study

---

## Purpose

Guides the agent through the complete species distribution / ecological niche modeling pipeline: from occurrence and predictor preparation to model fitting, ensemble building, thresholding, projection, and interpretation.

---

## When to Invoke

- Modeling the potential or realised distribution of one or more species
- Projecting distributions under climate or land-use scenarios
- Comparing niche overlap between taxa or time periods
- Assessing invasion risk or connectivity

---

## Inputs

| Input | Format | Required |
|-------|--------|----------|
| Occurrence records (cleaned) | CSV with lat/lon | Yes |
| Environmental predictor stack | GeoTIFF (multiband or stack) | Yes |
| Study area / calibration area | SHP, GPKG | Yes |
| Future/alternative scenario rasters | GeoTIFF | Optional |
| Background / pseudo-absence points | CSV | Optional |

---

## Outputs

| Output | Description |
|--------|-------------|
| `suitability_current.tif` | Continuous suitability map (current) |
| `suitability_binary.tif` | Thresholded binary map |
| `suitability_scenarios/` | Projected maps per scenario |
| `ensemble_sd.tif` | Uncertainty (SD across algorithms) |
| `variable_importance.csv` | Predictor contributions |
| `response_curves.png` | Marginal response per predictor |
| `sdm_report.md` | Full methodological narrative |

---

## Steps

### 1. Occurrence Curation
- Apply spatial thinning to reduce sampling bias (minimum distance = target resolution)
- Split into calibration and evaluation partitions using spatial blocks
- Report final occurrence count after thinning

### 2. Background / Pseudo-absence Sampling
- Sample background within the calibration area (or a bias-corrected version)
- Ratio: 1:1 to 1:10 (occurrences : background); document choice
- For pseudo-absence methods: apply geographic or environmental constraints

### 3. Predictor Selection
- Apply `predictive-modeling-best-practices` skill for collinearity reduction
- Prefer ecologically justified predictor subsets over data-driven selection alone
- Document final predictor set and sources

### 4. Algorithm Selection
- Run minimum 3 algorithms for ensemble:
  - MaxEnt (presence-background)
  - BRT / GBM (presence-absence or presence-background)
  - Random Forest
  - GLM (baseline)
- Additional: SVM, ANN, GAM as needed

### 5. Model Fitting and Tuning
- Tune regularisation/complexity per algorithm using spatial CV
- Store all tuned model objects and parameters

### 6. Ensemble Building
- Combine algorithms using weighted average (weights = TSS or AUC per algorithm)
- Report ensemble weights
- Compute ensemble SD as uncertainty layer

### 7. Thresholding
- Apply chosen threshold to produce binary map
- Report area predicted suitable (km²) above threshold

### 8. Projection
- Project ensemble to future/alternative scenarios
- Mask extrapolation areas (MESS or ExDet) to flag novel environments
- Report change in suitable area between current and projected

### 9. Interpretation
- Identify the 3 most important predictors
- Describe response curve shapes in ecological terms
- Flag any ecologically implausible responses
- Discuss model limitations and transferability

---

## Key Decisions to Document

- Spatial thinning distance
- Calibration area definition method
- Background sampling strategy
- Algorithm set and tuning ranges
- Ensemble weighting method
- Threshold selection method
- MESS/ExDet extrapolation masking

---

## Tools and Libraries

**R:** `biomod2`, `ENMeval`, `dismo`, `maxnet`, `sdm`, `kuenm`  
**Python:** `elapid`, `pysdm`, `sklearn`

---

## Resources

- `resources/sdm-checklist.md` — SDM reporting checklist (based on ODMAP protocol)
- `resources/calibration-area-guide.md` — M area selection methods
- `resources/algorithm-comparison.md` — algorithm strengths and limitations
- `examples/sdm/` — full worked example

---

## Critical Caveats

> **Suitability ≠ probability of occurrence.**
> The continuous output (`suitability_current.tif`) is an *index of relative environmental
> suitability*, not a probability.  Do not label outputs as "probability of presence" in
> reports, maps, or captions.  Use terms such as "habitat suitability index" or
> "climatic suitability score".

> **Bounding-box clip ≠ study area mask.**
> Clipping rasters by a rectangular bounding box (e.g., `-75,-35` to `-30,6`) does **not**
> restrict predictions to a political boundary or ecological region.  If results must be
> restricted to a specific territory (e.g., Brazil), load a vector polygon
> (`st_read()` / `gpd.read_file()`) and mask the raster to that geometry before any
> further analysis.  Failure to do so will inflate apparent suitable area and may
> produce ecologically misleading maps.

> **Demo / synthetic predictors.**
> If predictors were generated by a mock script rather than downloaded from WorldClim,
> CHELSA, or another validated source, all model outputs are for pipeline demonstration
> only.  Do not report metrics (AUC, TSS) or suitable area figures as if they describe
> real species ecology.  Replace synthetic predictors before any scientific use.

---

## Notes

- Follow the ODMAP (Overview of Data and Methods in Presence-Absence Modeling) reporting standard
- Always mask predictions to the calibration area unless explicitly projecting to novel regions
- Climate projections should use multiple GCMs and report uncertainty across models
- Python 3.11 or 3.12 recommended; Python 3.14 may lack stable wheels for rasterio/fiona
