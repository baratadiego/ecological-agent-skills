---
skill_version: 1.0.0
---

# Skill: acoustic-monitoring

**Domain:** Bioacoustics · Soundscape ecology · Acoustic indices · Species detection · PAM

---

## Purpose

Guides the agent through processing passive acoustic monitoring (PAM) recordings to compute soundscape biodiversity indices, detect species using automated classifiers, and analyse temporal trends in acoustic diversity. Covers ACI, BI, NDSI, H, ADI, and AEI index computation; BirdNET-based species detection with confidence thresholding; rarefaction-based richness estimation; and temporal trend analysis of soundscape composition.

---

## When to Invoke

Invoke this skill when:

- A user provides a directory of WAV or FLAC recordings from autonomous recorders
- The goal is to compute acoustic biodiversity indices across sites or time periods
- Automated species detection from audio is requested (BirdNET, Kaleidoscope)
- Soundscape trends over time (diel, seasonal, annual) are to be analysed
- Acoustic data must be integrated with field survey or camera trap data

**trigger_keywords:** `acoustic monitoring`, `soundscape`, `bioacoustics`, `acoustic index`, `ACI`, `NDSI`, `BirdNET`, `bird detection`, `bat echolocation`, `passive acoustic`, `PAM`, `audio recording`, `species accumulation acoustic`, `acoustic diversity`

---

## Inputs

| Input | Format | Required |
|---|---|---|
| Audio recordings directory | WAV or FLAC files | Required |
| Recording metadata CSV (site, date, time, recorder ID) | CSV | Required |
| Species list for filtering detections | TXT | Optional |
| Confidence threshold for species detection | Float 0–1 (default: 0.7) | Optional |
| Time resolution for index aggregation (minutes) | Integer (default: 1) | Optional |

---

## Outputs

| Output | Description |
|---|---|
| `acoustic_indices_timeseries.csv` | ACI, BI, NDSI, H, ADI, AEI per recording per time step |
| `indices_summary.csv` | Mean ± SD of each index per site and temporal stratum |
| `soundscape_plot.png` | Heatmap: hour of day × day × index value |
| `detections_raw.csv` | All BirdNET detections with confidence scores |
| `detections_filtered.csv` | Detections above confidence threshold |
| `species_accumulation.csv` | Cumulative species richness vs. recording hours |
| `detection_summary.png` | Detections per species × date × site |

---

## Steps

1. **Validate recordings**
   Check all files are WAV or FLAC, readable, and have consistent sample rates.
   Compute SNR for a random 10% sample. Flag files with SNR < 10 dB in metadata.
   Exclude flagged recordings from index computation.

2. **Compute acoustic indices** *(invoke `compute_acoustic_indices.R` or `.py`)*
   Calculate ACI, BI, NDSI, H, ADI, AEI for each recording at the specified time
   resolution. Aggregate to hourly and daily summaries.
   Output: `acoustic_indices_timeseries.csv`.

3. **Run automated species detection** *(invoke `batch_species_detection.py`)*
   Process all recordings with BirdNET-Analyzer CLI.
   Filter detections by confidence threshold (default: 0.7).
   Aggregate detections by species, date, and site.

4. **Validate detections**
   If the study region has a published BirdNET validation, apply region-specific
   precision/recall. If not, flag detections > 0.7 confidence as "probable" and
   require manual validation for species of conservation concern.

5. **Compute species accumulation curve**
   Use detection records to plot cumulative species vs. recording hours.
   Fit a Michaelis-Menten curve to estimate asymptotic richness.
   Flag sites with < 48h of recordings as potentially under-sampled.

6. **Analyse temporal trends**
   Use `environmental-time-series` skill if trend analysis over months/years is needed.
   For diel patterns: compute mean index by hour-of-day, plot soundscape fingerprint.

7. **Validate outputs and record decisions**
   Confirm all output files are non-empty and timestamped.
   Record SNR threshold, confidence threshold, and any excluded recordings in `decision_log.md`.

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| SNR < 10 dB in a recording | Recording dominated by noise; indices unreliable | Exclude from index computation; document in metadata |
| BirdNET confidence < 0.7 | Low-confidence detection; likely false positive | Flag as "unconfirmed"; require manual validation before use in analyses |
| < 48h of recordings per site | Insufficient for rarefaction-based richness | Report observed richness only; note undersampling caveat |
| NDSI consistently > 0.8 | Soundscape dominated by biophony | Check for equipment artefact or very remote site; validate with spectrogram |
| NDSI consistently < -0.5 | Soundscape dominated by geophony or anthrophony | Investigate noise source; may mask biological signal in other indices |

---

## Key Decisions to Document

Record the following in `decision_log.md` after running this skill:

- SNR threshold used for recording exclusion and how many recordings were excluded
- Confidence threshold used for BirdNET detections and rationale
- Whether regional BirdNET validation data were available and applied
- Which acoustic indices were prioritised and why
- Any recordings excluded due to equipment malfunction or file corruption

---

## Tools and Libraries

**R**
```r
suppressPackageStartupMessages(library(soundecology))  # acoustic indices (ACI, BI, NDSI, H, ADI, AEI)
suppressPackageStartupMessages(library(tuneR))         # WAV file reading
suppressPackageStartupMessages(library(seewave))       # spectrogram, SNR, dB computation
suppressPackageStartupMessages(library(dplyr))         # data manipulation
suppressPackageStartupMessages(library(ggplot2))       # plotting
suppressPackageStartupMessages(library(lubridate))     # datetime handling
```

**Python**
```python
import librosa          # audio loading, spectral features, ACI computation
import soundfile as sf  # WAV/FLAC reading
import numpy as np      # numerical operations
import pandas as pd     # data manipulation
from pathlib import Path  # file system
```

**CLI**
```bash
# BirdNET-Analyzer (must be installed separately)
python analyze.py --i <audio_dir> --o <output_dir> --min_conf 0.7
```

---

## Resources

- [`skills/acoustic-monitoring/resources/acoustic-indices-reference.md`](resources/acoustic-indices-reference.md) — Complete table of acoustic indices: formula, scale, interpretation, R package
- [`skills/acoustic-monitoring/resources/species-id-tools-comparison.md`](resources/species-id-tools-comparison.md) — Comparison of BirdNET, RavenPro, Kaleidoscope, ARBIMON and validation protocols
- [`skills/acoustic-monitoring/resources/soundscape-ecology-guide.md`](resources/soundscape-ecology-guide.md) — NDSI framework, diel and seasonal controls, rarefaction, and data integration

---

## Notes

- **Sample rate must match index requirements:** ACI and most soundecology indices require 44.1 kHz WAV. Recordings at 22 kHz will underestimate high-frequency components. Always check sample rate before computing indices.
- **BirdNET is trained on Cornell Lab recordings:** Performance degrades outside North America and Europe. Validate with local recordings before using for conservation decisions in other regions.
- **Diel patterns must be controlled in trend analyses:** Acoustic diversity peaks at dawn and dusk. Never compare morning recordings from site A with midday recordings from site B without controlling for time-of-day.
- **ACI is not equivalent to species richness:** ACI measures temporal complexity of the signal, not biological diversity. A site with heavy rain will have high ACI but low biological content. Always cross-validate with NDSI.
- **Hardware differences between recorders bias comparisons:** AudioMoth, Song Meter, and Marantz record at different gain levels. Normalise SPL or compute indices relative to within-recorder baselines when comparing across equipment types.
