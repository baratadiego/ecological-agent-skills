# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

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

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "model-validation-and-uncertainty"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(dismo))
suppressPackageStartupMessages(library(ggplot2))

# ── 1. Parse arguments ──────────────────────────────────────────────────────
log_step(1, "Parse arguments and validate inputs")
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
  log_warn("Fewer than 3 arguments provided. Using default paths for testing.")
  train_path  <- "data/predictors/env_train.tif"
  proj_path   <- "data/predictors/env_proj.tif"
  output_dir  <- "output/extrapolation"
} else {
  train_path  <- args[1]
  proj_path   <- args[2]
  output_dir  <- args[3]
}

log_decision("train_path", train_path, "raster stack used for model calibration")
log_decision("proj_path",  proj_path,  "raster stack for the projection area/period")

if (!file.exists(train_path)) {
  log_error(
    "Falha em validate inputs: raster de treinamento nao encontrado: %s\nCausa provavel: caminho incorreto ou arquivo GeoTIFF nao gerado\nVerifique: o argumento training_raster_stack.tif e o diretorio de trabalho\nSkill anterior: species-distribution-modelling",
    train_path
  )
  stop("Training raster not found.")
}
if (!file.exists(proj_path)) {
  log_error(
    "Falha em validate inputs: raster de projecao nao encontrado: %s\nCausa provavel: caminho incorreto ou arquivo GeoTIFF nao gerado\nVerifique: o argumento projection_raster_stack.tif e o diretorio de trabalho\nSkill anterior: species-distribution-modelling",
    proj_path
  )
  stop("Projection raster not found.")
}

# ── 2. Create output directory ───────────────────────────────────────────────
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── 3. Load raster stacks ────────────────────────────────────────────────────
log_step(2, "Load raster stacks")
tryCatch({
  log_info("Loading training stack: %s", train_path)
  train_stack <- rast(train_path)

  log_info("Loading projection stack: %s", proj_path)
  proj_stack  <- rast(proj_path)
}, error = function(e) {
  log_error(
    "Falha em load rasters: %s\nCausa provavel: arquivo GeoTIFF corrompido ou formato nao suportado\nVerifique: integridade dos arquivos TIF com gdalinfo\nSkill anterior: species-distribution-modelling",
    conditionMessage(e)
  )
  stop(e)
})

# Validate that both stacks have the same layers
if (!setequal(names(train_stack), names(proj_stack))) {
  mismatched <- setdiff(names(train_stack), names(proj_stack))
  log_error(
    "Falha em validate layers: nomes de camadas divergem entre stacks de treinamento e projecao.\nCamadas ausentes na projecao: %s\nCausa provavel: stacks gerados com variaveis diferentes\nVerifique: que ambos os TIFs tem as mesmas bandas nomeadas\nSkill anterior: species-distribution-modelling",
    paste(mismatched, collapse = ", ")
  )
  stop("Layer name mismatch between training and projection stacks.\n  Missing in projection: ",
       paste(mismatched, collapse = ", "))
}

# Reorder projection layers to match training layer order
proj_stack <- proj_stack[[names(train_stack)]]
n_vars <- nlyr(train_stack)
log_info("Variables (%d): %s", n_vars, paste(names(train_stack), collapse = ", "))

# ── 4. Extract calibration reference values ──────────────────────────────────
log_step(3, "Extract calibration reference values")
tryCatch({
  cal_vals <- as.data.frame(train_stack, na.rm = TRUE)
  log_info("Calibration pixels extracted: %d", nrow(cal_vals))

  if (nrow(cal_vals) < 100) {
    log_warn("Only %d non-NA calibration pixels. MOP estimates may be unstable.", nrow(cal_vals))
  }

  # Scale calibration values for MOP distance computation
  cal_center <- colMeans(cal_vals, na.rm = TRUE)
  cal_sd     <- apply(cal_vals, 2, sd, na.rm = TRUE)

  zero_sd_vars <- names(cal_sd)[cal_sd == 0]
  if (length(zero_sd_vars) > 0) {
    log_warn("Variables with zero variance (will be set to sd=1): %s", paste(zero_sd_vars, collapse = ", "))
  }

  # Replace zero sd with 1 to avoid division by zero
  cal_sd[cal_sd == 0] <- 1

  cal_scaled <- scale(cal_vals, center = cal_center, scale = cal_sd)
  n_cal      <- nrow(cal_scaled)
  log_decision("mop_scaling", "z-score using calibration mean/sd", "ensures all variables contribute equally to Euclidean distance")
}, error = function(e) {
  log_error(
    "Falha em extract calibration values: %s\nCausa provavel: raster de treinamento com todos os pixels NA\nVerifique: mascara e extent do raster de treinamento\nSkill anterior: species-distribution-modelling",
    conditionMessage(e)
  )
  stop(e)
})

# ── 5. Compute MOP (Mobility-Oriented Parity) ────────────────────────────────
# Reference: Owens et al. 2013. Ecol. Model. 263:10-18.
# DOI: 10.1016/j.ecolmodel.2013.04.011
#
# For each projection pixel, MOP = proportion of calibration points that are
# "closer" (in standardised Euclidean space) than the projection pixel.
# MOP = 0 means the pixel is beyond ALL calibration points — strict extrapolation.

log_step(4, "Compute MOP layer (Owens et al. 2013)")
log_decision("mop_percentile", "10th percentile of pixel-to-calibration distances", "standard implementation following Owens et al. 2013")
tryCatch({
  log_info("Computing MOP layer (this may take a few minutes)...")

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
  log_info("Saved: %s", mop_path)
}, error = function(e) {
  log_error(
    "Falha em MOP computation: %s\nCausa provavel: memoria insuficiente para rasters grandes ou valores NA inesperados\nVerifique: tamanho do raster de projecao e memoria disponivel\nSkill anterior: model-validation-and-uncertainty (calibration extraction)",
    conditionMessage(e)
  )
  stop(e)
})

# ── 6. Compute MESS (Multivariate Environmental Similarity Surfaces) ─────────
# Reference: Elith et al. 2010. Meth. Ecol. Evol. 1:330-342.
# DOI: 10.1111/j.2041-210X.2010.00036.x
#
# MESS < 0 indicates novel environment relative to calibration reference set.

log_step(5, "Compute MESS layer (Elith et al. 2010)")
tryCatch({
  log_info("Computing MESS layer...")

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
  log_info("Saved: %s", mess_path)
}, error = function(e) {
  log_error(
    "Falha em MESS computation: %s\nCausa provavel: incompatibilidade entre pacotes terra/raster ou raster sem CRS\nVerifique: versoes de terra e dismo, e que os rasters tem CRS definido\nSkill anterior: model-validation-and-uncertainty (calibration extraction)",
    conditionMessage(e)
  )
  stop(e)
})

# ── 7. Compute summary statistics ────────────────────────────────────────────
log_step(6, "Compute extrapolation summary statistics")
tryCatch({
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
  log_info("Saved: %s", csv_path)
}, error = function(e) {
  log_error(
    "Falha em summary statistics: %s\nCausa provavel: rasters MOP ou MESS invalidos\nVerifique: etapas anteriores para mensagens de erro\nSkill anterior: model-validation-and-uncertainty (MOP/MESS computation)",
    conditionMessage(e)
  )
  stop(e)
})

# ── 8. Automatic warning if extrapolation is severe ──────────────────────────
if (pct_mop_025 > 30) {
  log_warn(
    "EXTRAPOLATION WARNING: %.1f%% of the projection area has MOP < 0.25 (high novelty relative to calibration). Predictions in these areas should be treated with extreme caution. Recommendation: mask MOP < 0.25 pixels in publication figures and add explicit caveats in the methods section.",
    pct_mop_025
  )
}

if (pct_mop_zero > 10) {
  log_warn(
    "STRICT EXTRAPOLATION WARNING: %.1f%% of the projection area has MOP = 0 (model extrapolates beyond all calibration data). These pixels MUST be masked in publication figures.",
    pct_mop_zero
  )
}

# ── 9. Side-by-side diagnostic plots ─────────────────────────────────────────
log_step(7, "Generate extrapolation diagnostic plots")
tryCatch({
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
  log_info("Saved: %s", file.path(output_dir, "extrapolation_plots.png"))
}, error = function(e) {
  log_error(
    "Falha em diagnostic plots: %s\nCausa provavel: dispositivo grafico nao disponivel ou rasters invalidos\nVerifique: disponibilidade de X11/display e integridade dos rasters\nSkill anterior: model-validation-and-uncertainty (MOP/MESS computation)",
    conditionMessage(e)
  )
  stop(e)
})

# ── 10. Final summary ─────────────────────────────────────────────────────────
log_info("========== EXTRAPOLATION SUMMARY ==========")
log_info("%% area MOP = 0    (strict extrapolation): %.2f%%", pct_mop_zero)
log_info("%% area MOP < 0.25 (high novelty)        : %.2f%%", pct_mop_025)
log_info("%% area MOP < 0.50 (moderate novelty)    : %.2f%%", pct_mop_050)
log_info("%% area MESS < 0   (novel environment)   : %.2f%%", pct_mess_neg)
log_info("===========================================")
