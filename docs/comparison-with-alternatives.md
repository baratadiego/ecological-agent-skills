# Comparison with Alternative Tools

This document provides an objective comparison of **ecological-agent-skills** against established software tools used in quantitative ecology, species distribution modeling, population viability analysis, and spatial conservation planning.

## Comparison Table

| Criterion | ecological-agent-skills | Wallace | SDMtoolbox | biomod2 | kuenm | ENMTML | Zonation | Vortex |
|---|---|---|---|---|---|---|---|---|
| **Type** | Skill repository (R + Python) | R/Shiny GUI | ArcGIS plugin (Python) | R package | R package | R package | Standalone (C++) | Standalone (Windows) |
| **SDM algorithms** | MaxEnt, GLM, GAM, BRT, RF via biomod2/maxnet wrappers | MaxEnt, GLM, GAM, BRT, RF, BIOCLIM | MaxEnt (with background selection tools) | MaxEnt, GLM, GAM, GBM, RF, SRE, FDA, MARS, ANN, CTA (10+) | MaxEnt only (calibration-focused) | MaxEnt, GLM, GAM, GBM, RF, SVM, BIOCLIM, Domain (10+) | None (consumes SDM outputs) | None (not an SDM tool) |
| **PVA included** | Yes (matrix-based, stochastic demographic) | No | No | No | No | No | No | Yes (individual-based, genetics, catastrophes) |
| **Prioritization included** | Yes (via prioritizr wrapper) | No | No | No | No | No | Yes (core functionality) | No |
| **Connectivity included** | Yes (resistance surfaces, least-cost paths, circuit theory via gdistance/Circuitscape) | No | Partial (corridor tools in ArcGIS) | No | No | No | Partial (connectivity penalty in planning) | No |
| **Reproducibility** | 4/5 -- scripted pipelines with config files, but depends on user discipline to version inputs | 3/5 -- session-based, exports R scripts but GUI steps not fully logged | 2/5 -- ArcGIS model builder possible but manual steps common | 4/5 -- fully scripted R workflows | 4/5 -- scripted calibration with CSV logs | 4/5 -- scripted with HTML output reports | 2/5 -- GUI-driven parameter files, batch mode possible | 2/5 -- GUI with project files, XML scenarios exportable |
| **Learning curve** | 3/5 -- requires comfort with CLI/agents and R/Python, but SKILL.md docs guide each step | 2/5 -- GUI with step-by-step tabs, beginner-friendly | 3/5 -- requires ArcGIS expertise | 3/5 -- R programming required, good vignettes | 3/5 -- R programming, MaxEnt-specific knowledge | 3/5 -- R programming, similar interface to biomod2 | 4/5 -- complex parameter tuning, sparse documentation | 4/5 -- many parameters, population biology expertise needed |
| **AI agent support** | Yes (designed for agents: trigger keywords, SKILL.md index, AGENT_CONTEXT.md) | No | No | No | No | No | No | No |
| **Methodological decision docs** | Yes (theoretical-foundations linking choices to primary literature) | Partial (guidance text in GUI panels) | No | Partial (vignettes explain options) | Yes (calibration rationale in publications) | Partial (vignettes) | No (user must consult external literature) | No (user must consult external literature) |
| **Global scope** | Yes (GBIF/BIEN download, WorldClim/CHELSA layers, any region) | Yes (GBIF integration, WorldClim) | Partial (requires user-supplied layers, no built-in download) | Yes (user supplies data, no built-in download, but global in principle) | Partial (user supplies data, designed for any region) | Yes (built-in GBIF and WorldClim download) | Yes (user supplies layers, any region) | Yes (user defines parameters, any species) |
| **Last update / maintenance** | 2025 (active development) | 2024 (active, v2.x) | 2021 (maintenance mode, ArcGIS Pro migration unclear) | 2024 (active, CRAN) | 2023 (maintained, GitHub) | 2022 (low activity) | 2022 (Zonation 5 released, limited updates) | 2024 (active, v10.x) |
| **Licence** | MIT | GPL-3 | GPL-3 | GPL-2+ | GPL-3 | GPL-3 | Proprietary (free for academic use) | Proprietary (free for non-commercial use) |

## Positioning

ecological-agent-skills is the only repository designed specifically for use with AI agents, integrating 17 skills in reproducible pipelines with documented methodological decisions. It does not replace biomod2 or prioritizr -- it uses them as dependencies. It is distinguished by: (1) agent-native design with trigger keywords and skill index, (2) integrated coverage from data download through SDM, community ecology, impact assessment, PVA, connectivity, and spatial prioritization, (3) dual R+Python implementation for every script, and (4) theoretical-foundations document linking every methodological choice to primary literature.

Where Wallace and ENMTML excel at providing accessible, self-contained SDM workflows, and Vortex and Zonation offer deep functionality in PVA and spatial planning respectively, ecological-agent-skills occupies a distinct niche: it is a coordination layer that connects these analytical domains into end-to-end pipelines that an AI agent can discover, parameterize, and execute without manual GUI interaction. The repository is most valuable when an analyst needs to chain multiple analytical steps -- for example, downloading occurrence data, fitting an ensemble SDM, running a PVA on predicted suitable habitat, and feeding both outputs into a spatial prioritization -- in a single reproducible session guided by an AI assistant.

## Limitations of ecological-agent-skills

The following limitations should be considered when evaluating whether this repository is appropriate for a given use case:

- **No GUI** -- requires command-line or agent interface. Users who prefer point-and-click workflows should consider Wallace or Vortex instead.
- **Not a standalone software package** -- a skill library that wraps existing packages. It adds orchestration and documentation, not novel algorithms.
- **SDM algorithms depend on external packages** (maxnet, dismo, biomod2). If upstream packages introduce breaking changes, scripts may require updates.
- **PVA implementation is simpler than Vortex** -- no genetics module, no individual-based modeling, no catastrophe scheduling. For species requiring detailed genetic or demographic complexity, Vortex remains the better tool.
- **Prioritization is a wrapper around prioritizr** -- does not add novel optimization solvers or planning unit generation beyond what prioritizr already provides.
- **Test suite does not cover all edge cases** for scripts that require live API calls (GBIF, WorldClim). Tests use stored fixtures; failures against live APIs may not be caught until runtime.
- **Documentation is in English only**. Non-English-speaking users may face accessibility barriers, particularly for the methodological decision documents.
