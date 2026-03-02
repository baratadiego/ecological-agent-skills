---
resource_id: marxan-vs-prioritizr-comparison
skill_id: spatial-prioritization
---

# Marxan vs prioritizr vs Zonation: Tool Comparison

## Core Comparison

| Feature | Marxan | prioritizr | Zonation |
|---------|--------|-----------|---------|
| **Algorithm** | Simulated annealing (heuristic) | Integer Linear Programming (exact) | Iterative removal (hierarchical) |
| **Solution type** | Multiple near-optimal solutions | Single optimal (or near-optimal with gap) | Continuous priority rank surface |
| **Objective** | Minimum set / maximum coverage | Minimum set / maximum coverage / others | Hierarchical feature retention |
| **Targets** | Required | Required | Optional (uses curves) |
| **Spatial compactness** | BLM penalty | BLM penalty | Integrated via edge weights |
| **Speed on large problems** | Fast (heuristic) | Slower (exact, ILP overhead) | Fast (greedy removal) |
| **Repeatability** | Stochastic (multiple runs) | Deterministic (exact) | Deterministic |
| **R integration** | marxan R package | Native R (prioritizr) | ZonationR (wrapper) |
| **License** | Free (registration) | Open source (MIT) | Free (registration) |
| **Best for** | Exploratory planning, large PU counts | Exact solution, auditability | Landscape-wide ranking without targets |

---

## When to Use Each Tool

### Use Marxan when:
- Very large landscapes (> 100,000 planning units) where ILP is computationally infeasible
- Exploring multiple near-optimal solutions to present to stakeholders
- Legacy workflow compatibility required

### Use prioritizr when:
- Provably optimal or near-optimal solution required (legal/policy context)
- Multiple constraints (locked in, locked out, budget constraints) must be handled exactly
- Reproducibility and auditability are paramount
- Gap to optimality must be certified (gap < 1%)

### Use Zonation when:
- No hard targets — want to rank all areas from most to least irreplaceable
- Connectivity features (dispersal kernels, landscape complementarity) are central
- Creating a continuous priority surface for broad-scale land-use planning

---

## Equivalence of Marxan BLM and prioritizr BLM

Both tools use a Boundary Length Modifier to penalise fragmentation, but implementation differs:

```r
# prioritizr: BLM is applied as a penalty per unit of boundary
p_prioritizr <- p %>%
  add_boundary_penalties(penalty = 0.01, data = NULL)

# Marxan BLM equivalent (approximate)
# Marxan BLM ≈ prioritizr penalty × mean PU perimeter
```

**Calibration:** The same BLM value will produce different results in Marxan vs prioritizr because Marxan's objective function scaling differs. Calibrate each tool's BLM independently.

---

## Zonation Priority Surface in R (Concept)

Zonation iteratively removes the planning unit with the least conservation value, preserving the most irreplaceable areas until all PUs are removed. The order of removal = priority rank (last removed = highest priority).

```r
# Simplified Zonation-like ranking in R (for conceptual illustration)
# Full Zonation requires the standalone software
zonation_rank <- function(features, weights = NULL) {
  if (is.null(weights)) weights <- rep(1, nlyr(features))
  feature_vals <- as.data.frame(features, xy = FALSE, na.rm = FALSE)
  # Weighted rarity-normalised score per cell
  totals <- colSums(feature_vals, na.rm = TRUE)
  totals[totals == 0] <- 1
  norm_vals <- sweep(feature_vals, 2, totals, "/")
  cell_scores <- rowSums(norm_vals * rep(weights, each = nrow(norm_vals)),
                          na.rm = TRUE)
  # Rank cells: higher score = higher priority
  rank(-cell_scores, ties.method = "first")
}
```

---

## Irreplaceability Comparison

Both Marxan and prioritizr can compute irreplaceability scores:

| Method | Implementation | Interpretation |
|--------|---------------|----------------|
| Marxan summed solution frequency | Run 100 solutions; irreplaceability = frequency of selection | 1.0 = selected in all solutions = irreplaceable |
| prioritizr rarity-weighted richness | `eval_rare_richness_importance()` | Higher = rarer features concentrated in that PU |
| Zonation rank | Priority rank from removal order | Rank 1 = last removed = most irreplaceable |

```r
# prioritizr irreplaceability
irr_map <- eval_rare_richness_importance(p, s)

# Marxan portfolio approach via prioritizr
# Run 100 solutions with varying budgets/targets
solutions <- lapply(1:100, function(i) {
  solve(p %>% add_highs_solver(gap = 0.05))  # relaxed gap for diversity
})
# Frequency map
freq_map <- Reduce("+", solutions) / 100
```

---

## Output Format Comparison

| Output | Marxan | prioritizr | Zonation |
|--------|--------|-----------|---------|
| Solution raster | `.dat` grid or spatial join | `SpatRaster` (binary) | `.rank.compressed.tif` |
| Feature representation | `_mvbest.txt` | `eval_feature_representation_summary()` | `curves.txt` |
| Cost summary | `_summary.txt` | `eval_cost_summary()` | — |
| Boundary | `_boundcalc.txt` | `eval_boundary_summary()` | edge weight output |

---

## References

- Ball, I.R., Possingham, H.P. & Watts, M.E. (2009). Marxan and relatives: software for spatial conservation prioritisation. In: *Spatial Conservation Prioritisation* (pp. 185–195). Oxford University Press.
- Hanson, J.O. et al. (2024). prioritizr: Systematic conservation prioritization in R. *Methods in Ecology and Evolution*, 15(8), 1337–1344. DOI: 10.1111/2041-210X.14376
- Moilanen, A. et al. (2022). Zonation spatial conservation planning framework, Version 5. University of Helsinki.
