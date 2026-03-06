# Worked Example: Forest Loss Time Series — Oil Palm Expansion in Borneo

**Workflow:** assess-ecological-impact
**System:** Tropical rainforest of Borneo (Malaysia: Sabah/Sarawak; Indonesia: Kalimantan)
**Disturbance:** Oil palm concession establishment (2008--2012)
**Analysis:** BFAST breakpoint detection + landscape fragmentation (MESH) + BACI design
**Highlight:** Integration of NDVI time series with fragmentation metrics to quantify commodity-driven deforestation impact

---

## Step 1 --- Data Sources

| Dataset | Source | Spatial resolution | Temporal extent | Access |
|---------|--------|-------------------|----------------|--------|
| Hansen Global Forest Change (GFC) | University of Maryland / USGS | 30 m | 2000--2023 | Open; doi:10.1126/science.1244693 |
| MODIS NDVI (MOD13Q1) | NASA LP DAAC | 250 m, 16-day composites | 2000--2023 | Open; MODIS product |
| Oil palm concession boundaries | WRI Global Forest Watch | Vector polygons | Updated 2023 | Open; WRI |
| Borneo DEM (SRTM) | NASA / USGS | 90 m | Static (2000) | Open; SRTM v4.1 |

Hansen GFC layers used: `treecover2000` (baseline canopy cover %), `lossyear` (annual loss 2001--2023), `gain` (binary gain 2000--2012).

---

## Step 2 --- Study Design (BACI)

| Component | Description |
|-----------|-------------|
| Impact sites | 12 oil palm concession areas established 2008--2012 |
| Control sites | 12 matched protected forest areas (Sabah Parks, Heart of Borneo corridor) |
| Matching criteria | Elevation (< 150 m difference), slope (< 5 deg difference), initial tree cover (> 85% in both) |
| Before period | 2000--2007 (pre-concession baseline) |
| After period | 2013--2023 (post-conversion monitoring) |
| Buffer | 2008--2012 excluded as transition window |

**Response variables:**

| Variable | Source | Unit |
|----------|--------|------|
| NDVI trend | MODIS MOD13Q1 | Dimensionless (0--1) |
| Tree cover | Hansen GFC treecover2000 + lossyear | % canopy cover |
| Effective mesh size (MESH) | Derived from GFC binary forest mask | ha |

---

## Step 3 --- NDVI Time Series Analysis (BFAST)

BFAST decomposition applied to each site's mean NDVI time series (n = 552 composites per site over 2000--2023):

```
Y_t = T_t + S_t + e_t
```

where T_t = trend component, S_t = seasonal component, e_t = remainder.

### Breakpoint Detection Summary

| Metric | Impact sites (n = 12) | Control sites (n = 12) |
|--------|----------------------|----------------------|
| Sites with significant negative breakpoint | 10 (83%) | 1 (8%) |
| Sites with breakpoint within 2 yr of concession start | 10 (87% of detected) | 0 (0%) |
| Mean breakpoint year | 2010.4 +/- 1.1 | --- |
| Mean NDVI at breakpoint (drop magnitude) | -0.28 +/- 0.06 | -0.04 +/- 0.02 |
| Mean pre-breakpoint NDVI | 0.82 +/- 0.03 | 0.84 +/- 0.02 |
| Mean post-breakpoint NDVI | 0.54 +/- 0.08 | 0.80 +/- 0.03 |

Control site breakpoint (1 site) attributable to localised drought event (2015--2016 El Nino).

### Seasonal Component

Seasonal amplitude remained stable in control sites (mean = 0.06) but collapsed post-conversion in impact sites (pre: 0.07, post: 0.03), consistent with replacement of heterogeneous canopy by monoculture.

---

## Step 4 --- Tree Cover Change

| Group | Period | Mean tree cover (%) | SD (%) |
|-------|--------|-------------------|--------|
| Impact | Before (2000--2007) | 89.2 | 4.1 |
| Impact | After (2013--2023) | 31.4 | 18.7 |
| Control | Before (2000--2007) | 91.1 | 3.2 |
| Control | After (2013--2023) | 87.3 | 5.1 |

| Summary | Impact | Control |
|---------|--------|---------|
| Absolute change (pp) | **-57.8** | -3.8 |
| Relative change (%) | -64.8% | -4.2% |
| Net BACI effect | **-54.0 pp** | --- |

The 18.7% SD in post-conversion impact sites reflects heterogeneity among concessions: some retained small forest set-asides (high residual cover) while others cleared to near-zero canopy.

---

## Step 5 --- Fragmentation Analysis (MESH)

Effective mesh size (MESH) computed from binary forest mask (tree cover >= 60%) within a 10 km buffer around each site centroid.

### Primary Metric: Effective Mesh Size

| Group | MESH before (ha) | MESH after (ha) | Change (ha) | Change (%) |
|-------|-----------------|----------------|------------|-----------|
| Impact | 4,230 | 142 | -4,088 | **-96.6%** |
| Control | 5,180 | 4,890 | -290 | -5.6% |

### Supplementary Fragmentation Metrics (Impact Sites Only)

| Metric | Before (2007) | After (2023) | Change |
|--------|-------------|------------|--------|
| Number of patches (NP) | 8.3 +/- 2.1 | 47.6 +/- 12.3 | +473% |
| Edge density (m/ha) | 42.1 +/- 8.4 | 218.7 +/- 31.2 | +419% |
| Largest patch index (%) | 78.4 +/- 6.2 | 12.1 +/- 9.8 | -84.6% |
| Mean patch area (ha) | 1,412 +/- 340 | 38.2 +/- 21.4 | -97.3% |

---

## Step 6 --- BACI Statistical Model

### NDVI Model

```r
library(lme4)
m_ndvi <- lmer(ndvi ~ period * treatment + (1 | site_pair), data = baci_data)
anova(m_ndvi, type = "III")
```

| Term | Sum Sq | df | F | p |
|------|--------|----|----|---|
| period | 0.012 | 1 | 2.14 | 0.152 |
| treatment | 0.038 | 1 | 6.71 | 0.014 |
| **period x treatment** | **0.268** | **1** | **47.3** | **< 0.001** |
| Residual | 0.249 | 44 | --- | --- |

**Effect size (Cohen's d):** 2.8 (very large)
**95% CI for interaction coefficient:** [-0.34, -0.22]

### MESH Model

```r
m_mesh <- lmer(log(mesh + 1) ~ period * treatment + (1 | site_pair), data = baci_data)
anova(m_mesh, type = "III")
```

| Term | Sum Sq | df | F | p |
|------|--------|----|----|---|
| period | 1.42 | 1 | 4.87 | 0.033 |
| treatment | 3.18 | 1 | 10.91 | 0.002 |
| **period x treatment** | **9.10** | **1** | **31.2** | **< 0.001** |
| Residual | 12.84 | 44 | --- | --- |

**Effect size (Cohen's d):** 2.1 (very large)
**Observed statistical power (post hoc):** 0.99 for NDVI interaction; 0.97 for MESH interaction

---

## Step 7 --- Spatial Pattern of Loss

### Lossyear Raster Analysis

| Year | Area lost (ha) within concessions | Cumulative loss (%) |
|------|----------------------------------|-------------------|
| 2008 | 8,420 | 12.1 |
| 2009 | 14,630 | 33.2 |
| 2010 | 16,210 | 56.5 |
| 2011 | 12,870 | 75.0 |
| 2012 | 7,340 | 85.6 |
| 2013--2023 | 10,030 | 100.0 |

Peak conversion occurred 2009--2011, accounting for 62.8% of total forest loss within concession boundaries.

### Frontier Progression

| Distance from existing plantation edge | Proportion of loss |
|--------------------------------------|-------------------|
| 0--1 km | 34% |
| 1--3 km | 28% |
| 3--5 km | 16% |
| > 5 km | 22% |

**78% of all forest loss occurred within 5 km of existing plantation boundaries**, consistent with a frontier-expansion model of conversion.

### Riparian Buffer Compliance

| Buffer criterion | Concessions in compliance | Concessions in violation |
|-----------------|--------------------------|------------------------|
| 50 m riparian buffer (Malaysian standard) | 7 / 12 (58%) | **5 / 12 (42%)** |
| 100 m riparian buffer (RSPO guideline) | 3 / 12 (25%) | **9 / 12 (75%)** |

43% of concessions violated the 50 m riparian buffer requirement under Malaysian national law; 75% violated the more stringent RSPO voluntary standard.

---

## Ecological Interpretation

1. **Near-total habitat loss.** Oil palm conversion causes abrupt, near-complete canopy removal (mean loss = -57.8 pp) rather than gradual degradation. The BFAST breakpoint timing closely tracks concession establishment dates, confirming a direct causal link between concession licensing and forest loss.

2. **Functional isolation of remnant patches.** MESH reduction from approximately 4,230 ha to 142 ha (96.6%) indicates that remaining forest patches are too small and isolated to sustain area-sensitive species. Patch count increased nearly five-fold while mean patch area declined by 97%.

3. **Corridor severance.** Riparian buffer violations in 43--75% of concessions (depending on standard applied) sever hydrological and terrestrial corridor connectivity between remaining forest blocks, compounding the isolation effect measured by MESH.

4. **Monoculture homogenisation.** Collapse of NDVI seasonal amplitude post-conversion (from 0.07 to 0.03) reflects the replacement of structurally complex rainforest canopy by uniform oil palm plantation, reducing microhabitat heterogeneity.

5. **BACI design validation.** Control sites showed minimal change over the same period (tree cover loss = -3.8 pp, MESH loss = -5.6%), confirming that observed impacts at concession sites are attributable to conversion rather than regional climatic trends.

---

## Recommendations

1. **BFAST for abrupt change detection.** BFAST is effective for detecting commodity-driven land-use change in tropical forests where conversion is rapid (1--3 year clearing window). It outperforms linear trend analysis which underestimates the magnitude and timing of impact.

2. **Paired response variables.** Combining NDVI time series (intensity of change) with fragmentation metrics (spatial pattern of change) provides complementary evidence: NDVI captures the magnitude and timing of canopy loss while MESH captures the ecological consequences for landscape connectivity.

3. **Riparian compliance as standard metric.** Riparian buffer compliance should be included as a routine metric in environmental impact assessments for plantation development. The high violation rate observed here (43--75%) suggests current enforcement is insufficient.

4. **Statistical power.** The 12-site-pair design provided observed power >= 0.97 for the detected effect sizes. For smaller effect sizes (Cohen's d >= 0.8), a minimum of 20 site pairs is recommended.

5. **Temporal buffer.** Excluding the transition period (2008--2012) from both Before and After groups avoids ambiguity in assignment and strengthens causal inference under the BACI framework.

---

## References

- Hansen, M.C. et al. (2013). High-resolution global maps of 21st-century forest cover change. *Science*, 342(6160), 850--853. doi:10.1126/science.1244693
- Verbesselt, J. et al. (2010). Detecting trend and seasonal changes in satellite image time series. *Remote Sensing of Environment*, 114(1), 106--115. doi:10.1016/j.rse.2009.08.014
- Gaveau, D.L.A. et al. (2016). Rapid conversions and avoided deforestation: examining four decades of industrial plantation expansion in Borneo. *Scientific Reports*, 6, 32017. doi:10.1038/srep32017
- Jaeger, J.A.G. (2000). Landscape division, splitting index, and effective mesh size: new measures of landscape fragmentation. *Landscape Ecology*, 15, 115--130. doi:10.1023/A:1008129329289
- Carlson, K.M. et al. (2012). Committed carbon emissions, deforestation, and community land conversion from oil palm plantation expansion in West Kalimantan, Indonesia. *Proceedings of the National Academy of Sciences*, 109(19), 7559--7564. doi:10.1073/pnas.1200452109
