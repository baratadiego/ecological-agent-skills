# Spatial Cross-Validation Guide

## Why Spatial CV?

Standard random k-fold CV assumes independence between train and test folds. Ecological and SDM data are almost always spatially autocorrelated — nearby sites share similar environments and species composition. Random splits leak spatial information across folds, producing optimistically biased performance estimates.

**Rule:** If the response variable is spatially structured (which is almost always true for ecological data), use spatial CV.

## Block CV (Checkerboard / Grid)

Divides the study area into rectangular blocks. Points within the same block are assigned to the same fold.

```r
library(blockCV)
# Auto-select block size based on spatial autocorrelation range
sac <- cv_spatial_autocor(
  x   = occ_sf,             # sf object with presence/background
  column = "response",
  plot = TRUE
)
blocks <- cv_spatial(
  x          = occ_sf,
  column     = "response",
  k          = 5,
  size       = sac$range,   # use autocorrelation range as block size
  hexagon    = FALSE,
  report     = TRUE,
  plot       = TRUE
)
```

## Buffered Leave-One-Out (spatial LOO)

For each test point, exclude all training points within a buffer distance. Computationally expensive but most rigorous for small datasets.

```r
# In ENMeval:
library(ENMeval)
e <- ENMevaluate(
  occs      = occ_coords,
  envs      = predictor_stack,
  bg        = bg_coords,
  algorithm = "maxnet",
  partitions = "block"      # or "checkerboard1", "checkerboard2"
)
```

## Recommended Block Size

The block size should be at least as large as the spatial autocorrelation range of the response variable.

| Spatial resolution | Suggested starting block size |
|--------------------|-------------------------------|
| 1 km | 50–100 km |
| 5 km | 100–200 km |
| 10 km | 200–400 km |
| 25 km (continental) | 500–1000 km |

Always run `cv_spatial_autocor()` to confirm the empirical range for your specific dataset.

## Number of Folds

- **k = 4 or 5:** Standard. Balances bias and variance.
- **k = 10:** For larger datasets (> 500 occurrences).
- **Leave-one-out (LOO):** For very small datasets (< 30 occurrences).

## Checklist Before Running CV

- [ ] Confirmed spatial autocorrelation in response variable
- [ ] Block size ≥ autocorrelation range
- [ ] Each fold has presence AND background points
- [ ] No fold is empty or severely imbalanced (< 10 presences per fold)
- [ ] Same CV folds used across all candidate algorithms for fair comparison
