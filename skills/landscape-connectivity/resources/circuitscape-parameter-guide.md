---
resource_id: circuitscape-parameter-guide
skill_id: landscape-connectivity
---

# Circuitscape Parameter Guide

## What Circuitscape Models

Circuitscape applies circuit theory to landscape connectivity. Each raster cell is a resistor; current flows from source to ground nodes. **High current = high movement probability.** Unlike least-cost paths (single path), Circuitscape identifies all possible movement paths simultaneously, making it robust to barrier uncertainty.

**When to use Circuitscape:**
- Species with exploratory or random-walk dispersal (amphibians, many invertebrates)
- Gene flow modelling (isolation by resistance)
- Identifying multiple corridors and bottlenecks simultaneously

**When least-cost path may be preferred:**
- Species with directed, optimal-path movement (large carnivores following trails)
- Fine-resolution analysis where single corridors are sufficient

---

## Key Parameters

| Parameter | Options | Recommended default | Effect |
|-----------|---------|---------------------|--------|
| `scenario` | `pairwise`, `one-to-all`, `all-to-one` | `pairwise` | Analysis mode |
| `data_type` | `raster`, `network` | `raster` | Input format |
| `resistance_file` | path to .asc/.tif | — | Resistance surface |
| `point_file` | path to focal nodes .shp | — | Source/destination points |
| `write_cum_cur_map_only` | True/False | True (pairwise sums) | Output cumulative vs all pairwise maps |
| `log_transform_maps` | True/False | True | Log-scale current maps easier to visualise |
| `compress_grids` | True/False | True | Reduce output file size |
| `solver` | `cg+amg`, `cholmod` | `cg+amg` | Large rasters; cholmod for small/medium |
| `max_parallel` | int | n_cores - 1 | Parallelisation |

---

## Running Circuitscape from R (via System Call)

```r
# Usage: source("run_circuitscape.R")
suppressPackageStartupMessages(library(terra))

run_circuitscape <- function(resistance_tif, focal_points_shp, output_dir,
                              scenario = "pairwise", solver = "cg+amg") {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  # Export resistance as .asc (Circuitscape requires ASCII grid or GeoTIFF)
  res <- rast(resistance_tif)
  asc_path <- file.path(output_dir, "resistance.asc")
  writeRaster(res, asc_path, filetype = "AAIGrid", overwrite = TRUE)

  # Write Circuitscape INI configuration
  ini_path <- file.path(output_dir, "cs_config.ini")
  ini_content <- sprintf(
    "[circuitscape options]
scenario = %s
data_type = raster
resistance_file = %s
point_file = %s
output_file = %s
write_cum_cur_map_only = True
log_transform_maps = True
compress_grids = True
solver = %s
max_parallel = %d
",
    scenario,
    normalizePath(asc_path),
    normalizePath(focal_points_shp),
    normalizePath(file.path(output_dir, "cs_output")),
    solver,
    max(1L, parallel::detectCores() - 1L)
  )
  writeLines(ini_content, ini_path)

  # Call Circuitscape (must be installed and on PATH)
  cmd <- sprintf("cs_run.py %s", shQuote(ini_path))
  ret <- system(cmd)
  if (ret != 0) warning("Circuitscape returned non-zero exit code: ", ret)
  return(file.path(output_dir, "cs_output_cum_curmap.asc"))
}
```

---

## Interpreting Circuitscape Output Maps

| Output file | What it shows |
|-------------|--------------|
| `*_cum_curmap.asc` | Summed current across all pairwise flows — identifies corridors |
| `*_resistances.out` | Effective resistance between each pair of nodes |
| `*_curmap_X_Y.asc` | Current map for specific node pair X→Y |

### Post-processing current map in R

```r
suppressPackageStartupMessages(library(terra))

cur <- rast("outputs/circuitscape/cs_output_cum_curmap.asc")

# Log-scale for visualisation
cur_log <- log1p(cur)

# Identify pinch points: cells with high current in narrow flow paths
# Threshold: top 5% of current values
q95 <- quantile(values(cur_log), 0.95, na.rm = TRUE)
pinchpoints <- cur_log >= q95
writeRaster(pinchpoints, "outputs/circuitscape/pinchpoints.tif", overwrite = TRUE)
```

---

## Choosing Focal Nodes

| Scenario | Recommended focal nodes |
|----------|------------------------|
| Cross-landscape connectivity | Large core habitat patches (> 100 ha) |
| Corridor between two areas | Source and destination patches only |
| Full landscape assessment | All patches > minimum size threshold |
| Genetic sampling sites | Population sampling locations |

**Rule:** Keep focal node count ≤ 50 for pairwise scenario on standard hardware. More nodes → O(n²) compute time.

---

## Computational Considerations

| Raster resolution | Focal nodes | Typical runtime | Solver recommendation |
|------------------|-------------|----------------|----------------------|
| 30 m, 10×10 km extent | 20 | 2–5 min | cg+amg |
| 30 m, 100×100 km extent | 50 | 30–90 min | cg+amg |
| 10 m, 50×50 km extent | 30 | 2–8 h | cholmod or HPC |
| 1 m, any extent | — | Not feasible | Resample to ≥ 10 m |

**Tip:** Resample resistance raster to the coarsest resolution that still captures key barriers (e.g., roads, rivers). Test with 100 m resolution first; refine if necessary.

---

## Pitfalls

- **Current maps conflate corridors with high-permeability areas:** High current can result from many paths OR from a single wide, low-resistance path. Always check raster context (road maps, imagery) around high-current cells.
- **Focal nodes inside high-resistance cells:** Circuitscape places current sources at node locations. If a node is on a road (high resistance), effective resistance will be artificially inflated. Snap nodes to nearest low-resistance cell.
- **Ignoring NoData handling:** NoData cells are treated as barriers. Ensure NoData correctly represents barriers (not missing data). Fill missing cells with average neighbourhood resistance before analysis.
- **Comparing Circuitscape between landscapes without standardisation:** Cumulative current scales with number of focal nodes and landscape size. Only compare effective resistance values, not raw current maps, across landscapes.
- **Using Circuitscape for directed movement:** Circuitscape is symmetric. For strongly directional dispersal (stream-mediated, prevailing winds), use directional least-cost models instead.

---

## References

- McRae, B.H., Dickson, B.G., Keitt, T.H. & Shah, V.B. (2008). Using circuit theory to model connectivity in ecology, evolution, and conservation. *Ecology*, 89(10), 2712–2724. DOI: 10.1890/07-1861.1
- Shah, V.B. & McRae, B.H. (2008). Circuitscape: a tool for landscape ecology. *Proceedings of the 7th Python in Science Conference*, 62–65.
- Dickson, B.G. et al. (2019). Informing strategic efforts to expand and connect protected areas using a model of ecological flow, with application to the western United States. *Conservation Letters*, 12(3), e12647. DOI: 10.1111/conl.12647
