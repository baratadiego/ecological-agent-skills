# Changelog

All notable changes to this repository are documented here.
Format: [version] — date — description

## [Unreleased]

---

## [3.1.0] — 2026-03-28 — License migration, citation metadata, and catalog update

### Changed
- **LICENSE** — Replaced MIT license with GNU General Public License v3.0. The change aligns the repository license with GPL-licensed R dependencies used throughout the library (vegan, lme4, ggplot2, terra, prioritizr).
- All `.R` and `.py` scripts now carry SPDX `GPL-3.0-or-later` headers.
- `README.md` — Updated skill count (12 → 17), workflow count (8 → 9); added `run-multispecies-screening` to workflow table; corrected repository structure diagram; updated Phase 4 skill links in workflows table.
- `CONTRIBUTING.md` — Added GPL compatibility note for contributors.
- `environment.yaml` — Added license field.
- `CATALOG.md` — Added Phase 4 skills (13-17) to index table, Skill Details section, and Workflow × Skill Matrix (expanded to 17 columns).

### Added
- `CITATION.cff` — Machine-readable citation metadata (CFF v1.2.0).

---

## [3.0.0] — 2026-03-06 — Quality infrastructure and release process (all 6 phases complete)

### Added — Test Infrastructure
- `tests/regression/` — Regression test framework: `run_regression_tests.sh` (CSV/JSON/PNG comparison with tolerances), `update_references.sh` (--confirm-update safety gate), `REFERENCE_LOG.md`
- `tests/agent_smoke/smoke_test_cases.json` — 15 agent routing validation cases covering SDM, occupancy, community, impact, time series, prioritization, edge cases, and decision points
- `tests/agent_smoke/README.md` — Human validation protocol for smoke tests

### Added — CI Expansion (tests/ci_check.sh)
- Section 10: Global geographic coverage — verifies all 6 inhabited continents have examples
- Section 11: Example quality — checks data source documentation, species/system metadata, numeric results
- Section 12: Resource quality — checks for structured content (code blocks, tables, or checklists)
- Section 13: Script logging — verifies `log_` usage in R and `logging.` in Python scripts
- Section 14: Error handling — verifies `tryCatch` in R and `except` in Python scripts
- Section 15: Version consistency — checks skill_version field in all SKILL.md files
- Expanded CI report with date, version, script/example/resource counts, continent coverage

### Added — Release & Versioning
- `RELEASE_CHECKLIST.md` — Pre-release, release, and post-release checklist
- `KNOWN_ISSUES.md` — 3 known issues: blockCV with geographic CRS, ENMeval/terra compatibility, camtrapR Windows paths
- `docs/repository-statistics.md` — Complete content inventory: 17 skills, 9 workflows, 58 scripts, 14 examples, 53 resources, 585 CI checks

### Changed
- `CONTRIBUTING.md` — Added "Release Process" section
- `tests/ci_check.sh` — Expanded from 354 to 585 checks across 15 sections

## [2.3.0] — 2026-03-06 — Scientific documentation & global example coverage

### Added — Documentation
- `docs/theoretical-foundations.md` — Citable justifications for 10 methodological decisions (spatial CV, ensemble, partial ROC, calibration area, Bray-Curtis, MESH, IIC/PC, OR10, RM calibration, BACI random effects), with 17 primary references and consolidated bibliography
- `docs/global-examples-index.md` — Full inventory of 14 worked examples with geographic/taxonomic/thematic coverage analysis; all 6 inhabited continents represented
- `docs/comparison-with-alternatives.md` — Objective comparison vs. Wallace, SDMtoolbox, biomod2, kuenm, ENMTML, Zonation, Vortex across 12 criteria; includes honest limitations section

### Added — Global Examples (7 new, 14 total)
- `examples/sdm/wolf_recolonization_europe_example.md` — Grey wolf SDM + recolonization projection + livestock conflict analysis (Europe)
- `examples/sdm/koala_climate_change_example.md` — Koala SDM + SSP2-4.5 / SSP5-8.5 projection + MOP extrapolation (Australia)
- `examples/community/reef_fish_indopacific_example.md` — Reef fish beta diversity + depth gradient + PERMANOVA (Indo-Pacific)
- `examples/community/arctic_tundra_vegetation_example.md` — NDVI greening time series + BFAST + community shift (Arctic)
- `examples/occupancy/snow_leopard_himalayas_example.md` — Snow leopard single-season occupancy + camera trap detection (Himalayas)
- `examples/impact/forest_loss_borneo_timeseries_example.md` — BFAST + MESH fragmentation + BACI for oil palm expansion (Borneo)
- `examples/reproducible/whittaker_biome_sdm_example.md` — Fully reproducible red fox SDM with complete R code (Holarctic)

### Changed
- `README.md` — Added Documentation section linking to docs/ and Examples table with 14 entries
- `CATALOG.md` — Added Documentation (v2.3.0) and New Examples (v2.3.0) sections

---

## [2.2.0] — 2026-03-05 — Global occurrence download scripts and predictor data sources

### Added — Occurrence download scripts (Entregável 1)
Eight new scripts across four biodiversity data sources, each producing the **standard output schema**:
`species, decimalLatitude, decimalLongitude, eventDate, countryCode, basisOfRecord, coordinateUncertaintyInMeters, datasetName, occurrenceID, source, download_doi`

- **`skills/ecological-data-foundation/scripts/download_from_inat.R`** — rinat, quality_grade filter, captive=FALSE, year range, max 10 000 records
- **`skills/ecological-data-foundation/scripts/download_from_inat.py`** — pyinaturalist, auto-pagination, same schema + research-grade validation
- **`skills/ecological-data-foundation/scripts/download_from_ebird.R`** — auk EBD parser, Stationary+Traveling protocols, approved=TRUE; extra: `effort_distance_km, duration_minutes, observer_id`
- **`skills/ecological-data-foundation/scripts/download_from_ebird.py`** — pandas chunked EBD reader (500 k rows/chunk), same filters and schema
- **`skills/ecological-data-foundation/scripts/download_from_obis.R`** — robis, absence=FALSE, OBIS quality flags applied; extra: `depth, marine`
- **`skills/ecological-data-foundation/scripts/download_from_obis.py`** — requests OBIS REST API v3, pagination, same flags and schema
- **`skills/ecological-data-foundation/scripts/download_from_iucn.R`** — rredlist + IUCN API v3 (IUCN_REDLIST_KEY), country occurrences + habitats; extra: `rl_category, rl_criteria, population_trend, assessment_year`
- **`skills/ecological-data-foundation/scripts/download_from_iucn.py`** — requests IUCN API v3, same assessment data and schema

All scripts: globally generic (no hardcoded regions/taxa), inline logger, tryCatch/try-except error handling.

### Added — Global predictor data sources (Entregável 2)
- **`skills/geoprocessing-for-ecology/resources/global-predictor-sources.md`** — Reference table for 12 global data sources (WorldClim, CHELSA, TerraClimate, ERA5-Land, MODIS, Copernicus LC, SoilGrids, MERIT DEM, HydroSHEDS, GFW, ESA CCI LC, Human Footprint) with download code, resolution, DOI, and SDM guidance per source
- **`skills/geoprocessing-for-ecology/scripts/download_predictors.R`** — WorldClim v2.1 (geodata), CHELSA v2.1 (direct URL), MODIS placeholder; optional WKT clipping; outputs `predictor_metadata.csv`
- **`skills/geoprocessing-for-ecology/scripts/download_predictors.py`** — requests (WorldClim zip + CHELSA tiles), cdsapi (ERA5-Land), pystac placeholder; optional rasterio clipping; same metadata CSV

### Added — Data citation guide (Entregável 3)
- **`skills/ecological-data-foundation/resources/data-citation-guide.md`** — Citation formats for GBIF, iNaturalist, eBird, OBIS, IUCN, WorldClim/CHELSA; `occ_search` vs `occ_download` comparison table; CC licence compatibility matrix; data use policies; merge workflow

### Updated — Dependency files
- **`environment.yaml`**: Added `r-rgbif=3.7.9`, `r-geodata=0.6_2`, `requests=2.32.3`; pip: `pygbif==0.6.3`, `pyinaturalist==0.19.0`, `cdsapi==0.7.2`, `pystac-client==0.8.3`, `stackstac==0.5.1`, `planetary-computer==1.0.0`
- **`renv.lock`**: Added rinat, auk, robis, rredlist, geodata (R packages managed via renv)
- **`skills/SKILL_INDEX.json`**: Extended `primary_outputs` for `ecological-data-foundation` and `geoprocessing-for-ecology`; added 8 new trigger keywords for occurrence download

### Added — Tests
- **`tests/r/test-download-sources.R`** — 28 testthat tests: schema validation, coordinate filtering, OBIS quality flags, source column values, script file existence, Usage: line-1 compliance, suppressPackageStartupMessages, inline logger presence, resource file existence
- **`tests/python/test_download_sources.py`** — 23 pytest tests: iNat/OBIS/IUCN/eBird standardise_records schema, OBIS quality flags, eBird EBD parsing, metadata write functions, predictor URL format, SHA256 helper, save_metadata CSV

### CI
- All existing tests pass (334+ tests); new tests add schema + argument validation coverage with zero live API calls

---

## [2.1.0] — 2026-03-03 — Script quality: logging, error handling, new SDM and BACI scripts

### Added — Logging infrastructure
- **`templates/scripts/logger_setup.R`** — Reusable R logger template using futile.logger with dual console+file output, `log_step()`, `log_decision()`, `log_actionable_error()` wrappers
- **`templates/scripts/logger_setup.py`** — Python equivalent with `logging.basicConfig`, file rotation, same helper functions

### Added — Inline logger in ALL 43 skill scripts
Every script in `skills/*/scripts/` now contains an inline logger block (no external dependency) providing:
- `log_info()` / `log_warn()` / `log_error()` with ISO timestamp prefix
- `log_step(N, description)` to mark major processing stages
- `log_decision(variable, value, rationale)` to document analytical choices
- `dir.create("logs", ...)` auto-creates the log directory
- Log format: `[YYYY-MM-DD HH:MM:SS] [LEVEL]  message`

### Added — Actionable error handling in ALL 43 skill scripts
Every `tryCatch` / `try-except` block now emits a structured four-field error:
1. Failing step name
2. Probable cause
3. What to verify
4. Which upstream skill should have produced the missing input

Every script now validates all inputs before processing begins with `file.exists()` / `Path.exists()` guards.

### Added — SDM spatial prediction (Deliverable 3)
- **`skills/species-distribution-modeling/scripts/predict_distribution.R`**
  - Loads maxnet / gbm / randomForest / ensemble list models
  - Generates suitability [0,1], binary (MaxTSS/P10/MTP), uncertainty (ensemble SD), and MESS rasters
  - Warns if > 20% of area is in novel climate space
  - Outputs: `suitability_{scenario}.tif`, `binary_{scenario}.tif`, `uncertainty_{scenario}.tif`, `mess_{scenario}.tif`, `prediction_summary.csv`
- **`skills/species-distribution-modeling/scripts/predict_distribution.py`**
  - Sklearn equivalent: supports `predict_proba`, `decision_function`, and generic `predict`
  - Same outputs as R version; MESS computed from `training_ranges` stored in model dict
- **`skills/species-distribution-modeling/scripts/project_scenarios.R`**
  - Batch projection across all `.tif` stacks in `scenarios_dir` (SSP × year loop)
  - Auto-names outputs: `suitability_{ssp}_{year}.tif`
  - Outputs: `scenario_comparison.csv`, `scenario_change_map.tif`, `scenario_summary_plot.png`

### Added — BACI power analysis (Deliverable 4)
- **`skills/ecological-impact-assessment/scripts/power_analysis_baci.R`**
  - Three power curves: power × n_sites, power × n_surveys, power × effect_size
  - Minimum n for 80% and 90% power (searched over sites and surveys independently)
  - Outputs: `power_curves.png`, `power_summary.csv`, `minimum_n_recommendation.md`
  - Depends on: `pwr`, `ggplot2`, `patchwork`
- **`skills/ecological-impact-assessment/resources/study-design-guide.md`**
  - Recommended sites per group (≥5:5), surveys (≥3 before + 3 after)
  - Control site matching criteria and propensity-score matching example
  - Survey interval guidance by taxon, variance estimation methods
  - Effect size reference table by impact type (roads, dams, deforestation, mining, etc.)

### Added — Tests
- **`tests/r/test-logging-and-errors.R`** — 14 testthat tests covering:
  logger format, log_step/log_decision output, precondition check behaviour,
  predict_distribution binary map and MESS logic, power analysis monotonicity and plausible range,
  project_scenarios filename parsing and change map formula
- **`tests/python/test_logging_and_errors.py`** — 14 pytest tests covering the same areas

### Changed — CONTRIBUTING.md
- Versioning section expanded with per-skill `skill_version` policy (Patch/Minor/Major rules table)
- New "Logging Standards (v2.1.0+)" section documenting the mandatory inline logger pattern,
  log_step/log_decision conventions, and precondition check templates for R and Python

### Verified — skill_version
- All 17 SKILL.md files confirmed to have `skill_version: "1.0.0"` in YAML front-matter

---

## [2.0.0] — 2026-03-02 — Five advanced skills (Phase 2)

### Added — New skills (5)

- **`skills/camera-trap-processing/`** — Camera trap data pipeline:
  - `process_camtrap_data.R`: camtrapR record table, detection history, trap effort
  - `estimate_activity.R`: diel activity curves, Dhat4 bootstrap CI, circular statistics
  - `process_camtrap_data.py`: pure Python CSV summary and timeline
  - 3 resources: independence threshold guide, camtrapR workflow, activity patterns
  - 2 examples: 5 prompt scenarios + Leopard Serengeti full walkthrough

- **`skills/acoustic-monitoring/`** — Passive acoustic monitoring:
  - `compute_acoustic_indices.R`: ACI, BI, NDSI, H, ADI, AEI via soundecology + heatmap
  - `batch_species_detection.py`: BirdNET batch detection, confidence filtering, accumulation
  - `compute_acoustic_indices.py`: Python ACI/BI/NDSI/H from scratch via librosa
  - 3 resources: index reference, species-ID tools comparison, soundscape ecology guide
  - 2 examples: 5 prompt scenarios + Temperate Forest Birds full walkthrough

- **`skills/landscape-connectivity/`** — Graph-based connectivity metrics:
  - `connectivity_metrics.R`: IIC, PC, dIIC, dPC, betweenness centrality, network plot
  - `resistance_surface.R`: LC reclassification + slope + road-proximity resistance
  - `connectivity_analysis.py`: networkx IIC/PC/dPC, pairwise costs, matplotlib plot
  - 3 resources: graph theory guide, resistance surface guide, Circuitscape parameters
  - 2 examples: 5 prompt scenarios + Jaguar Mesoamerica Corridor full walkthrough

- **`skills/population-viability-analysis/`** — Matrix PVA and IUCN Criterion E:
  - `matrix_pva.R`: λ, sensitivity, elasticity heatmap, deterministic projection
  - `stochastic_pva.R`: Monte Carlo PVA, Beta/Lognormal draws, extinction curve, IUCN categories
  - `pva_analysis.py`: Python λ/sensitivity/elasticity + stochastic PVA
  - 3 resources: matrix model guide, extinction thresholds, sensitivity/elasticity reference
  - 2 examples: 5 prompt scenarios + African Elephant PVA full walkthrough

- **`skills/spatial-prioritization/`** — Systematic conservation prioritization:
  - `run_prioritization.R`: prioritizr min-set/max-coverage ILP, HiGHS solver, irreplaceability
  - `prioritization_sensitivity.R`: BLM calibration, target/cost sensitivity, portfolio frequency
  - 4 resources: prioritizr formulation, Marxan vs prioritizr, cost surface, representation targets
  - 2 examples: 5 prompt scenarios + Atlantic Forest 85-species full walkthrough

### Changed

- **`skills/SKILL_INDEX.json`**: Extended from 12 to 17 skills (added 5 new entries with
  trigger_keywords, min_inputs, primary_outputs, decision_points)
- **`CATALOG.md`**: Added "Advanced Skills (v2.0.0)" section documenting all files in 5 new skills
- **`README.md`**: Added 5-row "Advanced Skills" table; updated Implementation Roadmap with Phase 4
- **`renv.lock`**: Added camtrapR, overlap, soundecology, popbio, prioritizr, highs, igraph
- **`environment.yaml`**: Added librosa, soundfile, networkx, scikit-image
- **`tests/r/`**: Added 5 new testthat test files (≥3 tests each)
- **`tests/python/`**: Added 5 new pytest test files (≥3 tests each)

---

## [1.2.0] — 2026-03-01 — Agent navigation infrastructure (Phase 1)

### Added — Agent infrastructure

- **`AGENT_CONTEXT.md`** (root) — Primary entry-point document for AI agents.
  Written for LLM consumption. Contains: canonical skill invocation order by
  project type, disambiguation rules for overlapping skills, minimum sample-size
  table, scaling rules (simple → medium → complex projects), file and output
  naming conventions, and decision_log.md format.

- **`skills/SKILL_INDEX.json`** — Machine-readable index of all 12 skills.
  Each entry includes: `skill_id`, `display_name`, `version`, `domain`,
  `trigger_keywords`, `min_inputs`, `primary_outputs`, `depends_on_skills`,
  `called_by_workflows`, `decision_points`, and `skill_md_path`.
  Validated with `python -m json.tool`. Includes `_metadata` block.

- **`templates/SKILL_TEMPLATE.md`** — Blank template for new skills.
  Contains all mandatory SKILL.md sections with HTML comment guidance,
  `[OBRIGATÓRIO]` placeholders, and a pre-submission validation checklist.

- **`tests/ci_check.sh`** — Bash CI script for repository structural integrity.
  Checks: required root files, skill directory completeness, workflow presence,
  file size (no empty files), R/Python script quality standards,
  SKILL.md section coverage, SKILL_INDEX.json consistency, test coverage.
  Exit code 0 = all pass, 1 = any failure. Prints PASS/FAIL per check.

### Updated — All 12 SKILL.md files

- Added `skill_version: 1.0.0` YAML front-matter header to all 12 skill files:
  `biostatistics-workbench`, `community-ecology-ordination`,
  `ecological-data-foundation`, `ecological-impact-assessment`,
  `ecosystem-services-assessment`, `environmental-time-series`,
  `geoprocessing-for-ecology`, `model-validation-and-uncertainty`,
  `occupancy-and-detection`, `predictive-modeling-best-practices`,
  `reproducible-ecology-pipeline`, `species-distribution-modeling`.

### Updated — README.md

- Added **"For AI Agents"** section with links to `AGENT_CONTEXT.md`
  and `skills/SKILL_INDEX.json`.

---

## [1.1.0] — 2026-03-01 — Project rename + SDM expansion + Decision Points

### Breaking change
- **Project renamed** from `antigravity-eco-skills` to `ecological-agent-skills`.
  All internal references, file headers, and `environment.yaml` updated.
  The repository is now self-contained under the new name.

### Added — New resources

**skills/species-distribution-modeling:**
- `resources/maxent-calibration-guide.md` — Complete MaxEnt calibration reference:
  RM × FC effects, OR_AICc selection criterion, 35-model calibration grid,
  kuenm vs ENMeval comparison table, result interpretation, common pitfalls.
  References: Peterson et al. 2008, Warren & Seifert 2011, Kass et al. 2021.
- `resources/climate-scenario-preparation.md` — Future climate layer pipeline:
  CHELSA-Future, WorldClim, CMIP6 source comparison; SSP guide (SSP1-2.6 to SSP5-8.5);
  mandatory 5-step preparation pipeline with `terra::compareGeom()` verification.
- `scripts/tune_maxnet.R` — ENMeval grid search script: 35-model calibration,
  spatial block CV, OR_AICc selection, outputs calibration_results.csv,
  best_model_params.csv, calibration_plot.png, best_maxnet.rds.
- `scripts/prepare_future_layers.R` — Future layer preparation: reproject, crop/mask,
  resample, compareGeom, layer-name verification, clear error messages on failure.

**skills/predictive-modeling-best-practices:**
- `resources/sampling-bias-correction.md` — Sampling bias detection and correction:
  KDE bias map, KS environmental test, target-group background, kernel density
  weighting (MASS::kde2d), environmental filtering in PC space, decision table,
  ODMAP O4 reporting template. References: Phillips et al. 2009, Fourcade et al. 2014.

**skills/model-validation-and-uncertainty:**
- `resources/extrapolation-risk-guide.md` — MOP, ExDet (NT1/NT2), MESS comparison:
  concern thresholds, publication masking protocol, R implementations.
  References: Owens et al. 2013, Mesgaran et al. 2014, Elith et al. 2010.
- `scripts/extrapolation_risk.R` — MOP + MESS computation script: outputs
  mop_layer.tif, mess_layer.tif, extrapolation_summary.csv, extrapolation_plots.png;
  automatic severity warnings at MOP < 0.25 > 30% and MOP = 0 > 10%.

**skills/ecological-data-foundation:**
- `resources/gbif-data-citation-guide.md` — GBIF citation standards: DOI retrieval,
  occ_search vs occ_download decision guide, data_provenance.md template,
  R and Python code for saving download DOI.
- `scripts/download_from_gbif.R` — GBIF download script (R): single + batch species,
  occ_search for small datasets, occ_download with DOI for large/publication datasets,
  filters, metadata file, n < 30 warning.
- `scripts/download_from_gbif.py` — GBIF download script (Python, pygbif):
  equivalent functionality, async download with polling, same outputs.

### Added — New workflow

- `workflows/run-multispecies-screening/WORKFLOW.md` — 9th workflow:
  rapid multi-species SDM screening loop, priority classification (Alta/Média/Baixa),
  screening_summary.csv, parallelisation note (future::plan), Decision Points table.

### Added — Decision Points sections

Added `## Decision Points` table (Condition → Diagnosis → Recommended Action)
to all 9 workflows: run-sdm-study, run-occupancy-analysis, assess-ecological-impact,
analyze-community-structure, build-fire-risk-map, analyze-environmental-change,
assess-ecosystem-services, produce-technical-report, run-multispecies-screening.

### Updated
- `CATALOG.md` — added new resources index and updated Workflow × Skill matrix
  (run-multispecies-screening row added).
- `environment.yaml` — corrected `name:` field from `eco-skills` to
  `ecological-agent-skills`.

---

## [1.0.0] — 2025 — Initial release

### Added

**12 skills (full content):**
- `ecological-data-foundation` — Darwin Core schema, CoordinateCleaner QA, taxonomy validation
- `geoprocessing-for-ecology` — CRS management, raster stack, point extraction
- `biostatistics-workbench` — GLM/GLMM, DHARMa diagnostics, AIC model selection
- `predictive-modeling-best-practices` — Spatial CV (blockCV), VIF reduction, hyperparameter tuning
- `model-validation-and-uncertainty` — AUC/TSS/Boyce, calibration, sensitivity analysis
- `species-distribution-modeling` — MaxEnt/BRT/RF ensemble, MESS extrapolation, ODMAP checklist
- `occupancy-and-detection` — Single-season occupancy (unmarked), MacKenzie-Bailey GoF
- `community-ecology-ordination` — NMDS/PCoA, PERMANOVA, SIMPER, betapart
- `ecological-impact-assessment` — BACI mixed model, FRAGSTATS metrics, pressure index
- `environmental-time-series` — BFAST, Mann-Kendall, SPI/VCI anomaly indices
- `ecosystem-services-assessment` — InVEST integration, RUSLE C-factors, trade-off analysis
- `reproducible-ecology-pipeline` — params.yaml, decision log, reproducibility checklist

**8 workflows:**
- `run-sdm-study`, `assess-ecological-impact`, `analyze-community-structure`
- `build-fire-risk-map`, `run-occupancy-analysis`, `analyze-environmental-change`
- `assess-ecosystem-services`, `produce-technical-report`

**Per-skill resources:**
- Reference tables, decision guides, glossaries, and species-/biome-specific data

**Per-skill scripts (R + Python):**
- Production-ready and scaffold scripts for all 12 skills

**Templates:**
- `params.yaml` — project parameter manifest
- `invoke-skill.md`, `invoke-workflow.md` — prompt templates
- `pre-analysis-checklist.md`, `post-analysis-checklist.md`, `data-submission-checklist.md`
- `technical-report-template.md`
- `params_loader.R`, `params_loader.py`

**Worked examples:**
- Jaguar SDM (Amazon), Giant anteater SDM (Cerrado)
- BACI road impact (Atlantic Forest birds)
- Puma camera trap occupancy
- Bird community structure (Atlantic Forest)
- Phytoplankton community (Amazon reservoirs)
- Ecosystem services assessment (São Paulo Atlantic Forest)

---

## Roadmap

- [ ] v1.1: Add `landscape-connectivity` skill (IIC, PC, graph-based metrics)
- [ ] v1.1: Add `population-viability-analysis` skill
- [ ] v1.2: Add GEE (Google Earth Engine) script equivalents for raster workflows
- [ ] v1.2: Add `multispecies-occupancy` workflow (community occupancy models)
- [ ] v2.0: Add `deep-learning-for-ecology` skill (CNNs for camera trap, acoustic detection)
