# Workflow: run-acoustic-monitoring

**Purpose:** Process passive acoustic monitoring (PAM) recordings to compute soundscape indices and detect target species using automated classifiers
**Skills:** ecological-data-foundation → acoustic-monitoring → biostatistics-workbench → model-validation-and-uncertainty → reproducible-ecology-pipeline

---

## Trigger

Invoke when the user has passive acoustic recorder (PAM) data and wants to characterise the soundscape, detect species vocalisations, or test hypotheses about acoustic biodiversity across sites or time periods.

**Example prompts:**
- "Process my AudioMoth recordings and detect bird species using BirdNET"
- "Compute acoustic indices (ACI, NDSI) from my soundscape recordings across sites"
- "Analyse soundscape temporal patterns before and after a disturbance"
- "Run bat acoustic analysis to classify calls by species"

---

## Steps

### Step 1 — ecological-data-foundation
- Validate recorder metadata (GPS coordinates, deployment dates, recording schedule)
- Organise audio files by site and date; check for corrupt or zero-length files
- Standardise file naming to `SITE_YYYYMMDD_HHMMSS.wav`
- Output: `recorder_metadata_clean.csv`, `file_inventory.csv`, `qa_report.md`

### Step 2 — acoustic-monitoring
- Compute soundscape indices (ACI, NDSI, BIO, H) per recording using compute_acoustic_indices
- Run species detection on all recordings using batch_species_detection (BirdNET or equivalent)
- Aggregate detections by site, date, and hour
- Apply confidence threshold filter (default 0.5; adjust per species and classifier)
- Output: `acoustic_indices.csv`, `detections_raw.csv`, `detections_filtered.csv`, `activity_summary.csv`

### Step 3 — biostatistics-workbench
- Test differences in acoustic indices across sites, habitats, or treatment groups (GLM/GLMM)
- Model detection rate or acoustic index as function of environmental covariates
- For temporal analysis: test for trends or before-after differences using time series or BACI design
- Output: `model_summary.txt`, `model_selection_table.csv`, `effect_sizes.csv`

### Step 4 — model-validation-and-uncertainty
- Validate detection classifier performance against manual annotations (if available)
- Assess sensitivity of acoustic indices to recording time-of-day and weather
- Report false positive rates for target species detections
- Output: `validation_report.md`, `classifier_performance.csv`

### Step 5 — reproducible-ecology-pipeline
- Document confidence threshold justification for species detections
- Log classifier version (BirdNET model date), recording hardware, and sampling schedule
- Capture software environment (Python/birdnetlib versions, R/soundecology versions)
- Output: `parameter_manifest.yaml`, `decision_log.md`, `reproducibility_checklist.md`

---

## Expected Deliverables

- Acoustic index time series per site (ACI, NDSI, BIO, H)
- Species detection table with confidence scores
- Activity summary by species, site, and hour-of-day
- Statistical comparison of acoustic environment across groups
- Classifier performance metrics (if reference annotations available)
- Reproducibility package

---

## Minimum Data Requirements

- >= 1 passive acoustic recorder with georeferenced deployment metadata
- Audio recordings in WAV format (minimum 1 min per sample)
- Recording schedule documentation (start/end times, sampling interval)
- For species detection: species list expected in the study area

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| Confidence threshold < 0.3 yields no detections | Species absent or classifier underperforms | Verify species range; consider manual annotation of a sample; lower threshold with manual validation |
| ACI values near zero across all sites | Recordings dominated by anthropogenic noise or equipment failure | Inspect raw audio; apply noise gate; exclude corrupted files |
| Detection rate varies strongly by time-of-day | Dawn chorus or crepuscular activity confounds site comparisons | Standardise analysis to a fixed daily window (e.g., 1 h after sunrise) |
| No reference annotations available | Classifier accuracy unknown for local population | Report detections with uncertainty caveat; subsample for manual validation |
| Acoustic indices differ significantly between recorder models | Hardware-induced bias | Calibrate or exclude cross-model comparisons; stratify analysis by recorder type |
