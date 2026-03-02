---
skill_id: spatial-prioritization
example_type: full_walkthrough
taxon: Multi-species (Atlantic Forest endemic vertebrates)
region: Southern Bahia, Brazil — Atlantic Forest hotspot
---

# Atlantic Forest Biodiversity Hotspot Prioritization — Full Walkthrough

## Study Context

**Location:** Southern Bahia, Brazil — one of the world's most biodiverse (and threatened) Atlantic Forest remnants
**Objective:** Design a minimum-cost protected area expansion to meet 30% representation targets for 85 endemic vertebrate species while maximising compactness (coridor potential)
**Planning units:** 5×5 km grid cells, n = 3,240 valid PUs
**Features:** 85 species SDM suitability layers (MaxEnt, continuous 0–1)
**Cost:** Opportunity cost surface based on agricultural land value (R$/ha/yr)
**Existing PAs:** 12 federal and state reserves (already locked in, covering ~8% of area)

---

## Step 1 — Data Preparation

### Planning unit cost surface

```r
suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(sf))

# Agricultural opportunity cost: sugarcane + cattle + timber
sugarcane <- rast("data/sugarcane_revenue_reais_ha.tif")
cattle    <- rast("data/cattle_TLU_ha.tif") * 180  # R$/TLU/yr
timber    <- rast("data/timber_potential_reais_ha.tif")
opp_cost  <- max(sugarcane, cattle, timber, na.rm = TRUE)
opp_cost  <- aggregate(opp_cost, fact = 5, fun = "mean")  # resample to 5km

# Minimum floor
opp_cost[opp_cost < 1] <- 1
writeRaster(opp_cost, "data/pu_cost_5km.tif", overwrite = TRUE)
cat(sprintf("Cost range: %.0f – %.0f R$/ha/yr\n",
            global(opp_cost, "min")[[1]], global(opp_cost, "max")[[1]]))
```

**Cost statistics:**

| Statistic | Value (R$/ha/yr) |
|-----------|-----------------|
| Min | 1.0 |
| Median | 845 |
| Mean | 1,240 |
| Q95 | 3,890 |
| Max | 8,750 |

**Decision:** Log-transform cost for analysis to reduce influence of 5 outlier PUs with costs > 7,000 R$/ha/yr. Decision logged with rationale.

### Feature layers preparation

```r
feat_files <- list.files("data/sdm_continuous/", pattern = ".tif$", full.names = TRUE)
features   <- rast(feat_files)
features   <- resample(features, rast("data/pu_cost_5km.tif"), method = "bilinear")

# Check feature distribution: remove features with < 5 PUs with suitability > 0.3
feat_sums  <- global(features > 0.3, "sum", na.rm = TRUE)
low_feat   <- names(features)[feat_sums[[1]] < 5]
cat(sprintf("Removing %d features with very restricted range.\n", length(low_feat)))
features   <- features[[!names(features) %in% low_feat]]
```

**Result:** 3 species removed (range < 5 PUs); 82 features retained.

---

## Step 2 — Baseline Prioritization (Minimum Set, 30% Targets)

### Target computation (IUCN-based)

```r
species_meta <- read.csv("data/species_iucn_status.csv")
# Columns: species, iucn_category, current_protected_fraction

set_iucn_targets <- function(species_df) {
  raw <- dplyr::case_when(
    species_df$iucn_category == "CR" ~ 0.60,
    species_df$iucn_category == "EN" ~ 0.50,
    species_df$iucn_category == "VU" ~ 0.40,
    species_df$iucn_category == "NT" ~ 0.30,
    TRUE ~ 0.17
  )
  pmax(0, raw - species_df$current_protected_fraction)
}

targets_df <- set_iucn_targets(species_meta)
# Distribution: CR: 0.42 median (gap after 18% already protected)
#               EN: 0.35; VU: 0.28; NT: 0.22
write.csv(data.frame(feature_name = names(features), target = targets_df),
          "data/iucn_targets.csv", row.names = FALSE)
```

### Run baseline prioritization

```bash
Rscript run_prioritization.R \
  data/pu_cost_5km.tif \
  data/sdm_continuous/ \
  outputs/baseline/ \
  data/iucn_targets.csv \
  data/existing_PAs_5km.tif \
  data/excluded_urban_water.tif \
  0 \
  NA
```

**Baseline results:**

| Metric | Value |
|--------|-------|
| PUs selected | 487 / 3,240 (15.0%) |
| Total cost | R$ 234M/yr opportunity cost |
| Features with targets met | 79 / 82 (96.3%) |
| 3 features below target | *Diclidurus ingens* (CR, 0.41 vs 0.42 target), 2 VU bats |

**Action:** The 3 shortfall species have extremely restricted ranges. Manual inspection shows their key PUs are in a locked-out urban buffer. Decision: remove urban buffer restriction for those 3 PUs (no development plans confirmed) → re-run.

---

## Step 3 — Sensitivity Analysis

```bash
Rscript prioritization_sensitivity.R \
  data/pu_cost_5km.tif \
  data/sdm_continuous/ \
  outputs/sensitivity/ \
  data/iucn_targets.csv \
  data/existing_PAs_5km.tif \
  data/excluded_urban_water.tif
```

### BLM calibration

| BLM | Cost (R$M/yr) | Boundary length | PUs selected |
|-----|--------------|-----------------|-------------|
| 0 | 234 | 18,240 | 487 |
| 0.001 | 238 | 15,120 | 492 |
| 0.01 | 251 | 11,880 | 508 |
| 0.05 | 279 | 8,640 | 531 |
| 0.1 | 312 | 7,200 | 565 |

**Decision:** BLM = 0.01 selected (elbow point — 7% cost increase reduces boundary by 35%). This creates significantly more compact, corridor-compatible solutions.

### Target sensitivity

| Target scaling | Mean target | Cost (R$M/yr) | Features met |
|---------------|-------------|--------------|-------------|
| 50% | 0.17 | 98 | 82/82 |
| 75% | 0.26 | 167 | 82/82 |
| 100% (baseline) | 0.35 | 251 | 82/82 |
| 125% | 0.44 | 389 | 80/82 |
| 150% | 0.52 | 521 | 76/82 |

**Finding:** Cost increases 3× from 50% to 150% target scaling. Targets above ~130% become infeasible for 2+ species given locked-out area constraints.

---

## Step 4 — Final Solution (BLM = 0.01)

```bash
Rscript run_prioritization.R \
  data/pu_cost_5km.tif \
  data/sdm_continuous/ \
  outputs/final/ \
  data/iucn_targets.csv \
  data/existing_PAs_5km.tif \
  data/excluded_urban_water.tif \
  0.01 \
  NA
```

**Final solution results:**

| Metric | Value |
|--------|-------|
| PUs selected | 508 (15.7%) |
| Total opportunity cost | R$ 251M/yr |
| Area selected | ~12,700 km² |
| Combined with existing PAs | ~14,600 km² (20.8% of study area) |
| Features with targets met | 82 / 82 (100%) |
| Gap to optimality (HiGHS) | 0.8% |

**Irreplaceability analysis:**

```r
irr <- rast("outputs/final/irreplaceability.tif")
# High-priority areas (top 10% irreplaceability, not yet in PA system)
high_irr_unprotected <- (irr >= quantile(values(irr), 0.90, na.rm = TRUE)) &
                         (rast("data/existing_PAs_5km.tif") == 0)
n_high_irr_unprotected <- sum(values(high_irr_unprotected) == 1, na.rm = TRUE)
cat(sprintf("High-irreplaceability, unprotected PUs: %d (%.0f km²)\n",
            n_high_irr_unprotected, n_high_irr_unprotected * 25))
```

**Result:** 47 PUs (1,175 km²) have irreplaceability > 0.90 and are not currently protected. These are the highest-priority acquisition targets.

---

## Step 5 — Portfolio Irreplaceability Map

```r
freq <- rast("outputs/sensitivity/portfolio_frequency.tif")
# Areas selected in > 75% of scenarios = robust priorities
robust_areas <- freq >= 0.75
robust_area_km2 <- sum(values(robust_areas) == 1, na.rm = TRUE) * 25
cat(sprintf("Robust priority areas (selected in >75%% scenarios): %.0f km²\n",
            robust_area_km2))
```

**Result:** 8,450 km² selected in > 75% of all scenarios. These areas are recommended as the highest-priority acquisition regardless of cost or target assumptions.

---

## Step 6 — Final Outputs

```
outputs/
├── baseline/
│   ├── solution.tif                    # 487 PUs selected
│   ├── feature_representation.csv      # 82 species, 79 met targets
│   ├── cost_summary.csv
│   └── irreplaceability.tif
├── final/                              # BLM = 0.01
│   ├── solution.tif                    # 508 PUs, all 82 targets met
│   ├── feature_representation.csv
│   ├── irreplaceability.tif
│   └── prioritization_map.png
└── sensitivity/
    ├── blm_calibration.csv
    ├── blm_calibration_plot.png
    ├── target_sensitivity.csv
    ├── cost_scenario_sensitivity.csv
    └── portfolio_frequency.tif         # robust priorities (75% threshold)
```

---

## Summary Table

| Metric | Value |
|--------|-------|
| Planning units | 3,240 (5×5 km) |
| Features analysed | 82 Atlantic Forest endemics |
| Existing PA coverage | 8.0% (locked in) |
| Solution area | 15.7% (+ existing = 20.8%) |
| All targets met | Yes (82/82) |
| Opportunity cost | R$ 251M/yr |
| Gap to optimality | 0.8% |
| Robust priority area (>75% freq) | 8,450 km² |
| Irreplaceable unprotected area | 1,175 km² (47 PUs) |

---

## Decision Log

```yaml
- date: 2026-02-01
  skill_id: spatial-prioritization
  decision: "Log-transform cost; outlier PUs capped at 95th percentile"
  rationale: "5 PUs with cost > 7000 R$/ha dominated solution; log-transform standard practice"
  outputs: ["data/pu_cost_5km.tif"]

- date: 2026-02-02
  skill_id: spatial-prioritization
  decision: "BLM = 0.01 selected for final solution"
  rationale: "Elbow of cost-compactness curve; 7% cost increase for 35% boundary reduction"
  outputs: ["outputs/sensitivity/blm_calibration.csv"]

- date: 2026-02-03
  skill_id: spatial-prioritization
  decision: "Urban buffer exception for 3 CR bat species PUs"
  rationale: "No confirmed development plans in those PUs; verified with municipal zoning"
  outputs: ["outputs/final/solution.tif"]
```

---

## References

- Hanson, J.O. et al. (2024). prioritizr: Systematic conservation prioritization in R. *Methods in Ecology and Evolution*, 15(8), 1337–1344. DOI: 10.1111/2041-210X.14376
- CBD (2022). *Kunming-Montreal Global Biodiversity Framework*, Target 3. COP15.
- Rodrigues, A.S.L. et al. (2004). Effectiveness of the global protected area network in representing species diversity. *Nature*, 428, 640–643. DOI: 10.1038/nature02422
- Wilson, K.A. et al. (2009). Conserving biodiversity efficiently: what to do, where, and when. *PLOS Biology*, 7(9), e1000175. DOI: 10.1371/journal.pbio.1000175
