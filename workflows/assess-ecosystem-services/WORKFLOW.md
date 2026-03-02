# Workflow: assess-ecosystem-services

**Purpose:** Quantify and map ecosystem services across a landscape  
**Skills:** ecological-data-foundation → geoprocessing-for-ecology → ecosystem-services-assessment → biostatistics-workbench → reproducible-ecology-pipeline

---

## Trigger

Invoke when the user wants to quantify, map, or compare ecosystem services across a study area.

**Example prompts:**
- "Map carbon storage, water regulation, and erosion control for the Atlantic Forest"
- "Assess trade-offs between timber production and carbon sequestration in [region]"
- "Quantify ecosystem service co-benefits of restoring [X ha] of native vegetation"

---

## Steps

### Step 1 — ecological-data-foundation
- Ingest land cover map, biomass data, soil data, and DEM
- Validate attribute tables and temporal alignment
- Output: `landcover_validated.tif`, `qa_report.md`

### Step 2 — geoprocessing-for-ecology
- Reproject and align all input layers to common CRS and resolution
- Clip to study area; compute watershed delineation if needed
- Output: `inputs_aligned/`, `watershed.gpkg`

### Step 3 — ecosystem-services-assessment
- Select ES portfolio relevant to the study context
- Compute biophysical indicators per service
- Aggregate by land cover class
- Run trade-off analysis (pairwise correlations)
- Output: `es_indicator_maps/`, `es_summary_table.csv`, `tradeoff_matrix.csv`

### Step 4 — biostatistics-workbench
- Test for significant differences in ES values between land cover classes
- Report effect sizes for pairwise comparisons
- Output: `es_stats_results.csv`, `effect_sizes.csv`

### Step 5 — reproducible-ecology-pipeline
- Document ES method choices and parameter sources
- Output: `parameter_manifest.yaml`, `es_report.md`

---

## Expected Deliverables

- ES indicator maps (one per service)
- ES summary table by land cover class
- Trade-off matrix and visualisation
- Statistical comparison of ES across classes

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| Land cover classification accuracy < 85% | Propagated classification error in ES estimates | Conduct uncertainty analysis using accuracy matrix; report ES ranges, not point estimates |
| ES trade-off correlation > 0.8 between two services | Possible confounding by same land cover class driving both | Partial out land cover effect; test whether trade-off holds within land cover classes |
| InVEST model output contains NoData in > 30% of area | Input layer misalignment (CRS, extent, or resolution mismatch) | Recheck CRS and extent of all inputs; use `terra::compareGeom()` to verify alignment |
| Monetary valuation requested but local market data unavailable | Benefit transfer required; high uncertainty | Apply benefit transfer with explicit unit value uncertainty (±50% range); flag limitation prominently |
| Provisioning and regulating services conflict across scenarios | Synergy/trade-off analysis needed | Use Pareto frontier visualisation; do not rank services without considering trade-offs |
| ES values identical across all land cover classes | Model insensitive to land cover differences | Check if land cover classes are aggregated too broadly; inspect model parameters for land-cover-specific values |
| Water yield model shows negative values | Model misconfiguration or negative ET correction | Verify PET inputs and calibration; check if precipitation minus AET is negative in any pixel |
