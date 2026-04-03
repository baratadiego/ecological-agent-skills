# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript tune_maxnet.R <points_with_env_csv> <output_dir> [rm_values] [fc_values]

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
#   points_with_env_csv : CSV with columns decimalLongitude, decimalLatitude + env variables
#   output_dir          : Directory to write all outputs (created if absent)
#   rm_values           : Optional comma-separated RM grid (default: "0.5,1,1.5,2,3,4,6")
#   fc_values           : Optional comma-separated FC grid (default: "L,LQ,LQH,LQHP,LQHPT")
#
# Outputs:
#   calibration_results.csv  — all 35 model combinations with metrics
#   best_model_params.csv    — models selected by OR_AICc criterion
#   calibration_plot.png     — delta_AICc × OR10 scatterplot
#   best_maxnet.rds          — fitted maxnet model with best parameters

suppressPackageStartupMessages(library(ENMeval))
suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))

# ── 1. Parse arguments ──────────────────────────────────────────────────────
log_step(1, "Parse command-line arguments")
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  # Defaults for interactive/test use
  occ_csv    <- "tests/data/points_with_env.csv"
  output_dir <- "output/sdm_calibration"
  rm_vals    <- c(0.5, 1, 1.5, 2, 3, 4, 6)
  fc_vals    <- c("L", "LQ", "LQH", "LQHP", "LQHPT")
  log_warn("Fewer than 2 arguments. Using default values for interactive testing.")
} else {
  occ_csv    <- args[1]
  output_dir <- args[2]
  rm_vals    <- if (length(args) >= 3) as.numeric(strsplit(args[3], ",")[[1]]) else c(0.5, 1, 1.5, 2, 3, 4, 6)
  fc_vals    <- if (length(args) >= 4) strsplit(args[4], ",")[[1]] else c("L", "LQ", "LQH", "LQHP", "LQHPT")
}

log_info("Script: tune_maxnet.R | Skill: %s", SKILL_NAME)
log_info("OCC CSV    : %s", occ_csv)
log_info("Output dir : %s", output_dir)

# ── Input precondition check ──────────────────────────────────────────────────
if (!file.exists(occ_csv)) {
  log_error(
    "Input not found: %s\nProbable cause: file not yet generated pelo passo anterior.\nCheck a saida de: ecological-data-foundation (clean_occurrences)\nPrevious skill: ecological-data-foundation",
    occ_csv
  )
  stop("Missing: ", occ_csv)
}

# ── 2. Create output directory ───────────────────────────────────────────────
log_step(2, "Create output directory")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
log_info("Output directory ready: %s", output_dir)

log_decision("rm_vals", paste(rm_vals, collapse = ","), "regularisation multiplier grid for MaxEnt grid search")
log_decision("fc_vals", paste(fc_vals, collapse = ","), "feature class grid for MaxEnt grid search")
log_decision("total_models", length(rm_vals) * length(fc_vals), "total number of RM x FC combinations")

# ── 3. Load occurrence data ──────────────────────────────────────────────────
log_step(3, "Load occurrence data with environmental variables")
tryCatch({
  occ_data <- read.csv(occ_csv)
  log_info("Records loaded: %d | Columns: %d", nrow(occ_data), ncol(occ_data))
}, error = function(e) {
  log_error(
    "Failed to read CSV de ocorrencias '%s': %s\nProbable cause: corrupted file ou invalid format.\nCheck: %s\nPrevious skill: ecological-data-foundation",
    occ_csv, conditionMessage(e), occ_csv
  )
  stop(e)
})

# Identify coordinate columns (standard names)
lon_col <- intersect(c("decimalLongitude", "longitude", "lon", "x"), names(occ_data))[1]
lat_col <- intersect(c("decimalLatitude",  "latitude",  "lat", "y"), names(occ_data))[1]

if (is.na(lon_col) || is.na(lat_col)) {
  log_error(
    "Coordinate columns not found.\nExpected: decimalLongitude/decimalLatitude (or longitude/latitude, lon/lat, x/y).\nColumns present: %s\nProbable cause: CSV not processed by clean_occurrences.\nPrevious skill: ecological-data-foundation",
    paste(names(occ_data), collapse = ", ")
  )
  stop("Cannot find coordinate columns. Expected: decimalLongitude/decimalLatitude")
}

log_info("Longitude column: '%s' | Latitude column: '%s'", lon_col, lat_col)
occ_pts <- occ_data[, c(lon_col, lat_col)]
names(occ_pts) <- c("x", "y")

# Environmental predictor columns = everything except coordinates and species metadata
meta_cols <- c(lon_col, lat_col, "species", "scientificName", "gbifID",
               "occurrenceID", "datasetKey")
env_cols  <- setdiff(names(occ_data), meta_cols)

log_info("Occurrence records: %d", nrow(occ_pts))
log_info("Environmental variables (%d): %s", length(env_cols), paste(env_cols, collapse = ", "))

if (nrow(occ_pts) < 10) {
  log_error(
    "Insufficient occurrence records (%d). Minimum required: 10.\nProbable cause: excessive filtering in clean_occurrences or species with very restricted distribution.\nPrevious skill: ecological-data-foundation",
    nrow(occ_pts)
  )
  stop("Too few occurrences (", nrow(occ_pts), ") for calibration. Minimum required: 10")
}

if (nrow(occ_pts) < 30) {
  log_warn(
    "Few occurrence records (%d). Calibration results may be unstable. Recommended: >= 30.",
    nrow(occ_pts)
  )
}

# ── 4. Build environmental SpatRaster from occurrence columns ────────────────
log_step(4, "Prepare environmental data and background points")

# Background: if CSV has a 'type' column flagging bg points, use them;
# otherwise generate pseudo-background by spatial jitter.
if ("type" %in% names(occ_data)) {
  bg_idx  <- occ_data$type == "background"
  bg_pts  <- occ_data[bg_idx, c(lon_col, lat_col)]
  bg_env  <- occ_data[bg_idx, env_cols]
  occ_env <- occ_data[!bg_idx, env_cols]
  log_info("Column 'type' found. Using %d defined background points.", sum(bg_idx))
  log_decision("background_source", "type column", "column 'type' in CSV defines background points")
} else {
  log_warn("Column 'type' missing. Generating pseudo-background by jitter. Use a real background CSV in production.")
  log_decision("background_source", "jitter", "column 'type' missing; pseudo-background generated by random spatial jitter")
  set.seed(42)
  n_bg   <- min(10000, nrow(occ_data) * 10)
  bg_pts <- data.frame(
    x = occ_pts$x + runif(n_bg, -2, 2),
    y = occ_pts$y + runif(n_bg, -2, 2)
  )
  bg_env  <- occ_data[sample(nrow(occ_data), n_bg, replace = TRUE), env_cols]
  occ_env <- occ_data[, env_cols]
  log_info("Pseudo-background generated: %d points", n_bg)
}

names(bg_pts) <- c("x", "y")

# Try to load a SpatRaster if a raster file is provided as 5th argument,
# otherwise fall back to randkfold partitioning (block requires SpatRaster).
raster_arg  <- if (length(args) >= 5) args[5] else NULL
envs_stack  <- NULL

if (!is.null(raster_arg) && file.exists(raster_arg)) {
  envs_stack <- tryCatch({
    terra::rast(raster_arg)
  }, error = function(e) {
    log_warn("Could not load raster '%s': %s. Falling back to randkfold partitioning.", raster_arg, conditionMessage(e))
    NULL
  })
  if (!is.null(envs_stack)) {
    log_info("SpatRaster loaded from '%s': %d layers.", raster_arg, terra::nlyr(envs_stack))
    log_decision("partitions", "block",
                 "spatial block partitioning — avoids AUC inflation from spatial autocorrelation (Valavi et al. 2019)")
  }
} else {
  log_warn("No SpatRaster provided (pass raster TIF as 5th argument). Using randkfold partitioning.")
  log_decision("partitions", "randkfold",
               "no SpatRaster available; random k-fold CV used — note: may overestimate AUC due to spatial autocorrelation")
}

partition_method <- if (!is.null(envs_stack)) "block" else "randkfold"

# ── 5. Run ENMeval grid search ────────────────────────────────────────────────
log_step(5, "Run ENMeval grid search (MaxNet)")
log_info("RM values   : %s", paste(rm_vals, collapse = ", "))
log_info("FC values   : %s", paste(fc_vals, collapse = ", "))
log_info("Total models: %d", length(rm_vals) * length(fc_vals))
log_info("Partitions  : %s", partition_method)

# ENMevaluate with maxnet — block partitioning when raster available, randkfold otherwise
eval_out <- tryCatch({
  ENMevaluate(
    occs         = occ_pts,
    envs         = envs_stack,          # NULL triggers env extraction from occ columns
    bg           = bg_pts,
    occs.testing = NULL,
    algorithm    = "maxnet",
    partitions   = partition_method,
    tune.args    = list(rm = rm_vals, fc = fc_vals),
    other.settings = list(abs.auc.diff = FALSE)
  )
}, error = function(e) {
  log_error(
    "ENMevaluate failed: %s\nProbable cause: insufficient environmental data, ENMeval not installed, or occurrence points outside predictor extent.\nCheck: install.packages('ENMeval') and input data quality.\nPrevious skill: ecological-data-foundation",
    conditionMessage(e)
  )
  stop(e)
})

log_info("ENMeval calibration completed.")

# ── 6. Extract and process results table ─────────────────────────────────────
log_step(6, "Extract and process calibration results table")
tryCatch({
  res <- eval.results(eval_out)

  # Compute delta_AICc relative to the best (lowest AICc) model
  res$delta.AICc <- res$AICc - min(res$AICc, na.rm = TRUE)

  # Rename for clarity
  res <- res %>%
    rename(
      OR10 = or.10p.avg,
      AUC_train = auc.train,
      AUC_val   = auc.val.avg
    ) %>%
    arrange(delta.AICc)

  # Save full calibration table
  calib_path <- file.path(output_dir, "calibration_results.csv")
  write.csv(res, calib_path, row.names = FALSE)
  log_info("Written: %s", calib_path)
}, error = function(e) {
  log_error(
    "Failed to extract calibration results: %s\nProbable cause: ENMeval object with unexpected structure or renamed columns in the installed package version.\nCheck the installed ENMeval version.\nPrevious skill: species-distribution-modeling",
    conditionMessage(e)
  )
  stop(e)
})

# ── 7. Select best models by OR_AICc criterion ───────────────────────────────
log_step(7, "Select best models by OR_AICc criterion")
# Rule: OR10 <= 0.15 (allows slight tolerance above 0.10 expected)
#       AND delta_AICc < 2 (equivalent models by Burnham & Anderson)
or_threshold   <- 0.15
aicc_threshold <- 2

log_decision("or_threshold",   or_threshold,   "tolerance above 0.10 per Anderson et al. 2010")
log_decision("aicc_threshold", aicc_threshold, "equivalent models per Burnham & Anderson 2002 (delta_AICc < 2)")

best_models <- tryCatch({
  bm <- res %>%
    filter(OR10 <= or_threshold, delta.AICc < aicc_threshold) %>%
    arrange(OR10, delta.AICc)

  if (nrow(bm) == 0) {
    # Fallback: relax OR threshold and take AICc-best model
    log_warn(
      "No model meets OR10 <= %.2f AND delta_AICc < %.1f. Using model with lowest AICc as fallback.",
      or_threshold, aicc_threshold
    )
    log_decision(
      "selection_fallback", "aicc_best",
      "no model in the ideal quadrant; selected best by AICc to proceed"
    )
    bm <- res[1, ]
  } else {
    log_info("%d model(s) meet the OR_AICc criterion.", nrow(bm))
  }
  bm
}, error = function(e) {
  log_error(
    "Failed to select best models: %s\nProbable cause: OR10 or AICc columns missing in results table.\nPrevious skill: species-distribution-modeling",
    conditionMessage(e)
  )
  stop(e)
})

best_path <- file.path(output_dir, "best_model_params.csv")
write.csv(best_models, best_path, row.names = FALSE)
log_info("Written: %s", best_path)
log_info("Best models (first rows):")
message(capture.output(print(best_models[, c("tune.args.rm", "tune.args.fc", "OR10", "AICc", "delta.AICc")])))

# ── 8. Calibration plot ───────────────────────────────────────────────────────
log_step(8, "Generate calibration plot (delta_AICc vs OR10)")
tryCatch({
  p <- ggplot(res, aes(x = delta.AICc, y = OR10,
                        colour = tune.args.fc, size = tune.args.rm)) +
    geom_point(alpha = 0.8) +
    geom_hline(yintercept = or_threshold, linetype = "dashed", colour = "red",
               linewidth = 0.7) +
    geom_vline(xintercept = aicc_threshold, linetype = "dashed", colour = "blue",
               linewidth = 0.7) +
    annotate("text", x = aicc_threshold + 0.5, y = max(res$OR10) * 0.95,
             label = "delta_AICc = 2", colour = "blue", hjust = 0, size = 3) +
    annotate("text", x = max(res$delta.AICc) * 0.7, y = or_threshold + 0.005,
             label = "OR10 = 0.15", colour = "red", size = 3) +
    labs(
      title    = "MaxEnt Calibration: OR10 vs delta_AICc",
      subtitle = "Lower-left quadrant = best models (low omission + parsimonious)",
      x        = "delta AICc (relative to best model)",
      y        = "OR10 (omission rate at 10% training threshold)",
      colour   = "Feature Class",
      size     = "Regularization Multiplier"
    ) +
    theme_bw(base_size = 12)

  plot_path <- file.path(output_dir, "calibration_plot.png")
  ggsave(plot_path, p, width = 10, height = 7, dpi = 150)
  log_info("Written: %s", plot_path)
}, error = function(e) {
  log_error(
    "Failed to generate calibration plot: %s\nProbable cause: ggplot2 not installed or missing columns in results table.\nCheck: install.packages('ggplot2')\nPrevious skill: species-distribution-modeling",
    conditionMessage(e)
  )
  stop(e)
})

# ── 9. Fit final model with best parameters ────────────────────────────────
log_step(9, "Fit final model with best parameters")
best_rm <- best_models$tune.args.rm[1]
best_fc <- best_models$tune.args.fc[1]
log_info("Fitting final model: RM = %s | FC = %s", best_rm, best_fc)
log_decision("final_rm", best_rm, "RM of best-performing model by OR_AICc criterion")
log_decision("final_fc", best_fc, "FC of best-performing model by OR_AICc criterion")

tryCatch({
  # Retrieve the fitted model object from ENMeval results
  best_idx <- which(res$tune.args.rm == best_rm & res$tune.args.fc == best_fc)[1]
  best_model_obj <- eval.models(eval_out)[[best_idx]]

  # Save as RDS for downstream projection
  rds_path <- file.path(output_dir, "best_maxnet.rds")
  saveRDS(best_model_obj, rds_path)
  log_info("Written: %s", rds_path)
}, error = function(e) {
  log_error(
    "Failed to fit or save final model: %s\nProbable cause: model index not found in ENMeval results or serialization error.\nPrevious skill: species-distribution-modeling",
    conditionMessage(e)
  )
  stop(e)
})

# ── 10. Summary ──────────────────────────────────────────────────────────────
log_step(10, "Display calibration summary")
log_info("========== CALIBRATION SUMMARY ==========")
log_info("Models evaluated       : %d", nrow(res))
log_info("Models OR_AICc-ok      : %d", nrow(best_models))
log_info("Selected RM            : %s", best_rm)
log_info("Selected FC            : %s", best_fc)
log_info("Best OR10              : %.3f", best_models$OR10[1])
log_info("Best AUC (validation)  : %.3f", best_models$AUC_val[1])
log_info("Best delta_AICc        : %.3f", best_models$delta.AICc[1])
log_info("=========================================")
