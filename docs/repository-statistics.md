# Repository Statistics

Generated: 2026-04-04
Version: 3.2.0

---

## Content Summary

| Category | Count |
|----------|-------|
| Skills | 17 |
| Workflows | 14 |
| R scripts | 34 |
| Python scripts | 26 |
| Worked examples | 14 |
| Resource documents | 53 |
| Documentation files (docs/) | 8 |
| Test datasets (CSV) | 11 |
| Total files (excluding .git) | ~340 |

## Skill Breakdown

| Phase | Skills | Count |
|-------|--------|-------|
| Phase 1 (Foundation) | ecological-data-foundation, geoprocessing-for-ecology, biostatistics-workbench, predictive-modeling-best-practices, reproducible-ecology-pipeline | 5 |
| Phase 2 (Modeling) | model-validation-and-uncertainty, species-distribution-modeling, ecological-impact-assessment, environmental-time-series | 4 |
| Phase 3 (Specialist) | occupancy-and-detection, community-ecology-ordination, ecosystem-services-assessment | 3 |
| Phase 4 (Advanced) | camera-trap-processing, acoustic-monitoring, landscape-connectivity, population-viability-analysis, spatial-prioritization | 5 |

## Geographic Coverage

| Continent | Examples | Representative |
|-----------|---------|---------------|
| South America | 6 | Jaguar (Amazon), Anteater (Cerrado), Birds (Atlantic Forest), Phytoplankton (Amazon reservoirs), Puma (Atlantic Forest), BACI road (Atlantic Forest), Ecosystem services (São Paulo) |
| Europe | 2 | Grey Wolf (Western Europe), Arctic tundra (Greenland) |
| Asia | 3 | Reef fish (Indo-Pacific), Snow leopard (Himalayas), Forest loss (Borneo) |
| Oceania | 2 | Koala (Australia), Reef fish (Indo-Pacific) |
| North America | 2 | Red fox (Holarctic), Arctic tundra (Canada) |
| Africa | 1 | Red fox (Holarctic — North Africa margin) |
| **Total continents** | **6/6** | |

## Taxonomic Coverage

| Group | Species / Systems |
|-------|------------------|
| Mammals | Jaguar, anteater, wolf, koala, red fox, puma, snow leopard (7) |
| Birds | Atlantic Forest bird community (127 spp.) |
| Fish | Indo-Pacific reef fish (987 spp.) |
| Plants | Arctic tundra vegetation |
| Phytoplankton | Amazon reservoir assemblages |
| Ecosystems | Borneo forest, Atlantic Forest remnants |

## Analysis Types Covered

| Analysis | Example count |
|----------|-------------|
| SDM (species distribution modeling) | 5 |
| Community ecology (ordination, diversity) | 4 |
| Occupancy modeling | 2 |
| BACI impact assessment | 2 |
| Time series (NDVI, BFAST) | 2 |
| Ecosystem services | 1 |
| Climate change projection | 1 |
| Landscape fragmentation | 1 |
| Conflict analysis | 1 |
| Fully reproducible pipeline | 1 |

## CI Check Results

| Section | Checks |
|---------|--------|
| Structure checks | 652/652 passed |
| Skills verified | 17 |
| Workflows verified | 14 |
| Global coverage | 6/6 continents |
| Empty files | 0 (in tracked content) |
| JSON validation | SKILL_INDEX.json valid, smoke_test_cases.json valid |

## Test Suite

| Test type | Count |
|-----------|-------|
| CI structural checks | 652 |
| Python unit tests (pytest) | 176+ |
| R unit tests (testthat) | 28+ |
| Agent smoke test cases | 15 |
| Regression test infrastructure | Ready (reference outputs to be generated) |

## Release History

| Version | Date | Highlights |
|---------|------|-----------|
| 1.0.0 | 2026-02-28 | Initial: 12 skills, 8 workflows, 7 examples |
| 1.1.0 | 2026-03-01 | Rename, MaxEnt calibration, GBIF download, 9th workflow |
| 1.2.0 | 2026-03-02 | Agent infrastructure (AGENT_CONTEXT, SKILL_INDEX, CI) |
| 2.0.0 | 2026-03-03 | 5 advanced skills (camera trap, acoustic, connectivity, PVA, prioritization) |
| 2.1.0 | 2026-03-04 | Structured logging in all 43 scripts, SDM prediction, BACI power analysis |
| 2.2.0 | 2026-03-05 | Global data download scripts (iNat, eBird, OBIS, IUCN), predictor sources |
| 2.3.0 | 2026-03-06 | Scientific documentation, 7 global examples, comparison with alternatives |
| 3.0.0 | 2026-03-06 | Quality infrastructure: regression tests, smoke tests, expanded CI, release process |
| 3.1.0 | 2026-03-28 | License migration (MIT → GPL-3.0), CITATION.cff, CATALOG Phase 4 update |
| 3.2.0 | 2026-04-02 | Code quality: English translation, CHELSA default, environment-python.yaml, INSTALL.md, glossary, taxonomy diagram, DECISION_TREE, integration tests |
| 3.2.x | 2026-04-03 | Cross-reference fixes: SKILL_INDEX.json sync, run-acoustic-monitoring integration, Decision Points in 7 skills, CI hardening |
