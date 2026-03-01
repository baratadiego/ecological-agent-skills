# Changelog

All notable changes to this repository are documented here.
Format: [version] — date — description

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
