# Worked Example: BACI — Road Impact on Bird Richness

**Workflow:** assess-ecological-impact  
**System:** Birds (Atlantic Forest fragment)  
**Disturbance:** Federal highway expansion (construction 2018–2019)  
**Control sites:** 8 forest sites > 10 km from road, comparable habitat  
**Impact sites:** 8 forest sites within 2 km of road

---

## Study Design

| Period | Surveys | Dates |
|--------|---------|-------|
| Before | 3 (Jan 2016, Jan 2017, Jan 2018) | 3 annual surveys |
| After | 3 (Jan 2020, Jan 2021, Jan 2022) | 3 annual surveys post-construction |

## Model

```r
richness ~ period * treatment + (1|site), family = nbinom2()
```

## Results

| Term | Estimate | SE | z | p |
|------|---------|----|----|---|
| Intercept | 3.21 | 0.12 | 26.7 | < 0.001 |
| period_after | 0.04 | 0.09 | 0.44 | 0.66 |
| treatment_impact | -0.11 | 0.16 | -0.69 | 0.49 |
| **period_after:treatment_impact** | **-0.31** | **0.12** | **-2.58** | **0.010** |

## Interpretation

The BACI interaction (β = −0.31, SE = 0.12, p = 0.010) indicates a significant negative effect of road construction on bird richness at impact sites relative to control sites.

On the original scale: exp(−0.31) = 0.73, meaning impact sites showed approximately **27% lower bird richness** after road construction compared to what would be expected based on control site trends.

95% CI for the multiplicative effect: [0.58, 0.93]

## Fragmentation Results

| Metric | Pre-road (2015) | Post-road (2022) | Change |
|--------|----------------|-----------------|--------|
| Forest area (ha) | 12,450 | 10,890 | −12.5% |
| Patch count | 23 | 31 | +34.8% |
| Mean patch size (ha) | 541 | 351 | −35.1% |
| Edge density (m/ha) | 87 | 124 | +42.5% |
| MESH (ha) | 3,210 | 1,870 | −41.7% |

## Impact Classification

**Overall impact: MAJOR**

- Significant bird richness decline (−27%, BACI p = 0.010)
- Severe fragmentation increase (MESH −42%)
- High edge density (edge effects affecting interior species)
