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
