# Workflow: run-conservation-prioritization

**Purpose:** Identify priority areas for conservation using systematic planning tools (prioritizr/Marxan)
**Skills:** ecological-data-foundation → geoprocessing-for-ecology → species-distribution-modeling → spatial-prioritization → reproducible-ecology-pipeline

---

## Trigger

Invoke when the user wants to design a reserve network, identify priority areas for conservation, evaluate representation targets, or assess existing protected area coverage.

**Example prompts:**
- "Run a spatial prioritization for 50 species in the Atlantic Forest with 30% targets"
- "Design a reserve network using prioritizr to meet representation targets"
- "Evaluate which areas should be added to the protected area network for [region]"

---

## Steps

### Step 1 — ecological-data-foundation
- Validate species distribution data (rasters or occurrence records)
- Check planning unit layer (grid or irregular polygons)
- Validate cost layer and locked-in/locked-out constraint layers
- Output: `species_data_clean/`, `planning_units.shp`, `cost_layer.tif`, `qa_report.md`

### Step 2 — geoprocessing-for-ecology
- Reproject all layers to common equal-area CRS
- Align raster resolutions across species distributions and cost surface
- Clip to study area extent
- Rasterise planning units if needed
- Output: `planning_units_raster.tif`, `species_stack.tif`, `cost_aligned.tif`

### Step 3 — species-distribution-modeling (conditional)
- If species distributions are not yet available as rasters, fit SDMs
- Generate binary suitability maps for each species
- Stack all species distributions into a single raster stack
- Output: `species_binary_stack.tif`, `sdm_report.md`

### Step 4 — spatial-prioritization
- Define representation targets (e.g., 30% of each species' range)
- Set up minimum-set or maximum-coverage problem formulation
- Apply locked-in constraints (existing protected areas) and locked-out constraints
- Calibrate boundary length modifier (BLM) for spatial compactness
- Solve using ILP solver (HiGHS via prioritizr)
- Compute irreplaceability (selection frequency across near-optimal solutions)
- Run target sensitivity analysis (20%, 30%, 50%)
- Output: `solution_map.tif`, `representation_table.csv`, `irreplaceability_map.tif`, `blm_calibration.csv`, `sensitivity_report.md`

### Step 5 — reproducible-ecology-pipeline
- Document target justification and data sources
- Log solver parameters and BLM choice
- Record constraint rationale (locked-in/out areas)
- Output: `parameter_manifest.yaml`, `decision_log.md`, `reproducibility_checklist.md`

---

## Expected Deliverables

- Optimal reserve solution map
- Feature representation summary (% target met per species)
- Irreplaceability map (selection frequency)
- BLM calibration curve (cost vs boundary length)
- Target sensitivity analysis
- Cost efficiency summary
- Reproducibility package

---

## Minimum Data Requirements

- Distribution data (rasters or occurrence records) for >= 5 species/features
- Planning unit layer covering study area
- Cost layer (opportunity cost or area-based)
- Representation targets (default: 30% per feature)

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| Problem infeasible (no solution found) | Targets exceed available habitat | Reduce targets or expand study area; report which species are infeasible |
| > 50% of planning units selected | Targets too high or cost surface too uniform | Review target realism; consider log-linear targets scaled by range size |
| BLM calibration shows no elbow | Trade-off between cost and compactness is linear | Use BLM = 0 (no compactness penalty) and report fragmented solution; justify ecologically |
| Some species at 0% representation | Species range falls outside planning units or data gap | Add occurrence data or expand study area; flag unrepresented species |
| Locked-in areas already meet all targets | Existing protected areas are sufficient | Report as positive finding; analyse gap for underrepresented species |
| Irreplaceability > 0.9 for specific planning units | Critical areas with no substitutes | Flag as highest priority for immediate protection |
| Solution changes > 40% with +/- 10% target shift | High sensitivity to target choice | Report portfolio of solutions across target range; do not present single solution as definitive |
