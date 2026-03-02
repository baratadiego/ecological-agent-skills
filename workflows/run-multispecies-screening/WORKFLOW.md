# Workflow: run-multispecies-screening

Multi-species SDM screening pipeline for rapid prioritisation of conservation targets.

---

## Trigger Phrases

- "screening de [N] espécies"
- "lista de espécies ameaçadas"
- "triagem de risco"
- "priorização de espécies para modelagem"
- "quais espécies têm área adequada reduzida"
- "screen [N] species for distribution modeling"

---

## Skills Used

`1 → 2 → 4 → 6 → 5`

| Step | Skill |
|---|---|
| Data download + cleaning | `ecological-data-foundation` (skill 1) |
| Spatial operations | `geoprocessing-for-ecology` (skill 2) |
| Modeling best practices | `predictive-modeling-best-practices` (skill 4) |
| SDM | `species-distribution-modeling` (skill 6) |
| Validation | `model-validation-and-uncertainty` (skill 5) |

---

## Inputs

| Input | Format | Required | Description |
|---|---|---|---|
| `species_list.csv` | CSV with column `scientificName` | Yes | List of species to screen |
| `predictor_stack.tif` | Multi-band GeoTIFF | Yes | Environmental predictor layers |
| `study_area.shp` | Shapefile / GeoJSON | Yes | Geographic extent for projections |
| `n_min_occurrences` | Integer (default: 30) | No | Minimum cleaned records required |
| `auc_threshold` | Numeric 0–1 (default: 0.75) | No | Minimum AUC for "adequate model" |
| `suitable_area_threshold_km2` | Numeric (default: 50000) | No | Area below which species flagged as high priority |

---

## Pipeline — Loop per Species

For each `scientificName` in `species_list.csv`:

### Step 1 — Download + Cleaning
**Skill:** `ecological-data-foundation`

- Download occurrences from GBIF using `download_from_gbif.R` or `.py`
- Apply standard cleaning: coordinate flags, duplicates, spatial thinning (1 grid cell)
- Record `n_raw` and `n_clean`

### Step 2 — Data Sufficiency Check

```
IF n_clean < n_min_occurrences:
    → flag species as "dados_insuficientes" = TRUE
    → write row to screening_summary.csv with flag
    → SKIP to next species
```

### Step 3 — Quick Calibration
**Skill:** `species-distribution-modeling`

- Use fixed quick-calibration settings: RM = 1, FC = "LQ"
- Run `sdm_pipeline.py` or `run_ensemble_sdm.R` with these parameters
- No full ENMeval grid search (reserved for high-priority species in full `run-sdm-study`)

### Step 4 — Minimum Validation
**Skill:** `model-validation-and-uncertainty`

- Calculate AUC (random 20% hold-out) and TSS
- Run `validate_model.py` or `validate_sdm.R`
- Flag model as `model_adequate = AUC >= auc_threshold`

### Step 5 — Extrapolation Risk Check

- Run `extrapolation_risk.R` comparing training stack vs. full study area projection
- Record `pct_mop_zero` (% area with MOP = 0) and `pct_mop_low` (% area with MOP < 0.25)
- Flag `severe_extrapolation = pct_mop_zero > 0.40`

---

## Per-Species Outputs

All written to `output/{scientificName}/`:

| File | Description |
|---|---|
| `suitability_current.tif` | Continuous suitability map (0–1) |
| `binary_map.tif` | Binary presence/absence map (threshold = max TSS) |
| `metrics.csv` | AUC, TSS, n_clean, suitable_area_km2, pct_mop_zero |
| `mop_layer.tif` | MOP extrapolation layer |

---

## Consolidated Output

**File:** `output/screening_summary.csv`

| Column | Description |
|---|---|
| `scientificName` | Species name |
| `n_raw` | Records before cleaning |
| `n_clean` | Records after cleaning + thinning |
| `dados_insuficientes` | TRUE if n_clean < n_min |
| `AUC` | Model AUC (hold-out) |
| `TSS` | Model TSS |
| `suitable_area_km2` | Current suitable area (binary map) |
| `pct_mop_zero` | % projection area with MOP = 0 |
| `severe_extrapolation` | TRUE if pct_mop_zero > 0.40 |
| `model_adequate` | TRUE if AUC >= auc_threshold |
| `priority` | Alta / Média / Baixa (see criteria below) |

---

## Priority Classification Criteria

```
Alta priority:
  suitable_area_km2 < suitable_area_threshold_km2
  AND AUC >= auc_threshold
  AND dados_insuficientes == FALSE
  AND severe_extrapolation == FALSE

Média priority:
  (suitable_area_km2 >= suitable_area_threshold_km2 AND AUC >= auc_threshold)
  OR severe_extrapolation == TRUE (model adequate but extrapolation concern)

Baixa priority:
  AUC < auc_threshold (model unreliable)
  OR dados_insuficientes == TRUE
```

Species flagged `dados_insuficientes` or with `AUC < auc_threshold` should NOT be
ranked by area — insufficient basis for reliable prioritisation.

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| AUC < 0.70 | Model has no predictive power | Revise predictor set; do not include in priority ranking |
| n_clean < 30 after thinning | Insufficient data for reliable SDM | Classify as "dados_insuficientes"; supplement with field surveys |
| MOP = 0 in > 40% of projected area | Severe extrapolation | Flag as `severe_extrapolation`; restrict interpretation to calibration area |
| > 50% of range in a single biome | Biome-specific background needed | Re-run with biome-restricted background for that species |
| All species in list return AUC < 0.70 | Wrong predictor set or data quality issue | Check coordinate cleaning, CRS alignment, and predictor resolution |
| n species with Alta priority = 0 | Thresholds too strict or genuinely no high-priority species | Adjust `suitable_area_threshold_km2` and document rationale |

---

## Parallelisation Note

For lists of N > 10 species, use `future` for parallel processing:

```r
library(future)
library(furrr)

# Use all available cores (or set workers = N explicitly)
plan(multisession, workers = parallel::detectCores() - 1)

results <- future_map(species_list, run_single_species_screen,
                      .options = furrr_options(seed = 42))
```

For Python equivalents, use `concurrent.futures.ProcessPoolExecutor`.

---

## Deliverables

| Deliverable | Format | Description |
|---|---|---|
| `screening_summary.csv` | CSV | Master table with all species metrics and priority flags |
| `suitability_current.tif` | GeoTIFF (per species) | Continuous suitability map |
| `binary_map.tif` | GeoTIFF (per species) | Binary presence/absence |
| `mop_layer.tif` | GeoTIFF (per species) | Extrapolation risk layer |
| `metrics.csv` | CSV (per species) | Individual species metrics |
| `screening_report.md` | Markdown | Auto-generated summary with priority lists |

---

## Notes

- This workflow is designed for **rapid screening**, not publication-quality SDMs.
  High-priority species identified here should be modelled in full using `run-sdm-study`.
- The quick calibration (RM=1, FC=LQ) will generally produce slightly over-fitted
  models compared to full ENMeval calibration. This is acceptable for screening
  purposes but must not be used for conservation planning directly.
- Always document `n_min_occurrences` and `auc_threshold` used in the screening in
  the project's `params.yaml`.
- Record the GBIF download DOIs for each species in `data_provenance.md`.
