# Example Invocation Prompts — predictive-modeling-best-practices

## Full Pre-Modeling Assessment

```
Load skill: predictive-modeling-best-practices
Task: Pre-modeling assessment for a jaguar SDM.
Predictor stack: data/predictors_stack.tif (19 bioclim + NDVI + slope = 21 variables)
Occurrence points: data/occ_clean.csv (n = 347)
Background points: 10,000 random points within the Amazon biome.

1. Assess collinearity (threshold VIF < 5, |r| < 0.7). Use domain knowledge: prioritise
   bio1, bio4, bio12, bio15, bio5, NDVI, slope.
2. Define spatial CV strategy using blockCV. Study area is Amazon (~5 million km²).
3. Design BRT and MaxEnt tuning grids.
4. Produce: cv_strategy.md, collinearity_report.csv, selected_predictors.txt, modeling_plan.md
```

## Collinearity Check Only

```
Load skill: predictive-modeling-best-practices
Task: Run collinearity check only on the environmental matrix in data/env_matrix.csv.
Threshold: VIF < 10 (lenient). Output: collinearity_report.csv.
Do NOT run CV or tuning.
```

## Sampling Bias Detection and Correction

```
Load skill: predictive-modeling-best-practices
Task: Detect and correct sampling bias in jaguar occurrence records.
Occurrences: data/occ_clean.csv (n = 420, from GBIF)
Env stack: data/predictors_stack.tif
Study area: data/study_area/amazon_biome.shp

1. Generate kernel density bias map from occurrence coordinates.
2. Run KS test comparing environmental distribution of occurrences vs. background.
3. If bias detected: apply target-group background using Carnivora GBIF records.
4. As fallback: apply kernel density weighting to background.
5. Output: bias_map.png, ks_test_results.csv, bg_weighted.csv, bias_correction_report.md
```

## Environmental Filtering (Thin in Environmental Space)

```
Load skill: predictive-modeling-best-practices
Task: Apply environmental thinning to reduce bioclimatic over-representation.
Occurrences: data/occ_clean.csv (n = 850, many records from Cerrado)
Env stack: data/predictors_stack.tif (bio1, bio4, bio12, bio15 selected)

1. Extract env values at all occurrence points.
2. Run PCA on env values (first 2 axes).
3. Grid sample in PC1/PC2 space (cell size = 0.5 SD units).
4. Keep 1 record per environmental cell (random, seed = 42).
5. Report: n before / n after, PCA variance explained, env coverage plot.
Output: occ_env_thinned.csv, env_thinning_report.md
```
