# Test Datasets

Synthetic datasets for automated testing and demonstration of all skills.
All data are randomly generated with fixed seed 42 — ecologically plausible but not real.

## Files

| File | Rows | Skill | Notes |
|------|------|-------|-------|
| `occurrences_raw.csv` | 85 | ecological-data-foundation | 80 clean + 5 with known QA issues (zero coords, centroid, future date, duplicate) |
| `species_site_matrix.csv` | 30 sites × 20 spp | community-ecology-ordination | 3 groups (forest/savanna/pasture) with distinct assemblages |
| `site_metadata.csv` | 30 | community-ecology-ordination | Covariates for the 30 sites above |
| `detection_history.csv` | 40 sites × 5 occ | occupancy-and-detection | Known ψ≈0.65, p≈0.35; some NAs |
| `occ_site_covariates.csv` | 40 | occupancy-and-detection | Forest cover, elevation, road distance |
| `points_with_env.csv` | 280 (80 pres + 200 bg) | predictive-modeling, SDM | 6 env predictors + cv_fold column |
| `model_predictions.csv` | 280 | model-validation-and-uncertainty | observed (0/1) + predicted probability |
| `ndvi_monthly_series.csv` | 240 months | environmental-time-series | 2000–2019, breakpoint Jan 2010, recovery after |
| `baci_data.csv` | 96 | ecological-impact-assessment | 16 sites, 6 surveys, ~32% decline in impact group post-disturbance |
| `es_summary_table.csv` | 6 | ecosystem-services-assessment | Land cover × ES indicators |
| `richness_data.csv` | 90 | biostatistics-workbench | 3 land use groups, count response |

## Known QA Issues in occurrences_raw.csv

| occurrenceID | Issue | Expected flag |
|-------------|-------|--------------|
| bad_001 | Coordinates (0.0, 0.0) | COORD_ZERO |
| bad_002 | Brazil country centroid (-10.33, -53.2) | COORD_CENTROID |
| bad_003 | Latitude = 999.0 | COORD_OUT_OF_RANGE |
| bad_004 | eventDate = 2030-01-01 | DATE_FUTURE |
| bad_005 | Exact duplicate of first clean record | DUPLICATE_EXACT |

## Known Signal in ndvi_monthly_series.csv

- Baseline trend: +0.0003 NDVI/month (2000–2009)
- Breakpoint: January 2010 (month index 120)
- Post-break drop: −0.004 NDVI/month for 12 months
- Recovery: +0.002 NDVI/month from January 2011 onward

Tests should detect the breakpoint at or near month 120.

## Known Signal in baci_data.csv

- Disturbance period: between 2017 and 2019
- Expected BACI interaction: ~32% decline in abundance at impact sites
- 8 control sites, 8 impact sites; 3 before + 3 after surveys each
