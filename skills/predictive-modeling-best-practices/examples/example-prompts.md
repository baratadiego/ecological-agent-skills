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
