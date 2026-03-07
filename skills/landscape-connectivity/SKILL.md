---
name: landscape-connectivity
description: "Analyzes landscape connectivity using graph theory, resistance surfaces, and corridor identification for conservation planning. Use this skill when the user mentions habitat connectivity, wildlife corridors, Circuitscape, least-cost paths, resistance surfaces, IIC/dPC connectivity metrics, stepping stones, patch importance ranking, betweenness centrality, fragmentation analysis, landscape graphs, or pinchpoint identification."
skill_version: 1.0.0
---

# Skill: landscape-connectivity

**Domain:** Landscape connectivity · Graph theory · Circuitscape · Corridor · Resistance surface

---

## Purpose

Guides the agent through quantifying structural and functional landscape connectivity, identifying wildlife corridors, and calculating the contribution of individual habitat patches to overall network connectivity. Covers resistance surface construction, graph-based connectivity indices (IIC, PC, dPC), Circuitscape current mapping, and least-cost path analysis for corridor delineation.

---

## When to Invoke

Invoke this skill when:

- The user asks about habitat connectivity, wildlife corridors, or dispersal pathways
- Patches of habitat must be ranked by their importance to overall connectivity
- A resistance surface is needed for Circuitscape or least-cost path modelling
- The impact of habitat loss or fragmentation on connectivity must be quantified
- Gene flow, dispersal barriers, or landscape permeability are the focus

**trigger_keywords:** `habitat connectivity`, `wildlife corridor`, `dispersal`, `gene flow`, `landscape graph`, `resistance surface`, `least-cost path`, `circuit theory`, `Circuitscape`, `IIC`, `PC`, `dPC`, `corridor width`, `patch importance`, `landscape permeability`

---

## Inputs

| Input | Format | Required |
|---|---|---|
| Habitat/land cover raster | GeoTIFF | Required |
| Study area polygon | SHP or GPKG | Required |
| Dispersal distance or dispersal kernel parameters | CSV or text | Required |
| Resistance value table (land cover class → resistance) | CSV | Recommended |
| Existing protected areas or focal nodes | SHP or GPKG | Optional |
| Habitat class codes | Integer codes or CSV lookup | Optional |

---

## Outputs

| Output | Description |
|---|---|
| `patch_metrics.csv` | Area, perimeter, IIC, PC, dIIC, dPC per patch |
| `connectivity_summary.csv` | Global IIC, PC, and top-10 patches by dPC |
| `top_patches_map.tif` | Raster with dPC value per patch |
| `connectivity_graph.png` | Habitat patch network diagram |
| `resistance_surface.tif` | Resistance surface for Circuitscape input |
| `patch_betweenness.csv` | Betweenness centrality per patch (graph metric) |
| `least_cost_paths.gpkg` | Least-cost path lines between patch pairs |

---

## Steps

1. **Prepare habitat patches**
   Load land cover raster and mask to study area using `geoprocessing-for-ecology`.
   Reclassify to binary habitat/non-habitat. Extract discrete habitat patches
   with `terra::patches()` or `landscapemetrics::get_patches()`.
   Filter patches below minimum area threshold (document threshold in `decision_log.md`).

2. **Build resistance surface** *(invoke `resistance_surface.R`)*
   Reclassify land cover using the resistance table.
   Apply optional focal smoothing to avoid hard edges.
   Validate: all land cover classes must have an assigned resistance value.
   Output: `resistance_surface.tif`.

3. **Calculate distance matrix between patches**
   Compute pairwise Euclidean or least-cost distances between patch centroids.
   If dispersal distance threshold is unknown, use 3 values for sensitivity analysis:
   conservative (25th percentile), medium (median), optimistic (75th percentile).

4. **Compute connectivity indices** *(invoke `connectivity_metrics.R`)*
   Calculate IIC and PC for each dispersal distance scenario.
   Compute dIIC and dPC (patch removal importance) for all patches.
   Rank patches by dPC to identify conservation priorities.

5. **Run Circuitscape for corridor mapping** *(optional, requires Circuitscape installed)*
   Export focal nodes (top-N patches by dPC) and resistance surface.
   Run in `all-to-one` mode to produce cumulative current density map.
   Interpret high-current corridors as priority dispersal pathways.

6. **Delineate least-cost paths** *(invoke `connectivity_analysis.py`)*
   Use `scikit-image.graph.route_through_array()` for least-cost paths.
   Output vector lines between top-priority patch pairs.

7. **Validate outputs and record decisions**
   Check dPC values sum approximately to the global PC.
   Record dispersal distance scenario, resistance table source, and minimum patch area
   in `decision_log.md`.

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| Dispersal distance unknown | Sensitivity of results to this parameter is high | Run analysis at 3 distances (conservative, medium, optimistic); report range of outcomes |
| Landscape < 10 patches | Graph metrics statistically unstable | Use fragmentation metrics from ecological-impact-assessment skill instead |
| IIC or PC < 0.01 | Extremely low connectivity | Prioritise restoration before corridor analysis; identify bottleneck patches |
| dPC > 0.8 for a patch already deforested | High-priority patch lost | Escalate to restoration planning; include in gap analysis |
| All patches isolated (no edges at chosen distance) | Threshold too restrictive | Increase dispersal distance or use resistance-based (cost) distance threshold |

---

## Key Decisions to Document

Record the following in `decision_log.md` after running this skill:

- Dispersal distance(s) used and their biological justification
- Source of resistance values (literature, telemetry, expert opinion)
- Minimum patch area threshold applied and rationale
- Whether Circuitscape was run; mode used (pairwise, all-to-one, one-to-all)
- Top-N patches selected for focal node analysis

---

## Tools and Libraries

**R**
```r
suppressPackageStartupMessages(library(terra))              # raster operations
suppressPackageStartupMessages(library(sf))                 # vector operations
suppressPackageStartupMessages(library(landscapemetrics))   # patch extraction and metrics
suppressPackageStartupMessages(library(igraph))             # graph theory (IIC, PC, betweenness)
suppressPackageStartupMessages(library(dplyr))              # data manipulation
suppressPackageStartupMessages(library(ggplot2))            # plotting
```

**Python**
```python
import networkx as nx           # graph metrics (betweenness centrality)
from skimage.graph import route_through_array  # least-cost path
import geopandas as gpd         # vector operations
import rasterio                 # raster reading
import numpy as np              # numerical operations
from pathlib import Path        # file system
```

**CLI**
```bash
# Circuitscape (optional, must be installed)
circuitscape_4_0 <config_file.ini>
# or Julia-based CS4
julia -e "using Circuitscape; compute(<config_file.ini>)"
```

---

## Resources

- [`skills/landscape-connectivity/resources/graph-theory-for-ecology.md`](resources/graph-theory-for-ecology.md) — IIC, PC, dPC formulas, interpretation, and dispersal threshold definition
- [`skills/landscape-connectivity/resources/resistance-surface-guide.md`](resources/resistance-surface-guide.md) — Resistance value assignment by taxon, calibration methods, and Circuitscape export
- [`skills/landscape-connectivity/resources/circuitscape-parameter-guide.md`](resources/circuitscape-parameter-guide.md) — Circuitscape modes, focal nodes, solver selection, and output interpretation

---

## Notes

- **IIC and PC are scale-dependent:** Both indices depend on the total landscape area (`A`). Always report the landscape extent used in calculation to enable comparison across studies.
- **Euclidean distance ≠ functional connectivity:** Distance-based IIC/PC ignores landscape resistance. Use cost-distance for species sensitive to habitat matrix quality (e.g., forest-dependent species crossing agricultural land).
- **Circuitscape can be slow for large landscapes:** For rasters > 10 million cells, use the Julia implementation (Circuitscape.jl) which is 10–50× faster than the Python version.
- **Betweenness centrality is a proxy, not a measure of flow:** High betweenness patches are on many shortest paths but may not have high actual dispersal if resistance is high elsewhere.
- **Patch size confounds dPC:** Large patches tend to have high dPC because their removal drastically reduces total habitat area. Always report patch area alongside dPC to distinguish area effect from connectivity effect.
