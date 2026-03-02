# Skill Catalog — ecological-agent-skills

A quick-reference index for all 12 skills. Each row summarises the skill's domain, when to invoke it, expected inputs, expected outputs, and which workflows depend on it.

---

## Index

| # | Skill | Domain | Phase |
|---|-------|--------|-------|
| 1 | [ecological-data-foundation](#1-ecological-data-foundation) | Data management | 1 |
| 2 | [geoprocessing-for-ecology](#2-geoprocessing-for-ecology) | Spatial analysis | 1 |
| 3 | [biostatistics-workbench](#3-biostatistics-workbench) | Statistics | 1 |
| 4 | [predictive-modeling-best-practices](#4-predictive-modeling-best-practices) | ML / modeling | 1 |
| 5 | [model-validation-and-uncertainty](#5-model-validation-and-uncertainty) | Evaluation | 2 |
| 6 | [species-distribution-modeling](#6-species-distribution-modeling) | SDM / ENM | 2 |
| 7 | [occupancy-and-detection](#7-occupancy-and-detection) | Occupancy models | 3 |
| 8 | [community-ecology-ordination](#8-community-ecology-ordination) | Community ecology | 3 |
| 9 | [ecological-impact-assessment](#9-ecological-impact-assessment) | Impact & pressure | 2 |
| 10 | [environmental-time-series](#10-environmental-time-series) | Time series | 2 |
| 11 | [ecosystem-services-assessment](#11-ecosystem-services-assessment) | ES valuation | 3 |
| 12 | [reproducible-ecology-pipeline](#12-reproducible-ecology-pipeline) | Reproducibility | 1 |

---

## Skill Details

### 1. ecological-data-foundation
**Domain:** Data ingestion, cleaning, schema validation, metadata, initial QA  
**When to use:** At the start of any quantitative ecology project, before spatial operations or modeling.  
**Inputs:** Raw occurrence records, field survey tables, environmental rasters, sensor exports, CSV/XLSX/GDB files  
**Outputs:** Cleaned, validated dataset; QA report; metadata record; standardised schema  
**Used by workflows:** all  

---

### 2. geoprocessing-for-ecology
**Domain:** Coordinate reference systems, raster/vector operations, spatial extraction  
**When to use:** Whenever spatial data needs to be reprojected, clipped, buffered, intersected, or used to extract environmental values.  
**Inputs:** Shapefiles, GeoTIFFs, occurrence points, study area polygon  
**Outputs:** Reprojected/masked layers, extracted raster values, spatial join tables, buffer polygons  
**Used by workflows:** run-sdm-study, assess-ecological-impact, build-fire-risk-map, analyze-environmental-change, assess-ecosystem-services  

---

### 3. biostatistics-workbench
**Domain:** Hypothesis testing, GLM/GLMM, assumption checking, effect size, confidence intervals  
**When to use:** For inferential statistics, model selection between statistical models, or validating assumptions of any test.  
**Inputs:** Tabular ecological data, response and predictor variables  
**Outputs:** Test statistics, p-values, effect sizes, model comparison tables, assumption diagnostics  
**Used by workflows:** assess-ecological-impact, analyze-community-structure, run-occupancy-analysis, assess-ecosystem-services  

---

### 4. predictive-modeling-best-practices
**Domain:** Train/test split, cross-validation, hyperparameter tuning, collinearity, overfitting, data leakage  
**When to use:** Before fitting any machine learning or algorithmic model (SDM, random forest, BRT, etc.).  
**Inputs:** Feature matrix, target variable, candidate model list  
**Outputs:** CV strategy, tuning results, collinearity report, leakage audit  
**Used by workflows:** run-sdm-study, build-fire-risk-map  

---

### 5. model-validation-and-uncertainty
**Domain:** Performance metrics, calibration, sensitivity analysis, external validation, uncertainty quantification  
**When to use:** After any model is fitted; always required before reporting results.  
**Inputs:** Model object, validation dataset, predictions  
**Outputs:** AUC/TSS/RMSE/etc., calibration plots, sensitivity report, uncertainty maps/intervals  
**Used by workflows:** run-sdm-study, assess-ecological-impact, analyze-community-structure, build-fire-risk-map, run-occupancy-analysis  

---

### 6. species-distribution-modeling
**Domain:** SDM/ENM full pipeline (MaxEnt, BRT, ensemble, projection)  
**When to use:** To model the potential or realised distribution of one or more species.  
**Inputs:** Cleaned occurrence records, environmental predictor stack, study area extent  
**Outputs:** Suitability map, variable importance, model ensemble, projection under scenarios  
**Used by workflows:** run-sdm-study  

---

### 7. occupancy-and-detection
**Domain:** Single-season and dynamic occupancy models, imperfect detection, replicate surveys  
**When to use:** When detection is imperfect and the goal is to estimate occupancy probability separately from detection probability.  
**Inputs:** Detection/non-detection matrix, site covariates, observation covariates  
**Outputs:** Occupancy estimates (ψ), detection estimates (p), covariate effects, AIC table  
**Used by workflows:** run-occupancy-analysis  

---

### 8. community-ecology-ordination
**Domain:** NMDS, PCA, PCoA, diversity indices, cluster analysis, community composition  
**When to use:** For multivariate analysis of species assemblages, beta diversity, or community structure comparisons.  
**Inputs:** Species × site matrix, environmental metadata  
**Outputs:** Ordination plots, stress/eigenvalues, diversity metrics, cluster dendrograms, PERMANOVA results  
**Used by workflows:** analyze-community-structure  

---

### 9. ecological-impact-assessment
**Domain:** BACI design, before/after analysis, landscape fragmentation, anthropogenic pressure synthesis  
**When to use:** To quantify the effect of a disturbance, land-use change, or management intervention on ecological indicators.  
**Inputs:** Pre/post datasets, control/impact site data, pressure layers  
**Outputs:** Impact magnitude estimates, fragmentation metrics, pressure index, synthesis narrative  
**Used by workflows:** assess-ecological-impact, build-fire-risk-map, analyze-environmental-change  

---

### 10. environmental-time-series
**Domain:** Trend detection, seasonality decomposition, breakpoint analysis, anomaly detection, recovery trajectories  
**When to use:** For any temporal ecological signal: NDVI, temperature, rainfall, species abundance index, etc.  
**Inputs:** Time-indexed environmental or ecological variable (tabular or raster stack)  
**Outputs:** Trend estimate, seasonal component, breakpoint dates, anomaly flags, recovery rate  
**Used by workflows:** build-fire-risk-map, analyze-environmental-change  

---

### 11. ecosystem-services-assessment
**Domain:** ES indicators, provisioning/regulating/cultural service quantification, trade-off analysis  
**When to use:** To evaluate and spatially represent ecosystem services across a landscape.  
**Inputs:** Land cover map, biophysical data, socioeconomic layers, study area  
**Outputs:** ES indicator maps, trade-off matrix, summary table by land cover class  
**Used by workflows:** assess-ecosystem-services  

---

### 12. reproducible-ecology-pipeline
**Domain:** Provenance tracking, parameter logging, decision audit, reproducibility checklist  
**When to use:** Throughout every project; mandatory before any publication or technical report.  
**Inputs:** Any intermediate or final analytical outputs, code, model parameters  
**Outputs:** Reproducibility checklist, parameter manifest, decision log, audit trail  
**Used by workflows:** all  

---

## Workflow × Skill Matrix

|  | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|--|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:--:|:--:|:--:|
| run-sdm-study | ✓ | ✓ | | ✓ | ✓ | ✓ | | | | | | ✓ |
| assess-ecological-impact | ✓ | ✓ | ✓ | | ✓ | | | | ✓ | | | ✓ |
| analyze-community-structure | ✓ | | ✓ | | ✓ | | | ✓ | | | | ✓ |
| build-fire-risk-map | ✓ | ✓ | | ✓ | ✓ | | | | ✓ | ✓ | | |
| run-occupancy-analysis | ✓ | | ✓ | | ✓ | | ✓ | | | | | ✓ |
| analyze-environmental-change | ✓ | ✓ | | | | | | | ✓ | ✓ | | ✓ |
| assess-ecosystem-services | ✓ | ✓ | ✓ | | | | | | | | ✓ | ✓ |
| produce-technical-report | | | | | | | | | | | | ✓ |
| run-multispecies-screening | ✓ | ✓ | | ✓ | ✓ | ✓ | | | | | | |

---

## New Resources Added in v1.1.0

### skills/species-distribution-modeling/
| File | Description |
|---|---|
| `resources/maxent-calibration-guide.md` | RM × FC grid, OR_AICc criterion, kuenm vs ENMeval comparison |
| `resources/climate-scenario-preparation.md` | CHELSA/WorldClim sources, SSPs, mandatory preparation pipeline |
| `scripts/tune_maxnet.R` | ENMeval calibration grid search (35 models), OR_AICc selection, best_maxnet.rds |
| `scripts/prepare_future_layers.R` | Reproject, crop, compareGeom, layer-name verification for future stacks |

### skills/predictive-modeling-best-practices/
| File | Description |
|---|---|
| `resources/sampling-bias-correction.md` | Target-group background, KDE weighting, environmental filtering, decision table |

### skills/model-validation-and-uncertainty/
| File | Description |
|---|---|
| `resources/extrapolation-risk-guide.md` | MOP, ExDet (NT1/NT2), MESS — comparison table, thresholds, masking protocol |
| `scripts/extrapolation_risk.R` | MOP + MESS computation, summary CSV, extrapolation plots, severity warnings |

### skills/ecological-data-foundation/
| File | Description |
|---|---|
| `resources/gbif-data-citation-guide.md` | DOI retrieval, occ_search vs occ_download, ODMAP O4 reporting |
| `scripts/download_from_gbif.R` | Single + batch GBIF download with DOI, rgbif, filters, metadata |
| `scripts/download_from_gbif.py` | Python equivalent via pygbif |

### workflows/
| File | Description |
|---|---|
| `run-multispecies-screening/WORKFLOW.md` | 9th workflow — rapid multi-species SDM screening with priority classification |
| All 8 existing WORKFLOWs | Added `## Decision Points` section with condition → diagnosis → action tables |
