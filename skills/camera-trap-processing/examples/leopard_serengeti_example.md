---
skill_id: camera-trap-processing
example_type: full_walkthrough
taxon: African leopard (Panthera pardus)
region: Serengeti–Mara ecosystem, East Africa
---

# Leopard Activity and Diel Overlap — Serengeti Camera Trap Walkthrough

## Study Context

**Location:** Serengeti National Park, northern corridor (2.5° S, 34.8° E)
**Objective:** Characterise leopard diel activity pattern, compute temporal overlap with main prey (Thomson's gazelle, impala), and prepare detection histories for single-season occupancy modelling
**Camera stations:** 48 stations, 2 per 5-km² grid cell, deployed at game trails and waterhole approaches
**Survey duration:** 90 consecutive days (dry season, June–August)
**Equipment:** Bushnell Core No-Glow cameras, EXIF timestamps (UTC+3)

---

## Step 1 — Data Preparation and Event Processing

### Directory structure

```
data/camera_traps/
├── ST001/
│   ├── Panthera_pardus/
│   │   ├── ST001_20240601_050312.JPG
│   │   └── ST001_20240601_050318.JPG  ← same event (6 seconds apart)
│   └── Gazella_thomsonii/
│       └── ST001_20240602_143021.JPG
├── ST002/
│   └── ...
data/
└── camera_metadata.csv   (station_id, longitude, latitude, habitat, setup_date, retrieval_date)
```

### Run processing script

```bash
Rscript process_camtrap_data.R \
  data/camera_traps/ \
  data/camera_metadata.csv \
  outputs/camtrap/ \
  60    # 60-minute independence threshold for large carnivores
```

**Independence threshold rationale:** 60-minute threshold used for leopard (large carnivore home range > 20 km²); default 30 min would over-count patrol detections of the same individual. Decision logged in `decision_log.md`.

### Effort check

```r
effort <- read.csv("outputs/camtrap/trap_effort_summary.csv")
summary(effort$trap_nights)
#   Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
#   48.0    82.5    89.0    86.3    90.0    90.0
```

**Flag:** 3 stations with < 100 trap-nights (ST012 = 48, ST027 = 61, ST035 = 72). Cause: camera malfunction (ST012) and vandalism (ST027, ST035).

**Decision:** Exclude ST012, ST027, ST035 from occupancy analysis; retain for activity analysis if they have ≥ 10 leopard events.

---

## Step 2 — Species Summary

```r
recs <- read.csv("outputs/camtrap/record_table.csv")
sp_summary <- read.csv("outputs/camtrap/records_per_species.csv")

# Focal species check
library(dplyr)
sp_summary %>%
  filter(species %in% c("Panthera_pardus", "Gazella_thomsonii",
                         "Aepyceros_melampus")) %>%
  select(species, n_events, n_stations)
```

| species | n_events | n_stations |
|---------|----------|------------|
| Panthera_pardus | 412 | 38 |
| Gazella_thomsonii | 2,847 | 45 |
| Aepyceros_melampus | 1,204 | 42 |

**All three species exceed the 10-event minimum at sufficient stations.** Leopard detected at 38/48 stations (naïve occupancy = 0.79).

---

## Step 3 — Diel Activity Analysis

### Leopard activity

```bash
Rscript estimate_activity.R \
  outputs/camtrap/record_table.csv \
  "Panthera_pardus" \
  outputs/activity/
```

**Output — `circular_stats.csv`:**

| metric | value |
|--------|-------|
| mean_time | 02:14 |
| concentration_kappa | 0.82 |
| rayleigh_p | < 0.001 |
| n_events | 412 |

**Interpretation:** Strong noctural concentration (mean 02:14), highly non-uniform distribution (Rayleigh p < 0.001). κ = 0.82 indicates moderate directional concentration.

### Temporal overlap with prey

```bash
# Gazelle
Rscript estimate_activity.R \
  outputs/camtrap/record_table.csv \
  "Gazella_thomsonii" \
  outputs/activity/

# Impala
Rscript estimate_activity.R \
  outputs/camtrap/record_table.csv \
  "Aepyceros_melampus" \
  outputs/activity/
```

**Overlap results — `activity_overlap.csv`:**

| comparison | Dhat4 | CI_lower | CI_upper | interpretation |
|------------|-------|----------|----------|----------------|
| Leopard × Gazelle | 0.38 | 0.29 | 0.47 | Low overlap |
| Leopard × Impala | 0.51 | 0.43 | 0.59 | Moderate overlap |

**Interpretation:**
- Gazelle is strongly diurnal (mean activity 10:30); leopard is nocturnal → low temporal overlap (Δ = 0.38), consistent with gazelle using temporal partitioning to reduce predation risk
- Impala is more crepuscular (active 05:00–08:00 and 17:00–20:00) → moderate overlap with leopard dawn/dusk activity peaks (Δ = 0.51)

**Decision logged:**
```yaml
- date: 2024-09-15
  skill_id: camera-trap-processing
  decision: "Independence threshold set to 60 minutes for all large carnivores"
  rationale: "60-min threshold standard for Serengeti felids; Hamel et al. (2013)"
  outputs: ["outputs/camtrap/record_table.csv"]
```

---

## Step 4 — Detection History for Occupancy Modelling

```r
det_hist <- read.csv("outputs/camtrap/detection_history.csv")

# Structure for unmarked
library(unmarked)

# Weekly detection occasions (90 days → 12 weekly occasions)
# Rows = stations, Columns = occasions
y_leopard <- det_hist %>%
  filter(species == "Panthera_pardus") %>%
  select(-species, -station) %>%
  as.matrix()

# Site covariates
meta <- read.csv("data/camera_metadata.csv")
site_covs <- meta %>%
  select(station_id, habitat, dist_water_m, tree_cover_pct)

umf <- unmarkedFrameOccu(y = y_leopard, siteCovs = site_covs)
m0  <- occu(~1 ~1, data = umf)
m1  <- occu(~1 ~ habitat + dist_water_m, data = umf)
```

**Model selection:**

| Model | AIC | ΔAIC |
|-------|-----|------|
| m1: habitat + dist_water | 312.4 | 0.0 |
| m0: null | 328.1 | 15.7 |

**Key results:**
- Occupancy (ψ) = 0.83 (95% CI: 0.72–0.91)
- Detection probability (p) = 0.24 per week
- Dist_water significant negative effect: leopards less likely detected > 2 km from water (β = -0.43, SE = 0.17)

---

## Step 5 — Final Outputs

```
outputs/
├── camtrap/
│   ├── record_table.csv             # 4,821 independent events, 38 species
│   ├── detection_history.csv        # 48 stations × 12 weekly occasions per species
│   ├── camera_operation.csv         # effort matrix
│   ├── trap_effort_summary.csv      # 3 stations flagged < 100 trap-nights
│   └── records_per_species.csv      # 38 species detected
├── activity/
│   ├── Panthera_pardus_activity_plot.png
│   ├── activity_overlap.csv         # Dhat4 comparisons
│   ├── circular_stats.csv
│   └── activity_overlap.png         # dual-density overlap plot
└── figures/
    └── leopard_occupancy_map.png    # site-level predicted occupancy
```

---

## Summary Table

| Parameter | Value | Notes |
|-----------|-------|-------|
| Survey duration | 90 days | June–August (dry season) |
| Active stations | 45/48 | 3 excluded (< 100 trap-nights) |
| Total trap-nights | 3,884 | Effective effort |
| Leopard events (60-min threshold) | 412 | 38 stations |
| Naïve occupancy | 0.79 | 38/48 stations |
| Modelled occupancy (ψ) | 0.83 (0.72–0.91) | Single-season occu model |
| Detection probability (p/week) | 0.24 | |
| Diel peak | 02:14 | Strongly nocturnal |
| Overlap with gazelle (Δ) | 0.38 (low) | Temporal partitioning |
| Overlap with impala (Δ) | 0.51 (moderate) | Crepuscular co-activity |

---

## References

- Hamel, S. et al. (2013). Towards good practice guidance in using camera-traps in ecology: influence of sampling design on validity of ecological inferences. *Methods in Ecology and Evolution*, 4(2), 105–113. DOI: 10.1111/2041-210X.12036
- Meredith, M. & Ridout, M. (2021). *overlap: Estimates of Coefficient of Overlapping for Animal Activity Patterns*. R package version 0.3.4.
- MacKenzie, D.I. et al. (2002). Estimating site occupancy rates when detection probabilities are less than one. *Ecology*, 83(8), 2248–2255.
- Ridout, M.S. & Linkie, M. (2009). Estimating overlap of daily activity patterns from camera trap data. *Journal of Agricultural, Biological, and Environmental Statistics*, 14(3), 322–337. DOI: 10.1198/jabes.2009.08038
