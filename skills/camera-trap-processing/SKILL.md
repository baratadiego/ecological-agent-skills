---
skill_version: 1.0.0
---

# Skill: camera-trap-processing

**Domain:** Camera traps · Detection events · Activity patterns · Occupancy · Abundance indices

---

## Purpose

Guides the agent through processing raw camera trap image data into validated detection records, calculating activity pattern metrics, and preparing outputs for occupancy and abundance estimation. Covers detection event definition, independence filtering, trap effort computation, diel activity analysis, and integration with the occupancy-and-detection skill via detection history matrices.

---

## When to Invoke

Invoke this skill when:

- A user provides a directory of camera trap images or a raw detection CSV for processing
- The goal is to calculate wildlife activity patterns, diel overlap, or relative activity indices
- Detection history matrices are needed as input for occupancy models
- The user asks about independent detection events, trap effort, or camera operation
- Photographic mark-recapture or N-mixture models are planned

**trigger_keywords:** `camera trap`, `wildlife camera`, `detection event`, `trap night`, `activity pattern`, `diel activity`, `photographic index`, `camtrapR`, `detection history`, `occupancy camera`, `camera operation`, `independent detection`

---

## Inputs

| Input | Format | Required |
|---|---|---|
| Image directory (organised by camera station) | Directory tree | Required |
| Camera metadata CSV (station, lat, lon, setup date, retrieval date) | CSV | Required |
| Species list for filtering | TXT or CSV | Recommended |
| Independence threshold (minutes) | Integer (default: 30) | Optional |
| Detection record table (if images already processed) | CSV | Conditional |

---

## Outputs

| Output | Description |
|---|---|
| `record_table.csv` | One row per independent detection event per species per camera |
| `detection_history.csv` | Binary site × occasion matrix ready for `unmarked` |
| `camera_operation.csv` | Daily operation status per camera (1=active, 0=inactive) |
| `trap_effort_summary.csv` | Trap-nights per station and per species |
| `records_per_species.csv` | Count of independent events per species |
| `activity_plot.png` | Kernel density of diel activity with 95% CI |
| `activity_overlap.csv` | Diel overlap index Δ between two groups |
| `circular_stats.csv` | Mean activity time, concentration (κ), Rayleigh test |

---

## Steps

1. **Validate camera metadata**
   Confirm all stations have setup and retrieval dates, coordinates, and unique IDs.
   Run `process_camtrap_data.R` with the image directory and metadata CSV.
   The script creates the camera operation matrix from station dates.

2. **Extract EXIF and build record table**
   `camtrapR::recordTable()` reads image timestamps and species labels from directory structure.
   Check that directory hierarchy matches: `<station>/<species>/<images>`.
   Output: `record_table.csv` with columns station, species, datetime, filename.

3. **Apply independence filter**
   Events from the same species at the same station within `indep_threshold_min` (default: 30)
   are collapsed into a single event. Record the threshold in `decision_log.md`.
   If threshold is changed from 30 min, justify the choice using home range data.

4. **Calculate trap effort**
   Compute trap-nights per station from the camera operation matrix.
   Flag stations with < 100 trap-nights in `trap_effort_summary.csv`.
   Do not use stations with < 20 trap-nights in occupancy estimation.

5. **Generate detection history matrix**
   Use `camtrapR::detectionHistory()` with the chosen occasion length (default: 1 week).
   Output: binary matrix with rows = stations, columns = occasions.
   Pass to `occupancy-and-detection` skill for model fitting.

6. **Estimate diel activity patterns** *(optional — invoke `estimate_activity.R`)*
   Fit von Mises kernel to circular time-of-day data.
   Calculate Dhat4 overlap index between two groups (e.g., dry vs. wet season).
   If `n_independent_events < 10` per species, report relative activity index only.

7. **Validate outputs**
   Confirm all output files are non-empty. Check that detection history dimensions match
   (n_stations × n_occasions). Verify no station has all-NA rows.
   Record decisions in `decision_log.md`.

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| Time between photos < independence threshold | Events are not independent — same animal | Collapse to one event; use 30 min default unless home range data justifies otherwise |
| `n_independent_events` < 10 per species | Insufficient data for occupancy estimation | Report relative activity index (RAI) only; do not fit occupancy model |
| Camera operational time < 100 trap-nights | Insufficient sampling effort | Flag station; exclude from occupancy analysis; include in effort summary |
| Stations < 15 | Below minimum for occupancy model | Use naive occupancy with explicit caveat; see occupancy-and-detection skill |
| Missing EXIF timestamps | Images cannot be time-ordered | Request re-processing; use filename timestamps as fallback if consistent |

---

## Key Decisions to Document

Record the following in `decision_log.md` after running this skill:

- Which independence threshold (minutes) was used and why
- How many events were collapsed due to non-independence
- Which stations were excluded due to low effort and why
- What occasion length was used for detection history and why
- Whether any species had insufficient events for occupancy (RAI reported instead)

---

## Tools and Libraries

**R**
```r
suppressPackageStartupMessages(library(camtrapR))   # record table, detection history
suppressPackageStartupMessages(library(overlap))    # diel overlap index (Dhat4)
suppressPackageStartupMessages(library(circular))   # circular statistics
suppressPackageStartupMessages(library(dplyr))      # data manipulation
suppressPackageStartupMessages(library(ggplot2))    # plotting
suppressPackageStartupMessages(library(lubridate))  # date handling
```

**Python**
```python
import pandas as pd          # data manipulation
import numpy as np           # numerical operations
import matplotlib.pyplot as plt  # plotting
from pathlib import Path     # file system operations
```

---

## Resources

- [`skills/camera-trap-processing/resources/detection-event-definition-guide.md`](resources/detection-event-definition-guide.md) — Independence thresholds by taxon and how the choice affects estimates
- [`skills/camera-trap-processing/resources/camtrapR-workflow-guide.md`](resources/camtrapR-workflow-guide.md) — Directory structure, EXIF extraction, and key camtrapR functions
- [`skills/camera-trap-processing/resources/activity-patterns-reference.md`](resources/activity-patterns-reference.md) — Diel overlap index Δ, circular statistics, and seasonal stratification

---

## Notes

- **Directory structure is mandatory for camtrapR:** images must be organised as `<station>/<species>/<images>`. Flat directories will cause `recordTable()` to fail. If images are flat, reorganise before processing.
- **Independence threshold inflates occupancy if too short:** Using 5 min instead of 30 min can increase apparent detection events by 2–5×, biasing occupancy upward. Document the threshold and perform sensitivity analysis if in doubt.
- **Trap-nights ≠ camera-nights if cameras malfunction:** Always use the camera operation matrix, not simply `retrieval_date - setup_date`. Cameras with SD card failures, battery death, or tampering must be accounted for.
- **RAI is not equivalent to occupancy or density:** Relative Activity Index (detections per 100 trap-nights) is a naive index that conflates occupancy, detection probability, and activity. It is useful for relative comparisons only.
- **Circular time requires conversion to radians:** Activity times must be converted from clock hours to radians (`time_rad = hour * (2*pi/24)`) before fitting kernel density or calculating Δ.
