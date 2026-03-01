# SDM Algorithm Comparison

| Algorithm | Type | Presence data | Absence needed | Overfitting risk | Extrapolation | Interpretability |
|-----------|------|--------------|----------------|-----------------|---------------|-----------------|
| MaxEnt | ML (max entropy) | Presence-background | No | Moderate | Poor (clamping) | Moderate |
| BRT/GBM | Ensemble tree | PA or PB | Recommended | High if untuned | Poor | Moderate |
| Random Forest | Ensemble tree | PA or PB | Recommended | Low–moderate | Poor | Low |
| GLM | Statistical | PA | Yes | Low | Good | High |
| GAM | Statistical | PA | Yes | Moderate | Good | High |
| BIOCLIM | Envelope | Presence only | No | Low | Poor | High |
| Mahalanobis | Distance | Presence only | No | Low | Moderate | High |
| SVM | ML | PA or PB | Recommended | Moderate | Moderate | Low |
| ANN / MLP | Deep learning | PA | Recommended | Very high | Poor | Very low |

## Recommendations by Context

| Context | Recommended algorithms |
|---------|----------------------|
| Presence-only data only | MaxEnt + BIOCLIM (ensemble) |
| < 50 occurrences | MaxEnt + GLM (regularised) |
| 50–200 occurrences | MaxEnt + BRT + GLM |
| > 200 occurrences | BRT + RF + GLM + MaxEnt (full ensemble) |
| Need for projection to novel climates | GLM + GAM (better extrapolation) |
| Regulatory / conservation decision | Minimum 3 algorithms in ensemble |
| Publication | Ensemble ≥ 3 algorithms + uncertainty map |
