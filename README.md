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

## Implementation Roadmap

**Phase 1 (foundation):** `ecological-data-foundation`, `geoprocessing-for-ecology`, `biostatistics-workbench`, `predictive-modeling-best-practices`, `reproducible-ecology-pipeline`

**Phase 2 (modeling):** `model-validation-and-uncertainty`, `species-distribution-modeling`, `ecological-impact-assessment`, `environmental-time-series`

**Phase 3 (specialist):** `occupancy-and-detection`, `community-ecology-ordination`, `ecosystem-services-assessment`

**Phase 4:** Close all 8 workflows.

---

## Contributing

Follow the standard skill packaging pattern: one directory per skill, `SKILL.md` as the entry point, with optional `resources/`, `examples/`, and `scripts/` subdirectories.
