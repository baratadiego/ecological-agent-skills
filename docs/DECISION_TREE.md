# Skill Selection Decision Tree

Use this guide to identify which skill (or sequence of skills) to invoke based on your data type and analytical goal. Start at the top and follow the branches that match your situation.

---

## Quick Reference Table

| If your data is... | And your goal is... | Start with skill |
|--------------------|---------------------|------------------|
| Occurrence records (species coordinates) | Download, clean, validate | ecological-data-foundation |
| Occurrence records + environmental layers | Model species distribution | ecological-data-foundation → geoprocessing-for-ecology → predictive-modeling-best-practices → species-distribution-modeling |
| Raster / vector layers only | Reproject, clip, stack, extract values | geoprocessing-for-ecology |
| Tabular ecological data (1 response, N predictors) | Statistical test or regression | biostatistics-workbench |
| Species × site matrix | Community composition / ordination | ecological-data-foundation → community-ecology-ordination |
| Replicated detection/non-detection surveys | Occupancy and detection probability | ecological-data-foundation → occupancy-and-detection |
| Before/after, control/impact data | Quantify disturbance effect (BACI) | ecological-data-foundation → ecological-impact-assessment |
| Time-indexed environmental variable | Trend, breakpoint, anomaly | ecological-data-foundation → environmental-time-series |
| Land cover + biophysical layers | Ecosystem services mapping | ecological-data-foundation → geoprocessing-for-ecology → ecosystem-services-assessment |
| Camera trap image records | Detection events, diel activity | camera-trap-processing (→ occupancy-and-detection) |
| Audio recordings (WAV/FLAC) | Soundscape indices, species detection | acoustic-monitoring (→ environmental-time-series) |
| Habitat patches + land cover raster | Landscape connectivity, corridors | geoprocessing-for-ecology → landscape-connectivity |
| Vital rates (survival, fecundity by stage) | Population viability, IUCN Criterion E | biostatistics-workbench → population-viability-analysis |
| Suitability maps + planning units | Reserve design, prioritization | species-distribution-modeling → spatial-prioritization |
| Any fitted model | Evaluate performance, quantify uncertainty | model-validation-and-uncertainty |
| Any completed analysis | Audit trail, reproducibility checklist | reproducible-ecology-pipeline |

---

## Decision Tree — Detailed

### Step 1: What type of data do you have?

```
Root
 ├── A. Occurrence records (species lat/lon)        → go to Branch A
 ├── B. Spatial rasters or vectors only             → go to Branch B
 ├── C. Tabular survey data (sites × variables)     → go to Branch C
 ├── D. Time series data                            → go to Branch D
 ├── E. Multimedia data (images / audio)            → go to Branch E
 └── F. Model outputs (predictions, suitability)   → go to Branch F
```

---

### Branch A — Occurrence Records

```
A. Occurrence records
 ├── A1. Raw / uncleaned records?
 │    └── ALWAYS start with: ecological-data-foundation
 │         (cleaning, QA, deduplication, coordinate flags)
 │
 ├── A2. Goal: map species distribution / suitability?
 │    └── ecological-data-foundation
 │         → geoprocessing-for-ecology       (extract env. values)
 │         → predictive-modeling-best-practices  (predictor selection, CV design)
 │         → species-distribution-modeling   (MaxEnt / RF / BRT / ensemble)
 │         → model-validation-and-uncertainty (AUC, TSS, uncertainty maps)
 │         → reproducible-ecology-pipeline
 │
 ├── A3. Goal: occupancy and detection probability?
 │    → Replicated visit data required (detection history matrix)
 │    └── ecological-data-foundation
 │         → occupancy-and-detection
 │         → biostatistics-workbench
 │         → reproducible-ecology-pipeline
 │
 └── A4. Multiple species simultaneously?
      └── Follow workflow: run-multispecies-screening
           (ecological-data-foundation → geoprocessing-for-ecology
            → species-distribution-modeling (loop) → model-validation-and-uncertainty)
```

---

### Branch B — Spatial Rasters or Vectors

```
B. Spatial rasters or vectors
 ├── B1. Need to reproject, clip, resample, stack layers?
 │    └── geoprocessing-for-ecology (standalone)
 │
 ├── B2. Need to extract environmental values at occurrence points?
 │    └── geoprocessing-for-ecology (stack_and_extract.py)
 │         → then continue with predictive-modeling-best-practices
 │
 ├── B3. Land cover raster + biophysical data → ecosystem services?
 │    └── ecological-data-foundation → geoprocessing-for-ecology
 │         → ecosystem-services-assessment → reproducible-ecology-pipeline
 │
 └── B4. Habitat patches + dispersal distance → connectivity?
      └── geoprocessing-for-ecology → landscape-connectivity
```

---

### Branch C — Tabular Survey Data

```
C. Tabular survey data
 ├── C1. Single response variable (abundance, richness, biomass)?
 │    └── ecological-data-foundation → biostatistics-workbench
 │         (GLM/GLMM, hypothesis testing, model selection)
 │
 ├── C2. Species × site matrix (multiple species, multiple sites)?
 │    └── ecological-data-foundation → community-ecology-ordination
 │         (NMDS, PCA, PCoA, diversity indices, PERMANOVA)
 │
 ├── C3. Before/after, control/impact sites (BACI)?
 │    └── ecological-data-foundation → ecological-impact-assessment
 │         → biostatistics-workbench → model-validation-and-uncertainty
 │
 ├── C4. Vital rates by age/stage class?
 │    └── biostatistics-workbench → population-viability-analysis
 │         (lambda, elasticity, stochastic PVA, IUCN Criterion E)
 │
 └── C5. Planning units + species features?
      └── species-distribution-modeling → spatial-prioritization
           (prioritizr/Marxan, representation targets, reserve design)
```

---

### Branch D — Time Series Data

```
D. Time series data
 ├── D1. Environmental signal (NDVI, temperature, rainfall)?
 │    └── ecological-data-foundation → environmental-time-series
 │         (Mann-Kendall trend, BFAST breakpoint, anomaly detection)
 │
 ├── D2. Biodiversity metric over time (species index, acoustic)?
 │    └── ecological-data-foundation → environmental-time-series
 │         → biostatistics-workbench (if inferential comparison needed)
 │
 └── D3. Fire risk or land cover change?
      └── Follow workflow: build-fire-risk-map or analyze-environmental-change
           (ecological-data-foundation → geoprocessing-for-ecology
            → ecological-impact-assessment → environmental-time-series)
```

---

### Branch E — Multimedia Data

```
E. Multimedia data
 ├── E1. Camera trap images?
 │    └── camera-trap-processing
 │         (detection events, diel activity, trap effort table)
 │         → occupancy-and-detection  (if occupancy estimation needed)
 │
 └── E2. Audio recordings (WAV/FLAC)?
      └── acoustic-monitoring
           (ACI/NDSI/ADI soundscape indices, BirdNET species detection)
           → environmental-time-series  (if temporal trend analysis needed)
```

---

### Branch F — Model Outputs

```
F. Model outputs
 ├── F1. Model fitted; need performance metrics?
 │    └── model-validation-and-uncertainty
 │         (AUC, TSS, RMSE, calibration, sensitivity, uncertainty maps)
 │
 ├── F2. Suitability maps; need conservation priorities?
 │    └── spatial-prioritization
 │         (planning units, targets, BLM, prioritizr/Marxan)
 │
 └── F3. Any outputs; need reproducibility checklist?
      └── reproducible-ecology-pipeline
           (parameter manifest, decision log, audit trail)
```

---

## Disambiguation Rules

Apply exactly one rule when two skills seem applicable.

### ecological-data-foundation vs. geoprocessing-for-ecology
- **ecological-data-foundation**: cleaning, deduplication, column validation, coordinate QA.
- **geoprocessing-for-ecology**: spatial operations on rasters/vectors (reproject, mask, stack, extract).
- If the task involves occurrence records AND spatial operations, run **ecological-data-foundation first**.

### predictive-modeling-best-practices vs. model-validation-and-uncertainty
- **predictive-modeling-best-practices**: BEFORE fitting — predictor selection, collinearity, CV design.
- **model-validation-and-uncertainty**: AFTER fitting — metrics, calibration, uncertainty quantification.
- Never reverse this order.

### species-distribution-modeling vs. occupancy-and-detection
- **species-distribution-modeling**: suitability surface from presence/absence + environmental predictors.
- **occupancy-and-detection**: occupancy probability (psi) + detection (p) from replicated visit data.

### ecological-impact-assessment vs. biostatistics-workbench
- **ecological-impact-assessment**: data with explicit before/after + control/impact structure (BACI), or landscape fragmentation metrics.
- **biostatistics-workbench**: statistical comparisons without BACI design.

### biostatistics-workbench vs. community-ecology-ordination
- **biostatistics-workbench**: one response variable, one or more predictors.
- **community-ecology-ordination**: species × site matrix as primary input (multivariate assemblage data).

---

## Minimum Records Quick Reference

| Analysis | Do NOT proceed below | Recommended |
|----------|----------------------|-------------|
| SDM (any algorithm) | 10 occurrences | >= 30 |
| Occupancy model | 15 sites | >= 30 sites, >= 3 visits |
| BACI mixed model | 5 control + 5 impact sites | >= 10 per group |
| Community ordination | 5 sites | >= 10 sites |
| GLM (single predictor) | 20 observations | >= 50 |
| Stochastic PVA | 5 years of count data | >= 10 years |
