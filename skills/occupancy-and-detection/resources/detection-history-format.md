# Detection History Format Reference

The detection history matrix is the primary input for all occupancy models. Correct formatting is essential.

## Matrix Structure

- **Rows** = sites (sampling units)
- **Columns** = survey occasions (within season)
- **Values**: `1` (detected), `0` (surveyed, not detected), `NA` (not surveyed)

```
         occ1  occ2  occ3  occ4  occ5  occ6
site_01     1     0     1     1     0    NA
site_02     0     0     0     0     0     0
site_03    NA     1     1     0     1     1
site_04     0    NA     0    NA     0     0
site_05     0     0     0     0     0     0
```

## Critical Rules

1. `0` means the site WAS surveyed but species was NOT detected — not the same as `NA`
2. `NA` means the site was NOT surveyed on that occasion (equipment failure, weather, etc.)
3. A row of all zeros = site was surveyed on all occasions, never detected
4. A row of all `NA` = site was never surveyed; **remove this row**
5. Occasions must be within the closure period (population assumed closed)

## Building the Matrix in R

```r
library(dplyr)
library(tidyr)

# Assuming raw_data has columns: site_id, occasion, detected (0/1), surveyed (TRUE/FALSE)
det_history <- raw_data |>
  mutate(value = ifelse(!surveyed, NA, detected)) |>
  pivot_wider(id_cols = site_id, names_from = occasion, values_from = value,
              names_prefix = "occ") |>
  column_to_rownames("site_id") |>
  as.matrix()

# Sanity checks
cat("Sites:", nrow(det_history), "\n")
cat("Occasions:", ncol(det_history), "\n")
cat("Detection rate:", mean(det_history, na.rm = TRUE), "\n")
cat("Sites with ≥1 detection:", sum(rowSums(det_history, na.rm=TRUE) > 0), "\n")
cat("Sites never surveyed (remove):", sum(rowSums(!is.na(det_history)) == 0), "\n")
```

## Observation Covariates

Site-level covariates (for ψ): one row per site, one column per variable.
Observation-level covariates (for p): same dimensions as detection history matrix, or a list of matrices.

```r
# Site covariates (same row order as detection history)
site_covs <- data.frame(
  forest_cover = c(0.82, 0.45, 0.91, 0.33, 0.71),  # 0–1
  elevation_m  = c(450, 230, 680, 150, 520),
  row.names    = rownames(det_history)
)

# Observation covariates (matrix: same dimensions as detection history)
effort_nights <- matrix(
  c(3, 3, NA, 3, 3, 3,   # site 1
    3, 3, 3, 3, 3, 3,    # site 2
    ...),
  nrow = nrow(det_history), byrow = TRUE
)

# Build unmarkedFrame
library(unmarked)
umf <- unmarkedFrameOccu(
  y        = det_history,
  siteCovs = site_covs,
  obsCovs  = list(effort = effort_nights)
)
summary(umf)
```

## Standardising Covariates

Always standardise continuous covariates to mean = 0, SD = 1 before modelling:

```r
site_covs_std <- site_covs |>
  mutate(across(where(is.numeric), ~ as.vector(scale(.))))
```

This improves numerical stability and allows direct comparison of coefficient magnitudes.

## Common Formatting Errors

| Error | Symptom | Fix |
|-------|---------|-----|
| Using -9 or 999 as NA code | Model fails to converge | Replace with `NA` |
| Occasions in wrong order | Apparent temporal patterns are artefacts | Sort by date within site |
| Site covariate row order mismatched | Covariates assigned to wrong sites | Use row names to match |
| Mixing detection probability with occupancy | Overestimates p | Only use surveys within closure period |
| Zero variance in a covariate | Model rank deficiency | Remove constant covariates |
