# ecological-agent-skills

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

A curated, agent-agnostic skill library for **quantitative ecology** workflows, designed for use with any AI coding agent.

This repository provides 17 modular skills and 13 multi-step workflows covering the full spectrum of quantitative ecology: from raw data ingestion and geoprocessing to species distribution modeling, occupancy analysis, community ecology, ecological impact assessment, and reproducible reporting.

---

## Compatibility

These skills work with any AI agent that can read structured Markdown instructions and execute R/Python scripts. Tested frameworks include:

| Agent Framework | Install / Reference Path |
|----------------|--------------------------|
| **Claude Code** | Reference via system prompt, `CLAUDE.md`, or MCP configuration |
| **Gemini CLI / Antigravity** | `~/.gemini/ecological-agent-skills/skills/` |
| **GitHub Copilot** | Reference via `.github/copilot-instructions.md` or workspace context |
| **Cursor / Windsurf** | Add as workspace folder; reference `AGENT_CONTEXT.md` in rules |
| **Any agent** | `.agent/skills/` (project root) or direct file reference

---

## Repository Structure

```
ecological-agent-skills/
├── README.md
├── CATALOG.md                    ← skill index with metadata
├── skills/                       ← 17 modular skills
│   └── <skill-name>/
│       ├── SKILL.md              ← main instructions
│       ├── resources/            ← checklists, glossaries, templates
│       ├── examples/             ← usage prompt examples
│       └── scripts/              ← optional R/Python/bash helpers
├── workflows/                    ← 8 multi-step playbooks
│   └── <workflow-name>/
│       └── WORKFLOW.md
├── templates/
│   ├── prompts/
│   ├── reports/
│   ├── checklists/
│   └── scripts/
└── examples/
    ├── sdm/
    ├── impact/
    ├── occupancy/
    └── community/
```

---

## Skills (17)

| # | Skill | Domain |
|---|-------|--------|
| 1 | `ecological-data-foundation` | Data ingestion, QA, schema |
| 2 | `geoprocessing-for-ecology` | CRS, raster, vector, spatial ops |
| 3 | `biostatistics-workbench` | Tests, GLM/GLMM, effect sizes |
| 4 | `predictive-modeling-best-practices` | CV, tuning, leakage, collinearity |
| 5 | `model-validation-and-uncertainty` | Metrics, calibration, sensitivity |
| 6 | `species-distribution-modeling` | SDM/ENM full pipeline |
| 7 | `occupancy-and-detection` | Occupancy models, detectability |
| 8 | `community-ecology-ordination` | NMDS, PCA, diversity, clustering |
| 9 | `ecological-impact-assessment` | BACI, fragmentation, pressure |
| 10 | `environmental-time-series` | Trend, seasonality, breakpoint |
| 11 | `ecosystem-services-assessment` | ES indicators, valuation |
| 12 | `reproducible-ecology-pipeline` | Traceability, audit, checklist |

**Advanced Skills (v2.0.0)**

| # | Skill ID | Core capability |
|---|---|---|
| 13 | `camera-trap-processing` | Detection events, RAI, diel activity, Dhat4 overlap |
| 14 | `acoustic-monitoring` | ACI/NDSI indices, BirdNET detection, soundscape ecology |
| 15 | `landscape-connectivity` | IIC, PC, dPC, Circuitscape current maps, resistance surfaces |
| 16 | `population-viability-analysis` | Leslie/Lefkovitch λ, stochastic PVA, IUCN Criterion E |
| 17 | `spatial-prioritization` | prioritizr ILP, 30×30 targets, BLM calibration, irreplaceability |

See [CATALOG.md](CATALOG.md) for full metadata, inputs, outputs, and workflow linkages.

---

## Workflows (13)

| Workflow | Skills Used |
|----------|-------------|
| `run-sdm-study` | 1 → 2 → 4 → 6 → 5 → 12 |
| `assess-ecological-impact` | 1 → 2 → 9 → 3 → 5 → 12 |
| `analyze-community-structure` | 1 → 3 → 8 → 5 → 12 |
| `build-fire-risk-map` | 1 → 2 → 10 → 4 → 5 → 9 |
| `run-occupancy-analysis` | 1 → 3 → 7 → 5 → 12 |
| `analyze-environmental-change` | 1 → 2 → 10 → 9 → 12 |
| `assess-ecosystem-services` | 1 → 2 → 11 → 3 → 12 |
| `produce-technical-report` | 12 → outputs → template → synthesis |
| `run-multispecies-screening` | 1 → 2 → 4 → 6 → 5 |
| `run-camera-trap-occupancy` | 1 → 13 → 7 → 5 → 12 |
| `assess-landscape-connectivity` | 1 → 2 → 15 → 5 → 12 |
| `run-population-viability` | 1 → 3 → 16 → 5 → 12 |
| `run-conservation-prioritization` | 1 → 2 → 6 → 17 → 12 |

---

## How to Use Skills

### Natural invocation
```
Use the species-distribution-modeling skill to build a MaxEnt model for Chrysocyon brachyurus.
```

### Explicit skill reference
```
Load skill: ecological-data-foundation
Task: validate and clean the occurrence dataset at data/raw/occurrences.csv
```

### Chaining via workflow
```
Run workflow: run-sdm-study
Species: Panthera onca
Study area: Amazon biome
Predictors: WorldClim v2.1 + MapBiomas land cover
```

---

## For AI Agents

If you are an AI agent operating in this repository, **read these two files first**:

| File | Purpose |
|---|---|
| [`AGENT_CONTEXT.md`](AGENT_CONTEXT.md) | Canonical rules for skill invocation, disambiguation, minimum sample sizes, project scaling, and file conventions |
| [`skills/SKILL_INDEX.json`](skills/SKILL_INDEX.json) | Machine-readable index of all skills with trigger keywords, required inputs, outputs, dependencies, and decision thresholds |

**Quick start for agents:**
1. Read `AGENT_CONTEXT.md` in full before any task.
2. Search `skills/SKILL_INDEX.json` by `trigger_keywords` to select the correct skill.
3. Read the full `SKILL.md` of the selected skill before executing any step.
4. Check `min_inputs` and `decision_points` before running scripts.
5. Write decisions to `decision_log.md` after each skill completes.

---

## Implementation Roadmap

**Phase 1 (foundation):** `ecological-data-foundation`, `geoprocessing-for-ecology`, `biostatistics-workbench`, `predictive-modeling-best-practices`, `reproducible-ecology-pipeline`

**Phase 2 (modeling):** `model-validation-and-uncertainty`, `species-distribution-modeling`, `ecological-impact-assessment`, `environmental-time-series`

**Phase 3 (specialist):** `occupancy-and-detection`, `community-ecology-ordination`, `ecosystem-services-assessment`

**Phase 4 (advanced):** `camera-trap-processing`, `acoustic-monitoring`, `landscape-connectivity`, `population-viability-analysis`, `spatial-prioritization`

---

## Documentation

| Document | Description |
|----------|-------------|
| [`docs/theoretical-foundations.md`](docs/theoretical-foundations.md) | Citable justifications for every methodological decision (spatial CV, ensemble, partial ROC, MESH, BACI, etc.) with primary references |
| [`docs/global-examples-index.md`](docs/global-examples-index.md) | Inventory of all 14 worked examples with geographic, taxonomic, and thematic coverage analysis |
| [`docs/comparison-with-alternatives.md`](docs/comparison-with-alternatives.md) | Objective comparison vs. Wallace, biomod2, kuenm, ENMTML, SDMtoolbox, Zonation, Vortex |
| [`CATALOG.md`](CATALOG.md) | Skill-level metadata: inputs, outputs, trigger keywords, workflow linkages |

---

## Examples (14)

| Region | Example |
|--------|---------|
| Amazon, Brazil | Jaguar SDM |
| Cerrado, Brazil | Giant Anteater SDM |
| Atlantic Forest, Brazil | Bird community, Puma occupancy, BACI road impact, Ecosystem services |
| Amazon reservoirs | Phytoplankton community |
| Western Europe | Grey Wolf recolonization + conflict |
| Eastern Australia | Koala climate change SDM + MOP |
| Indo-Pacific | Reef fish beta diversity |
| Central Himalayas | Snow Leopard occupancy |
| Borneo | Forest loss time series + BACI |
| Arctic (Greenland/Canada) | Tundra vegetation greening |
| Holarctic (global) | Red Fox — fully reproducible SDM |

See [`docs/global-examples-index.md`](docs/global-examples-index.md) for full details with data sources and DOIs.

---

## Contributing

Follow the standard skill packaging pattern: one directory per skill, `SKILL.md` as the entry point, with optional `resources/`, `examples/`, and `scripts/` subdirectories.

---

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE) or later. See `CITATION.cff` for citation metadata.
