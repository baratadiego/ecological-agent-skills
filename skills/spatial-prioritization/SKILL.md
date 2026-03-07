---
name: spatial-prioritization
description: "Solves systematic conservation planning problems using integer linear programming (prioritizr), Marxan, or Zonation for protected area design. Use this skill when the user mentions conservation planning, 30x30 targets, Marxan, Zonation, prioritizr, irreplaceability, boundary length modifier (BLM), minimum set problems, representation targets, systematic conservation, or protected area network design."
skill_version: 1.0.0
---

# Skill: spatial-prioritization

**Domain:** Conservation planning · prioritizr · Marxan · Zonation · Reserve design · 30×30

---

## Purpose

Guides the agent through systematic conservation planning to identify priority areas that efficiently represent biodiversity targets under cost constraints. Covers problem formulation (minimum-set, maximum-coverage), planning unit design, target definition, cost surface selection, connectivity penalties, and solving with integer linear programming. Produces priority maps, irreplaceability surfaces, and cost-effectiveness curves for decision-makers.

---

## When to Invoke

Invoke this skill when:

- The user requests conservation area prioritisation, gap analysis, or reserve design
- Systematic conservation planning (Marxan, Zonation, prioritizr) is needed
- Protected area network adequacy must be evaluated against biodiversity targets
- A 30×30 or other area-based conservation target must be spatially allocated
- Trade-offs between cost and biodiversity representation must be quantified

**trigger_keywords:** `conservation planning`, `protected areas`, `Marxan`, `Zonation`, `prioritizr`, `reserve design`, `systematic conservation`, `30x30`, `biodiversity target`, `irreplaceability`, `complementarity`, `gap analysis`, `cost-effectiveness`, `planning unit`, `boundary length modifier`

---

## Inputs

| Input | Format | Required |
|---|---|---|
| Species suitability or distribution stack | GeoTIFF (multiband) | Required |
| Cost surface raster | GeoTIFF | Required |
| Study area polygon | SHP or GPKG | Required |
| Conservation targets per species (%) | CSV | Recommended |
| Locked-in areas (existing protected areas) | SHP or GPKG | Optional |
| Locked-out areas (exclusion zones) | SHP or GPKG | Optional |
| Connectivity layer (habitat patches or resistance surface) | GeoTIFF or GPKG | Optional |

---

## Outputs

| Output | Description |
|---|---|
| `priority_solution.tif` | Binary raster: 1 = selected planning unit, 0 = not selected |
| `irreplaceability.tif` | Selection frequency across portfolio of near-optimal solutions |
| `targets_achieved.csv` | % of target met per species/feature in the solution |
| `cost_effectiveness_curve.png` | Total cost vs. % targets achieved across budget levels |
| `solution_summary.md` | Narrative: total area, cost, targets met, connectivity score |
| `sensitivity_results.csv` | Solution metrics across BLM and target combinations |

---

## Steps

1. **Define planning units**
   Use the study area raster cells as planning units (pixel-based) or create a hexagonal
   grid at the appropriate resolution. Confirm CRS matches all input layers.
   Record planning unit size and type in `decision_log.md`.

2. **Prepare features (biodiversity layers)**
   Load species suitability stack from `species-distribution-modeling` skill.
   Optionally include ecosystem service layers from `ecosystem-services-assessment`.
   Normalise all feature layers to [0, 1] if combining different units.

3. **Define targets**
   Default: 30% of each species' total distribution within the study area.
   If IUCN threat status data are available, apply higher targets for threatened species
   (CR: 50%, EN: 40%, VU: 30%).
   Save target table as `params/targets.csv`.

4. **Build and solve the prioritisation problem** *(invoke `run_prioritization.R`)*
   Create problem with `prioritizr::problem()`, add targets, cost, and penalties.
   Set locked-in (existing protected areas) and locked-out (excluded) zones.
   Add connectivity penalty using `add_boundary_penalties(penalty = BLM)`.
   Solve with `highs` solver (default) or `symphony` (fallback).

5. **Evaluate solution**
   Check `targets_achieved.csv`: all features must reach ≥ 80% of target.
   If any feature < 80%: budget is insufficient; run `prioritization_sensitivity.R`.
   Calculate irreplaceability as selection frequency across 100 near-optimal solutions.

6. **Generate cost-effectiveness curve** *(invoke `prioritization_sensitivity.R`)*
   Solve at 5 budget levels (50%, 75%, 100%, 125%, 150% of selected solution cost).
   Plot cumulative targets achieved vs. total cost.
   Present to decision-maker as trade-off summary.

7. **Validate and document**
   Verify `priority_solution.tif` covers the expected % of study area.
   Record solver used, BLM value, target definitions, and any infeasible scenarios
   in `decision_log.md`.

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| No feasible solution found in 1000 iterations | Budget too restrictive or targets unachievable | Relax targets (reduce by 5% increments) or increase budget; document trade-off |
| < 80% of targets achieved in solution | Budget insufficient for full representation | Present cost-effectiveness curve; let decision-maker choose acceptable representation level |
| Irreplaceability > 0.8 for a deforested area | Critical irreplaceable area is already lost | Escalate to restoration analysis; include in gap analysis narrative |
| BLM = 0 gives highly fragmented solution | Connectivity not enforced | Calibrate BLM: increase until solution compactness is acceptable without losing > 10% of targets |
| Existing protected areas already meet targets | No additional areas needed | Perform gap analysis only; report which species remain under-represented |

---

## Key Decisions to Document

Record the following in `decision_log.md` after running this skill:

- Planning unit type (pixel vs. hexagon), size, and CRS used
- Target percentages per feature and their justification (30×30, IUCN status, etc.)
- Cost surface used (area proxy, economic value, opportunity cost) and its source
- BLM value applied and how it was calibrated
- Solver used (highs, symphony, gurobi) and whether any scenarios were infeasible

---

## Tools and Libraries

**R**
```r
suppressPackageStartupMessages(library(prioritizr))   # conservation planning problem
suppressPackageStartupMessages(library(highs))        # HiGHS solver (recommended, free)
suppressPackageStartupMessages(library(terra))        # raster handling
suppressPackageStartupMessages(library(sf))           # vector handling
suppressPackageStartupMessages(library(dplyr))        # data manipulation
suppressPackageStartupMessages(library(ggplot2))      # cost-effectiveness plots
```

**Python** *(support layer only — core analysis in R)*
```python
import geopandas as gpd     # spatial data inspection
import rasterio             # raster inspection
import numpy as np          # array operations
from pathlib import Path    # file system
```

---

## Resources

- [`skills/spatial-prioritization/resources/prioritizr-formulation-guide.md`](resources/prioritizr-formulation-guide.md) — Problem types, planning units, targets, costs, BLM, solvers, and locked zones
- [`skills/spatial-prioritization/resources/marxan-vs-prioritizr-comparison.md`](resources/marxan-vs-prioritizr-comparison.md) — Comparison of Marxan, Zonation, prioritizr, and OPT; migration guide
- [`skills/spatial-prioritization/resources/cost-surface-reference.md`](resources/cost-surface-reference.md) — Cost proxy options, global data sources, normalisation, and sensitivity to cost
- [`skills/spatial-prioritization/resources/representation-targets-guide.md`](resources/representation-targets-guide.md) — 10%/17%/30% targets, species-level targets, fine-filter vs. coarse-filter approaches

---

## Notes

- **prioritizr requires a solver:** The `highs` package provides a free, high-performance solver sufficient for most problems. `gurobi` is faster for very large problems but requires an academic licence. Do not attempt to solve without an explicit solver; `prioritizr` will error.
- **Boundary length modifier (BLM) requires calibration:** BLM = 0 produces the cheapest but most fragmented solution. Too high a BLM increases cost dramatically. Calibrate by plotting cost vs. total boundary length across BLM values (built into `prioritization_sensitivity.R`).
- **Irreplaceability ≠ priority:** A planning unit with irreplaceability = 1.0 is selected in every near-optimal solution but may be inexpensive. A unit with irreplaceability = 0.3 is selected only in some solutions. Report both the solution map and irreplaceability map.
- **Planning unit size affects resolution and computation time:** 1 km² pixels for a country-scale analysis may produce millions of planning units, making ILP very slow. Aggregate to 10 km² for national-scale problems; use 1 km² only for regional scales.
- **Locked-in areas must be in the same CRS as planning units:** CRS mismatch between existing protected areas and planning units is a common error that causes protected areas to be ignored in the solution.
