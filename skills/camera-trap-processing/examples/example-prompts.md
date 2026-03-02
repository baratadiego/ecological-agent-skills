---
skill_id: camera-trap-processing
example_count: 5
---

# Camera Trap Processing — Example Prompts

## Scenario 1: Multi-Species Occupancy Survey

**Context:** Savanna park, 40 stations deployed for 60 days. Goal: build detection histories for all medium-to-large mammals for an occupancy modelling exercise.

**Prompt:**
> "I have 60 days of camera trap data from 40 stations in a savanna park. Process all images, define independent detection events (30-min threshold for mammals), build a weekly detection history matrix, and flag stations with less than 100 trap-nights."

**Expected workflow:**
1. `process_camtrap_data.R <image_dir> <metadata.csv> outputs/ 30`
2. Inspect `trap_effort_summary.csv` — exclude stations < 100 trap-nights
3. Load `detection_history.csv` into `unmarked` for single-season occupancy modelling
4. Check `records_per_species.csv` — exclude species with < 10 events from occupancy

**Key decision points:**
- Stations excluded for effort < 100 trap-nights: re-visit in next field season
- Species with < 10 events: report RAI only, not occupancy

---

## Scenario 2: Predator–Prey Temporal Overlap

**Context:** African savanna. Compare diel activity patterns of lions and wildebeest. Determine the degree of temporal overlap (Δ) and assess whether lions are more active when wildebeest is active.

**Prompt:**
> "I have 6 months of camera trap data for lions and wildebeest at a savanna site. Estimate diel activity curves for both species and compute temporal overlap (Dhat4). Test whether overlap is significantly higher than expected by chance using a bootstrap permutation test."

**Expected workflow:**
1. `estimate_activity.R record_table.csv "Lion" outputs/`
2. `estimate_activity.R record_table.csv "Wildebeest" outputs/`
3. Load both activity CSV outputs; compare Dhat4 estimates with bootstrap CI
4. Report interpretation: Δ > 0.75 = high overlap → possible pursuit or avoidance

**Key decision points:**
- If n Lion < 75 → bootstrap CI will be wide; interpret cautiously
- If 95% CI of Δ does not overlap 0.5 (random) → significant temporal association

---

## Scenario 3: Relative Activity Index (RAI) Across a Disturbance Gradient

**Context:** Forest–agricultural edge transect, 3 habitat types (interior, edge, farmland). Compare RAI of 5 focal species across habitat zones.

**Prompt:**
> "Compare the Relative Activity Index (RAI) for tapir, peccary, deer, ocelot, and armadillo across three habitat types (forest interior, forest edge, farmland) using 90 days of camera trap data. Test for significant habitat effects on RAI."

**Expected workflow:**
1. `process_camtrap_data.R` for entire dataset; join with habitat zone from metadata
2. Compute RAI = detections / trap-nights × 100 per station × species
3. Kruskal-Wallis or negative binomial GLM: `RAI ~ habitat_type + (1 | station)`
4. Post-hoc Dunn test for pairwise habitat comparisons
5. Plot faceted bar chart (species × habitat) with SE bars

**Expected findings:**
- Tapir likely shows strong avoidance of farmland
- Armadillo may show edge preference
- Report effect sizes (η²) alongside p-values

---

## Scenario 4: Camera Trap Population Index Trend

**Context:** Long-term monitoring (5 years). Track RAI of a threatened ungulate across annual survey periods to detect population decline.

**Prompt:**
> "I have 5 years of annual camera trap surveys (60-day seasons, same 25 stations each year) for a threatened deer species. Calculate RAI per station per year, test for a significant linear trend, and assess whether the population is declining."

**Expected workflow:**
1. `process_camtrap_data.R` for each year; combine record tables with year column
2. Compute station-level RAI per year
3. Linear mixed model: `log(RAI + 0.01) ~ year + (1 | station)`
4. If slope < 0 and p < 0.05 → declining trend; estimate annual rate of change
5. Plot RAI time series per station; highlight trend line with 95% CI

**Key decision points:**
- If station composition differs between years → use only stations sampled all 5 years
- If RAI changes > 50% between consecutive years → check for recording malfunctions

---

## Scenario 5: Camera Trap Data for Occupancy Modelling Integration

**Context:** Joint camera trap + acoustic monitoring survey. Need to prepare occupancy inputs for 12 focal bird species detected in both data streams.

**Prompt:**
> "I have 45 days of camera trap data (for ground-dwelling birds) alongside acoustic monitoring results from the same stations. Prepare weekly detection history matrices for 12 focal species, combine with acoustic detection histories, and run a multi-method occupancy model in unmarked."

**Expected workflow:**
1. `process_camtrap_data.R` → `detection_history.csv` (camera)
2. Acoustic detections filtered to ≥ 0.7 confidence → binary weekly matrix
3. Bind camera and acoustic histories as two observation methods in `unmarked::occuMS()`
4. Compare detection probability estimates between methods
5. Report false-absence risk for each method per species

**Key decision points:**
- If camera detection probability < 0.10 for arboreal species → remove camera data for that species
- If acoustic and camera occupancy estimates differ > 20% → investigate site-level covariates
