# Worked Example: Jaguar SDM in the Amazon

**Workflow:** run-sdm-study  
**Species:** Panthera onca (jaguar)  
**Study area:** Brazilian Amazon biome  
**Predictors:** WorldClim v2.1 (bio1, bio4, bio12, bio15) + NDVI (MOD13A3 mean) + slope (SRTM)

---

## Step 1 — Data Sources

| Dataset | Source | Records |
|---------|--------|---------|
| GBIF occurrence | doi:10.15468/dl.xxxxx | 1,247 raw |
| SpeciesLink | specieslink.net | 89 raw |
| Field data 2019–2023 | Own collection | 34 raw |
| **Total after cleaning** | — | **423** |
| **After 10 km thinning** | — | **186** |

## Step 2 — QA Results Summary

| Issue | Count | Action |
|-------|-------|--------|
| Zero coordinates | 3 | Removed |
| Country centroid | 7 | Removed |
| Outside country polygon | 12 | Removed |
| Taxonomy: synonyms resolved | 18 | Resolved to P. onca |
| Exact duplicates | 56 | Deduplicated |
| After cleaning | **423** | Retained |

## Step 3 — Collinearity Results

Final predictor set after VIF reduction (threshold VIF < 5):

| Variable | VIF | Decision |
|----------|-----|----------|
| bio1 (MAT) | 2.1 | Keep |
| bio4 (Temp seasonality) | 3.4 | Keep |
| bio12 (MAP) | 1.9 | Keep |
| bio15 (Prec seasonality) | 2.8 | Keep |
| NDVI_mean | 1.7 | Keep |
| slope | 1.3 | Keep |
| bio5 | 8.2 | **Remove** (collinear with bio1) |
| bio6 | 7.9 | **Remove** (collinear with bio1) |

## Step 4 — Spatial CV Configuration

```
Block size: 350 km (exceeds SAC range of ~280 km)
Folds: 5
Presences per fold: 31–44
Background per fold: 1,800–2,100
```

## Step 5 — Model Performance

| Algorithm | AUC (CV) | TSS (CV) | Boyce (test) |
|-----------|---------|---------|-------------|
| MaxEnt | 0.887 | 0.693 | 0.91 |
| BRT | 0.901 | 0.718 | 0.88 |
| Random Forest | 0.894 | 0.706 | 0.85 |
| **Ensemble (wt avg)** | **0.912** | **0.731** | **0.93** |

## Step 6 — Variable Importance (Ensemble)

| Variable | Importance (%) |
|----------|--------------|
| bio12 (MAP) | 34.2 |
| NDVI_mean | 22.1 |
| bio4 (seasonality) | 18.7 |
| bio1 (MAT) | 12.4 |
| bio15 | 8.3 |
| slope | 4.3 |

## Step 7 — Key Findings

- **Current suitable area:** 2,847,000 km² (MaxTSS threshold = 0.48)
- **Under SSP2-4.5 2050:** 2,231,000 km² (−21.6% change)
- **Main drivers:** Annual precipitation (bio12) and vegetation greenness (NDVI) are the strongest predictors
- **Areas of concern:** Eastern Amazon shows highest predicted loss under climate scenarios
