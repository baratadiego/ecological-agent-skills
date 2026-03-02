# Climate Scenario Preparation Guide

Preparing future climate layers for SDM projection: sources, SSPs, time horizons, and pipeline.

---

## 1. Sources of Future Climate Data

| Source | Resolution | SSPs available | Temporal coverage | Recommended for |
|---|---|---|---|---|
| **CHELSA-Future** | ~1 km (30 arc-sec) | SSP1-2.6, SSP3-7.0, SSP5-8.5 | 2041–2060, 2061–2080 | **Primary recommendation** — high resolution, bias-corrected |
| **WorldClim v2.1 future** | ~18 km (10 arc-min) | SSP1-2.6, SSP2-4.5, SSP3-7.0, SSP5-8.5 | 2021–2040, 2041–2060, 2061–2080, 2081–2100 | Regional studies where 10-min resolution is acceptable |
| **CMIP6 raw** | ~100 km (1°) | All SSPs from each GCM | Monthly, 1850–2100 | Research requiring specific GCM; requires statistical downscaling |
| **TerraClimate** | ~4 km | N/A (historical only) | 1958–present | Historical baseline calibration |

**Key reference:** Karger et al. 2017 (CHELSA v1). DOI: [10.1038/sdata.2017.122](https://doi.org/10.1038/sdata.2017.122)

**Download portals:**
- CHELSA: https://chelsa-climate.org/downloads/
- WorldClim: https://worldclim.org/data/cmip6/cmip6climate.html

---

## 2. SSPs — Shared Socioeconomic Pathways

| SSP | Common name | Radiative forcing (2100) | Temperature anomaly (°C, 2100) | When to use |
|---|---|---|---|---|
| **SSP1-2.6** | Optimistic / sustainability | 2.6 W/m² | ~1.8°C | Show "best case" scenario |
| **SSP2-4.5** | Intermediate | 4.5 W/m² | ~2.7°C | **Always include** — most likely trajectory |
| **SSP3-7.0** | Regional rivalry | 7.0 W/m² | ~3.6°C | Regional fragmentation scenarios |
| **SSP5-8.5** | High emissions / fossil fuel | 8.5 W/m² | ~4.4°C | **Always include** — worst-case bound |

**Minimum reporting standard:** Always include at least **SSP2-4.5** and **SSP5-8.5** to capture intermediate and worst-case trajectories. Including SSP1-2.6 (optimistic) is recommended to illustrate the conservation value of mitigation.

---

## 3. Standard Time Horizons

| Label | Period | Commonly called |
|---|---|---|
| Near future | 2021–2040 | "2030" |
| Mid-century | 2041–2060 | **"2050"** (most used) |
| Late-century | 2061–2080 | **"2070"** (most used) |
| End-of-century | 2081–2100 | "2100" |

**Recommendation:** Report at minimum **2050** and **2070** for each SSP. This yields 4 projection scenarios minimum (SSP2-4.5 × 2050, SSP2-4.5 × 2070, SSP5-8.5 × 2050, SSP5-8.5 × 2070).

---

## 4. Mandatory Preparation Pipeline

Follow these steps in order before passing any future layer to a model:

### Step 1 — Download future layers
Download the same set of bioclimatic/environmental variables that were selected
during calibration. **Never add or remove variables between current and future.**

```r
# Example: listing CHELSA-Future files for a specific SSP and GCM
# Files follow naming convention: CHELSA_{var}_2041-2060_{ssp}_{gcm}_V.2.1.tif
chelsa_files <- list.files("data/chelsa_future/ssp585_2050/", pattern = "\\.tif$",
                            full.names = TRUE)
```

### Step 2 — Reproject to calibration CRS

```r
suppressPackageStartupMessages(library(terra))

# Load reference (calibration) stack
ref_stack    <- rast("data/predictors/env_train.tif")
future_stack <- rast(chelsa_files)

# Reproject to match calibration CRS
future_stack <- project(future_stack, crs(ref_stack), method = "bilinear")
```

### Step 3 — Clip and mask to projection area (G area)

The projection area (G area) is typically the full study continent or biome.
It must be the same for all SSPs and time periods.

```r
study_area <- vect("data/study_area/g_area.shp")
future_stack <- crop(future_stack,   study_area)
future_stack <- mask(future_stack,   study_area)
```

### Step 4 — Verify identical geometry with terra::compareGeom()

This is **critical** — silent geometry mismatches cause wrong predictions.

```r
# compareGeom returns TRUE if extent, resolution, CRS all match
if (!compareGeom(ref_stack, future_stack, stopOnError = FALSE)) {
  # Resample to exactly match reference grid
  future_stack <- resample(future_stack, ref_stack, method = "bilinear")

  # Verify again
  if (!compareGeom(ref_stack, future_stack, stopOnError = FALSE)) {
    stop("Geometry mismatch persists after resampling. Check CRS and extent.")
  }
}
message("Geometry check passed.")
```

### Step 5 — Verify layer names match calibration stack

Layer name matching is **critical for maxnet and biomod2** — the model uses
names to match predictors. A mismatch causes silent wrong variable assignment.

```r
# Check names
ref_names    <- names(ref_stack)
future_names <- names(future_stack)

missing_in_future <- setdiff(ref_names, future_names)
extra_in_future   <- setdiff(future_names, ref_names)

if (length(missing_in_future) > 0) {
  stop("Future stack is missing layers present in calibration: ",
       paste(missing_in_future, collapse = ", "))
}

if (length(extra_in_future) > 0) {
  message("Extra layers in future stack (will be dropped): ",
          paste(extra_in_future, collapse = ", "))
  future_stack <- future_stack[[ref_names]]  # subset to calibration variables
}

# Reorder to match calibration
future_stack <- future_stack[[ref_names]]
message("Layer names verified and ordered.")
```

---

## 5. Quick-Reference Checklist

| Step | Check | Status |
|---|---|---|
| Same variables as calibration | All bioclim variables identical | ☐ |
| CRS matches calibration stack | `crs(future) == crs(train)` | ☐ |
| Resolution matches | `res(future) == res(train)` | ☐ |
| Extent matches after crop | `compareGeom()` returns TRUE | ☐ |
| Layer names identical and in same order | `names(future) == names(train)` | ☐ |
| Masked to G area polygon | `mask()` applied | ☐ |
| Output file saved with SSP+year label | `future_stack_ssp585_2050.tif` | ☐ |

---

## 6. Common Errors

- **Using different variables between current and future:** e.g., using bio1–bio5 for calibration but bio1–bio3 for future. This is an automatic error in maxnet.
- **Not clipping to G area:** projecting to a wider area than intended inflates apparent suitable area and may increase extrapolation.
- **Silent CRS incompatibilities:** `terra::project()` will reproject, but if you skip this step and the CRS differs by even the datum, predictions will be geographically offset.
- **Using a different GCM for each SSP:** GCMs have different temperature sensitivities; using different GCMs per SSP conflates SSP and GCM effects. Use the same GCM(s) across all SSPs.
- **Layer name mismatch after renaming:** CHELSA uses long names like `CHELSA_bio1_2041-2060_ssp585_MPI-ESM1-2-HR_V.2.1`; rename layers to match short names (`bio1`, `bio2`, …) immediately after loading.

---

## 7. References

| Citation | DOI |
|---|---|
| Karger et al. 2017. Sci. Data 4:170122 (CHELSA) | [10.1038/sdata.2017.122](https://doi.org/10.1038/sdata.2017.122) |
| Fick & Hijmans 2017. Int. J. Climatol. (WorldClim 2) | [10.1002/joc.5086](https://doi.org/10.1002/joc.5086) |
| Eyring et al. 2016. Geosci. Model Dev. (CMIP6) | [10.5194/gmd-9-1937-2016](https://doi.org/10.5194/gmd-9-1937-2016) |
| O'Neill et al. 2016. Geosci. Model Dev. (SSPs) | [10.5194/gmd-9-3461-2016](https://doi.org/10.5194/gmd-9-3461-2016) |
| Zurell et al. 2020. Ecography (ODMAP) | [10.1111/ecog.04960](https://doi.org/10.1111/ecog.04960) |
