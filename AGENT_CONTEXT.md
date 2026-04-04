# AGENT_CONTEXT.md

This file is written for AI agents, not humans.
Read this file first before performing any task in this repository.
Do not skip sections. Every rule here is enforced at runtime.

---

## 1. How to Use This Repository

This repository is a modular skill library for quantitative ecology.
It is structured for use by AI agents operating within agent frameworks
(Claude Code, Gemini CLI, GitHub Copilot, Cursor, or any compatible system).

**Skills** are self-contained analysis modules. Each skill:
- Lives at `skills/<skill-id>/`
- Is described by `skills/<skill-id>/SKILL.md`
- Contains scripts in `scripts/`, reference material in `resources/`, and
  worked examples in `examples/`

**Workflows** are ordered sequences of skills for complete project pipelines.
Each workflow lives at `workflows/<workflow-id>/WORKFLOW.md`.

**Rules — read before invoking any skill:**

1. Read `skills/SKILL_INDEX.json` first to identify the correct skill for the task.
   Do not rely on skill names alone; use `trigger_keywords` and `domain` fields.
2. Read the full `SKILL.md` of the selected skill before executing any step.
   Do not skip to the scripts.
3. Check `min_inputs` in the skill index. If a required input is missing, request it
   from the user before proceeding.
4. After completing each analytical step, write decisions to `decision_log.md` as
   required by the `reproducible-ecology-pipeline` skill.
5. Validate outputs listed in `primary_outputs` before marking a skill as complete.

---

## 2. Canonical Invocation Order by Project Type

| Project Type | Step 1 | Step 2 | Step 3 | Step 4 | Step 5 |
|---|---|---|---|---|---|
| **SDM — complete** | ecological-data-foundation | geoprocessing-for-ecology | predictive-modeling-best-practices | species-distribution-modeling | model-validation-and-uncertainty |
| **SDM — projection only** | geoprocessing-for-ecology | species-distribution-modeling | model-validation-and-uncertainty | — | — |
| **Ecological impact (BACI)** | ecological-data-foundation | ecological-impact-assessment | biostatistics-workbench | model-validation-and-uncertainty | reproducible-ecology-pipeline |
| **Community analysis** | ecological-data-foundation | community-ecology-ordination | biostatistics-workbench | reproducible-ecology-pipeline | — |
| **Occupancy and detection** | ecological-data-foundation | occupancy-and-detection | biostatistics-workbench | reproducible-ecology-pipeline | — |
| **Environmental time series** | ecological-data-foundation | environmental-time-series | biostatistics-workbench | reproducible-ecology-pipeline | — |
| **Ecosystem services** | ecological-data-foundation | geoprocessing-for-ecology | ecosystem-services-assessment | model-validation-and-uncertainty | reproducible-ecology-pipeline |
| **Multispecies screening** | ecological-data-foundation | geoprocessing-for-ecology | species-distribution-modeling (loop) | model-validation-and-uncertainty | reproducible-ecology-pipeline |
| **Acoustic monitoring** | ecological-data-foundation | acoustic-monitoring | biostatistics-workbench | model-validation-and-uncertainty | reproducible-ecology-pipeline |
| **Camera trap occupancy** | ecological-data-foundation | camera-trap-processing | occupancy-and-detection | model-validation-and-uncertainty | reproducible-ecology-pipeline |
| **Landscape connectivity** | ecological-data-foundation | geoprocessing-for-ecology | landscape-connectivity | model-validation-and-uncertainty | reproducible-ecology-pipeline |
| **Population viability** | ecological-data-foundation | biostatistics-workbench | population-viability-analysis | model-validation-and-uncertainty | reproducible-ecology-pipeline |
| **Conservation prioritization** | ecological-data-foundation | geoprocessing-for-ecology | species-distribution-modeling | spatial-prioritization | reproducible-ecology-pipeline |

For multispecies projects always read `workflows/run-multispecies-screening/WORKFLOW.md`
before starting. It contains the priority classification logic.

Available workflows (14): `run-sdm-study`, `run-multispecies-screening`, `run-occupancy-analysis`, `run-camera-trap-occupancy`, `run-acoustic-monitoring`, `run-population-viability`, `run-conservation-prioritization`, `assess-ecological-impact`, `assess-ecosystem-services`, `assess-landscape-connectivity`, `analyze-community-structure`, `analyze-environmental-change`, `build-fire-risk-map`, `produce-technical-report`.

---

## 3. Disambiguation Rules for Overlapping Skills

Apply exactly one rule per ambiguous situation. Do not invoke two skills for the
same analytical question.

### biostatistics-workbench vs community-ecology-ordination
- Use **biostatistics-workbench** when the question involves a single response variable
  (abundance, richness, biomass) and one or more predictors.
- Use **community-ecology-ordination** when the question involves species composition
  across multiple sites (a species × site matrix is the primary input).

### ecological-data-foundation vs geoprocessing-for-ecology
- Use **ecological-data-foundation** for cleaning, deduplicating, validating, and
  standardising occurrence records or survey tables.
- Use **geoprocessing-for-ecology** for spatial operations on rasters and vectors:
  reprojection, masking, stacking, buffer creation, spatial extraction.
- If the task involves occurrence records AND spatial extraction, invoke
  ecological-data-foundation first, then geoprocessing-for-ecology.

### model-validation-and-uncertainty vs predictive-modeling-best-practices
- Use **predictive-modeling-best-practices** BEFORE fitting any model:
  predictor selection, collinearity reduction, CV strategy design, bias correction.
- Use **model-validation-and-uncertainty** AFTER fitting any model:
  performance metrics, calibration, uncertainty quantification, extrapolation risk.
- Never reverse this order.

### ecological-impact-assessment vs biostatistics-workbench
- Use **ecological-impact-assessment** when the data has explicit temporal structure
  (before/after) and spatial structure (control/impact sites), or when computing
  landscape fragmentation or pressure indices.
- Use **biostatistics-workbench** for statistical comparisons that do not involve
  a BACI design or landscape metrics.

### species-distribution-modeling vs occupancy-and-detection
- Use **species-distribution-modeling** when the goal is a spatial suitability surface
  using presence-only or presence-absence records and environmental predictors.
- Use **occupancy-and-detection** when the goal is to estimate occupancy probability (ψ)
  and detection probability (p) using replicated-visit detection history data.

### ecological-data-foundation vs reproducible-ecology-pipeline
- Use **ecological-data-foundation** for data cleaning and QA at the start of the pipeline.
- Use **reproducible-ecology-pipeline** for logging decisions, generating file manifests,
  and ensuring auditability — invoke at the end of each major analytical phase.

---

## 4. When NOT to Invoke Any Skill

Do not invoke any skill for the following situations. Answer directly.

- **Conceptual questions about methods**: "What is MaxEnt?", "How does NMDS work?"
  → Explain directly. No skill invocation.
- **Interpretation of already-computed results**: "What does an AUC of 0.75 mean for
  my model?" → Interpret directly. Do not re-run scripts.
- **Code review of existing scripts**: "Is this R script correct?" → Review and respond
  directly. Do not re-execute the script.
- **n < 10 records for any modelling task**: Do not invoke any modelling skill.
  Communicate the limitation to the user explicitly. Suggest options (literature review,
  expert knowledge, qualitative assessment).

---

## 5. Minimum Sample Size Requirements

If the available n is below the minimum absolute threshold, do not proceed with modelling.
State the limitation, explain why modelling is unreliable, and suggest alternatives.

| Analysis Type | n minimum (absolute) | n recommended | Action if below minimum |
|---|---|---|---|
| SDM (MaxEnt/ensemble) | 10 occurrences | ≥ 30 | Do not fit model; suggest literature-based range map |
| Occupancy model (single-season) | 15 sites | ≥ 30 sites, ≥ 3 visits | Do not fit model; use naive occupancy with explicit caveat |
| BACI (mixed model) | 5 control + 5 impact sites, ≥ 3 time periods | ≥ 10 per group | Report power deficit; fit model with explicit uncertainty caveat |
| Community ordination (NMDS/PERMANOVA) | 5 sites | ≥ 10 sites | Reduce dimensionality; note low power |
| GLM (single predictor) | 20 observations | ≥ 50 | Fit with caution; report wide CIs explicitly |
| PVA (population viability) | 5 years of count data | ≥ 10 years | Do not run stochastic PVA; use deterministic model only |

---

## 6. Scaling Between Simple and Complex Projects

Apply the appropriate routing based on project complexity:

**Simple project** (1 species, 1 analysis, no pipeline):
→ Invoke the single relevant skill directly.
→ Example: "Clean this occurrence CSV" → ecological-data-foundation only.

**Medium project** (1 species, full analytical pipeline):
→ Follow the canonical invocation order from Section 2.
→ Read the corresponding workflow WORKFLOW.md before starting.
→ Example: Complete SDM → read `workflows/run-sdm-study/WORKFLOW.md`.

**Complex project** (multiple species, multiple analyses, or iterative pipeline):
→ Read `workflows/run-multispecies-screening/WORKFLOW.md` first.
→ Use `future::plan(multisession)` in R for species-level parallelisation.
→ Prioritise species using the High/Medium/Low classification defined in that workflow.
→ Do not proceed to projection for Medium or Low priority species until High priority
  species have passed model validation.

---

## 7. Environmental Data Sources

### Default source: CHELSA v2.1

The default environmental predictor source for all SDM and geoprocessing workflows is **CHELSA v2.1**
(Climatologies at High resolution for the Earth's Land Surface Areas).

- Resolution: ~1 km (30 arcsec)
- Variables: BIO1-BIO19 (1981-2010 climatology)
- Download URL pattern: `https://os.zhdk.cloud.switch.ch/chelsav2/GLOBAL/climatologies/1981-2010/bio/CHELSA_bio{N}_1981-2010_V.2.1.tif`
- No authentication required
- License: CC BY 4.0

**WorldClim v2.1** is the automatic fallback if CHELSA downloads fail.
The `download_predictors.py` script handles this transparently — no user action required.

Do not default to WorldClim unless the user explicitly requests it or CHELSA is unavailable.

### Python version compatibility

| Python | Status for this repository |
|--------|---------------------------|
| 3.11 | Recommended — all packages build correctly |
| 3.12 | Supported — most packages available |
| 3.13 | Untested |
| 3.14 | Not recommended — `elapid` (MaxEnt) fails to build; `pygbif` has API bugs |

If `elapid` is unavailable (Python 3.12+), `sdm_pipeline.py` automatically falls back to an
RF + BRT ensemble without MaxEnt. This is logged as a DECISION entry.

If `pygbif` raises a `TypeError` on `Session.request()` (Python 3.14), `download_from_gbif.py`
automatically falls back to direct HTTP calls to the GBIF REST API.

### Spatial thinning

`clean_occurrences.py` accepts an optional third argument `thin_deg` (decimal degrees).
When provided, one record is retained per `thin_deg × thin_deg` grid cell to reduce
spatial autocorrelation before SDM fitting. Recommended values: 0.1 (~11 km) to 0.5 (~55 km).

Example:
```bash
python clean_occurrences.py data/raw/occurrences.csv data/processed 0.1
```

---

## 8. File Conventions of This Repository

### Where to put input data
- Place raw input files in `data/raw/` (create if absent).
- Place cleaned, analysis-ready files in `data/processed/`.
- GBIF downloads go in `data/raw/gbif/`.

### Where to write outputs
- Model outputs: `outputs/<skill-id>/` (create per skill, per species if needed).
- Reports: `outputs/reports/`.
- Figures: `outputs/figures/`.
- Logs: `outputs/logs/`.

### Naming conventions
- Occurrence files: `occurrences_<species-slug>_<source>_<YYYYMMDD>.csv`
- Raster outputs: `<variable>_<species-slug>_<scenario>_<year>.tif`
- Reports: `<skill-id>_report_<YYYYMMDD>.md`
- Follow `snake_case` for all file names. No spaces.

### Recording decisions
After each analytical step, append to `decision_log.md` at the project root:
```
## [YYYY-MM-DD] <Skill ID> — <brief description>
- Decision: <what was decided>
- Rationale: <why>
- Alternatives considered: <what else was evaluated>
- Output files: <list of files generated>
```
If `decision_log.md` does not exist, create it before appending.

### Checking the skill index
Before invoking any skill, execute this lookup:
1. Open `skills/SKILL_INDEX.json`.
2. Search `trigger_keywords` for terms matching the user request.
3. Check `depends_on_skills` — all dependencies must have been completed first.
4. Check `decision_points` — verify n thresholds and quality gates before proceeding.
