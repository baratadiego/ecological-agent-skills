# Worked Example: Giant Anteater SDM — Cerrado Biome

**Workflow:** run-sdm-study  
**Species:** Myrmecophaga tridactyla (giant anteater)  
**Study area:** Cerrado biome + 200 km buffer  
**Status:** Vulnerable (IUCN); key megafauna of Brazilian savanna

---

## Step 1 — Data Summary

| Source | Records (raw) | After cleaning |
|--------|--------------|---------------|
| GBIF | 1,842 | 612 |
| SpeciesLink (MZUSP, MNRJ) | 234 | 201 |
| Pantanal field surveys 2020–22 | 87 | 82 |
| After 5 km thinning | — | **238** |

## Step 2 — Predictor Selection

Variables tested: WorldClim v2.1 (bio1–bio19) + NDVI (MOD13A3) + slope + soil clay content

After collinearity reduction (VIF < 5, |r| < 0.7):

| Variable | Source | Ecological rationale |
|----------|--------|---------------------|
| bio1 (MAT) | WorldClim | Thermoregulation threshold |
| bio12 (MAP) | WorldClim | Ant/termite prey availability |
| bio15 (Prec. seasonality) | WorldClim | Cerrado dry season |
| NDVI (annual mean) | MODIS | Vegetation structure / foraging |
| Slope | SRTM | Burrow site suitability |

## Step 3 — Spatial CV

Block size: 250 km (SAC range = 180 km)  
Folds: 5 | Min presences per fold: 42

## Step 4 — Model Performance

| Algorithm | AUC (CV) | TSS (CV) | Boyce |
|-----------|---------|---------|-------|
| MaxEnt (λ=1.5, LQH) | 0.881 | 0.687 | 0.88 |
| BRT (n=1000, lr=0.01, tc=5) | 0.902 | 0.718 | 0.91 |
| Random Forest (n=500) | 0.896 | 0.712 | 0.89 |
| **Ensemble** | **0.914** | **0.729** | **0.93** |

## Step 5 — Variable Importance

| Variable | RF importance (%) | MaxEnt contribution (%) |
|----------|-----------------|------------------------|
| bio12 (MAP) | 38.1 | 41.2 |
| NDVI | 24.7 | 22.3 |
| bio15 | 17.2 | 18.9 |
| bio1 | 12.4 | 11.4 |
| slope | 7.6 | 6.2 |

## Step 6 — Key Results

- **Current suitable area:** 1,127,000 km² above MaxTSS threshold (0.46)
- **Core suitable area (top 25% suitability):** 380,000 km²  
- **Projected under SSP2-4.5 2050:** 891,000 km² (−20.9%)
- **Projected under SSP5-8.5 2050:** 712,000 km² (−36.8%)
- **Change hotspot:** Southwestern Cerrado loses most area under both scenarios

## Ecological Interpretation

Annual precipitation was the strongest predictor, consistent with its role in driving termite mound density. NDVI captures vegetation structure important for foraging. The anteater shows high sensitivity to climate change with projected range contraction concentrated in the already fragmented and deforested eastern Cerrado.

**Recommendation:** Priority conservation areas should focus on the western Cerrado (Chapada dos Guimarães, Serra das Araras) and Pantanal-Cerrado transition zone, which maintain high projected suitability under all scenarios.
