# Workflow: analyze-environmental-change

**Purpose:** Detect and characterise long-term environmental change from remote sensing or monitoring data  
**Skills:** ecological-data-foundation → geoprocessing-for-ecology → environmental-time-series → ecological-impact-assessment → reproducible-ecology-pipeline

---

## Trigger

Invoke when the user wants to analyse temporal trends in environmental conditions (NDVI, land cover, temperature, rainfall, deforestation) over years to decades.

**Example prompts:**
- "Analyse NDVI trends in the Pantanal over the last 20 years"
- "Detect breakpoints in forest cover loss in the Brazilian Amazon"
- "Characterise vegetation recovery after the 2019-2020 fires"

---

## Steps

### Step 1 — ecological-data-foundation
- Ingest time series data (satellite-derived or monitoring station)
- Validate temporal consistency, units, and metadata
- Output: `timeseries_clean.csv` or raster stack

### Step 2 — geoprocessing-for-ecology
- Reproject and align raster time stack
- Extract series for specific zones or polygons
- Create cloud-masked composites (if satellite data)
- Output: `timeseries_stack.tif`, `zone_extracts.csv`

### Step 3 — environmental-time-series
- STL decomposition (trend + seasonal + remainder)
- Mann-Kendall trend test + Sen's slope (pixel-wise or site-wise)
- BFAST breakpoint detection
- Standardised anomaly computation
- Recovery trajectory (if post-disturbance)
- Output: `trend_results.csv`, `breakpoints.csv`, `anomaly_series.csv`, `recovery_metrics.csv`

### Step 4 — ecological-impact-assessment
- Classify trend magnitude: significant improvement / stable / significant degradation
- Identify spatial hotspots of change
- Overlay with land cover, protected areas, and pressure layers
- Synthesise drivers of observed change
- Output: `change_classification.tif`, `impact_synthesis.md`

### Step 5 — reproducible-ecology-pipeline
- Document baseline period, decomposition parameters, breakpoint thresholds
- Output: `parameter_manifest.yaml`, `decision_log.md`

---

## Expected Deliverables

- Trend map (slope and significance per pixel)
- Breakpoint map (date and magnitude)
- Anomaly time series
- Change classification map
- Recovery metrics (if applicable)

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| Mann-Kendall tau < 0.1 despite visual trend | Trend masked by high inter-annual variance | Apply pre-whitening (remove autocorrelation before MK test); report Sen's slope with 95% CI instead of tau alone |
| BFAST detects > 5 breakpoints | Oversegmentation of time series | Increase `h` parameter (minimum segment length as fraction of series); inspect breakpoints for plausibility |
| Time series < 10 years | Insufficient length for reliable trend detection | Report descriptive statistics (mean, SD, range) only; state limitation; do not report Mann-Kendall as significant |
| Missing data > 20% in any season | Seasonal decomposition unreliable | Impute with STL or linear interpolation before decomposition; document imputation in methods |
| Breakpoint coincides with sensor change or data gap | Artefact, not ecological signal | Verify against independent data source (e.g., Landsat vs MODIS comparison); exclude artefact breakpoints |
| STL trend component shows oscillation at period equal to satellite revisit | Orbital artefact leaking into trend | Apply Fourier pre-filtering; use MODIS 16-day composites instead of 8-day |
| Recovery rate > 100% (NDVI exceeds pre-disturbance level) | Regrowth exceeds baseline; possible change in land use | Verify with high-resolution imagery; investigate if secondary vegetation is replacing degraded pasture |
