# ecological-agent-skills

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

A curated, agent-agnostic skill library for **quantitative ecology** workflows, designed for use with any AI coding agent.

**17 modular skills** | **13 multi-step workflows** | **58 R/Python scripts** | **14 worked examples across 6 continents**

---

## Table of Contents

- [New Here? Start Here!](#new-here-start-here)
- [Installation](#installation)
- [Core Concepts](#core-concepts)
- [Skills (17)](#skills-17)
- [Workflows (13)](#workflows-13)
- [How to Use Skills](#how-to-use-skills)
- [For AI Agents](#for-ai-agents)
- [Examples (14)](#examples-14)
- [Documentation](#documentation)
- [Implementation Roadmap](#implementation-roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## New Here? Start Here!

**What is this?** A collection of structured Markdown instructions (skills) that teach AI agents how to perform quantitative ecology analyses — from cleaning GBIF data to running species distribution models, occupancy analysis, PVA, and conservation prioritization.

**Who is it for?** Ecologists, conservation biologists, and environmental scientists who use AI coding agents to assist with data analysis in R or Python.

**1-minute quick start:**

```bash
# 1. Clone the repository
git clone https://github.com/baratadiego/ecological-agent-skills.git

# 2. Tell your agent about it (example for Claude Code)
cd ecological-agent-skills
# The agent reads AGENT_CONTEXT.md and skills/SKILL_INDEX.json automatically

# 3. Ask your agent to run an analysis
```

```
Use the species-distribution-modeling skill to build a MaxEnt model
for Panthera onca in the Amazon biome using WorldClim v2.1 predictors.
```

**That's it.** The agent reads the skill instructions, follows the decision points, runs the R/Python scripts, and produces validated outputs with full reproducibility tracking.

**Pick a starting workflow:**

| Your goal | Workflow to run |
|-----------|----------------|
| Model where a species occurs | `run-sdm-study` |
| Estimate occupancy from camera traps | `run-camera-trap-occupancy` |
| Assess impact of a disturbance | `assess-ecological-impact` |
| Compare community composition | `analyze-community-structure` |
| Identify conservation priority areas | `run-conservation-prioritization` |

---

## Installation

### Option A — Clone (recommended)

```bash
git clone https://github.com/baratadiego/ecological-agent-skills.git
```

### Option B — Download ZIP

Download from [Releases](https://github.com/baratadiego/ecological-agent-skills/releases) and extract to your preferred location.

### Setup per agent framework

| Agent Framework | Setup |
|----------------|-------|
| **Claude Code** | Clone into your project or reference via `CLAUDE.md`. Add `Read AGENT_CONTEXT.md before any ecology task` to your system prompt or project instructions |
| **Gemini CLI** | Clone to `~/.gemini/ecological-agent-skills/skills/`. Skills are auto-discovered |
| **GitHub Copilot** | Clone into workspace. Reference `AGENT_CONTEXT.md` in `.github/copilot-instructions.md` |
| **Cursor** | Clone into workspace. Add `AGENT_CONTEXT.md` path to Cursor Rules (`.cursor/rules/`) |
| **Windsurf** | Clone into workspace. Reference in `.windsurfrules` |
| **Any other agent** | Place at `.agent/skills/` in your project root, or point the agent to `AGENT_CONTEXT.md` directly |

### Environment setup (for running scripts)

```bash
# Python + R environment via conda
conda env create -f environment.yaml
conda activate eco-skills

# R packages via renv (inside R session)
renv::restore()
```

---

## Core Concepts

**Skills** are self-contained analysis modules. Each skill lives in its own directory with:
- `SKILL.md` — instructions the agent reads before executing
- `resources/` — reference guides, checklists, decision tables
- `scripts/` — R and Python scripts the agent can run
- `examples/` — worked examples and prompt templates

**Workflows** chain multiple skills into end-to-end pipelines (e.g., data cleaning → modeling → validation → reporting).

**Decision Points** are built into every skill and workflow — conditional logic that tells the agent what to do when AUC is too low, sample size is insufficient, or assumptions are violated.

---

## Skills (17)

### Foundation (Phase 1)

| # | Skill | Domain |
|---|-------|--------|
| 1 | `ecological-data-foundation` | Data ingestion, QA, schema |
| 2 | `geoprocessing-for-ecology` | CRS, raster, vector, spatial ops |
| 3 | `biostatistics-workbench` | Tests, GLM/GLMM, effect sizes |
| 4 | `predictive-modeling-best-practices` | CV, tuning, leakage, collinearity |
| 12 | `reproducible-ecology-pipeline` | Traceability, audit, checklist |

### Modeling (Phase 2)

| # | Skill | Domain |
|---|-------|--------|
| 5 | `model-validation-and-uncertainty` | Metrics, calibration, sensitivity |
| 6 | `species-distribution-modeling` | SDM/ENM full pipeline |
| 9 | `ecological-impact-assessment` | BACI, fragmentation, pressure |
| 10 | `environmental-time-series` | Trend, seasonality, breakpoint |

### Specialist (Phase 3)

| # | Skill | Domain |
|---|-------|--------|
| 7 | `occupancy-and-detection` | Occupancy models, detectability |
| 8 | `community-ecology-ordination` | NMDS, PCA, diversity, clustering |
| 11 | `ecosystem-services-assessment` | ES indicators, valuation |

### Advanced (Phase 4)

| # | Skill | Domain |
|---|-------|--------|
| 13 | `camera-trap-processing` | Detection events, RAI, diel activity, Dhat4 overlap |
| 14 | `acoustic-monitoring` | ACI/NDSI indices, BirdNET detection, soundscape ecology |
| 15 | `landscape-connectivity` | IIC, PC, dPC, Circuitscape, resistance surfaces |
| 16 | `population-viability-analysis` | Leslie/Lefkovitch lambda, stochastic PVA, IUCN Criterion E |
| 17 | `spatial-prioritization` | prioritizr ILP, 30x30 targets, BLM calibration, irreplaceability |

See [CATALOG.md](CATALOG.md) for full metadata, inputs, outputs, and workflow linkages.

---

## Workflows (13)

| Workflow | Skills Used | Purpose |
|----------|-------------|---------|
| `run-sdm-study` | 1 → 2 → 4 → 6 → 5 → 12 | Species distribution modeling |
| `assess-ecological-impact` | 1 → 2 → 9 → 3 → 5 → 12 | BACI impact analysis |
| `analyze-community-structure` | 1 → 3 → 8 → 5 → 12 | Community ordination |
| `build-fire-risk-map` | 1 → 2 → 10 → 4 → 5 → 9 | Fire risk spatial model |
| `run-occupancy-analysis` | 1 → 3 → 7 → 5 → 12 | Occupancy with imperfect detection |
| `analyze-environmental-change` | 1 → 2 → 10 → 9 → 12 | Environmental time series |
| `assess-ecosystem-services` | 1 → 2 → 11 → 3 → 12 | ES valuation |
| `produce-technical-report` | 12 → template → synthesis | Report generation |
| `run-multispecies-screening` | 1 → 2 → 4 → 6 → 5 | Rapid multi-species SDM |
| `run-camera-trap-occupancy` | 1 → 13 → 7 → 5 → 12 | Camera trap to occupancy |
| `assess-landscape-connectivity` | 1 → 2 → 15 → 5 → 12 | Corridor and patch importance |
| `run-population-viability` | 1 → 3 → 16 → 5 → 12 | PVA and extinction risk |
| `run-conservation-prioritization` | 1 → 2 → 6 → 17 → 12 | Reserve network design |

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

## Examples (14)

| Region | Example | Analysis |
|--------|---------|----------|
| Amazon, Brazil | Jaguar | SDM |
| Cerrado, Brazil | Giant Anteater | SDM |
| Atlantic Forest, Brazil | Bird community | Community ordination |
| Atlantic Forest, Brazil | Puma | Occupancy |
| Atlantic Forest, Brazil | Road construction | BACI impact |
| Atlantic Forest, Brazil | Ecosystem services | ES valuation |
| Amazon reservoirs | Phytoplankton | Community shift |
| Western Europe | Grey Wolf | SDM + recolonization + conflict |
| Eastern Australia | Koala | SDM + climate change + MOP |
| Indo-Pacific | Reef fish (987 spp.) | Beta diversity + PERMANOVA |
| Central Himalayas | Snow Leopard | Occupancy + camera trap |
| Borneo | Tropical forest | BFAST + MESH + BACI |
| Arctic (Greenland/Canada) | Tundra vegetation | NDVI greening |
| Holarctic (global) | Red Fox | Fully reproducible SDM |

See [`docs/global-examples-index.md`](docs/global-examples-index.md) for full details with data sources and DOIs.

---

## Documentation

| Document | Description |
|----------|-------------|
| [`docs/theoretical-foundations.md`](docs/theoretical-foundations.md) | Citable justifications for 10 methodological decisions with primary references |
| [`docs/global-examples-index.md`](docs/global-examples-index.md) | Inventory of all 14 examples with geographic and taxonomic coverage |
| [`docs/comparison-with-alternatives.md`](docs/comparison-with-alternatives.md) | Comparison vs. Wallace, biomod2, kuenm, ENMTML, SDMtoolbox, Zonation, Vortex |
| [`CATALOG.md`](CATALOG.md) | Skill-level metadata: inputs, outputs, trigger keywords, workflow linkages |

---

## Repository Structure

```
ecological-agent-skills/
├── AGENT_CONTEXT.md              ← rules for AI agents (read first)
├── CATALOG.md                    ← skill index with metadata
├── CITATION.cff                  ← citation metadata
├── CHANGELOG.md                  ← version history
├── CONTRIBUTING.md               ← contributor guidelines
├── KNOWN_ISSUES.md               ← documented issues with workarounds
├── RELEASE_CHECKLIST.md          ← release process
├── environment.yaml              ← conda environment (Python + R)
├── renv.lock                     ← R package lock file
├── skills/                       ← 17 modular skills
│   ├── SKILL_INDEX.json          ← machine-readable skill registry
│   └── <skill-name>/
│       ├── SKILL.md              ← main instructions
│       ├── resources/            ← checklists, glossaries, templates
│       ├── examples/             ← usage prompt examples
│       └── scripts/              ← R/Python helpers
├── workflows/                    ← 13 multi-step playbooks
│   └── <workflow-name>/
│       └── WORKFLOW.md
├── templates/                    ← reusable prompts, reports, checklists
├── examples/                     ← 14 worked examples (6 continents)
├── docs/                         ← theoretical foundations, comparisons
├── tests/                        ← pytest + testthat + 585 CI checks
│   ├── ci_check.sh               ← structural integrity checker
│   ├── python/                   ← 19 pytest test files
│   ├── r/                        ← 18 testthat test files
│   ├── data/                     ← 11 test CSVs
│   ├── regression/               ← reference-based regression tests
│   └── agent_smoke/              ← 15 agent routing validation cases
└── .github/workflows/ci.yml      ← GitHub Actions CI
```

---

## Implementation Roadmap

| Phase | Skills | Status |
|-------|--------|--------|
| **Phase 1** — Foundation | ecological-data-foundation, geoprocessing-for-ecology, biostatistics-workbench, predictive-modeling-best-practices, reproducible-ecology-pipeline | Complete |
| **Phase 2** — Modeling | model-validation-and-uncertainty, species-distribution-modeling, ecological-impact-assessment, environmental-time-series | Complete |
| **Phase 3** — Specialist | occupancy-and-detection, community-ecology-ordination, ecosystem-services-assessment | Complete |
| **Phase 4** — Advanced | camera-trap-processing, acoustic-monitoring, landscape-connectivity, population-viability-analysis, spatial-prioritization | Complete |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

Follow the standard skill packaging pattern: one directory per skill, `SKILL.md` as the entry point, with optional `resources/`, `examples/`, and `scripts/` subdirectories.

---

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE) or later. See [`CITATION.cff`](CITATION.cff) for citation metadata.
