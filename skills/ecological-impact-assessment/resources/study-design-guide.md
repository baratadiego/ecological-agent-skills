# BACI Study Design Guide

## Overview

A well-designed BACI (Before-After Control-Impact) study requires careful decisions about site selection, survey timing, and sample size before fieldwork begins. Underpowered studies cannot detect real impacts; overdesigned studies waste resources. This guide provides evidence-based recommendations for each decision.

---

## 1. How Many Sites? Control vs. Impact

### Recommendation: ≥ 5 control + ≥ 5 impact sites

| Sites per group | Approx. power (d=0.5, 4 surveys, α=0.05) | Notes |
|----------------|------------------------------------------|-------|
| 3               | ~0.29                                    | Severely underpowered; only detect large effects |
| 5               | ~0.46                                    | Minimum acceptable for preliminary screening |
| 10              | ~0.74                                    | Adequate for medium-large effects |
| 15              | ~0.89                                    | Recommended for publication |
| 20+             | ~0.95+                                   | Required for small effects (d < 0.3) |

**Why spatial replication matters more than temporal:** Adding sites reduces pseudo-replication and provides genuine spatial independence. Multiple survey occasions at the same site are not independent — they increase precision within a site but cannot substitute for spatial replication.

**Equal vs. unequal allocation:** Balance (equal n control and impact) is optimal when variance is homogeneous. If one group is more variable, allocate more sites there (proportional to σ ratio).

---

## 2. How Many Surveys? Before and After

### Recommendation: ≥ 3 pre-impact + ≥ 3 post-impact occasions

| Survey design | Notes |
|--------------|-------|
| 1 before + 1 after | Inadequate — cannot estimate background variance |
| 2 before + 2 after | Marginal — acceptable only with many sites (n ≥ 15) |
| **3 before + 3 after** | **Minimum recommended** |
| 4 before + 4 after | Preferred for publication; allows seasonal coverage |
| 6+ before + 6+ after | Required for detecting gradual, delayed, or cyclical impacts |

**Asymmetric designs:** More pre-impact surveys are better than symmetric if baseline variance is unknown (collect baseline data opportunistically while awaiting impact).

**Temporal extent:** Surveys should span at least one full seasonal cycle (12 months) to avoid confounding phenological variation with impact effects.

---

## 3. How to Select Control Sites (Matching Criteria)

Control sites must be ecologically equivalent to impact sites in every way **except** exposure to the stressor. Failure here is the most common source of BACI bias.

### Matching criteria checklist

| Criterion | Description | How to verify |
|-----------|-------------|---------------|
| **Habitat type** | Same vegetation class, canopy cover, soil type | Remote sensing / field survey |
| **Disturbance history** | No recent land-use change within ≥ 10 years | Historical imagery / land records |
| **Hydrology** | Similar drainage, upstream catchment area | GIS topographic analysis |
| **Human access** | Similar road density, hunting/gathering pressure | Map + community consultation |
| **Spatial isolation** | ≥ minimum dispersal distance from impact site | Species-specific dispersal data |
| **Environmental gradients** | Similar elevation, aspect, slope | DEM analysis |
| **Connectivity** | No shared corridor that allows spill-over | Landscape connectivity analysis |

### Matching algorithm (propensity score matching)
```r
# Using MatchIt package
library(MatchIt)
match_obj <- matchit(treated ~ habitat + elevation + slope + dist_road,
                     data      = site_covariates,
                     method    = "nearest",
                     distance  = "logit",
                     ratio     = 1)  # 1:1 matching
summary(match_obj)
# Check standardised mean differences < 0.1 for all covariates
```

---

## 4. Survey Interval (Closure Period)

The time between consecutive survey occasions must balance:

| Concern | Recommendation |
|---------|---------------|
| **Independence** | Interval ≥ 2 × animal home-range crossing time |
| **Seasonal coverage** | Cover wet + dry season (or all 4 seasons) within a year |
| **Biological response time** | Post-impact surveys should begin after sufficient time for response (e.g., 6 months for vegetation recovery; 1–2 breeding seasons for birds) |
| **Minimum interval** | Never < 2 weeks for mobile species (risk of individual recapture) |

**Typical intervals by taxon:**

| Taxon | Minimum interval | Rationale |
|-------|----------------|-----------|
| Large mammals | 4–6 weeks | Home range traversal time |
| Birds (point counts) | 2–3 weeks | Territory turnover between surveys |
| Amphibians | 2–4 weeks | Breeding pond drying/filling cycles |
| Fish (electrofishing) | 4–8 weeks | Habitat recovery after survey disturbance |
| Plants | 3–12 months | Phenological completeness |
| Invertebrates | 2–4 weeks | Generation time consideration |

---

## 5. How to Estimate Variance for Power Analysis

A variance estimate (σ²) is required to convert effect size to Cohen's d. Three approaches:

### Option A: From pilot data (preferred)
```r
# Compute pooled within-site, within-period variance from at least 5 sites × 2 occasions
pilot_data <- read.csv("pilot_sites.csv")   # columns: site, period, y (response)
# Mixed model to extract residual variance
library(lme4)
mod    <- lmer(y ~ (1 | site) + (1 | period), data = pilot_data)
sigma2 <- sigma(mod)^2   # residual (within-site) variance
cat("Variance estimate:", sigma2, "\n")
```

### Option B: From literature
Search for studies with the same response variable (e.g., bird abundance, fish CPUE) and same habitat type. Extract reported SD and use σ² = SD².

| Common ecological responses | Typical CV | Approx. σ² (if mean = 10) |
|----------------------------|-----------|--------------------------|
| Bird point count abundance | 0.4–0.8   | 16–64 |
| Camera-trap RAI | 0.6–1.2 | 36–144 |
| Tree basal area (m²/ha) | 0.1–0.3 | 1–9 |
| Fish CPUE | 0.8–2.0 | 64–400 |
| Macroinvertebrate richness | 0.2–0.4 | 4–16 |

### Option C: Conservative default
Use σ² = 1.0, which means the effect_size argument to `power_analysis_baci.R` is directly Cohen's d (fully standardised).

---

## 6. Ecologically Relevant Effect Sizes by Impact Type

Use these as starting points when no pilot data are available. Cohen's d values are for the BACI interaction term (difference-in-differences).

| Impact type | Typical detectable effect (d) | Response variable | Source |
|------------|------------------------------|-------------------|--------|
| **Road construction** | 0.4–0.8 | Bird/mammal abundance within 500 m | Trombulak & Frissell (2000) |
| **Dam / reservoir** | 0.6–1.2 | Fish species richness, benthic community | Poff et al. (2007) |
| **Deforestation (partial)** | 0.5–0.9 | Bird richness, amphibian abundance | Barlow et al. (2007) |
| **Mining (artisanal)** | 0.8–1.5 | Benthic invertebrate richness | Dudgeon et al. (2006) |
| **Invasive species introduction** | 0.3–0.7 | Native species richness | Blackburn et al. (2014) |
| **Agricultural expansion** | 0.5–1.0 | Pollinator abundance, bird richness | Benton et al. (2003) |
| **Protected area establishment** | 0.2–0.5 | Large mammal density (10–15 yr lag) | Craigie et al. (2010) |
| **Ecological restoration** | 0.3–0.6 | Vegetation cover, bird diversity | Benayas et al. (2009) |

**Note:** Larger Cohen's d values require fewer sites to detect; smaller values (d < 0.3) may require n > 20 sites per group and render BACI impractical without landscape-scale monitoring programs.

---

## 7. Pitfalls and Common Mistakes

| Pitfall | Consequence | Prevention |
|---------|-------------|------------|
| Control sites too close to impact | Spillover contamination | Distance ≥ max dispersal distance |
| Surveys only in impact-accessible season | Seasonal confounding | Stratified survey schedule |
| Single impact site | No spatial replication — can't compute error | Always ≥ 3 impact sites |
| Starting surveys after impact begins | No before data | Anticipate impacts; survey pre-emptively |
| Ignoring spatial autocorrelation | Inflated degrees of freedom | Use spatial mixed models (glmmTMB) |
| Unbalanced loss of sites | Post-hoc unbalanced design | Monitor site accessibility; have spare sites |

---

## References

- Underwood, A.J. (1994). On beyond BACI. *Ecological Applications*, 4(1), 3–15. [https://doi.org/10.2307/1942083](https://doi.org/10.2307/1942083)
- Stewart-Oaten, A. & Bence, J.R. (2001). Temporal and spatial variation. *Ecological Monographs*, 71(2), 305–339. [https://doi.org/10.1890/0012-9615(2001)071[0305:TASVI]2.0.CO;2](https://doi.org/10.1890/0012-9615(2001)071[0305:TASVI]2.0.CO;2)
- Rosenbaum, P.R. & Rubin, D.B. (1983). The central role of the propensity score. *Biometrika*, 70(1), 41–55. [https://doi.org/10.1093/biomet/70.1.41](https://doi.org/10.1093/biomet/70.1.41)
- Cohen, J. (1988). *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.). Lawrence Erlbaum Associates.
