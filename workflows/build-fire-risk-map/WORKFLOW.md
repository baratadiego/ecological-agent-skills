# Workflow: build-fire-risk-map

**Purpose:** Produce a spatial fire risk map integrating historical fire data, vegetation, climate, and terrain  
**Skills:** ecological-data-foundation → geoprocessing-for-ecology → environmental-time-series → predictive-modeling-best-practices → model-validation-and-uncertainty → ecological-impact-assessment

---

## Trigger

Invoke when the user wants to map fire risk or fire susceptibility for a landscape.

**Example prompts:**
- "Build a fire risk map for the Cerrado"
- "Map fire susceptibility integrating NDVI trends, rainfall anomalies, and land use"
- "Predict which areas are most likely to burn in the next dry season"

---

## Steps

### Step 1 — ecological-data-foundation
- Ingest fire occurrence data (INPE BDQueimadas, MODIS burned area, VIIRS)
- Validate dates, coordinates, and confidence levels
- Filter to high-confidence fire pixels
- Output: `fire_records_clean.csv`, `qa_report.md`

### Step 2 — geoprocessing-for-ecology
- Reproject all layers to project CRS (UTM)
- Align terrain (DEM, slope, aspect), land cover, and climate rasters to common grid
- Compute distance to roads, edge density, and proximity to fire ignitions
- Output: `predictors_stack.tif`, `spatial_qa_report.md`

### Step 3 — environmental-time-series
- Compute NDVI trend and anomalies (vegetation dryness proxy)
- Compute rainfall SPI (drought index)
- Detect fire frequency per pixel from historical MODIS record
- Output: `ndvi_trend.tif`, `spi_anomaly.tif`, `fire_frequency.tif`

### Step 4 — predictive-modeling-best-practices
- Assess collinearity of all predictor candidates
- Define spatial CV strategy (buffered k-fold)
- Tune BRT and Random Forest hyperparameters
- Output: `cv_strategy.md`, `selected_predictors.txt`, `tuning_results.csv`

### Step 5 — model-validation-and-uncertainty
- Compute AUC-ROC, TSS, and Brier score on spatial CV folds
- Calibrate predicted probabilities
- Map ensemble uncertainty (SD across algorithms)
- Output: `performance_metrics.csv`, `fire_risk_uncertainty.tif`, `validation_report.md`

### Step 6 — ecological-impact-assessment
- Classify risk zones: low / moderate / high / very high
- Compute area and proportion in each risk class per land cover type
- Overlay with infrastructure and protected area boundaries
- Output: `fire_risk_map.tif`, `risk_by_landcover.csv`, `impact_synthesis.md`

---

## Expected Deliverables

- Continuous fire risk probability map
- Classified risk zone map (4 classes)
- Model performance table
- Risk summary by land cover class
- Uncertainty map
