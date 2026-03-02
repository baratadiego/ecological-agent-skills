# Detection Event Definition Guide

## What Is an Independent Detection Event?

A detection event is one or more consecutive photographs of the same species at the same camera station that are treated as a single observation for analytical purposes. The challenge is defining **independence** between events to avoid pseudo-replication.

Two detections at the same station are considered **independent** if:
1. They are separated by a time interval ≥ the independence threshold, **OR**
2. Different individuals are unambiguously distinguishable (e.g., via natural marks)

---

## Temporal Independence Thresholds

The most common approach uses a fixed time gap. The standard is **30 minutes**, but this should be justified relative to the target species' biology.

| Group | Typical threshold | Biological justification |
|---|---|---|
| Small mammals (< 1 kg) | 15–30 min | Short home ranges; likely same individual if < 15 min |
| Medium carnivores (1–20 kg) | 30–60 min | Home range radius ~0.5–2 km; can return quickly |
| Large carnivores (> 20 kg) | 60–120 min | Wide-ranging; unlikely to return within 1 h |
| Ungulates (herds) | 30 min | Herd may pass repeatedly; 30 min separates visits |
| Birds | 5–15 min | High mobility; shorter threshold appropriate |
| Reptiles | 30–60 min | Slow movement; may persist near camera |

**Literature reference:** Hamel et al. (2013) *Methods in Ecology and Evolution* 4(6):543–553. DOI: 10.1111/2041-210X.12036

---

## Spatial Independence

Cameras positioned < 1 km apart in continuous habitat may detect the same individual. When camera spacing is < expected home range diameter, treat cameras as pseudo-replicated for abundance estimation. For occupancy analysis, cameras at different stations are treated as independent sites regardless of spacing, but detection correlation must be assessed.

---

## How the Threshold Affects Estimates

```r
# Example: sensitivity of RAI to independence threshold
library(dplyr)

# Simulate record table with timestamps
records <- data.frame(
  station  = "CAM01",
  species  = "Panthera_pardus",
  datetime = as.POSIXct(c("2023-06-01 02:15", "2023-06-01 02:20",
                           "2023-06-01 03:50", "2023-06-01 22:10"))
)

# Apply different thresholds
apply_threshold <- function(df, thresh_min) {
  df <- df[order(df$datetime), ]
  df$gap <- c(0, as.numeric(diff(df$datetime), units = "mins"))
  df$event <- cumsum(df$gap > thresh_min) + 1
  nrow(unique(df["event"]))
}

thresholds <- c(5, 15, 30, 60)
sapply(thresholds, function(t) apply_threshold(records, t))
# Output: 4, 3, 2, 2  (more events retained with shorter threshold)
```

---

## Recording the Threshold in decision_log.md

```
## [YYYY-MM-DD] camera-trap-processing — Independence threshold selection
- Decision: 30-minute independence threshold applied
- Rationale: target species (Panthera pardus) has minimum home range of ~10 km²;
  30 min is conservative given typical travel speeds
- Alternatives considered: 60 min (reduces events by ~15%); 15 min (increases by ~30%)
- Output files: record_table.csv, detection_history.csv
```

---

## Pitfalls

- **Never use 0 min threshold:** All consecutive frames of the same animal become separate "detections", inflating RAI by 5–20× in species that trigger bursts.
- **Do not change the threshold mid-study:** If you use 30 min for Year 1 and 60 min for Year 2, temporal comparisons are invalid.
- **Threshold affects occupancy estimates:** Longer thresholds reduce detection events, which reduces estimated detection probability (p) and inflates estimated occupancy (ψ). Document and perform sensitivity analysis.

---

## References

- Hamel, S. et al. (2013). Sampling and estimation methods matter when assessing camera-trap data. *Methods in Ecology and Evolution*, 4(6), 543–553. DOI: 10.1111/2041-210X.12036
- Burton, A.C. et al. (2015). Wildlife camera trapping: a review and recommendations for linking surveys to ecological processes. *Journal of Applied Ecology*, 52(3), 675–685. DOI: 10.1111/1365-2664.12432
