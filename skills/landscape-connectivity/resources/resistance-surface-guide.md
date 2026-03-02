---
resource_id: resistance-surface-guide
skill_id: landscape-connectivity
---

# Resistance Surface Construction Guide

## Conceptual Framework

A **resistance surface** (also called a cost surface) assigns a movement cost to each raster cell based on the permeability of that land cover or habitat feature to the focal species. Least-cost path and Circuitscape analyses use resistance surfaces to model functionally realistic movement corridors.

**Resistance ≠ inverse of habitat suitability.** Resistance should reflect movement cost, not habitat preference. A species may move through unsuitable habitat quickly (low resistance) or slowly (high resistance).

---

## Resistance Assignment Methods

| Method | Data requirement | Strengths | Weaknesses |
|--------|-----------------|-----------|------------|
| **Expert opinion** | Land cover map + expert | Fast, applicable when no telemetry | Subjective; high uncertainty |
| **Inverse SDM suitability** | Occurrence + env layers | Empirically grounded | Conflates habitat use with movement |
| **Empirical movement model** | GPS telemetry, step-selection | Most ecologically valid | Requires large GPS datasets |
| **Gene flow (IBR)** | Population genetics + landscape | Tests functional connectivity | Requires population genetics |

---

## Resistance Value Tables by Land Cover

### Example: Forest carnivore (jaguar-like)

| Land cover class | Resistance | Rationale |
|-----------------|-----------|-----------|
| Dense tropical forest | 1 (minimum) | Preferred habitat |
| Secondary forest | 3 | Suboptimal but permeable |
| Cerrado/savanna | 5 | Used for movement |
| Shrubland | 8 | Low canopy; avoidance |
| Pasture (low density) | 20 | Crosses at night |
| Pasture (high density cattle) | 40 | Crossing risk; human presence |
| Roads (unpaved) | 30 | Crossing risk |
| Roads (paved, 2-lane) | 80 | High mortality risk |
| Highways (4-lane) | 200 | Effective barrier |
| Urban | 500 | Near-absolute barrier |
| Water (rivers > 200 m) | 100 | Species-dependent |

**Note:** Resistance values are relative. Scale (1–10 vs 1–1000) does not affect relative results but affects absolute cost distances.

---

## Building a Resistance Raster in R

```r
# Usage: source this block or call from resistance_surface.R
suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(dplyr))

# Inputs:
#   lc_raster: SpatRaster with integer land cover codes
#   resistance_table: data.frame with columns 'lc_code' and 'resistance'

build_resistance_raster <- function(lc_raster, resistance_table) {
  # Create reclassification matrix: from, to, becomes
  rcl_mat <- as.matrix(
    resistance_table %>%
      arrange(lc_code) %>%
      mutate(from = lc_code - 0.5, to = lc_code + 0.5) %>%
      select(from, to, resistance)
  )
  res_raster <- classify(lc_raster, rcl_mat, include.lowest = TRUE)
  return(res_raster)
}

# Example usage
lc <- rast("data/landcover_2024.tif")
rt <- read.csv("data/resistance_values.csv")  # columns: lc_code, resistance
resistance <- build_resistance_raster(lc, rt)
writeRaster(resistance, "outputs/resistance_surface.tif", overwrite = TRUE)
```

---

## Multi-Layer Resistance (Additive/Multiplicative)

When multiple landscape features contribute to resistance (land cover + road proximity + slope):

```r
suppressPackageStartupMessages(library(terra))

lc_res    <- rast("outputs/lc_resistance.tif")
road_res  <- rast("outputs/road_resistance.tif")   # distance-weighted road effect
slope_res <- rast("outputs/slope_resistance.tif")  # penalise steep terrain

# Multiplicative combination (common for Circuitscape)
combined <- lc_res * road_res * slope_res
combined <- combined / global(combined, "min")[[1]]  # rescale min to 1

writeRaster(combined, "outputs/resistance_combined.tif", overwrite = TRUE)
```

**Caution:** Multiplicative combinations can generate extreme values. Cap at a maximum (e.g., 1000) to avoid numerical instability in Circuitscape.

---

## Slope-Based Resistance (Terrain)

```r
dem <- rast("data/dem_30m.tif")
slope_deg <- terrain(dem, v = "slope", unit = "degrees")

# Non-linear cost: steep slopes exponentially costly
slope_res <- exp(slope_deg / 15)   # doubles every ~10°
slope_res <- slope_res / global(slope_res, "min")[[1]]
```

---

## Validation Approaches

| Method | What it tests |
|--------|--------------|
| Least-cost path overlay with GPS tracks | Are predicted corridors used by GPS-tracked individuals? |
| Isolation by resistance (IBR) vs IBD | Does resistance predict genetic differentiation better than Euclidean distance? |
| Leave-one-out cross-validation | Do alternative resistance surfaces predict held-out movement events? |
| Expert review | Are corridor predictions ecologically sensible? |

---

## Pitfalls

- **Uniform resistance for entire land cover class:** Resistance often varies within a class (e.g., pasture near roads vs interior pasture). Consider adding a road-proximity effect layer.
- **Resistance values assigned without uncertainty bounds:** Always report the sensitivity of corridor predictions to ±50% changes in key resistance values.
- **Ignoring patch boundaries in cost surface:** Resistance inside source/destination patches should be set to minimum (1) to avoid spuriously increasing corridor cost.
- **Using suitability maps directly as inverse resistance:** SDM suitability predicts habitat use, not movement cost. A species may traverse unsuitable habitat rapidly, warranting low resistance.
- **Resolution mismatch:** Resistance raster cell size should be ≤ 1/10 of the species' mean step length to capture fine-scale barriers.

---

## References

- Zeller, K.A., McGarigal, K. & Whiteley, A.R. (2012). Estimating landscape resistance to movement: a review. *Landscape Ecology*, 27(6), 777–797. DOI: 10.1007/s10980-012-9737-0
- Pullinger, M.G. & Johnson, C.J. (2010). Maintaining or restoring connectivity of modified landscapes. *Biological Conservation*, 143(6), 1483–1493. DOI: 10.1016/j.biocon.2010.03.019
- McRae, B.H. & Beier, P. (2007). Circuit theory predicts gene flow in plant and animal populations. *PNAS*, 104(50), 19885–19890. DOI: 10.1073/pnas.0706568104
