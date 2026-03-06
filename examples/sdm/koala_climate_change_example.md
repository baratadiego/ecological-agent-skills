# Worked Example: Koala SDM with Climate Change Projections

**Workflow:** run-sdm-study
**Species:** Phascolarctos cinereus (koala)
**Study area:** Eastern Australia (Queensland, New South Wales, Victoria, South Australia)
**Predictors:** WorldClim v2.1 current + CMIP6 2050 (SSP2-4.5, SSP5-8.5)
**Special focus:** MOP extrapolation analysis for future projections

---

## Step 1 — Data Sources

| Dataset | Source | Records |
|---------|--------|---------|
| GBIF occurrence | doi:10.15468/dl.xxxxx | 18,500 raw |
| Atlas of Living Australia | ala.org.au | 42,300 raw |
| **Total raw** | — | **60,800** |
| After deduplication | — | 28,400 |
| After coordinate cleaning | — | 12,400 |
| **After 10 km thinning** | — | **1,830** |

Predictors:

| Source | Variables | Resolution | Period |
|--------|-----------|-----------|--------|
| WorldClim v2.1 | 19 BIO + elevation | 2.5 arc-min | 1970–2000 |
| CMIP6 ensemble (5 GCMs) | 19 BIO | 2.5 arc-min | 2041–2060 |
| MODIS MOD13A3 | NDVI annual mean | 1 km | 2010–2020 |
| Hansen GFC | tree cover 2000 | 30 m (aggregated to 2.5') | 2000 |

GCMs used: ACCESS-CM2, CNRM-CM6-1, EC-Earth3-Veg, MIROC6, MRI-ESM2-0

## Step 2 — QA Results Summary

| Issue | Count | Action |
|-------|-------|--------|
| Zero / missing coordinates | 340 | Removed |
| Country centroid | 89 | Removed |
| Coordinate precision < 10 km | 1,200 | Removed |
| Pre-1990 records | 8,700 | Removed (climate mismatch) |
| Exact duplicates | 22,100 | Deduplicated |
| Outside Australia polygon | 170 | Removed |
| Marine / sea coordinates | 41 | Removed |
| After cleaning | **12,400** | Retained |
| After 10 km thinning (spThin) | **1,830** | Retained |

## Step 3 — Calibration Area (M)

M = IUCN koala distribution range (2022 assessment) buffered 200 km.

Rationale: koala is an arboreal folivore restricted to Eucalyptus woodland in eastern Australia. The arid interior and western Australia are inaccessible — no records, no suitable habitat. Including those areas would inflate apparent niche breadth.

M area: 2,840,000 km²

## Step 4 — Collinearity Results

Final predictor set after VIF reduction (threshold VIF < 5):

| Variable | VIF | Decision |
|----------|-----|----------|
| bio1 (MAT) | 2.3 | Keep |
| bio4 (Temp seasonality) | 3.1 | Keep |
| bio12 (MAP) | 2.7 | Keep |
| bio15 (Prec seasonality) | 2.4 | Keep |
| NDVI_mean | 1.9 | Keep |
| tree_cover | 2.1 | Keep |
| bio5 | 9.3 | **Remove** (collinear with bio1) |
| bio6 | 8.7 | **Remove** (collinear with bio1) |
| bio13 | 7.1 | **Remove** (collinear with bio12) |

Retained: 6 predictors

## Step 5 — Spatial CV Configuration

```
Block size: 250 km (exceeds SAC range of ~180 km)
Folds: 5
Presences per fold: 310–420
Background per fold: 8,200–9,100
```

## Step 6 — Model Performance (Current Climate)

| Algorithm | AUC (CV) | TSS (CV) | Boyce (test) |
|-----------|---------|---------|-------------|
| MaxEnt | 0.872 | 0.684 | 0.87 |
| BRT | 0.891 | 0.703 | 0.91 |
| RF | 0.865 | 0.672 | 0.84 |
| GLM | 0.849 | 0.651 | 0.80 |
| **Ensemble (TSS-weighted)** | **0.901** | **0.721** | **0.93** |

## Step 7 — Variable Importance

| Variable | Contribution (%) |
|----------|-----------------|
| tree_cover | 31 |
| bio12 (MAP) | 24 |
| bio1 (MAT) | 18 |
| NDVI_mean | 10 |
| bio15 (Prec seasonality) | 9 |
| bio4 (Temp seasonality) | 8 |

Tree cover dominance is ecologically expected — koalas are obligate arboreal folivores dependent on Eucalyptus canopy.

## Step 8 — Current Suitability

Threshold: 10th percentile training presence (OR10)

| Category | Area (km²) | % of M |
|----------|-----------|--------|
| Core habitat (> 0.6) | 412,000 | 14.5 |
| Moderate (0.3–0.6) | 835,000 | 29.4 |
| **Total suitable** | **1,247,000** | **43.9** |

Core habitat concentrated along eastern seaboard from SE Queensland through NSW to Victoria, with inland extensions along major river systems.

## Step 9 — Future Projections (2050)

| Scenario | Suitable area (km²) | Change (%) | Core habitat (km²) | Core change (%) |
|----------|-------------------|-----------|-------------------|----------------|
| Current | 1,247,000 | — | 412,000 | — |
| SSP2-4.5 (2050) | 987,000 | −20.9 | 298,000 | −27.7 |
| SSP5-8.5 (2050) | 743,000 | −40.4 | 187,000 | −54.6 |

Geographic shifts:

| Region | SSP2-4.5 change (km²) | SSP5-8.5 change (km²) |
|--------|----------------------|----------------------|
| Northern QLD (loss) | −189,000 | −312,000 |
| Central NSW (loss) | −94,000 | −178,000 |
| Tasmania (gain) | +23,000 | +41,000 |
| Southern Victoria (stable/gain) | +8,000 | −12,000 |
| Net range shift | ~200 km south | ~350 km south |

## Step 10 — MOP Extrapolation Analysis

MOP (Mobility-Oriented Parity) identifies areas where future climate has no analogue in current training data.

| Scenario | % projected range in extrapolation (MOP < 0.5) | Location of extrapolation |
|----------|----|-----|
| SSP2-4.5 | 8.2 | Inland QLD/NSW edges |
| SSP5-8.5 | 17.4 | Inland + northern QLD |

Extrapolation is concentrated where future temperatures exceed the maximum in current training data. Predictions in these zones are unreliable and should be masked or flagged in published maps.

## Ecological Interpretation

- **Tree cover is the strongest predictor** (31%), reflecting obligate dependence on Eucalyptus canopy. Climate suitability alone is insufficient — habitat must exist.
- **Precipitation (bio12) ranks second** (24%). Drought stress reduces Eucalyptus leaf water content, causing koala starvation and dehydration — the proximate cause of mass mortality during the 2019–2020 drought.
- **Range contraction is projected from the northern margin**, consistent with increasing heat stress and declining precipitation.
- **Tasmania emerges as a climate refugium** (+23,000 to +41,000 km²), but requires Eucalyptus woodland connectivity. Currently, koalas do not occur naturally in Tasmania.
- **SSP5-8.5 projects > 50% core habitat loss**, consistent with the IUCN uplisting from Vulnerable to Endangered (2022).
- **MOP flags 17% of SSP5-8.5 projections as extrapolation** — publishing raw suitability maps without extrapolation flags would be misleading.

## Recommendations

1. **Always compute MOP** when projecting SDMs to future scenarios. Raw suitability maps without extrapolation flags overstate confidence.
2. **Use multi-GCM ensemble** (≥ 5 GCMs) to capture inter-model uncertainty in climate projections.
3. **Compare SSP scenarios** to bracket plausible futures — SSP2-4.5 and SSP5-8.5 span the moderate-to-high range.
4. **Consider dispersal limitation**: koala maximum natal dispersal is ~50 km (Dique et al. 2003). Newly suitable areas in Tasmania are unreachable without assisted translocation.
5. **Pair SDM projections with land-use scenarios** — suitable climate does not equal suitable habitat if forest is cleared for agriculture or development.
6. **Report both continuous suitability and binary thresholded maps** — OR10 threshold provides conservative range estimate.

## References

- Adams-Hosking, C., McAlpine, C.A., Rhodes, J.R., Grantham, H.S. & Moss, P.T. (2016). Modelling changes in the distribution of the critical habitat of the koala. *Animal Conservation*, 19(6), 529–540. doi:10.1111/acv.12271
- Araújo, M.B. & New, M. (2007). Ensemble forecasting of species distributions. *Trends in Ecology & Evolution*, 22(1), 42–47. doi:10.1016/j.tree.2006.09.010
- Dique, D.S., Thompson, J., Preece, H.J., de Villiers, D.L. & Carrick, F.N. (2003). Dispersal patterns in a regional koala population in south-east Queensland. *Wildlife Research*, 30, 281–290. doi:10.1071/WR01043
- Owens, H.L., Campbell, L.P., Dornak, L.L., et al. (2013). Constraints on interpretation of ecological niche models by limited environmental ranges on calibration areas. *Ecological Modelling*, 263, 10–18. doi:10.1016/j.ecolmodel.2013.04.011
- Woinarski, J.C.Z. & Burbidge, A.A. (2022). Phascolarctos cinereus (amended assessment). *The IUCN Red List of Threatened Species* 2022: e.T16892A166496779.
