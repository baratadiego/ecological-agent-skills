# Soundscape Ecology Guide

## The NDSI Framework: Three Components of Soundscape

| Component | Definition | Frequency range (typical) | NDSI role |
|---|---|---|---|
| Biophony | Sounds produced by biological organisms | 2–8 kHz | Numerator |
| Geophony | Non-biological natural sounds (wind, rain, rivers) | Broadband | — |
| Anthrophony | Human-generated sounds (traffic, machinery) | 0.2–2 kHz | Denominator |

**NDSI** measures the dominance of biological over anthropogenic signals. Values near +1 indicate pristine soundscapes; values near -1 indicate urbanised or disturbed sites.

---

## Controlling for Diel and Seasonal Variation

### Why it matters
Acoustic diversity peaks at dawn and dusk ("dawn chorus" and "dusk chorus"). Comparing morning recordings from one site with afternoon recordings from another produces spurious differences unrelated to biodiversity.

### Recommended control strategies

1. **Stratify by time window:** Compare only recordings taken in the same 1-hour window (e.g., 05:00–06:00 for dawn chorus).
2. **Mixed-effects model with time-of-day as covariate:**

```r
suppressPackageStartupMessages(library(lme4))
suppressPackageStartupMessages(library(lubridate))

indices$hour <- hour(indices$datetime)
indices$cos_hour <- cos(2 * pi * indices$hour / 24)
indices$sin_hour <- sin(2 * pi * indices$hour / 24)

# Model ACI with hour and site as predictors
model <- lmer(ACI ~ cos_hour + sin_hour + habitat_type + (1 | site / recorder_id),
              data = indices)
```

3. **Seasonal stratification:** Group months into seasons (wet/dry or astronomical seasons) and analyse separately or include as a fixed effect.

---

## Rarefaction for Acoustic Richness Estimation

```r
# Species accumulation curve from BirdNET detections
# Requires detection matrix (sites × species)
suppressPackageStartupMessages(library(vegan))

det_matrix <- read.csv("detections_filtered.csv") %>%
  group_by(site, species) %>%
  summarise(n = n(), .groups = "drop") %>%
  tidyr::pivot_wider(names_from = species, values_from = n, values_fill = 0)

sp_matrix <- as.matrix(det_matrix[, -1])
sp_accum <- specaccum(sp_matrix, method = "rarefaction")
plot(sp_accum, xlab = "Recording hours", ylab = "Cumulative species detected")
```

**Rule:** Flag sites with < 48 hours of recordings as under-sampled relative to asymptotic richness.

---

## Integrating Acoustic and Visual Survey Data

| Data type | Acoustic | Camera trap | Transect |
|---|---|---|---|
| What it detects | Vocalising species | Mobile species at detection range | Visible species in survey belt |
| Temporal resolution | Continuous | Event-based | Snapshot |
| Species ID confidence | Moderate (requires validation) | High (image) | High (observer) |
| Integration approach | Multi-state model / species accumulation | Occupancy model | Distance sampling |

---

## Common Soundscape Gradients

| Gradient | Expected NDSI trend | Expected ACI trend |
|---|---|---|
| Urban → rural | Increasing | Increasing |
| Deforested → intact forest | Increasing | Increasing |
| Day → night (tropical) | Variable | Increasing (insect chorus) |
| Dry → wet season | Increasing | Increasing (amphibians, insects) |
| Degraded habitat recovery | Increasing over years | Increasing |

---

## References

- Pijanowski, B.C. et al. (2011). Soundscape ecology: the science of sound in the landscape. *BioScience*, 61(3), 203–216. DOI: 10.1525/bio.2011.61.3.6
- Sueur, J. & Farina, A. (2015). Ecoacoustics: the ecological investigation and interpretation of environmental sound. *Biosemiotics*, 8(3), 493–502. DOI: 10.1007/s12304-015-9248-x
- Tucker, D. et al. (2014). Linking ecological condition and the soundscape in fragmented Australian forests. *Landscape Ecology*, 29(4), 745–758. DOI: 10.1007/s10980-014-9978-6
