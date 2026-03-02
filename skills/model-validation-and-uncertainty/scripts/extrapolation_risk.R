# Usage: Rscript extrapolation_risk.R <training_raster_stack.tif> <projection_raster_stack.tif> <output_dir>
#
# Arguments:
#   training_raster_stack.tif   : Multi-band GeoTIFF used for model calibration
#   projection_raster_stack.tif : Multi-band GeoTIFF for the projection area/period
#   output_dir                  : Directory for outputs (created if absent)
#
# Outputs:
#   mop_layer.tif              — MOP raster (0 = strict extrapolation, 1 = fully within range)
#   mess_layer.tif             — MESS raster (negative = novel environment)
#   extrapolation_summary.csv  — Summary statistics (% area per threshold)
#   extrapolation_plots.png    — Side-by-side MOP and MESS maps

suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(dismo))
suppressPackageStartupMessages(library(ggplot2))

# ── 1. Parse arguments ──────────────────────────────────────────────────────
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
  message("Using default paths for testing.")
  train_path  <- "data/predictors/env_train.tif"
  proj_path   <- "data/predictors/env_proj.tif"
  output_dir  <- "output/extrapolation"
} else {
  train_path  <- args[1]
  proj_path   <- args[2]
  output_dir  <- args[3]
}

# ── 2. Create output directory ───────────────────────────────────────────────
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── 3. Load raster stacks ────────────────────────────────────────────────────
message("Loading training stack: ", train_path)
train_stack <- rast(train_path)

message("Loading projection stack: ", proj_path)
proj_stack  <- rast(proj_path)

# Validate that both stacks have the same layers
if (!setequal(names(train_stack), names(proj_stack))) {
  mismatched <- setdiff(names(train_stack), names(proj_stack))
  stop("Layer name mismatch between training and projection stacks.\n",
       "  Missing in projection: ", paste(mismatched, collapse = ", "))
}

# Reorder projection layers to match training layer order
proj_stack <- proj_stack[[names(train_stack)]]
n_vars <- nlyr(train_stack)
message("Variables: ", paste(names(train_stack), collapse = ", "))

# ── 4. Extract calibration reference values ──────────────────────────────────
message("Extracting calibration reference values...")
cal_vals <- as.data.frame(train_stack, na.rm = TRUE)

# Scale calibration values for MOP distance computation
cal_center <- colMeans(cal_vals, na.rm = TRUE)
cal_sd     <- apply(cal_vals, 2, sd, na.rm = TRUE)

# Replace zero sd with 1 to avoid division by zero
cal_sd[cal_sd == 0] <- 1

cal_scaled <- scale(cal_vals, center = cal_center, scale = cal_sd)
n_cal      <- nrow(cal_scaled)

# ── 5. Compute MOP (Mobility-Oriented Parity) ────────────────────────────────
# Reference: Owens et al. 2013. Ecol. Model. 263:10-18.
# DOI: 10.1016/j.ecolmodel.2013.04.011
#
# For each projection pixel, MOP = proportion of calibration points that are
# "closer" (in standardised Euclidean space) than the projection pixel.
# MOP = 0 means the pixel is beyond ALL calibration points — strict extrapolation.

message("Computing MOP layer (this may take a few minutes)...")

# Compute the centroid distance of each calibration point
cal_centroid_dist <- sqrt(rowSums(cal_scaled^2))

# Apply MOP computation pixel by pixel using terra::app
proj_vals <- as.data.frame(proj_stack, na.rm = FALSE, xy = TRUE)
xy_cols   <- c("x", "y")
env_cols  <- setdiff(names(proj_vals), xy_cols)

mop_compute <- function(px_env) {
  if (any(is.na(px_env))) return(NA_real_)

  # Scale projection pixel using calibration parameters
  px_scaled <- (as.numeric(px_env) - cal_center) / cal_sd

  # Euclidean distance from this pixel to every calibration point
  d_px_to_cal <- sqrt(rowSums(sweep(cal_scaled, 2, px_scaled, "-")^2))

  # MOP = proportion of calibration points whose centroid distance
  # is less than the 10th percentile of distances from this pixel
  ref_dist <- quantile(d_px_to_cal, 0.1)
  sum(cal_centroid_dist < ref_dist) / n_cal
}

mop_vals <- apply(proj_vals[, env_cols], 1, mop_compute)

# Reconstruct as SpatRaster
mop_rast        <- rast(proj_stack[[1]])
values(mop_rast) <- NA
# Map back to all pixels (including those with NA that were skipped)
full_vals                                <- rep(NA_real_, ncell(mop_rast))
non_na_idx                               <- which(!is.na(values(proj_stack[[1]])))
full_vals[non_na_idx[seq_along(mop_vals)]] <- mop_vals
values(mop_rast) <- full_vals
names(mop_rast)  <- "MOP"

# Save MOP raster
mop_path <- file.path(output_dir, "mop_layer.tif")
writeRaster(mop_rast, mop_path, overwrite = TRUE)
message("Saved: ", mop_path)

# ── 6. Compute MESS (Multivariate Environmental Similarity Surfaces) ─────────
# Reference: Elith et al. 2010. Meth. Ecol. Evol. 1:330-342.
# DOI: 10.1111/j.2041-210X.2010.00036.x
#
# MESS < 0 indicates novel environment relative to calibration reference set.

message("Computing MESS layer...")

# dismo::mess requires a RasterStack (terra → raster conversion for compatibility)
suppressPackageStartupMessages(library(raster))
proj_raster <- raster::stack(proj_stack)
train_df    <- cal_vals  # reference points

mess_result <- dismo::mess(proj_raster, train_df, full = FALSE)

# Convert back to terra SpatRaster
mess_rast  <- rast(mess_result)
names(mess_rast) <- "MESS"

# Save MESS raster
mess_path <- file.path(output_dir, "mess_layer.tif")
writeRaster(mess_rast, mess_path, overwrite = TRUE)
message("Saved: ", mess_path)

# ── 7. Compute summary statistics ────────────────────────────────────────────
message("Computing extrapolation summary statistics...")

mop_v  <- values(mop_rast,  na.rm = TRUE)
mess_v <- values(mess_rast, na.rm = TRUE)
n_proj <- length(mop_v)

pct_mop_zero <- round(100 * sum(mop_v == 0,     na.rm = TRUE) / n_proj, 2)
pct_mop_025  <- round(100 * sum(mop_v < 0.25,   na.rm = TRUE) / n_proj, 2)
pct_mop_050  <- round(100 * sum(mop_v < 0.50,   na.rm = TRUE) / n_proj, 2)
pct_mess_neg <- round(100 * sum(mess_v < 0,      na.rm = TRUE) / length(mess_v[!is.na(mess_v)]), 2)

summary_df <- data.frame(
  metric = c("pct_area_MOP_zero",
             "pct_area_MOP_lt_0.25",
             "pct_area_MOP_lt_0.50",
             "pct_area_MESS_negative"),
  value  = c(pct_mop_zero, pct_mop_025, pct_mop_050, pct_mess_neg),
  interpretation = c(
    "Strict extrapolation (MOP = 0)",
    "High novelty (MOP < 0.25)",
    "Moderate-high novelty (MOP < 0.50)",
    "Novel environment in MESS (MESS < 0)"
  )
)

csv_path <- file.path(output_dir, "extrapolation_summary.csv")
write.csv(summary_df, csv_path, row.names = FALSE)
message("Saved: ", csv_path)

# ── 8. Automatic warning if extrapolation is severe ──────────────────────────
if (pct_mop_025 > 30) {
  warning(
    "\n\n*** EXTRAPOLATION WARNING ***\n",
    round(pct_mop_025, 1), "% of the projection area has MOP < 0.25 ",
    "(high novelty relative to calibration).\n",
    "Predictions in these areas should be treated with extreme caution.\n",
    "Recommendation: mask MOP < 0.25 pixels in publication figures and add\n",
    "explicit caveats in the methods section.\n"
  )
}

if (pct_mop_zero > 10) {
  warning(
    "\n*** STRICT EXTRAPOLATION WARNING ***\n",
    round(pct_mop_zero, 1), "% of the projection area has MOP = 0 ",
    "(model extrapolates beyond all calibration data).\n",
    "These pixels MUST be masked in publication figures.\n"
  )
}

# ── 9. Side-by-side diagnostic plots ─────────────────────────────────────────
message("Generating extrapolation plots...")

png(file.path(output_dir, "extrapolation_plots.png"),
    width = 1600, height = 700, res = 150)
par(mfrow = c(1, 2), mar = c(4, 4, 3, 5))

# MOP map
plot(mop_rast, main = "MOP (0 = strict extrapolation)",
     col = rev(terrain.colors(100)),
     legend = TRUE, axes = FALSE)
mtext(paste0("MOP = 0: ", pct_mop_zero, "% | MOP < 0.25: ", pct_mop_025, "%"),
      side = 1, cex = 0.8)

# MESS map (diverging palette: red = novel, blue = similar)
mess_cols <- colorRampPalette(c("red", "white", "steelblue"))(100)
plot(mess_rast, main = "MESS (negative = novel environment)",
     col = mess_cols,
     legend = TRUE, axes = FALSE)
mtext(paste0("MESS < 0: ", pct_mess_neg, "%"),
      side = 1, cex = 0.8)

dev.off()
message("Saved: ", file.path(output_dir, "extrapolation_plots.png"))

# ── 10. Final summary ─────────────────────────────────────────────────────────
message("\n========== EXTRAPOLATION SUMMARY ==========")
message("% area MOP = 0    (strict extrapolation): ", pct_mop_zero, "%")
message("% area MOP < 0.25 (high novelty)        : ", pct_mop_025, "%")
message("% area MOP < 0.50 (moderate novelty)    : ", pct_mop_050, "%")
message("% area MESS < 0   (novel environment)   : ", pct_mess_neg, "%")
message("===========================================\n")
