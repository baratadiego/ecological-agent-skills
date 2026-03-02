---
resource_id: representation-targets-guide
skill_id: spatial-prioritization
---

# Representation Targets Guide

## What Are Representation Targets?

Representation targets define the minimum amount of each biodiversity feature that must be included in the conservation solution. They operationalise policy commitments (30×30) and species-level conservation requirements into quantitative thresholds for ILP formulation.

---

## Target Types in prioritizr

| Target type | Function | Input format | Example |
|-------------|---------|--------------|---------|
| Relative | `add_relative_targets()` | Proportion of total feature amount | 0.30 = protect 30% of each feature |
| Absolute | `add_absolute_targets()` | Raw units (km², individuals, occurrences) | 500 km² of suitable habitat |
| Loglinear | `add_loglinear_targets()` | Curve from lower to upper bound | Small-range spp → higher targets |

---

## 30×30 Target Implementation

```r
suppressPackageStartupMessages(library(prioritizr))

# Simple: 30% of each feature
p_30x30 <- p %>%
  add_relative_targets(0.30)

# Refined: 30% of terrestrial features, 30% of marine features
# Apply different targets per feature group
n_terrestrial <- 45
n_marine      <- 20
targets_vec   <- c(rep(0.30, n_terrestrial), rep(0.30, n_marine))
p_30x30_v2    <- p %>%
  add_relative_targets(targets_vec)
```

**Note:** 30×30 refers to 30% of area protected by 2030. The ILP target of 0.30 for each feature is not equivalent to 30% of area — the solution may protect more or less than 30% of area depending on feature distribution.

---

## IUCN-Based Targets (Gap Analysis)

```r
compute_iucn_targets <- function(species_df, features, existing_pa_raster) {
  # species_df: columns species, iucn_category, total_range_km2
  # features: SpatRaster with one layer per species
  # existing_pa_raster: 1 = protected, 0 = not

  n <- nrow(species_df)
  targets <- numeric(n)

  for (i in seq_len(n)) {
    cat_i <- species_df$iucn_category[i]
    # Raw targets by IUCN category (based on Jenkins et al. 2015)
    raw_target <- switch(cat_i,
      CR = 0.60,
      EN = 0.50,
      VU = 0.40,
      NT = 0.30,
           0.17  # LC default (Aichi Target 11)
    )
    # Gap analysis: subtract already protected fraction
    feat_layer  <- features[[i]]
    total_amt   <- global(feat_layer, "sum", na.rm = TRUE)[[1]]
    pa_amt      <- global(feat_layer * existing_pa_raster, "sum", na.rm = TRUE)[[1]]
    pct_protected <- pa_amt / max(total_amt, 1e-9)
    gap_target  <- max(0, raw_target - pct_protected)
    targets[i]  <- gap_target
  }
  targets
}
```

---

## Log-Linear Targets for Range-Size-Based Scaling

Large-range species require smaller proportional targets than small-range species (Rodrigues et al. 2004):

```r
# Log-linear target function
# Lower target for widespread, upper target for rare species
loglinear_targets <- function(range_km2,
                               lower_threshold_km2 = 1000,
                               upper_threshold_km2  = 250000,
                               lower_target = 0.10,
                               upper_target = 1.00) {
  targets <- ifelse(range_km2 < lower_threshold_km2,
    upper_target,
    ifelse(range_km2 > upper_threshold_km2,
      lower_target,
      upper_target + (lower_target - upper_target) *
        (log(range_km2) - log(lower_threshold_km2)) /
        (log(upper_threshold_km2) - log(lower_threshold_km2))
    )
  )
  targets
}

# Example
species_ranges <- c(100, 1000, 50000, 500000)  # km²
targets <- loglinear_targets(species_ranges)
cat(data.frame(range_km2 = species_ranges, target = round(targets, 2)))
```

| Range (km²) | Target |
|-------------|--------|
| 100 | 1.00 (100%) |
| 1,000 | 1.00 (threshold) |
| 50,000 | 0.62 |
| 500,000 | 0.10 |

---

## Feature Weights (Prioritising Threatened Species)

When not all features are equally important, apply weights:

```r
# Weight by IUCN category
weights_vec <- case_when(
  species_df$iucn_category == "CR" ~ 4,
  species_df$iucn_category == "EN" ~ 3,
  species_df$iucn_category == "VU" ~ 2,
  species_df$iucn_category == "NT" ~ 1.5,
  TRUE ~ 1
)

# Apply in maximum coverage problem
p_weighted <- problem(pu, features) %>%
  add_max_features_objective(budget = total_budget) %>%
  add_absolute_targets(1e-6) %>%  # minimum feasibility
  add_feature_weights(weights_vec) %>%
  add_binary_decisions() %>%
  add_highs_solver(gap = 0.01)
```

---

## Target Shortfalls and Cost-Benefit Curves

When targets cannot be fully met within budget:

```r
# Evaluate target shortfalls after solving
rep_summary <- eval_feature_representation_summary(p, s)
shortfall_df <- rep_summary %>%
  mutate(target = targets_vec,
         shortfall = pmax(0, target - relative_held),
         pct_shortfall = shortfall / target * 100) %>%
  arrange(desc(shortfall))

# Cost-effectiveness curve: cost vs % of targets met
budgets <- seq(0.2, 1.0, by = 0.1) * total_budget
ce_results <- lapply(budgets, function(b) {
  p_b <- p %>% add_max_features_objective(budget = b)
  s_b <- solve(p_b)
  rep_b <- eval_feature_representation_summary(p_b, s_b)
  data.frame(budget = b,
             pct_targets_met = mean(rep_b$relative_held >= targets_vec) * 100)
})
ce_df <- dplyr::bind_rows(ce_results)
```

---

## Pitfalls

- **Relative targets applied to features with zero total:** If a feature has total_amount = 0 (no occurrence in study area), any relative target is infeasible. Filter out zero-occurrence features before analysis.
- **Targets exceeding currently achievable area:** If 80% of a species' range is already developed, a target of 0.60 may be infeasible. Check feasibility before optimisation.
- **Equal targets for all species regardless of area or threat:** This treats a critically endangered microendemic the same as a common widespread species. Always use IUCN or range-based targets.
- **Forgetting to account for feature detectability:** SDM-based features represent potential habitat, not confirmed presence. Over-targeting poorly surveyed species inflates solution cost without confirmed benefit.
- **Targets ignore quality:** A target of 30% met by degraded habitat may not achieve conservation objectives. Consider weighting feature layers by habitat quality before setting targets.

---

## References

- Rodrigues, A.S.L. et al. (2004). Effectiveness of the global protected area network in representing species diversity. *Nature*, 428, 640–643. DOI: 10.1038/nature02422
- Jenkins, C.N. et al. (2015). Global patterns of terrestrial vertebrate diversity and conservation. *PNAS*, 112(18), 5667–5672. DOI: 10.1073/pnas.1302251112
- CBD (2022). *Kunming-Montreal Global Biodiversity Framework*. Convention on Biological Diversity, COP15.
