# Collinearity Management — Decision Guide

## Step 1: Compute Correlations

```r
library(usdm)
env_matrix <- values(predictor_stack) |> na.omit()

# Pairwise Pearson correlation
cor_matrix <- cor(env_matrix, method = "pearson")

# VIF for each variable
vif_results <- vifstep(env_matrix, th = 5)  # remove until all VIF < 5
print(vif_results)
```

## Step 2: Apply the Decision Tree

```
Compute pairwise |r| for all predictors
     ↓
Any |r| > 0.7?
  NO  → Proceed; compute VIF as confirmation
  YES → Apply reduction strategy (Step 3)
     ↓
Any VIF > 5?
  NO  → Predictor set is acceptable
  YES → Continue removing highest-VIF predictors
```

## Step 3: Reduction Strategies

### A. Domain Knowledge Priority (preferred)
- List all predictors; mark those most ecologically relevant to the target species/process
- When two correlated predictors must be reduced, keep the one with stronger ecological rationale
- Document the justification for each kept predictor

### B. VIF Stepwise Removal
- Iteratively remove the predictor with the highest VIF until all VIF < 5 (or < 10 for lenient threshold)
- `usdm::vifstep()` automates this

### C. PCA (last resort, when interpretability is secondary)
- Apply PCA to collinear predictor block
- Retain axes explaining ≥ 90% of variance
- Trade-off: loses direct interpretation of individual predictors

## Step 4: Document

Record in `collinearity_report.csv`:

| Predictor | VIF | Max_pairwise_r | Decision | Justification |
|-----------|-----|----------------|----------|---------------|
| bio1 | 2.3 | 0.61 | Keep | Key temperature variable |
| bio4 | 8.7 | 0.83 | Remove | Collinear with bio1 |
| bio12 | 1.9 | 0.45 | Keep | Key precipitation variable |

## Common Collinear Groups in Bioclimatic Variables

| Group | Variables | Keep |
|-------|-----------|------|
| Temperature mean | bio1, bio11 | bio1 |
| Temperature seasonality | bio4, bio7 | bio4 |
| Precipitation total | bio12, bio13, bio14 | bio12 |
| Precipitation seasonality | bio15, bio3 | bio15 |
| Thermal extremes | bio5, bio6, bio8, bio9 | bio5 or bio6 (context-dependent) |
