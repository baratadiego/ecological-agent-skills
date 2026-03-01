# Worked Example: Puma Occupancy from Camera Traps

**Workflow:** run-occupancy-analysis  
**Species:** Puma concolor  
**Method:** Single-season occupancy (unmarked)  
**Survey:** 60 camera trap stations, 6 survey occasions (12-day periods), Atlantic Forest

---

## Detection History Summary

- Sites: 60
- Occasions: 6 (each = 12 days)
- Total trap-nights: 60 × 72 = 4,320
- Detections: 89 independent events
- Sites with ≥ 1 detection: 31 / 60
- **Naive occupancy:** 0.517

## Candidate Models

| Model | ψ covariates | p covariates | AICc | ΔAIC | Weight |
|-------|-------------|-------------|------|------|--------|
| m3 | forest_cover + dist_to_road | effort | 184.2 | 0.0 | 0.61 |
| m4 | forest_cover | effort | 186.1 | 1.9 | 0.24 |
| m2 | dist_to_road | effort | 189.3 | 5.1 | 0.05 |
| m1 | 1 (null) | effort | 191.7 | 7.5 | 0.02 |
| m0 | 1 | 1 | 192.4 | 8.2 | 0.01 |

## Goodness-of-Fit

MacKenzie-Bailey χ² test (1,000 parametric bootstrap iterations):  
χ²_observed = 12.4, p = 0.34 → **No evidence of lack of fit (ĉ ≈ 1.1, use AICc)**

## Best Model Results (m3)

### Occupancy (ψ)

| Covariate | Estimate (logit) | SE | 95% CI (prob) |
|-----------|----------------|----|--------------|
| Intercept | 0.42 | 0.31 | — |
| forest_cover (std) | 1.18 | 0.29 | — |
| dist_to_road (std) | 0.64 | 0.22 | — |

**Mean ψ = 0.71** (95% CI: 0.58–0.81)

### Detection (p)

| Covariate | Estimate (logit) | SE | p (prob scale) |
|-----------|----------------|----|--------------|
| Intercept | -1.24 | 0.19 | — |
| effort (std) | 0.38 | 0.11 | — |

**Mean p per occasion = 0.22** (95% CI: 0.17–0.28)

### Minimum surveys for absence confirmation (p = 0.22, α = 0.05)

K ≥ log(0.05) / log(1 − 0.22) ≈ **10.4 → 11 surveys needed to confirm absence**

## Ecological Interpretation

Puma occupancy was positively associated with forest cover (β = 1.18, p < 0.001) and distance from roads (β = 0.64, p = 0.004). Sites with > 80% forest cover within 2 km had predicted occupancy of 0.89 (95% CI: 0.74–0.96), compared to 0.31 (95% CI: 0.14–0.55) for sites with < 30% forest cover.
