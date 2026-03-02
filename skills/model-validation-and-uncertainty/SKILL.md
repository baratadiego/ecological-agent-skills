---
skill_version: 1.0.0
---

# Skill: model-validation-and-uncertainty

**Domain:** Metrics · Calibration · Sensitivity · External validation · Uncertainty  
**Phase:** 2 — Modeling  
**Used by:** run-sdm-study, assess-ecological-impact, analyze-community-structure, build-fire-risk-map, run-occupancy-analysis

---

## Purpose

Guides the agent through rigorous evaluation of any fitted model: computing performance metrics on held-out data, assessing calibration, running sensitivity analyses, performing external validation, and quantifying and visualising prediction uncertainty.

---

## When to Invoke

- After any model is fitted, before results are reported
- When the user asks about model performance, reliability, or uncertainty
- When preparing results for publication or decision-making

---

## Inputs

| Input | Format | Required |
|-------|--------|----------|
| Fitted model object | RData, pkl, ONNX | Yes |
| Validation dataset (independent) | CSV | Yes |
| Training/CV predictions | CSV | Yes |
| Prediction surface/map | GeoTIFF | Conditional |

---

## Outputs

| Output | Description |
|--------|-------------|
| `performance_metrics.csv` | Full metric table (train, CV, test) |
| `calibration_plot.png` | Observed vs predicted calibration curve |
| `roc_curve.png` | ROC curve with AUC (for classifiers) |
| `sensitivity_report.md` | Effect of parameter/predictor perturbation |
| `uncertainty_map.tif` | Spatial uncertainty (SD across ensemble or bootstrap) |
| `validation_report.md` | Comprehensive validation narrative |

---

## Steps

### 1. Select Appropriate Metrics

| Task | Primary metrics | Secondary |
|------|----------------|-----------|
| Binary classification (SDM) | AUC-ROC, TSS, Boyce index | Sensitivity, specificity |
| Regression (abundance, biomass) | RMSE, MAE, R² | Bias, MAPE |
| Occupancy | AUC, WAIC, posterior predictive checks | |
| Community ordination | Stress (NMDS), R² (RDA/CCA) | Procrustes |
| Count / Poisson | RMSE, Pseudo-R², dispersion | |

### 2. Compute Metrics on Train, CV, and Test Sets
- Report all three to diagnose overfitting (train >> CV/test gap)
- Report metric mean ± SD across CV folds

### 3. Assess Calibration
- For classifiers: plot mean predicted probability vs. observed occurrence rate across bins
- For regression: plot predicted vs. observed scatter
- Compute calibration slope and intercept; values near 1 and 0 are ideal

### 4. Threshold Selection (for binary predictions)
- Maximise TSS (Youden's J)
- Maximise Sensitivity + Specificity
- Fixed prevalence-based threshold
- Document chosen threshold and rationale

### 5. Variable Importance and Response Curves
- Compute permutation importance for each predictor
- Plot partial dependence / marginal effect curves for top predictors
- Flag predictors with response curves showing ecologically implausible patterns

### 6. Sensitivity Analysis
- Perturb each hyperparameter by ±10%; measure effect on primary metric
- Remove each predictor in turn; measure effect (jackknife importance)
- Assess sensitivity to background/pseudo-absence sampling strategy (for SDMs)

### 7. External Validation
- Apply model to an independent dataset (different time period, different region)
- Report metric degradation; quantify transferability
- Flag models with poor transferability before applying to novel conditions

### 8. Uncertainty Quantification
- Ensemble SD: standard deviation across ensemble members or bootstrap replicates
- Bayesian credible intervals: for Bayesian models, report posterior predictive intervals
- Map uncertainty spatially where relevant
- Report regions of high uncertainty explicitly

---

## Key Decisions to Document

- Primary and secondary metrics chosen and rationale
- Threshold selection method
- External validation dataset description
- Uncertainty quantification method

---

## Tools and Libraries

**R:** `ROCR`, `PresenceAbsence`, `dismo`, `gbm`, `boot`, `brms`  
**Python:** `sklearn.metrics`, `scikit-learn`, `shap`, `pysdm`

---

## Resources

- `resources/metric-selection-guide.md` — which metrics for which task
- `resources/threshold-selection-guide.md` — threshold methods compared
- `examples/` — calibration plot and uncertainty map examples

---

## Notes

- Never report only training performance
- Boyce index is preferred over AUC for presence-only SDMs
- For small samples, report bootstrapped CIs around all metrics
