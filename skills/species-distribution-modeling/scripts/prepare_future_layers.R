# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript prepare_future_layers.R <current_stack.tif> <future_layers_dir> <study_area.shp> <output_dir> [ssp_label] [year_label]

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "species-distribution-modeling"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

#
# Arguments:
#   current_stack.tif   : Reference calibration raster stack (sets CRS, resolution, extent)
#   future_layers_dir   : Directory containing future climate .tif files (one per variable)
#   study_area.shp      : Shapefile / GeoPackage defining the projection area (G area)
#   output_dir          : Directory to write the prepared future stack (created if absent)
#   ssp_label           : Optional SSP label for output filename (default: "ssp245")
#   year_label          : Optional time horizon label for output filename (default: "2050")
#
# Output:
#   future_stack_{ssp_label}_{year_label}.tif  — prepared stack ready for model projection

suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(sf))

# ── 1. Parse arguments ──────────────────────────────────────────────────────
log_step(1, "Parse command-line arguments")
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 4) {
  log_warn("Fewer than 4 arguments. Using default paths for testing.")
  current_tif      <- "data/predictors/env_train.tif"
  future_dir       <- "data/chelsa_future/ssp245_2050/"
  study_area_path  <- "data/study_area/g_area.shp"
  output_dir       <- "output/future_layers"
  ssp_label        <- "ssp245"
  year_label       <- "2050"
} else {
  current_tif      <- args[1]
  future_dir       <- args[2]
  study_area_path  <- args[3]
  output_dir       <- args[4]
  ssp_label        <- if (length(args) >= 5) args[5] else "ssp245"
  year_label       <- if (length(args) >= 6) args[6] else "2050"
}

log_info("Script: prepare_future_layers.R | Skill: %s", SKILL_NAME)
log_info("Calibration stack  : %s", current_tif)
log_info("Future directory    : %s", future_dir)
log_info("Study area         : %s", study_area_path)
log_info("Output dir          : %s", output_dir)
log_info("SSP label           : %s", ssp_label)
log_info("Year label          : %s", year_label)

log_decision("ssp_label",  ssp_label,  "SSP scenario label for output file naming")
log_decision("year_label", year_label, "temporal horizon label for output file naming")

# ── Input precondition checks ─────────────────────────────────────────────────
if (!file.exists(current_tif)) {
  log_error(
    "Input not found: %s\nProbable cause: file not yet generated pelo passo anterior.\nCheck a saida de: species-distribution-modeling (prepare_predictors ou similar)\nPrevious skill: species-distribution-modeling",
    current_tif
  )
  stop("Calibration stack not found: ", current_tif)
}

if (!file.exists(study_area_path)) {
  log_error(
    "Input not found: %s\nProbable cause: shapefile de study area missing.\nCheck a saida de: ecological-data-foundation ou etapa de definicao da G area.\nPrevious skill: species-distribution-modeling",
    study_area_path
  )
  stop("Study area file not found: ", study_area_path)
}

if (!dir.exists(future_dir)) {
  log_error(
    "Future layers directory not found: %s\nProbable cause: CHELSA/WorldClim future layers not yet downloaded.\nDownload the future GeoTIFFs and place them in: %s\nPrevious skill: species-distribution-modeling",
    future_dir, future_dir
  )
  stop("Future layers directory not found: ", future_dir)
}

# ── 2. Create output directory ───────────────────────────────────────────────
log_step(2, "Create output directory")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
log_info("Output directory ready: %s", output_dir)

# ── 3. Load reference calibration stack ─────────────────────────────────────
log_step(3, "Load reference calibration stack")
ref_stack <- tryCatch({
  rast(current_tif)
}, error = function(e) {
  log_error(
    "Failed to load calibration stack '%s': %s\nProbable cause: corrupted GeoTIFF file or format not supported by terra.\nPrevious skill: species-distribution-modeling",
    current_tif, conditionMessage(e)
  )
  stop(e)
})

log_info("CRS    : %s", crs(ref_stack, describe = TRUE)$name)
log_info("Extent : %s", paste(round(as.vector(ext(ref_stack)), 3), collapse = ", "))
log_info("Res    : %s", paste(res(ref_stack), collapse = " x "))
log_info("Layers : %s", paste(names(ref_stack), collapse = ", "))

# ── 4. Load study area (G area) ──────────────────────────────────────────────
log_step(4, "Load study area (G area)")
study_area <- tryCatch({
  vect(study_area_path)
}, error = function(e) {
  log_error(
    "Failed to load study area '%s': %s\nProbable cause: corrupted shapefile, invalid projection or unsupported format.\nCheck: ogrinfo '%s'\nPrevious skill: species-distribution-modeling",
    study_area_path, conditionMessage(e), study_area_path
  )
  stop(e)
})

# Reproject study area to match calibration CRS if needed
if (!identical(crs(study_area), crs(ref_stack))) {
  log_info("Reprojecting study area to calibration CRS...")
  study_area <- tryCatch(
    project(study_area, crs(ref_stack)),
    error = function(e) {
      log_error(
        "Failed to reprojetar study area: %s\nProbable cause: CRS invalido ou incompativel.\nPrevious skill: species-distribution-modeling",
        conditionMessage(e)
      )
      stop(e)
    }
  )
  log_info("Reprojection completed.")
} else {
  log_info("Study area CRS already matches calibration. No reprojection needed.")
}

# ── 5. Load future climate layers ────────────────────────────────────────────
log_step(5, "Load future climate layers")
future_files <- list.files(future_dir, pattern = "\\.tif$", full.names = TRUE,
                            recursive = FALSE)
if (length(future_files) == 0) {
  log_error(
    "No .tif files found in: %s\nProbable cause: future layers not downloaded or files use a different extension.\nCheck the contents of the directory.\nPrevious skill: species-distribution-modeling",
    future_dir
  )
  stop("No .tif files found in: ", future_dir)
}

log_info("Future layer files found: %d", length(future_files))

# Stack all future layers
future_raw <- tryCatch({
  rast(future_files)
}, error = function(e) {
  log_error(
    "Failed to stack future layers: %s\nProbable cause: corrupted GeoTIFFs or incompatible extents.\nCheck: run gdalinfo on files in %s\nPrevious skill: species-distribution-modeling",
    conditionMessage(e), future_dir
  )
  stop(e)
})
log_info("Raw future layer names: %s", paste(names(future_raw), collapse = ", "))

# ── 6. Rename future layers to match calibration ─────────────────────────────
log_step(6, "Rename future layers to match calibration")
# Strategy: if layer names differ but count matches, rename by position.
# If counts differ, attempt name matching. Fail clearly if neither works.

ref_names    <- names(ref_stack)
future_names <- names(future_raw)

if (setequal(ref_names, future_names)) {
  # Names match already — reorder to calibration order
  future_raw <- future_raw[[ref_names]]
  log_info("Layer names match. Reordered to match calibration.")
  log_decision("rename_strategy", "reorder", "identical names, reordered only")

} else if (length(future_names) == length(ref_names) &&
           !setequal(ref_names, future_names)) {
  # Same count but different names — rename by position (common with CHELSA long names)
  log_warn(
    "Layer names differ from calibration stack. Renaming by position (%d layers).",
    length(ref_names)
  )
  log_info("Old names  : %s", paste(future_names, collapse = ", "))
  log_info("New names  : %s", paste(ref_names,    collapse = ", "))
  log_decision("rename_strategy", "by_position", "same number of layers but different names (common with CHELSA)")
  names(future_raw) <- ref_names

} else {
  # Different count — try to find matching layers by partial name
  log_warn("Layer count differs. Attempting partial name matching...")
  matched <- sapply(ref_names, function(rn) {
    idx <- which(grepl(rn, future_names, fixed = TRUE))
    if (length(idx) == 1) idx else NA_integer_
  })

  if (any(is.na(matched))) {
    missing_layers <- ref_names[is.na(matched)]
    log_error(
      "Cannot match future layers to calibration layers.\nCalibration expects: %s\nFuture layers: %s\nNo match for: %s\nAction: rename the future .tif files to exactly match the calibration layer names.\nPrevious skill: species-distribution-modeling",
      paste(ref_names,    collapse = ", "),
      paste(future_names, collapse = ", "),
      paste(missing_layers, collapse = ", ")
    )
    stop(
      "Cannot match future layers to calibration layers.\n",
      "  Calibration expects: ", paste(ref_names, collapse = ", "), "\n",
      "  Future layers found: ", paste(future_names, collapse = ", "), "\n",
      "  Could not find match for: ", paste(missing_layers, collapse = ", "), "\n",
      "  Action: rename future .tif files to match calibration layer names exactly."
    )
  }

  future_raw <- future_raw[[matched]]
  names(future_raw) <- ref_names
  log_info("Layers matched by partial name. Reordered to match calibration.")
  log_decision("rename_strategy", "partial_name_match", "different count; matched by substring")
}

# ── 7. Reproject to calibration CRS ──────────────────────────────────────────
log_step(7, "Reproject future stack to calibration CRS")
if (!identical(crs(future_raw), crs(ref_stack))) {
  log_info("Reprojecting future stack to calibration CRS...")
  log_decision("resample_method_reproj", "bilinear", "bilinear interpolation for continuous climate data")
  future_raw <- tryCatch(
    project(future_raw, crs(ref_stack), method = "bilinear"),
    error = function(e) {
      log_error(
        "Failed to reprojetar stack futuro: %s\nProbable cause: CRS invalido ou falta de memoria para o raster.\nPrevious skill: species-distribution-modeling",
        conditionMessage(e)
      )
      stop(e)
    }
  )
  log_info("Reprojection completed.")
} else {
  log_info("CRS already matches calibration. No reprojection needed.")
}

# ── 8. Crop and mask to study area (G area) ───────────────────────────────────
log_step(8, "Crop and mask to study area")
tryCatch({
  future_cropped <- crop(future_raw,    study_area)
  future_masked  <- mask(future_cropped, study_area)
  log_info("Clip and mask applied. Valid cells after mask: not calculated (use global(future_masked, 'notNA')).")
}, error = function(e) {
  log_error(
    "Failed to clip and mask future stack: %s\nProbable cause: study area extent outside the future raster extent.\nCheck the projection and extent of all files.\nPrevious skill: species-distribution-modeling",
    conditionMessage(e)
  )
  stop(e)
})

# ── 9. Resample to exactly match calibration grid ────────────────────────────
log_step(9, "Resample to match calibration grid exactly")
log_decision("resample_method", "bilinear", "bilinear interpolation for continuous climate data")
future_resampled <- tryCatch(
  resample(future_masked, ref_stack, method = "bilinear"),
  error = function(e) {
    log_error(
      "Failed to resample future stack: %s\nProbable cause: CRS or extent incompatibility between future stack and calibration stack.\nCheck steps 7 and 8.\nPrevious skill: species-distribution-modeling",
      conditionMessage(e)
    )
    stop(e)
  }
)

# ── 10. Geometry verification ────────────────────────────────────────────────
log_step(10, "Check future stack geometry against calibration")
geom_ok <- tryCatch(
  compareGeom(ref_stack, future_resampled, stopOnError = FALSE,
              res = TRUE, orig = TRUE, crs = TRUE),
  error = function(e) {
    log_warn("compareGeom returned error: %s. Proceeding with caution.", conditionMessage(e))
    FALSE
  }
)

if (!geom_ok) {
  log_error(
    "Geometry check FAILED after resampling.\nCalibration: ext=%s res=%s crs=%s\nFuture     : ext=%s res=%s crs=%s\nCheck for extent or datum incompatibilities and re-run.\nPrevious skill: species-distribution-modeling",
    as.character(ext(ref_stack)),
    paste(res(ref_stack), collapse = "x"),
    crs(ref_stack, describe = TRUE)$name,
    as.character(ext(future_resampled)),
    paste(res(future_resampled), collapse = "x"),
    crs(future_resampled, describe = TRUE)$name
  )
  stop(
    "Geometry verification FAILED after resampling.\n",
    "  Calibration: ext=", as.character(ext(ref_stack)),
    " res=", paste(res(ref_stack), collapse="x"),
    " crs=", crs(ref_stack, describe=TRUE)$name, "\n",
    "  Future:      ext=", as.character(ext(future_resampled)),
    " res=", paste(res(future_resampled), collapse="x"),
    " crs=", crs(future_resampled, describe=TRUE)$name, "\n",
    "  Check for extent or datum mismatches and re-run."
  )
}
log_info("Geometry check PASSED.")

# ── 11. Final layer name verification ────────────────────────────────────────
log_step(11, "Check final layer names")
if (!identical(names(future_resampled), names(ref_stack))) {
  name_diff <- setdiff(names(future_resampled), names(ref_stack))
  log_error(
    "Layer name mismatch in final stack.\nExpected: %s\nObtained: %s\nDivergent: %s\nPrevious skill: species-distribution-modeling",
    paste(names(ref_stack),       collapse = ", "),
    paste(names(future_resampled), collapse = ", "),
    paste(name_diff, collapse = ", ")
  )
  stop(
    "Layer name mismatch in final stack.\n",
    "  Expected: ", paste(names(ref_stack), collapse = ", "), "\n",
    "  Got:      ", paste(names(future_resampled), collapse = ", "), "\n",
    "  Differing layers: ", paste(name_diff, collapse = ", ")
  )
}
log_info("Layer names verified. Layers: %s", paste(names(future_resampled), collapse = ", "))

# ── 12. Save output ───────────────────────────────────────────────────────────
log_step(12, "Write prepared future stack")
out_filename <- paste0("future_stack_", ssp_label, "_", year_label, ".tif")
out_path     <- file.path(output_dir, out_filename)

tryCatch({
  writeRaster(future_resampled, out_path, overwrite = TRUE)
  log_info("Written: %s", out_path)
}, error = function(e) {
  log_error(
    "Failed to write output raster '%s': %s\nProbable cause: no write permission or insufficient disk space.\nPrevious skill: species-distribution-modeling",
    out_path, conditionMessage(e)
  )
  stop(e)
})

# ── 13. Summary ───────────────────────────────────────────────────────────────
log_step(13, "Display prepared future layers summary")
log_info("========== PREPARED FUTURE LAYERS SUMMARY ==========")
log_info("SSP                : %s", ssp_label)
log_info("Temporal horizon   : %s", year_label)
log_info("Prepared layers    : %d", nlyr(future_resampled))
log_info("Layer names        : %s", paste(names(future_resampled), collapse = ", "))
log_info("Output CRS         : %s", crs(future_resampled, describe = TRUE)$name)
log_info("Output resolution  : %s units", paste(res(future_resampled), collapse = " x "))
log_info("Output file        : %s", out_path)
log_info("=========================================================")
log_info("Ready for: maxnet::predict(), biomod2::BIOMOD_Projection() or sdm_pipeline.py")
