# Example Invocation Prompts — species-distribution-modeling

## Full SDM Pipeline

```
Load skill: species-distribution-modeling
Task: Build a habitat suitability model for Panthera onca in the Amazon biome.

Inputs:
  - Occurrences: data/processed/data_clean.csv (n = 523 after cleaning)
  - Predictors: data/predictors_stack.tif (bio1, bio4, bio12, bio15, NDVI, slope — 6 vars, collinearity checked)
  - Calibration area: data/spatial/amazon_buffered.shp
  - Background: 10,000 points sampled within calibration area

Steps:
  1. Spatial thinning: 10 km minimum distance
  2. Spatial CV: 5 blocks (blockCV, block size = 300 km)
  3. Algorithms: MaxEnt (maxnet), BRT (gbm), Random Forest
  4. Ensemble: weighted average by TSS score per algorithm
  5. Threshold: MaxTSS and P10
  6. Uncertainty: SD across algorithms

Output: suitability_current.tif, suitability_binary.tif, variable_importance.csv, response_curves.png, sdm_report.md
```

## Projection to 2050

```
Load skill: species-distribution-modeling
Task: Project the fitted jaguar SDM to 2050 conditions.
Scenario rasters: data/predictors_2050_ssp245/ (same variable names as current stack)
Calibration area: data/spatial/amazon_buffered.shp
Apply MESS mask to flag areas outside training range.
Compute change in suitable area (km²) between current and 2050.
Output: suitability_2050_ssp245.tif, mess_mask.tif, change_summary.csv
```
