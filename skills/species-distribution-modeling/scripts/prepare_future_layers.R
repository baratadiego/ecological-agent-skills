# Usage: Rscript prepare_future_layers.R <current_stack.tif> <future_layers_dir> <study_area.shp> <output_dir> [ssp_label] [year_label]
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
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 4) {
  message("Using default paths for testing.")
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

# ── 2. Create output directory ───────────────────────────────────────────────
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── 3. Load reference calibration stack ─────────────────────────────────────
message("Loading calibration stack: ", current_tif)
if (!file.exists(current_tif)) {
  stop("Calibration stack not found: ", current_tif)
}
ref_stack <- rast(current_tif)
message("  CRS    : ", crs(ref_stack, describe = TRUE)$name)
message("  Extent : ", paste(round(as.vector(ext(ref_stack)), 3), collapse = ", "))
message("  Res    : ", paste(res(ref_stack), collapse = " × "))
message("  Layers : ", paste(names(ref_stack), collapse = ", "))

# ── 4. Load study area (G area) ──────────────────────────────────────────────
message("Loading study area: ", study_area_path)
if (!file.exists(study_area_path)) {
  stop("Study area file not found: ", study_area_path)
}
study_area <- vect(study_area_path)

# Reproject study area to match calibration CRS if needed
if (!identical(crs(study_area), crs(ref_stack))) {
  message("  Reprojecting study area to calibration CRS...")
  study_area <- project(study_area, crs(ref_stack))
}

# ── 5. Load future climate layers ────────────────────────────────────────────
message("Loading future layers from: ", future_dir)
if (!dir.exists(future_dir)) {
  stop("Future layers directory not found: ", future_dir)
}

future_files <- list.files(future_dir, pattern = "\\.tif$", full.names = TRUE,
                            recursive = FALSE)
if (length(future_files) == 0) {
  stop("No .tif files found in: ", future_dir)
}

message("  Found ", length(future_files), " future layer files.")

# Stack all future layers
future_raw <- rast(future_files)
message("  Future layer names (raw): ", paste(names(future_raw), collapse = ", "))

# ── 6. Rename future layers to match calibration ─────────────────────────────
# Strategy: if layer names differ but count matches, rename by position.
# If counts differ, attempt name matching. Fail clearly if neither works.

ref_names    <- names(ref_stack)
future_names <- names(future_raw)

if (setequal(ref_names, future_names)) {
  # Names match already — reorder to calibration order
  future_raw <- future_raw[[ref_names]]
  message("  Layer names match calibration. Reordered to calibration order.")

} else if (length(future_names) == length(ref_names) &&
           !setequal(ref_names, future_names)) {
  # Same count but different names — rename by position (common with CHELSA long names)
  message("  Layer names differ from calibration. Renaming by position (", length(ref_names), " layers).")
  message("  Old names: ", paste(future_names, collapse = ", "))
  message("  New names: ", paste(ref_names,    collapse = ", "))
  names(future_raw) <- ref_names

} else {
  # Different count — try to find matching layers by partial name
  matched <- sapply(ref_names, function(rn) {
    idx <- which(grepl(rn, future_names, fixed = TRUE))
    if (length(idx) == 1) idx else NA_integer_
  })

  if (any(is.na(matched))) {
    missing_layers <- ref_names[is.na(matched)]
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
  message("  Matched layers by partial name. Reordered to calibration order.")
}

# ── 7. Reproject to calibration CRS ──────────────────────────────────────────
if (!identical(crs(future_raw), crs(ref_stack))) {
  message("Reprojecting future stack to calibration CRS...")
  future_raw <- project(future_raw, crs(ref_stack), method = "bilinear")
  message("  Reprojection complete.")
} else {
  message("CRS already matches calibration. No reprojection needed.")
}

# ── 8. Crop and mask to study area (G area) ───────────────────────────────────
message("Cropping and masking to study area...")
future_cropped <- crop(future_raw,   study_area)
future_masked  <- mask(future_cropped, study_area)

# ── 9. Resample to exactly match calibration grid ────────────────────────────
message("Resampling to calibration grid (bilinear interpolation)...")
future_resampled <- resample(future_masked, ref_stack, method = "bilinear")

# ── 10. Geometry verification ────────────────────────────────────────────────
message("Verifying geometry against calibration stack...")
geom_ok <- compareGeom(ref_stack, future_resampled, stopOnError = FALSE,
                        res = TRUE, orig = TRUE, crs = TRUE)

if (!geom_ok) {
  stop(
    "Geometry verification FAILED after resampling.\n",
    "  Calibration: ext=", as.character(ext(ref_stack)),
    " res=", paste(res(ref_stack), collapse="×"),
    " crs=", crs(ref_stack, describe=TRUE)$name, "\n",
    "  Future:      ext=", as.character(ext(future_resampled)),
    " res=", paste(res(future_resampled), collapse="×"),
    " crs=", crs(future_resampled, describe=TRUE)$name, "\n",
    "  Check for extent or datum mismatches and re-run."
  )
}
message("  Geometry check PASSED.")

# ── 11. Final layer name verification ────────────────────────────────────────
if (!identical(names(future_resampled), names(ref_stack))) {
  name_diff <- setdiff(names(future_resampled), names(ref_stack))
  stop(
    "Layer name mismatch in final stack.\n",
    "  Expected: ", paste(names(ref_stack), collapse = ", "), "\n",
    "  Got:      ", paste(names(future_resampled), collapse = ", "), "\n",
    "  Differing layers: ", paste(name_diff, collapse = ", ")
  )
}
message("  Layer name check PASSED. Names: ", paste(names(future_resampled), collapse = ", "))

# ── 12. Save output ───────────────────────────────────────────────────────────
out_filename <- paste0("future_stack_", ssp_label, "_", year_label, ".tif")
out_path     <- file.path(output_dir, out_filename)

writeRaster(future_resampled, out_path, overwrite = TRUE)
message("Saved: ", out_path)

# ── 13. Summary ───────────────────────────────────────────────────────────────
message("\n========== FUTURE LAYERS SUMMARY ==========")
message("SSP              : ", ssp_label)
message("Year horizon     : ", year_label)
message("Layers prepared  : ", nlyr(future_resampled))
message("Layer names      : ", paste(names(future_resampled), collapse = ", "))
message("Output CRS       : ", crs(future_resampled, describe = TRUE)$name)
message("Output resolution: ", paste(res(future_resampled), collapse = " × "), " units")
message("Output file      : ", out_path)
message("============================================\n")
message("Ready to pass to: maxnet::predict(), biomod2::BIOMOD_Projection(), or sdm_pipeline.py")
