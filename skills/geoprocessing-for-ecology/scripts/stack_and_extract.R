# stack_and_extract.R
# Clip rasters to study area and extract values at points
# Usage: Rscript stack_and_extract.R <raster_dir> <points_csv> <studyarea_shp> <output_dir>
# Requires: terra, sf

suppressPackageStartupMessages({
  library(terra)
  library(sf)
})

args        <- commandArgs(trailingOnly = TRUE)
raster_dir  <- ifelse(length(args) >= 1, args[1], "data/predictors/raw")
points_file <- ifelse(length(args) >= 2, args[2], "data/processed/data_clean.csv")
area_file   <- ifelse(length(args) >= 3, args[3], "data/spatial/study_area.shp")
output_dir  <- ifelse(length(args) >= 4, args[4], "data/processed")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── 1. Load study area ─────────────────────────────────────────────────────
cat("Loading study area:", area_file, "\n")
study_area <- vect(area_file)

# ── 2. Load and stack rasters ──────────────────────────────────────────────
tif_files <- list.files(raster_dir, pattern = "\\.tif$", full.names = TRUE)
cat("Rasters found:", length(tif_files), "\n")
if (length(tif_files) == 0) stop("No .tif files found in ", raster_dir)

stack_raw <- rast(tif_files)

# ── 3. Reproject study area to raster CRS, then crop and mask ─────────────
study_proj <- project(study_area, crs(stack_raw))
stack_crop <- crop(stack_raw, study_proj)
stack_mask <- mask(stack_crop, study_proj)

# ── 4. Write stack ─────────────────────────────────────────────────────────
stack_out <- file.path(output_dir, "predictors_stack.tif")
writeRaster(stack_mask, stack_out, overwrite = TRUE)
cat("Stack written:", stack_out, "\n")

# ── 5. Load points and extract ─────────────────────────────────────────────
pts_df <- read.csv(points_file)
if (!all(c("decimalLongitude", "decimalLatitude") %in% names(pts_df))) {
  stop("Points CSV must have columns: decimalLongitude, decimalLatitude")
}

pts_vect <- vect(pts_df, geom = c("decimalLongitude", "decimalLatitude"),
                 crs = "EPSG:4326")
pts_proj <- project(pts_vect, crs(stack_mask))

extracted <- terra::extract(stack_mask, pts_proj, ID = FALSE)
pts_env   <- cbind(pts_df, extracted)

env_out <- file.path(output_dir, "points_with_env.csv")
write.csv(pts_env, env_out, row.names = FALSE)
cat("Extracted values written:", env_out, "\n")
cat("Points with complete env data:", sum(complete.cases(extracted)), "/", nrow(extracted), "\n")
