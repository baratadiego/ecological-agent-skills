---
skill_id: acoustic-monitoring
example_type: full_walkthrough
taxon: Birds (Passerines)
region: Temperate broadleaf forest, central Europe
---

# Temperate Forest Bird Monitoring — Full Acoustic Walkthrough

## Study Context

**Location:** Oak-beech forest complex, 2,400 ha, Thuringia, Germany (51.2° N, 11.0° E)
**Objective:** Assess bird species richness and acoustic diversity across a habitat quality gradient (managed vs. old-growth forest patches)
**Recorders:** 8 × AudioMoth v1.2, deployed at 50-m forest interior points
**Recording schedule:** 04:30–07:30 UTC daily, May–July (spring migration + breeding)
**Total recordings:** ~2,160 files (270 per station × 8 stations), each 10 minutes at 32 kHz

---

## Step 1 — Compute Acoustic Indices

```bash
# Run for each station directory
Rscript compute_acoustic_indices.R \
  data/audio/station_01/ \
  outputs/indices/station_01/ \
  1 \
  0 \
  16000
```

**Decision:** Frequency max set to 16 kHz (Nyquist for 32 kHz recorders). Passerine vocalisations fall mainly 2–10 kHz.

**Flags raised during processing:**
- Station 05: 14 files with NDSI < -0.3 during 05:00–06:00 → road noise detected
  - **Decision:** Exclude station 05 dawn-chorus window from comparative analysis; retain for trend analysis only

**Output check:**

```r
library(dplyr)
idx <- read.csv("outputs/indices/all_stations_combined.csv")

# Check recording coverage per station
idx %>%
  group_by(station) %>%
  summarise(n_files = n(),
            n_hours  = n_recordings * 10 / 60,  # 10-min files
            pct_valid = mean(!is.na(ACI)) * 100)
```

| station    | n_files | recording_hours | pct_valid |
|------------|---------|-----------------|-----------|
| station_01 | 270     | 45.0            | 98.5      |
| station_03 | 268     | 44.7            | 97.8      |
| station_05 | 270     | 45.0            | 96.3      |
| station_07 | 214     | 35.7            | 94.9      |

**Flag:** Station 07 has only 214 files (malfunction from July 12). Recording hours < 48h for July window — flagged as under-sampled for July species richness.

---

## Step 2 — BirdNET Species Detection

```bash
python batch_species_detection.py \
  data/audio/ \
  outputs/birdnet/ \
  --confidence 0.7 \
  --lat 51.2 \
  --lon 11.0 \
  --date 2024-05-15 \
  --overlap 1.0
```

**Confidence filtering decisions:**

| Confidence band | n detections | Action |
|-----------------|-------------|--------|
| < 0.50          | 8,412       | Exclude (high FP rate) |
| 0.50–0.69       | 3,201       | Retain as "unconfirmed" |
| 0.70–0.89       | 6,847       | Retain (main analysis) |
| ≥ 0.90          | 2,104       | High confidence |

**Species accumulation check:**

```python
import pandas as pd
import matplotlib.pyplot as plt

det = pd.read_csv("outputs/birdnet/detections_filtered.csv")
# Sort by datetime to produce accumulation curve
det_sorted = det.sort_values("datetime")
det_sorted["cumulative_species"] = det_sorted["common_name"].expanding().apply(
    lambda x: x.nunique()
)
plt.plot(range(len(det_sorted)), det_sorted["cumulative_species"])
plt.xlabel("Detection number")
plt.ylabel("Cumulative species detected")
plt.title("Species accumulation — all stations")
```

**Result:** Curve asymptotes at ~47 species by detection 5,000 of 8,951. All stations exceed 48 recording hours → richness estimates considered reliable.

---

## Step 3 — Diel and Temporal Analysis

### Dawn Chorus Peak

```r
library(dplyr); library(lubridate); library(ggplot2)

idx <- read.csv("outputs/indices/all_stations_combined.csv")
idx$datetime <- as.POSIXct(idx$datetime, tz = "UTC")
idx$hour     <- lubridate::hour(idx$datetime)

# Filter to dawn window (04:30–07:30)
dawn <- idx %>% filter(hour %in% c(4, 5, 6, 7))

# ACI by hour
dawn %>%
  group_by(hour) %>%
  summarise(ACI_mean = mean(ACI, na.rm = TRUE),
            ACI_sd   = sd(ACI, na.rm = TRUE)) %>%
  ggplot(aes(x = hour, y = ACI_mean)) +
  geom_ribbon(aes(ymin = ACI_mean - ACI_sd, ymax = ACI_mean + ACI_sd),
              alpha = 0.3) +
  geom_line(size = 1.2) +
  labs(x = "Hour (UTC)", y = "ACI", title = "Dawn chorus ACI")
```

**Finding:** ACI peaks at hour 05 (mean = 1,842 ± 312), declining by hour 07 (mean = 1,421 ± 287).

### Seasonal Trend

```r
idx$month <- lubridate::month(idx$datetime)

idx %>%
  filter(hour == 5) %>%
  group_by(station, month) %>%
  summarise(ACI_mean = mean(ACI, na.rm = TRUE), .groups = "drop") %>%
  ggplot(aes(x = month, y = ACI_mean, colour = station)) +
  geom_line() + geom_point() +
  labs(x = "Month", y = "ACI (hour 05)", title = "Seasonal ACI trend by station")
```

**Finding:** ACI peaks in June (breeding peak) then declines in July (post-breeding silence).

---

## Step 4 — Habitat Comparison

### Station metadata

```r
meta <- data.frame(
  station      = paste0("station_0", c(1,2,3,4,5,6,7,8)),
  habitat_type = c("old_growth", "old_growth", "managed", "managed",
                   "managed", "old_growth", "old_growth", "managed")
)

idx_meta <- left_join(idx, meta, by = "station")
```

### Mixed-effects model

```r
suppressPackageStartupMessages(library(lme4))
suppressPackageStartupMessages(library(lmerTest))

dawn_meta <- idx_meta %>%
  filter(hour %in% c(4, 5, 6))

m1 <- lmer(ACI ~ habitat_type + (1 | station),
           data = dawn_meta, REML = TRUE)
summary(m1)
```

**Results:**

| Effect | Estimate | SE | t | p |
|--------|----------|----|---|---|
| Intercept (managed) | 1,312.4 | 68.3 | 19.2 | < 0.001 |
| habitat_type [old_growth] | **+284.7** | 97.1 | 2.93 | **0.018** |

**Interpretation:** Old-growth stations had significantly higher dawn ACI (+285 units, p = 0.018), consistent with higher acoustic complexity from greater species richness and vocal activity.

### NDSI comparison

```r
m2 <- lmer(NDSI ~ habitat_type + cos_hour + sin_hour + (1 | station),
           data = idx_meta %>%
             mutate(cos_hour = cos(2 * pi * hour / 24),
                    sin_hour = sin(2 * pi * hour / 24)))
summary(m2)
```

**Result:** No significant habitat effect on NDSI (p = 0.21). Both habitat types are remote from roads → low anthrophony → NDSI near +0.7 across all stations. ACI is the more sensitive discriminator here.

---

## Step 5 — Species Richness Comparison

```r
det <- read.csv("outputs/birdnet/detections_filtered.csv")
det <- left_join(det, meta, by = c("station" = "station"))

species_richness <- det %>%
  group_by(station, habitat_type) %>%
  summarise(n_species = n_distinct(common_name), .groups = "drop")

wilcox.test(n_species ~ habitat_type, data = species_richness)
```

| Habitat | Mean species | Median | Range |
|---------|-------------|--------|-------|
| Old-growth | 38.5 | 39 | 34–43 |
| Managed | 28.3 | 28 | 24–33 |

**Wilcoxon test:** W = 16, p = 0.028 — significantly more species in old-growth stations.

---

## Step 6 — Outputs and Reporting

```
outputs/
├── indices/
│   ├── all_stations_combined.csv       # 17,280 rows × 9 index columns
│   ├── indices_summary_by_hour.csv     # mean ACI/NDSI/H by hour
│   └── soundscape_plot.png             # heatmap: date × hour, coloured by ACI
├── birdnet/
│   ├── detections_raw.csv              # 20,551 total detections
│   ├── detections_filtered.csv         # 8,951 detections (conf ≥ 0.7)
│   ├── species_list.csv                # 53 species detected
│   ├── detection_summary.csv           # species × hour matrix
│   └── species_accumulation.csv
└── figures/
    ├── dawn_aci_by_habitat.png
    ├── seasonal_aci_trend.png
    └── species_richness_boxplot.png
```

### Summary table for report

| Metric | Old-growth | Managed | p-value |
|--------|-----------|---------|---------|
| Dawn ACI (mean ± SD) | 1,597 ± 298 | 1,312 ± 245 | 0.018 |
| NDSI (all hours) | 0.73 ± 0.12 | 0.69 ± 0.15 | 0.21 |
| Species richness (BirdNET) | 38.5 ± 4.3 | 28.3 ± 4.7 | 0.028 |
| Recording hours | 45.0 (8 stations) | 44.4 (8 stations) | — |

---

## Decision Log

```yaml
- date: 2024-08-10
  skill_id: acoustic-monitoring
  decision: "Excluded station 05 dawn window from ACI comparison (NDSI < -0.3)"
  rationale: "Persistent road noise detected 04:30–06:30; n=14 files affected"
  outputs: ["outputs/indices/station_05/acoustic_indices_timeseries.csv"]

- date: 2024-08-10
  skill_id: acoustic-monitoring
  decision: "Confidence threshold set to 0.7 for main analysis"
  rationale: "Precision at 0.7 band estimated 0.82 from subsample of 100 validated clips"
  outputs: ["outputs/birdnet/detections_filtered.csv"]

- date: 2024-08-11
  skill_id: acoustic-monitoring
  decision: "ACI selected as primary diversity metric (over ADI, H)"
  rationale: "ACI showed highest correlation with manual point-count richness (r = 0.71)"
  outputs: ["outputs/figures/index_correlation_matrix.png"]
```

---

## References

- Pieretti, N., Farina, A. & Morri, D. (2011). A new methodology to infer the singing activity of an avian community: the Acoustic Complexity Index (ACI). *Ecological Indicators*, 11(3), 868–873. DOI: 10.1016/j.ecolind.2010.11.005
- Sueur, J., Pavoine, S., Hamerlynck, O. & Duvail, S. (2008). Rapid acoustic survey for biodiversity appraisal. *PLOS ONE*, 3(12), e4065. DOI: 10.1371/journal.pone.0004065
- Kahl, S. et al. (2021). BirdNET: A deep learning solution for avian diversity monitoring. *Ecological Informatics*, 61, 101236. DOI: 10.1016/j.ecoinf.2021.101236
