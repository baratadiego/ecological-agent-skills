---
resource_id: cost-surface-reference
skill_id: spatial-prioritization
---

# Cost Surface Reference for Conservation Planning

## Types of Conservation Cost

| Cost type | Definition | Data source | Bias risk |
|-----------|-----------|-------------|-----------|
| **Land acquisition** | Market value of land | Cadastral databases, government assessments | Overvalues urban-adjacent land |
| **Opportunity cost** | Foregone income if land is protected | Crop productivity + livestock density | Ignores non-market values |
| **Management cost** | Annual monitoring, enforcement, restoration | Government agency budgets | Variable by governance context |
| **Transaction cost** | Legal, administrative negotiation costs | Expert estimate | Often ignored; can dominate |
| **Area (proxy)** | Equal cost per PU (1 per cell) | Always available | No economic information |

**Recommended hierarchy:** Opportunity cost > land acquisition cost > area proxy. Use area proxy only when no cost data is available.

---

## Opportunity Cost Construction

```r
suppressPackageStartupMessages(library(terra))

# Components of agricultural opportunity cost
crop_value     <- rast("data/crop_net_revenue_usd_ha.tif")   # $/ha/yr
livestock_value <- rast("data/livestock_density_TLU_ha.tif")  # TLU/ha → $/ha/yr
timber_value   <- rast("data/timber_potential_usd_ha.tif")    # $/ha

# Weight livestock by price per TLU (e.g., 200 USD/TLU/yr)
livestock_opp <- livestock_value * 200

# Total opportunity cost = max of competing land uses
opp_cost <- max(crop_value, livestock_opp, timber_value, na.rm = TRUE)

# Replace NA with low cost (not zero — zero cost attracts solver spuriously)
opp_cost[is.na(opp_cost)] <- 1
writeRaster(opp_cost, "data/opportunity_cost.tif", overwrite = TRUE)
```

---

## Cost Normalisation

```r
# Option 1: Standardise to 0–1 (useful for comparing solutions across regions)
cost_norm <- (opp_cost - global(opp_cost, "min", na.rm = TRUE)[[1]]) /
             (global(opp_cost, "max", na.rm = TRUE)[[1]] -
              global(opp_cost, "min", na.rm = TRUE)[[1]])

# Option 2: Log-transform (reduces influence of outlier high-cost cells)
cost_log <- log1p(opp_cost)

# Option 3: Percentile cap (cap at 95th percentile to remove outliers)
q95 <- quantile(values(opp_cost), 0.95, na.rm = TRUE)
cost_capped <- min(opp_cost, q95)
```

**Choose normalisation based on cost distribution.** If cost is approximately log-normal (common for land values), log-transform avoids a few high-cost cells dominating the solution.

---

## Cost Surface Uncertainty

Cost data often has high uncertainty. Test prioritisation robustness:

```r
# Run prioritization under 3 cost scenarios
cost_low  <- cost * 0.7   # -30% uncertainty
cost_base <- cost
cost_high <- cost * 1.3   # +30% uncertainty

run_scenario <- function(cost_raster, name) {
  p <- problem(cost_raster, features) %>%
    add_min_set_objective() %>%
    add_relative_targets(targets) %>%
    add_highs_solver(gap = 0.01) %>%
    add_binary_decisions()
  s <- solve(p)
  data.frame(scenario = name,
             cost = eval_cost_summary(p, s)$cost,
             n_pu = sum(values(s), na.rm = TRUE))
}

scenarios <- lapply(list(cost_low, cost_base, cost_high),
                    list("low", "base", "high"),
                    function(c, n) run_scenario(c, n))
```

---

## Locked-In and Locked-Out Planning Units

| Category | Definition | R implementation |
|----------|-----------|-----------------|
| **Locked-in** | Must be selected (existing PAs, community reserves) | `add_locked_in_constraints(locked_in_raster)` |
| **Locked-out** | Cannot be selected (developed areas, water bodies, military) | `add_locked_out_constraints(locked_out_raster)` |
| **Semi-locked** | Selected only if budget allows | Remove from locked constraints; let solver decide |

```r
# Build locked-in raster from protected area shapefile
pas <- st_read("data/wdpa_protected_areas.shp", quiet = TRUE)
locked_in <- rasterize(vect(pas), cost, field = 1, background = 0)
locked_in[is.na(cost)] <- NA  # match planning unit extent

# Build locked-out from urban and water polygons
excluded <- st_read("data/urban_water_excluded.shp", quiet = TRUE)
locked_out <- rasterize(vect(excluded), cost, field = 1, background = 0)
locked_out[is.na(cost)] <- NA
```

---

## Pitfalls

- **Zero-cost cells attracting all PUs:** If cost = 0 for some PUs, the solver trivially selects them. Use a minimum cost floor (e.g., 1) for all non-excluded PUs.
- **Cost misalignment with features:** If cost raster is at 10-km resolution but features at 1-km, resampling introduces spatial mismatch. Always build cost at the same resolution as the analysis.
- **Ignoring non-market values:** Pure opportunity cost undervalues inaccessible, culturally important, or wilderness areas. Consider supplementing with ecosystem service values.
- **Using area as cost when land access is the real constraint:** In many developing-country contexts, political access (community agreements, government willingness) is the real cost, not land value. Document which cost metric was used and why.
- **Static cost surface:** Land values change over time. For 30-year planning horizons, consider projected future opportunity cost (discounted NPV of land use revenues).

---

## References

- Naidoo, R. & Iwamura, T. (2007). Global-scale mapping of economic benefits from agricultural lands. *Biological Conservation*, 140(1–2), 40–49. DOI: 10.1016/j.biocon.2007.07.025
- Polasky, S. et al. (2008). Where to put things? Spatial land management to sustain biodiversity and economic returns. *Biological Conservation*, 141(6), 1505–1524. DOI: 10.1016/j.biocon.2008.03.022
- Ferraro, P.J. (2003). Asymmetric information and contract design for payments for environmental services. *Ecological Economics*, 65(4), 810–821. DOI: 10.1016/j.ecolecon.2007.07.029
