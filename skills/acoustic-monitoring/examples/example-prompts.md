---
skill_id: acoustic-monitoring
example_count: 5
---

# Acoustic Monitoring — Example Prompts

## Scenario 1: Dawn Chorus Diversity Assessment

**Context:** Atlantic Forest fragment, southeastern Brazil. Autonomous recorders (AudioMoth) deployed at 12 stations. Recordings at 05:00–07:00 and 17:00–19:00 for 30 consecutive days.

**Prompt:**
> "I have 30 days of AudioMoth recordings (2 × 2-hour windows per day) from 12 stations in an Atlantic Forest fragment. Compute ACI, NDSI, and H for all files, then compare dawn-chorus acoustic diversity between core forest and edge stations. Control for diel variation and test whether core stations have significantly higher ACI."

**Expected workflow:**
1. `compute_acoustic_indices.R` or `compute_acoustic_indices.py` on all audio files
2. Merge indices CSV with station metadata (core vs. edge)
3. Fit linear mixed model: `ACI ~ habitat + (1 | station)` with dawn window only
4. Plot boxplots by habitat type; report effect size (Cohen's d)

**Key decision points:**
- If NDSI < 0 at dawn → high anthrophony (nearby road); flag station as disturbed
- If n recordings per station < 10 → exclude from comparative analysis

---

## Scenario 2: Continuous BirdNET Monitoring — Species Phenology

**Context:** Temperate oak woodland, 6 months of continuous recording. Identify seasonal arrival/departure dates for migratory species using automated detection.

**Prompt:**
> "Run BirdNET on 6 months of continuous recordings from a temperate woodland site. Filter detections with confidence ≥ 0.8, produce a species accumulation curve, and identify the first and last detection date for each migratory species."

**Expected workflow:**
1. `batch_species_detection.py --confidence 0.8 --lat 51.5 --lon -1.2` on all .wav files
2. Load `detections_filtered.csv`; parse date from datetime column
3. Group by species → `first_detection` and `last_detection`
4. Flag species with < 5 detections as uncertain
5. Plot phenology chart (horizontal bars per species × date)

**Key decision points:**
- Confidence < 0.7 → mark as "unconfirmed"; do not include in phenology table
- If species detected only once → exclude from arrival/departure analysis

---

## Scenario 3: Urban Soundscape Gradient

**Context:** Transect from city centre to rural area. 10 recording stations at 2-km intervals. Assess how NDSI and ACI change along the urban-rural gradient.

**Prompt:**
> "I have recordings from 10 stations along a 20 km urban-rural transect. Calculate NDSI and ACI for all stations, test for a significant linear trend with distance from city centre, and produce a gradient plot."

**Expected workflow:**
1. `compute_acoustic_indices.py` per station
2. Join with station metadata (distance_km)
3. Regression: `NDSI ~ distance_km`; test slope significance (p < 0.05)
4. Plot NDSI and ACI vs distance with 95% CI ribbon

**Expected outputs:**
- NDSI should increase monotonically from urban (negative) to rural (near +1)
- ACI typically increases but may plateau in intact habitat

---

## Scenario 4: Post-Restoration Acoustic Recovery

**Context:** Degraded wetland restored 3 years ago. Compare pre-restoration (year 0), post-restoration year 1, and year 3 recordings to assess amphibian soundscape recovery.

**Prompt:**
> "I have 3 years of wet-season recordings (same stations, same dates ± 7 days) spanning a wetland restoration project. Compare ACI and ADI across years. Has the soundscape recovered toward reference wetland values?"

**Expected workflow:**
1. Compute indices per year; aggregate to daily means per station
2. Linear mixed model: `ACI ~ year + (1 | station)`
3. Compare to reference site recordings using effect size
4. Plot time-series of monthly mean ACI with restoration milestone marked

**Key decision points:**
- If station n recordings differs between years → use rarefied means (resample to min n)
- If recovery incomplete at year 3 → recommend extended monitoring

---

## Scenario 5: Multi-Index Habitat Comparison — Fire Chronosequence

**Context:** Savanna sites with different fire histories (1, 3, 5, 10+ years since fire). Determine which acoustic index best discriminates fire age classes.

**Prompt:**
> "I have acoustic recordings from savanna sites with 4 fire age classes (1yr, 3yr, 5yr, 10yr post-fire). Compute all available indices (ACI, BI, NDSI, H, ADI, AEI). Run a PCA on index values to identify the main axis of acoustic variation. Which index best separates fire ages?"

**Expected workflow:**
1. `compute_acoustic_indices.R` across all sites
2. PCA on standardised index matrix
3. ANOVA or Kruskal-Wallis for each index across fire age class
4. Select index with highest η² (effect size); plot boxplots by fire age

**Expected findings:**
- BI typically tracks vegetation structure recovery (increases with fire age)
- NDSI may not discriminate if sites are far from urban influence
