# Worked Example: Snow Leopard Occupancy in the Central Himalayas

**Workflow:** run-occupancy-analysis
**Species:** Panthera uncia (snow leopard)
**Study area:** Central Himalayas, Nepal/India border (Kanchenjunga-Makalu landscape)
**Method:** Single-season occupancy model (unmarked)
**Survey:** 64 camera trap stations across 4 valleys, 3 survey occasions (30-day periods), Oct--Dec 2023

---

## Step 1 --- Survey Design

| Parameter | Value |
|-----------|-------|
| Camera trap stations | 64 (16 per valley) |
| Valleys surveyed | Ghunsa, Olangchung, Thudam, Papung |
| Altitude range | 3,200--5,100 m a.s.l. |
| Survey period | 1 October -- 31 December 2023 |
| Sampling occasions | 3 (each = 30-day window) |
| Total trap-nights | 64 x 90 = **5,760** |
| Camera model | Reconyx HyperFire HP2X |
| Minimum station spacing | 2.5 km (based on estimated female home range) |
| Placement protocol | Ridge lines, cliff bases, scent-marking rocks along game trails |

Station placement followed a systematic random design stratified by altitude band (3,200--3,800 m, 3,800--4,400 m, 4,400--5,100 m) to ensure representation across the elevational gradient. Two cameras were deployed per station (opposing angles) to maximise individual capture probability and reduce false negatives.

---

## Step 2 --- Detection History Summary

| Metric | Value |
|--------|-------|
| Total independent detections | 47 events |
| Stations with >= 1 detection | 22 / 64 |
| **Naive occupancy** | **0.344** |

### Detections per occasion

| Occasion | Period | Stations with detection | Detection rate |
|----------|--------|------------------------|---------------|
| occ1 | 01 Oct -- 30 Oct | 14 | 0.219 |
| occ2 | 01 Nov -- 30 Nov | 11 | 0.172 |
| occ3 | 01 Dec -- 31 Dec | 9 | 0.141 |

Detection frequency declined across occasions, consistent with increasing snow accumulation reducing camera trigger reliability and potentially restricting animal movement at the highest stations.

---

## Step 3 --- Site Covariates (Occupancy)

All continuous covariates were standardised to zero mean and unit variance (z-score) prior to modelling.

| Covariate | Description | Mean | SD | Range |
|-----------|-------------|------|----|-------|
| altitude | Elevation (m a.s.l.) | 4,150 | 520 | 3,200--5,100 |
| ruggedness | Terrain Ruggedness Index (TRI, SRTM 30 m) | 287 | 94 | 112--518 |
| distance_to_ridge | Distance to nearest ridgeline (km) | 1.42 | 0.87 | 0.08--3.91 |
| prey_index | Blue sheep (Pseudois nayaur) pellet group count within 500 m radius | 8.3 | 5.1 | 0--24 |
| human_disturbance | Distance to nearest permanent settlement (km) | 6.7 | 3.4 | 0.9--18.2 |

Prey index was derived from systematic pellet transects conducted at each camera station during the deployment visit. Blue sheep pellet groups were counted within a 500 m radius following the protocol of Jackson et al. (2006).

---

## Step 4 --- Detection Covariates

| Covariate | Description | Type | Mean / Levels | Range |
|-----------|-------------|------|---------------|-------|
| snow_depth | MODIS fractional snow cover (MOD10A1), 30-day composite per occasion | Continuous | 42% | 0--98% |
| temperature | Minimum temperature from on-site data logger (degrees C), occasion mean | Continuous | -8.3 | -22.1 -- 3.6 |
| trail_width | Trail type at station | Categorical | game trail (n=28), livestock trail (n=21), none (n=15) | --- |

Snow depth and temperature were expected to influence camera trap performance (battery life, trigger speed) and animal activity patterns. Trail type was hypothesised to affect the probability that a snow leopard, if present, would pass within the camera detection zone.

---

## Step 5 --- Model Selection

Models were fitted using the `unmarked` package in R (`occu()` function). Model selection was based on AICc given the moderate sample size (n = 64 sites).

| Rank | Model | psi covariates | p covariates | K | AICc | dAICc | w |
|------|-------|---------------|-------------|---|------|-------|---|
| 1 | m5 | altitude + altitude^2 + prey_index + ruggedness | snow_depth + trail | 9 | 342.1 | 0.0 | 0.42 |
| 2 | m4 | altitude + altitude^2 + prey_index | snow_depth + trail | 8 | 343.4 | 1.3 | 0.22 |
| 3 | m6 | altitude + altitude^2 + prey_index + human_dist | snow_depth | 8 | 344.2 | 2.1 | 0.15 |
| 4 | m3 | altitude + altitude^2 + ruggedness | snow_depth + trail | 8 | 345.8 | 3.7 | 0.07 |
| 5 | m2 | altitude + altitude^2 | snow_depth | 5 | 348.9 | 6.8 | 0.01 |
| 6 | m1 | prey_index | snow_depth | 4 | 352.3 | 10.2 | <0.01 |
| 7 | m0 | 1 (null) | 1 (null) | 2 | 360.5 | 18.4 | <0.001 |

### Goodness-of-fit

MacKenzie--Bailey chi-squared test (1,000 parametric bootstrap iterations):
chi-squared_observed = 14.7, p = 0.28 --> **No evidence of lack of fit (c-hat = 1.12; AICc retained)**

---

## Step 6 --- Parameter Estimates (Top Model m5)

### Occupancy covariates (logit scale)

| Covariate | Beta | SE | z | P |
|-----------|------|----|---|---|
| Intercept | -0.12 | 0.34 | -0.35 | 0.724 |
| altitude (linear, std) | 0.41 | 0.28 | 1.46 | 0.143 |
| altitude^2 (std) | **-0.84** | 0.31 | -2.71 | **0.007** |
| prey_index (std) | **1.12** | 0.38 | 2.95 | **0.003** |
| ruggedness (std) | **0.67** | 0.29 | 2.31 | **0.021** |

The quadratic altitude term (beta = -0.84) indicates a unimodal response with peak predicted occupancy at approximately 4,200 m a.s.l. Prey availability (beta = 1.12) was the strongest positive predictor: a one-SD increase in pellet count raised the odds of occupancy by a factor of 3.06 (exp(1.12)). Rugged terrain (beta = 0.67) was positively associated with occupancy, consistent with the species' preference for broken cliff habitat.

### Detection covariates (logit scale)

| Covariate | Beta | SE | z | P |
|-----------|------|----|---|---|
| Intercept | -1.14 | 0.26 | -4.38 | <0.001 |
| snow_depth (std) | **-0.53** | 0.21 | -2.52 | **0.012** |
| trail_type: game trail | **0.89** | 0.34 | 2.62 | **0.009** |
| trail_type: livestock trail | 0.31 | 0.36 | 0.86 | 0.389 |

Deep snow reduced detection probability (beta = -0.53), likely through impaired camera trigger mechanisms and altered animal movement routes. Cameras on game trails had significantly higher detection than random placements (beta = 0.89), translating to a 2.4-fold increase in the odds of detection per occasion.

---

## Step 7 --- Derived Estimates

| Parameter | Estimate | SE | 95% CI |
|-----------|----------|----|--------|
| Model-averaged occupancy (psi-hat) | **0.47** | 0.08 | 0.32--0.63 |
| Mean detection probability (p-hat) | **0.31** | 0.05 | 0.22--0.42 |
| Naive occupancy | 0.34 | --- | --- |

- Naive occupancy (0.34) **underestimates true occupancy by 28%** (0.47 vs 0.34), underscoring the importance of accounting for imperfect detection in low-density carnivore surveys.
- Model-averaging was conducted across all models with dAICc < 7 using Burnham--Anderson weights.

### Minimum surveys for absence confirmation

Given p-hat = 0.31 and a desired confidence of alpha = 0.05:

```
K >= log(0.05) / log(1 - 0.31) = 8.1 --> 9 occasions minimum
```

With only 3 occasions in this study, the probability of detecting the species at an occupied site was:

```
P(detect | present) = 1 - (1 - 0.31)^3 = 0.672
```

This means roughly one-third of occupied sites may go undetected with the current design --- reinforcing that at minimum **4 occasions** are required for reliable inference when p < 0.35.

---

## Step 8 --- Predicted Occupancy Map

Occupancy probability was predicted across a 1 km^2 grid covering the 1,840 km^2 study area using the top model and spatially explicit covariate layers.

| Occupancy class | psi range | Area (km^2) | % of study area | Description |
|-----------------|-----------|-------------|-----------------|-------------|
| **High** | > 0.6 | 423 | 23% | Alpine ridgelines, 3,900--4,500 m; high prey density; remote from settlements |
| **Medium** | 0.3--0.6 | 626 | 34% | Transitional slopes; moderate ruggedness; mixed prey availability |
| **Low** | < 0.3 | 791 | 43% | Valley floors near settlements; very high altitude (> 4,800 m) with sparse prey |

High-occupancy zones concentrated along the ridgeline corridor connecting Ghunsa and Thudam valleys, forming a potential dispersal axis for the regional population. The lowest predicted occupancy occurred at elevations above 4,800 m where blue sheep density drops sharply and terrain becomes predominantly glacial.

---

## Ecological Interpretation

1. **Unimodal altitude effect.** The quadratic altitude term reveals peak occupancy at approximately 4,200 m a.s.l., closely matching the upper distribution of blue sheep herds in the study area. Occupancy declines both at lower elevations (where human disturbance increases) and at the highest elevations (where prey becomes scarce and snow cover is persistent). This pattern is consistent with range-wide assessments by the Snow Leopard Trust (2023).

2. **Prey availability as the dominant driver.** The prey index (beta = 1.12) emerged as the single strongest predictor of snow leopard site use. This finding aligns with Jackson et al. (2006), who identified ungulate biomass as the primary determinant of snow leopard density across their range. Sites in the upper quartile of prey index (>= 13 pellet groups) had predicted occupancy of 0.74 (95% CI: 0.56--0.87), compared to 0.19 (95% CI: 0.08--0.39) at sites with zero pellet detections.

3. **Rugged terrain preference.** Positive association with TRI (beta = 0.67) reflects the species' well-documented reliance on broken cliff habitat for stalking prey, denning, and avoiding interspecific competition. Flat or gently undulating terrain within the study area was largely avoided.

4. **Low detection probability.** Mean per-occasion detection of 0.31 confirms that snow leopards are among the most difficult large carnivores to survey. Naive occupancy underestimated model-based occupancy by 28%, a magnitude consistent with findings from other high-altitude felid studies. This underscores the necessity of occupancy modelling frameworks (MacKenzie et al., 2002) for reliable inference on elusive species.

5. **Human disturbance signal.** Although distance to settlement did not appear in the top model, it featured in the third-ranked model (dAICc = 2.1, w = 0.15), suggesting a marginal negative effect. Given the conservation relevance of human--wildlife conflict in the region, further investigation with a larger sample is warranted.

---

## Recommendations

### Survey design
- **Minimum 4 occasions** recommended for species with p < 0.35 to achieve detection probability > 0.80 at occupied sites.
- **Camera placement on game trails** increases detection 2.4x relative to random placement; prioritise ridgeline game trails with scent-marking evidence.
- **Winter surveys (Oct--Dec)** are optimal: reduced vegetation obstruction, snow tracking aids station selection, and snow leopard territorial marking behaviour peaks during pre-mating season.

### Conservation priorities
- Protect the high-occupancy ridgeline corridor (3,900--4,500 m) connecting Ghunsa and Thudam valleys as a priority zone for anti-poaching patrols and livestock management programmes.
- Expand blue sheep monitoring to quantify prey population trends --- occupancy of the predator is tightly coupled to prey availability.
- Investigate human disturbance effects with a targeted design including stations at varying distances from settlements to inform community-based conservation interventions.

### Analytical considerations
- With c-hat = 1.12, model fit is acceptable but not exemplary; consider multi-season models as additional years of data accumulate to assess colonisation-extinction dynamics.
- Bayesian estimation may be preferable for very sparse detection histories (few detections per site) to stabilise parameter estimates.

---

## References

- Jackson, R.M., Roe, J.D., Wangchuk, R. & Hunter, D.O. (2006). Estimating snow leopard population abundance using photography and capture-recapture techniques. *Wildlife Society Bulletin*, 34(3), 772--781. doi:10.2193/0091-7648(2006)34[772:ESLPAU]2.0.CO;2
- MacKenzie, D.I., Nichols, J.D., Lachman, G.B., Droege, S., Royle, J.A. & Langtimm, C.A. (2002). Estimating site occupancy rates when detection probabilities are less than one. *Ecology*, 83(8), 2248--2255. doi:10.1890/0012-9658(2002)083[2248:ESORWD]2.0.CO;2
- Snow Leopard Trust (2023). Range-wide monitoring data. https://snowleopard.org
