---
resource_id: prioritizr-formulation-guide
skill_id: spatial-prioritization
---

# prioritizr Problem Formulation Guide

## Problem Types

| Problem type | Objective | When to use |
|-------------|-----------|-------------|
| **Minimum set** | Minimise total cost subject to meeting targets | Tight budgets; known targets (30×30) |
| **Maximum coverage** | Maximise features protected subject to budget | Fixed budget; want to maximise benefit |
| **Maximum utility** | Maximise weighted feature benefit | Prioritising high-value features |
| **Phylogenetic diversity** | Maximise phylogenetic diversity protected | Biodiversity triage |

---

## Minimum Set Problem — Core Structure

```r
# Usage: source this block or call from run_prioritization.R
suppressPackageStartupMessages(library(prioritizr))
suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(sf))

# Inputs:
#   pu_raster     — SpatRaster, planning units (cell = one PU)
#                   Values = cost; NA = excluded from analysis
#   features      — SpatRaster, one layer per biodiversity feature
#                   Values = amount of feature in each PU (0–1 suitability or area)
#   targets       — numeric vector, length = n_features, proportion to protect
#   locked_in     — SpatRaster, 1 = must be selected (existing PAs)
#   locked_out    — SpatRaster, 1 = must not be selected (developed areas)

build_problem <- function(pu_raster, features, targets,
                           locked_in = NULL, locked_out = NULL,
                           blm = 0) {
  p <- problem(pu_raster, features) %>%
    add_min_set_objective() %>%
    add_relative_targets(targets) %>%
    add_binary_decisions() %>%
    add_default_solver(gap = 0.01, time_limit = 600, verbose = FALSE)

  if (!is.null(locked_in)) {
    p <- p %>% add_locked_in_constraints(locked_in)
  }
  if (!is.null(locked_out)) {
    p <- p %>% add_locked_out_constraints(locked_out)
  }
  if (blm > 0) {
    p <- p %>% add_boundary_penalties(penalty = blm, data = NULL)
  }
  p
}
```

---

## Setting Representation Targets

| Target basis | Example value | Recommended for |
|-------------|-------------|-----------------|
| Fixed proportion | 0.30 (30% of range) | 30×30 policy, simple analyses |
| IUCN-based rule | Declining spp → 0.50; stable → 0.25 | Threat-based targets |
| Gap analysis | 1 − (current protected / total range) | Sites already partially protected |
| Area-based | Minimum area to maintain MVP | Species with known minimum area |

```r
# IUCN-based target function
set_iucn_targets <- function(species_df) {
  # species_df: columns 'species', 'iucn_category', 'protected_fraction'
  targets <- ifelse(species_df$iucn_category %in% c("CR", "EN"), 0.60,
             ifelse(species_df$iucn_category == "VU",             0.50,
             ifelse(species_df$iucn_category == "NT",             0.35,
                                                                  0.25)))
  # Reduce by already protected fraction (gap analysis)
  gap_targets <- pmax(0, targets - species_df$protected_fraction)
  gap_targets
}
```

---

## Boundary Length Modifier (BLM) Calibration

BLM controls the compactness of the selected solution:
- BLM = 0: ignores spatial compactness (fragmented solution)
- Large BLM: highly compact, may sacrifice feature representation

```r
# BLM calibration: evaluate cost-compactness tradeoff
blm_values <- c(0, 0.001, 0.01, 0.1, 1, 10)

blm_results <- lapply(blm_values, function(blm) {
  p <- build_problem(pu, features, targets, locked_in, blm = blm)
  s <- solve(p)
  list(
    blm           = blm,
    total_cost    = eval_cost_summary(p, s)$cost,
    total_boundary = eval_boundary_summary(p, s)$boundary,
    n_pu_selected  = sum(values(s), na.rm = TRUE)
  )
})

blm_df <- dplyr::bind_rows(blm_results)
# Plot: total cost vs boundary length — choose elbow point
```

**Rule:** Select BLM at the elbow of the cost–boundary tradeoff curve. Above the elbow, additional boundary reduction costs disproportionately more.

---

## Solvers

| Solver | R package | License | Recommended for |
|--------|----------|---------|----------------|
| **HiGHS** | `highs` | MIT (free) | Default for new analyses |
| Gurobi | `gurobi` | Commercial | Large problems, fastest |
| CPLEX | — | Commercial | Enterprise use |
| lpsymphony | `lpsymphony` | Free | Fallback if HiGHS unavailable |
| Rsymphony | `Rsymphony` | Free | Small problems |

```r
# Use HiGHS (free, recommended)
p <- p %>%
  add_highs_solver(gap = 0.01, time_limit = 600, verbose = FALSE)
```

---

## Evaluating Solution Performance

```r
# After solving
s <- solve(p)

# Feature representation
rep_summary <- eval_feature_representation_summary(p, s)
print(rep_summary)
# Columns: feature, total_amount, absolute_held, relative_held

# Targets met?
targets_met <- rep_summary$relative_held >= targets
cat(sprintf("Targets met: %d / %d features\n",
            sum(targets_met), length(targets_met)))

# Cost summary
cost_df <- eval_cost_summary(p, s)
cat(sprintf("Total cost: %g\n", cost_df$cost))

# Number of PUs selected
n_pu <- sum(values(s), na.rm = TRUE)
cat(sprintf("PUs selected: %d / %d\n", n_pu, ncell(s[!is.na(s)])))
```

---

## Irreplaceability (Rarity-Weighted Richness)

```r
# Compute portfolio irreplaceability via feature rarity weighting
irr <- eval_rare_richness_importance(p, s)
writeRaster(irr, "outputs/prioritization/irreplaceability.tif", overwrite = TRUE)

# High-irreplaceability PUs not in solution = overlooked priorities
high_irr <- irr >= quantile(values(irr), 0.80, na.rm = TRUE)
high_irr_not_selected <- high_irr & (s == 0)
```

---

## Pitfalls

- **Feature layers with different spatial extents:** All feature and cost rasters must have identical extent, resolution, and CRS. Reproject and resample to a common grid before analysis.
- **Targets set to 1.0 (100%):** A target of 1.0 requires protecting all PUs with any amount of the feature — often infeasible. Use 0.9 maximum unless justified.
- **Ignoring existing PAs:** Not locking in existing protected areas means the solver may exclude them and replace with cheaper PUs. Always lock in existing PAs.
- **Cost = area:** Equal-area PUs with cost = 1 creates minimum-set problems but maximises area, not biodiversity per cost unit. Use real cost data (land value, opportunity cost) where available.
- **BLM = 0 in fragmented landscapes:** Without boundary penalty, solutions are often highly fragmented and impractical. Always test with at least one non-zero BLM value.
- **Ignoring connectivity in feature layers:** Using species presence/absence rather than SDM suitability as features may overrepresent common, widespread species.

---

## References

- Hanson, J.O. et al. (2024). prioritizr: Systematic conservation prioritization in R. *Methods in Ecology and Evolution*, 15(8), 1337–1344. DOI: 10.1111/2041-210X.14376
- Marxan Conservation Solutions (2020). Marxan User Manual v2.43.
- Wilson, K.A. et al. (2009). Conserving biodiversity efficiently: what to do, where, and when. *PLOS Biology*, 7(9), e1000175. DOI: 10.1371/journal.pbio.1000175
