# Example Invocation Prompts — model-validation-and-uncertainty

## Full Validation Suite

```
Load skill: model-validation-and-uncertainty
Task: Validate the SDM ensemble for Chrysocyon brachyurus.
Files:
  - models/ensemble_predictions.csv (columns: site_id, observed, predicted_prob)
  - models/cv_fold_predictions.csv  (columns: fold, observed, predicted_prob)
  - outputs/suitability_ensemble.tif
  - outputs/suitability_sd.tif (uncertainty)

Run:
1. AUC-ROC and TSS on CV folds and independent test set.
2. Boyce index on test set.
3. Calibration plot (10 bins).
4. Threshold selection: MaxTSS and P10.
5. Report: performance_metrics.csv, calibration_plot.png, validation_report.md
```

## Calibration Check Only

```
Load skill: model-validation-and-uncertainty
Task: Calibration assessment only.
Predictions: outputs/glm_predictions.csv (obs: 0/1, pred: probability 0-1).
Generate calibration plot with 10 bins. Report calibration slope and intercept.
A well-calibrated model should have slope ≈ 1 and intercept ≈ 0.
```
