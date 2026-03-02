# Changelog

All notable changes to this repository are documented here.
Format: [version] — date — description

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
