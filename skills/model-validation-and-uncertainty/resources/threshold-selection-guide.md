# Threshold Selection Guide for Binary Predictions

## Why Threshold Selection Matters

SDMs and classifiers produce continuous suitability/probability values. A threshold converts these to binary predictions (suitable/not suitable, present/absent). The choice of threshold directly affects the area predicted suitable and the balance of errors.

## Common Methods

### 1. Maximum TSS (Youden's J) — **Recommended general default**
- Threshold that maximises Sensitivity + Specificity − 1
- Balanced between omission and commission errors
- Not sensitive to prevalence

```r
library(PresenceAbsence)
opt_thresh <- optimal.thresholds(
  DATA = data.frame(plotID = 1:nrow(val), obs = val$observed, pred = val$predicted),
  threshold = 101,
  which.model = 1,
  opt.methods = "MaxKappa"  # or "MaxTSS"
)
```

### 2. Equal Sensitivity and Specificity
- Threshold where Sensitivity = Specificity
- Good when false positives and false negatives have equal cost

### 3. Minimum Training Presence (MTP)
- Threshold below which no training presence falls (0th percentile of training scores)
- Very permissive (large suitable area); good for detecting all potential habitat
- Use when false negatives are very costly (conservation planning)

### 4. 10th Percentile Training Presence (P10)
- Threshold below which 10% of training presences fall
- Slightly more restrictive than MTP; removes poorly-surveyed sites
- Standard in MaxEnt studies

### 5. Fixed Prevalence Threshold
- Set threshold to match the observed prevalence in the dataset
- Appropriate when calibration data have known representative prevalence

## Decision Guide

```
Primary goal is conservation planning (find all habitat)?
  → Use MTP or P10 (low omission error)

Primary goal is invasive species management (restrict false positives)?
  → Use Maximum TSS or Equal Sensitivity/Specificity

Publishing an SDM study (general)?
  → Report results at both MaxTSS and P10 thresholds

Comparing multiple species / scenarios?
  → Use a consistent, a priori defined threshold for all
```

## Reporting Requirements

Always report:
- Threshold value used (e.g., 0.42)
- Method used to select it
- Resulting sensitivity, specificity, and TSS at that threshold
- Area predicted suitable (km²) above threshold
