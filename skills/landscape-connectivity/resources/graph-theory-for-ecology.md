---
resource_id: graph-theory-for-ecology
skill_id: landscape-connectivity
---

# Graph Theory for Landscape Ecology

## Core Connectivity Metrics

| Metric | Formula | Scale | Interpretation | Requires |
|--------|---------|-------|----------------|---------|
| **IIC** (Integral Index of Connectivity) | (1/A²) Σ (aᵢ × aⱼ) / (1 + nᵢⱼ) | 0–1 | Landscape-level binary connectivity | Dispersal threshold |
| **PC** (Probability of Connectivity) | (1/A²) Σ pᵢⱼ* × aᵢ × aⱼ | 0–1 | Landscape-level probabilistic connectivity | Dispersal function |
| **dIIC** (patch contribution to IIC) | [(IIC − IICremove) / IIC] × 100 | % | Importance of patch i to overall IIC | — |
| **dPC** (patch contribution to PC) | [(PC − PCremove) / PC] × 100 | % | Importance of patch i to overall PC | — |
| **BC** (Betweenness Centrality) | fraction of shortest paths through node i | 0–1 | Stepping stone / corridor value | — |
| **EC** (Eigenvalue Centrality) | dominant eigenvector component | 0–∞ | Well-connected patches in dense cluster | — |

**Landscape area A:** total study area (same units as patch areas).

---

## When to Use IIC vs PC

| Condition | Recommended metric | Reason |
|-----------|--------------------|--------|
| Dispersal threshold unknown | IIC | Binary; only requires yes/no connection |
| Dispersal probability decay known | PC | Incorporates full movement function |
| Comparing two landscapes | dIIC, dPC | Relative patch importance is comparable |
| Identifying stepping stones | BC | Patches with high BC are corridor nodes |
| Data on gene flow or mark-recapture | PC | Can calibrate pᵢⱼ* with empirical data |

---

## Computing IIC and dPC in R (igraph)

```r
# Usage: source("connectivity_metrics.R")
suppressPackageStartupMessages(library(igraph))
suppressPackageStartupMessages(library(sf))

# Patches: sf polygon layer with attribute 'area_ha'
# Dispersal threshold: dmax in map units (e.g., metres)

compute_iic <- function(patches, dmax) {
  n   <- nrow(patches)
  A   <- sum(patches$area_ha)
  coords <- st_centroid(patches) %>% st_coordinates()
  dist_mat <- as.matrix(dist(coords))

  # Binary adjacency: connected if distance < dmax
  adj <- (dist_mat < dmax) * 1
  diag(adj) <- 0
  g <- graph_from_adjacency_matrix(adj, mode = "undirected")

  # Shortest paths (hop count)
  sp <- distances(g, algorithm = "bfs")

  IIC_num <- 0
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      nij <- sp[i, j]
      if (is.finite(nij)) {
        IIC_num <- IIC_num +
          (patches$area_ha[i] * patches$area_ha[j]) / (1 + nij)
      }
    }
  }
  IIC <- IIC_num / A^2
  return(IIC)
}

# Patch importance: dIIC
compute_diic <- function(patches, dmax) {
  IIC_full <- compute_iic(patches, dmax)
  diic_vec  <- numeric(nrow(patches))
  for (i in seq_len(nrow(patches))) {
    IIC_i     <- compute_iic(patches[-i, ], dmax)
    diic_vec[i] <- (IIC_full - IIC_i) / IIC_full * 100
  }
  patches$dIIC <- diic_vec
  return(patches)
}
```

---

## Interpreting dPC Values

| dPC (%) | Patch importance | Recommended action |
|---------|-----------------|-------------------|
| > 10    | Critical | Highest protection priority; any loss severely disrupts connectivity |
| 5–10    | High | Priority for protection or restoration buffer |
| 1–5     | Moderate | Monitor; stepping-stone function likely |
| < 1     | Low | May contribute if adjacent patches are lost |
| 0       | Isolated | Not connected within dispersal distance; restoration needed first |

---

## Dispersal Distance Sensitivity Analysis

When the species dispersal distance is uncertain, run connectivity across a range:

```r
dmax_values <- c(500, 1000, 2000, 5000)  # metres
results <- lapply(dmax_values, function(d) {
  iic <- compute_iic(patches, dmax = d)
  data.frame(dmax = d, IIC = iic)
})
sens_df <- dplyr::bind_rows(results)
plot(sens_df$dmax, sens_df$IIC, type = "b",
     xlab = "Dispersal distance (m)", ylab = "IIC",
     main = "Connectivity sensitivity to dispersal distance")
```

**Rule:** If IIC changes < 10% across the plausible dmax range → results are robust to dispersal distance uncertainty.

---

## Pitfalls

- **Euclidean vs cost distance:** Graph edges based on straight-line distance ignore barriers (roads, rivers). Use cost distance for species with limited matrix permeability.
- **Patch definition:** Patches defined at too coarse a resolution inflate IIC by merging sub-patches that are not functionally connected.
- **Island patches:** Isolated patches (not connected to any other patch) contribute only their intra-patch value to IIC/PC. Report isolation separately.
- **Directed vs undirected graphs:** Most landscape connectivity models assume undirected movement. For rivers or wind-pollinated species, use directed graphs.
- **Comparing across study areas:** IIC and PC scale with A². Always normalise by landscape area when comparing sites.

---

## References

- Pascual-Hortal, L. & Saura, S. (2006). Comparison and development of new graph-based landscape connectivity indices. *Landscape Ecology*, 21(7), 959–967. DOI: 10.1007/s10980-006-0013-z
- Saura, S. & Torné, J. (2009). Conefor Sensinode 2.2: A software package for quantifying the importance of habitat patches for landscape connectivity. *Environmental Modelling & Software*, 24(1), 135–139. DOI: 10.1016/j.envsoft.2008.05.005
- Urban, D. & Keitt, T. (2001). Landscape connectivity: a graph-theoretic perspective. *Ecology*, 82(5), 1205–1218. DOI: 10.1890/0012-9658(2001)082[1205:LCAGTP]2.0.CO;2
