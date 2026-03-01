# Landscape Fragmentation Metrics Reference

Computed with `landscapemetrics` (R) or FRAGSTATS. Always report the spatial resolution used.

## Patch-Level Metrics

| Metric | Abbreviation | Unit | Description |
|--------|-------------|------|-------------|
| Patch area | AREA | ha | Area of each patch |
| Perimeter | PERIM | m | Total perimeter of patch |
| Perimeter-area ratio | PARA | m/ha | Shape complexity; higher = more irregular |
| Shape index | SHAPE | — | PERIM / (4√AREA); 1 = square; higher = complex |
| Fractal dimension index | FRAC | — | 1–2; higher = more complex shape |
| Core area | CORE | ha | Area > edge distance from patch edge |
| Core area index | CAI | % | % of patch that is core area |
| Proximity index | PROX | — | Area/distance to nearest same-class patch |

## Class-Level Metrics

| Metric | Abbreviation | Unit | Description |
|--------|-------------|------|-------------|
| Total class area | CA | ha | Sum of all patch areas |
| Number of patches | NP | count | Count of patches |
| Patch density | PD | n/100 ha | NP per 100 ha landscape |
| Largest patch index | LPI | % | % of landscape in largest patch |
| Mean patch area | AREA_MN | ha | Average patch size |
| Mean patch shape index | SHAPE_MN | — | Average patch shape complexity |
| Edge density | ED | m/ha | Total edge length per ha |
| Mean nearest-neighbour distance | ENN_MN | m | Isolation between patches |
| Aggregation index | AI | % | 0–100; 100 = fully aggregated |
| Splitting index | SPLIT | — | Fragmentation; 1 = unfragmented |
| Effective mesh size | MESH | ha | Probability two random points in same patch × landscape area |
| Landscape shape index | LSI | — | Total edge / min edge for same total area |

## Connectivity Metrics

| Metric | Description | R package |
|--------|-------------|----------|
| COHESION | Patch cohesion index; physical connectedness | landscapemetrics |
| CONNECT | Functional connectivity based on distance threshold | landscapemetrics |
| IIC | Integral Index of Connectivity (graph-based) | conefor / igraph |
| PC | Probability of Connectivity | conefor |
| dPC, dIIC | Importance of each patch to overall connectivity | conefor |

## Key Metrics for Impact Assessment

Recommended minimum set for before/after comparison:

1. **CA** — total habitat area (has it declined?)
2. **NP** — number of patches (has fragmentation increased?)
3. **LPI** — largest patch index (is the main mass intact?)
4. **ED** — edge density (are edge effects increasing?)
5. **MESH** — effective mesh size (functional fragmentation — most comprehensive single metric)
6. **COHESION** — physical connectivity of patches

## R Code Template

```r
library(terra)
library(landscapemetrics)

lc <- rast("landcover.tif")
habitat_class <- 3  # class code for the habitat of interest

# Patch-level
patch_metrics <- calculate_lsm(lc, what = c("lsm_p_area", "lsm_p_shape", "lsm_p_core"),
                                 class = habitat_class)

# Class-level
class_metrics <- calculate_lsm(lc, what = c("lsm_c_ca", "lsm_c_np", "lsm_c_lpi",
                                              "lsm_c_ed", "lsm_c_mesh", "lsm_c_cohesion"),
                                 class = habitat_class)
print(class_metrics)
```

## Interpreting MESH (Effective Mesh Size)

MESH (m_eff) = Σ(Ai²) / A_total

where Ai = area of patch i, A_total = total landscape area.

- **High MESH** = landscape dominated by large, connected patches → low functional fragmentation
- **Low MESH** = landscape cut into many small patches → high fragmentation
- MESH is the **most recommended single metric** for summarising fragmentation because it is sensitive to both patch size and patch number and is interpretable in area units (ha).

Example: MESH drops from 5,000 ha to 800 ha → a person starting at a random point is now 6× more likely to be confined to a smaller patch.
