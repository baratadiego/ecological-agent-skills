# Model Performance Metric Selection Guide

## Binary Classification (Presence/Absence, SDMs)

| Metric | Range | Better | Notes |
|--------|-------|--------|-------|
| AUC-ROC | 0–1 | Higher | Threshold-independent. 0.7 = acceptable, 0.8 = good, 0.9 = excellent. Inflated for large bg samples. |
| TSS (True Skill Statistic) | -1 to 1 | Higher | Threshold-dependent. TSS = Sensitivity + Specificity − 1. 0.4 = acceptable, 0.6 = good. |
| Boyce Index | -1 to 1 | Higher → 1 | Presence-only metric. Preferred over AUC for presence-background models. |
| Kappa | 0–1 | Higher | Prevalence-sensitive; avoid for imbalanced datasets. |
| Brier Score | 0–1 | Lower | Mean squared error of predicted probabilities. Good calibration metric. |
| Sensitivity (Recall) | 0–1 | Higher | True positive rate. Critical when false negatives are costly. |
| Specificity | 0–1 | Higher | True negative rate. |
| F1 Score | 0–1 | Higher | Harmonic mean of precision and recall. Good for imbalanced classes. |

**Recommendation for SDMs:** Report AUC + TSS + Boyce index. Use Boyce as primary for presence-background.

## Regression (Abundance, Biomass, NDVI)

| Metric | Formula | Notes |
|--------|---------|-------|
| RMSE | √(mean((obs−pred)²)) | Same units as response. Lower is better. |
| MAE | mean(|obs−pred|) | Robust to outliers. Lower is better. |
| R² | 1 − SS_res/SS_tot | Proportion variance explained. Higher is better. |
| Bias | mean(pred−obs) | Systematic over/underestimation. Should be ≈ 0. |
| MAPE | mean(|obs−pred|/obs) × 100 | Percentage error. Problematic when obs ≈ 0. |

## Count / Poisson Models

| Metric | Notes |
|--------|-------|
| Pseudo-R² (McFadden) | 1 − (logL_model / logL_null). > 0.2 = good fit. |
| Pearson dispersion | Sum(pearson²) / df. Should be ≈ 1 for well-fitted Poisson. |
| DHARMa KS test | Uniformity of randomised quantile residuals. |

## Occupancy Models

| Metric | Notes |
|--------|-------|
| AUC (if binary) | Applied to site-level occupancy predictions |
| MacKenzie-Bailey χ² | Goodness-of-fit via parametric bootstrap |
| ĉ (c-hat) | Overdispersion factor. If > 1.5, use QAICc. |
| WAIC | For Bayesian occupancy models |

## Reporting Template

Always report as: **metric (train / CV / test)**

Example:
> AUC = 0.91 (train) / 0.84 (spatial CV, 5-fold) / 0.82 (independent test)
> TSS = 0.78 (train) / 0.67 (CV) / 0.65 (test)
> Boyce Index = 0.93 (test)
