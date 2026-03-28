# Workflow: assess-landscape-connectivity

**Purpose:** Assess habitat connectivity for a focal species using resistance surfaces and graph-theoretic metrics
**Skills:** ecological-data-foundation → geoprocessing-for-ecology → landscape-connectivity → model-validation-and-uncertainty → reproducible-ecology-pipeline

---

## Trigger

Invoke when the user wants to evaluate landscape connectivity, identify wildlife corridors, rank habitat patches by importance, or detect connectivity pinchpoints.

**Example prompts:**
- "Assess connectivity for jaguars across the Mesoamerican Biological Corridor"
- "Build a resistance surface and identify corridor pinchpoints for [species]"
- "Rank habitat patches by connectivity importance using IIC and dPC"

---

## Steps

### Step 1 — ecological-data-foundation
- Validate habitat patch layer (polygon or raster)
- Verify land cover classification and reclassification table
- Check dispersal distance estimate (literature or telemetry-based)
- Output: `patches_clean.shp`, `landcover_validated.tif`, `dispersal_params.csv`

### Step 2 — geoprocessing-for-ecology
- Reproject all layers to equal-area CRS
- Clip land cover and ancillary layers (slope, roads, rivers) to study area
- Compute patch area, centroid coordinates, and pairwise Euclidean distances
- Output: `patches_projected.shp`, `landcover_clipped.tif`, `patch_distances.csv`

### Step 3 — landscape-connectivity
- Build resistance surface from land cover reclassification (+ optional slope, road proximity)
- Compute pairwise least-cost distances between patches
- Calculate graph-theoretic metrics: IIC, PC, dIIC, dPC, betweenness centrality
- Rank patches by contribution to overall connectivity
- Run Circuitscape (if available) for current flow and pinchpoint detection
- Output: `resistance_surface.tif`, `connectivity_metrics.csv`, `patch_importance.csv`, `pinchpoint_map.tif`

### Step 4 — model-validation-and-uncertainty
- Sensitivity analysis: vary resistance values +/- 50% for top 3 land cover classes
- Compare patch rankings across resistance scenarios
- Assess sensitivity to dispersal distance threshold
- Output: `sensitivity_report.md`, `scenario_comparison.csv`

### Step 5 — reproducible-ecology-pipeline
- Document resistance value sources and justification
- Log dispersal distance estimate and source
- Record Circuitscape parameters and software versions
- Output: `parameter_manifest.yaml`, `decision_log.md`, `reproducibility_checklist.md`

---

## Expected Deliverables

- Resistance surface map
- Patch importance ranking (IIC, dPC, betweenness)
- Connectivity graph visualisation
- Pinchpoint map (current flow)
- Sensitivity analysis across resistance scenarios
- Reproducibility package

---

## Minimum Data Requirements

- Habitat patch layer with >= 5 patches
- Land cover raster covering study area
- Resistance reclassification table (land cover class -> resistance value)
- Dispersal distance estimate for focal species (meters)

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| IIC or PC = 0 | All patches are isolated beyond dispersal threshold | Increase dispersal threshold or verify it against telemetry data; report fragmentation severity |
| Single patch dominates dPC (> 80%) | Connectivity depends on one critical patch | Flag as conservation priority; run removal scenario to quantify impact |
| Resistance values lack empirical basis | Expert opinion only, no telemetry validation | Report as expert-based; run sensitivity analysis across plausible ranges |
| Circuitscape fails to converge | Grid too large or resistance contrast too high | Reduce resolution or aggregate land cover classes; check for zero-resistance barriers |
| Patch ranking changes > 30% across scenarios | High sensitivity to resistance parameterisation | Report full scenario range; do not present single-scenario ranking as definitive |
| Dispersal distance estimate varies > 2x in literature | Uncertain movement capacity | Run analysis at low, medium, and high estimates; report range of connectivity outcomes |
