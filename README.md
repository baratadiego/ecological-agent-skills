# ecological-agent-skills

A curated skill library for **quantitative ecology** workflows, compatible with the [Antigravity](https://github.com/ecological-agent-skills) agent framework.

This repository provides 12 modular skills and 8 multi-step workflows covering the full spectrum of quantitative ecology: from raw data ingestion and geoprocessing to species distribution modeling, occupancy analysis, community ecology, ecological impact assessment, and reproducible reporting.

---

## Compatibility

These skills are designed for use with **Antigravity**-compatible agents (e.g., Gemini CLI, Claude Code, or any agent that supports the `.agent/skills/` convention).

Install paths:
- **Antigravity / Gemini CLI:** `~/.gemini/ecological-agent-skills/skills/`
- **Generic agent:** `.agent/skills/` (project root)
- **Claude Code:** reference via system prompt or MCP configuration

---

## Repository Structure

```
ecological-agent-skills/
├── README.md
├── CATALOG.md                    ← skill index with metadata
├── skills/                       ← 12 modular skills
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

## Skills (12)

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

## Workflows (8)

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

---

## How to Use Skills

### Natural invocation (Antigravity)
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

## Contributing

Follow the standard skill packaging pattern: one directory per skill, `SKILL.md` as the entry point, with optional `resources/`, `examples/`, and `scripts/` subdirectories.
