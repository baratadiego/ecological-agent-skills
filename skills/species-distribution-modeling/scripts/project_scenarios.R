# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript project_scenarios.R <model_rds> <scenarios_dir> <output_dir> [threshold_from_csv]
# Project a fitted SDM across multiple future climate scenario stacks.
# scenarios_dir must contain .tif files named: <ssp>_<year>.tif (e.g. ssp245_2050.tif)

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "species-distribution-modeling"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages({
  library(terra)
})

# ── Arguments ─────────────────────────────────────────────────────────────────
args              <- commandArgs(trailingOnly = TRUE)
model_rds         <- if (length(args) >= 1) args[1] else stop("model_rds required")
scenarios_dir     <- if (length(args) >= 2) args[2] else stop("scenarios_dir required")
output_dir        <- if (length(args) >= 3) args[3] else "outputs/projections"
threshold_from_csv<- if (length(args) >= 4) args[4] else NULL  # path to prediction_summary.csv

log_decision("scenarios_dir",      scenarios_dir, "Directory containing SSP scenario stacks")
log_decision("threshold_from_csv", ifelse(is.null(threshold_from_csv), "NULL", threshold_from_csv),
             "If provided, reuse threshold from predict_distribution.R output")

# ── Precondition checks ───────────────────────────────────────────────────────
if (!file.exists(model_rds)) {
  log_error("Model RDS not found: %s\nProbable cause: run_ensemble_sdm.R did not complete.\nCheck: the output of skills/species-distribution-modeling.\nPrevious skill: species-distribution-modeling", model_rds)
  stop("Missing model: ", model_rds)
}
if (!dir.exists(scenarios_dir)) {
  log_error("Scenarios dir not found: %s\nProbable cause: prepare_future_layers.R was not executed.\nCheck: CMIP6 stacks foram baixados e preparados.\nPrevious skill: geoprocessing-for-ecology", scenarios_dir)
  stop("Missing scenarios dir: ", scenarios_dir)
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Step 1: Load model ────────────────────────────────────────────────────────
log_step(1, "Loading model")
model_obj <- tryCatch(readRDS(model_rds), error = function(e) {
  log_error("Failed to read model RDS: %s\nProbable cause: corrupted file.\nCheck: Rscript generated the model with saveRDS().", conditionMessage(e))
  stop(e)
})
is_ensemble <- is.list(model_obj) && !inherits(model_obj, "MaxEnt")
log_info("Model class: %s | ensemble: %s", class(model_obj)[1], is_ensemble)

# ── Step 2: Get threshold ─────────────────────────────────────────────────────
log_step(2, "Resolving binary threshold")
threshold_val <- NA_real_
if (!is.null(threshold_from_csv) && file.exists(threshold_from_csv)) {
  sum_df        <- read.csv(threshold_from_csv, stringsAsFactors = FALSE)
  threshold_val <- sum_df$threshold_value[1]
  log_info("Threshold loaded from CSV: %.4f", threshold_val)
} else if (!is.null(model_obj$threshold_values)) {
  threshold_val <- model_obj$threshold_values["MaxTSS"]
  log_info("Threshold from model (MaxTSS): %.4f", threshold_val)
} else {
  log_warn("No threshold source available; binary maps will use P10 of each scenario map")
}

# ── Helper: predict from one stack ────────────────────────────────────────────
predict_stack <- function(mod, preds) {
  cls <- class(mod)[1]
  if (cls == "maxnet") {
    suppressPackageStartupMessages(library(maxnet))
    pred_df <- as.data.frame(preds, na.rm = FALSE)
    p       <- predict(mod, pred_df, type = "cloglog")
    r       <- preds[[1]]; values(r) <- p; return(r)
  } else if (cls %in% c("gbm", "BRT")) {
    suppressPackageStartupMessages(library(gbm))
    pred_df <- as.data.frame(preds, na.rm = FALSE)
    p       <- predict.gbm(mod, pred_df, n.trees = mod$n.trees, type = "response")
    r       <- preds[[1]]; values(r) <- p; return(r)
  } else if (cls == "randomForest") {
    suppressPackageStartupMessages(library(randomForest))
    pred_df <- as.data.frame(preds, na.rm = FALSE)
    p       <- predict(mod, pred_df, type = "prob")[, 2]
    r       <- preds[[1]]; values(r) <- p; return(r)
  } else {
    return(predict(mod, preds))
  }
}

# ── Step 3: Find scenario stacks ──────────────────────────────────────────────
log_step(3, "Scanning scenario stacks")
tif_files <- list.files(scenarios_dir, pattern = "\\.tif$", full.names = TRUE)
if (length(tif_files) == 0) {
  log_error("No .tif files found in: %s\nProbable cause: prepare_future_layers.R did not generate the stacks.\nCheck: .tif files exist in scenarios_dir.", scenarios_dir)
  stop("No .tif files in scenarios_dir")
}
log_info("Found %d scenario stack(s)", length(tif_files))

# Parse scenario labels from filenames (e.g. ssp245_2050.tif → ssp245_2050)
scenario_labels <- tools::file_path_sans_ext(basename(tif_files))
log_decision("scenario_labels", paste(scenario_labels, collapse=", "),
             "Derived from .tif filenames in scenarios_dir")

# ── Step 4: Project each scenario ────────────────────────────────────────────
log_step(4, "Projecting across all scenarios")

results <- vector("list", length(tif_files))
current_suit <- NULL   # will be set from first file for change map

for (i in seq_along(tif_files)) {
  lbl  <- scenario_labels[i]
  tif  <- tif_files[i]
  log_info("Projecting scenario %d/%d: %s", i, length(tif_files), lbl)

  preds <- tryCatch(rast(tif), error = function(e) {
    log_error("Failed to read stack %s: %s\nProbable cause: corrupted file ou incorrect path.", lbl, conditionMessage(e))
    return(NULL)
  })
  if (is.null(preds)) { results[[i]] <- NULL; next }

  suit <- tryCatch({
    if (is_ensemble) {
      preds_list <- lapply(model_obj$models, predict_stack, preds = preds)
      suit_stack <- rast(preds_list)
      w <- if (!is.null(model_obj$auc_weights)) model_obj$auc_weights else
           rep(1 / nlyr(suit_stack), nlyr(suit_stack))
      app(suit_stack, function(x) weighted.mean(x, w, na.rm = TRUE))
    } else {
      predict_stack(model_obj, preds)
    }
  }, error = function(e) {
    log_error("Failed projecting scenario %s: %s\nCheck: stack has the same predictors as the model.", lbl, conditionMessage(e))
    NULL
  })
  if (is.null(suit)) { results[[i]] <- NULL; next }

  # Save suitability raster
  suit_file <- file.path(output_dir, paste0("suitability_", lbl, ".tif"))
  writeRaster(suit, suit_file, overwrite = TRUE)

  # Binary map
  thr_use <- if (!is.na(threshold_val)) threshold_val else
             quantile(values(suit), 0.10, na.rm = TRUE)
  binary  <- suit >= thr_use
  bin_file <- file.path(output_dir, paste0("binary_", lbl, ".tif"))
  writeRaster(binary, bin_file, overwrite = TRUE, datatype = "INT1U")

  # Area stats
  suitable_cells <- sum(values(binary) == 1, na.rm = TRUE)
  total_cells    <- sum(!is.na(values(suit)))
  cell_area_km2  <- prod(res(suit)) / 1e6

  results[[i]] <- data.frame(
    scenario          = lbl,
    threshold_used    = round(thr_use, 4),
    suitable_area_km2 = round(suitable_cells * cell_area_km2, 1),
    total_area_km2    = round(total_cells    * cell_area_km2, 1),
    pct_suitable      = round(100 * suitable_cells / total_cells, 2),
    mean_suitability  = round(mean(values(suit), na.rm = TRUE), 4),
    stringsAsFactors  = FALSE
  )

  # Keep first scenario as "current" reference for change map
  if (i == 1) current_suit <- suit

  log_info("  %s: suitable = %.1f km2 (%.1f%%)",
           lbl, results[[i]]$suitable_area_km2, results[[i]]$pct_suitable)
}

# ── Step 5: Scenario comparison CSV ───────────────────────────────────────────
log_step(5, "Writing scenario comparison table")
valid_results  <- Filter(Negate(is.null), results)
comparison_df  <- do.call(rbind, valid_results)
comp_file      <- file.path(output_dir, "scenario_comparison.csv")
write.csv(comparison_df, comp_file, row.names = FALSE)
log_info("Scenario comparison saved: %s", comp_file)

# ── Step 6: Change map (vs. first scenario) ────────────────────────────────────
log_step(6, "Computing change map relative to first scenario")
if (!is.null(current_suit) && length(tif_files) > 1) {
  tryCatch({
    # Load and stack all suitability rasters
    suit_files  <- file.path(output_dir, paste0("suitability_", scenario_labels, ".tif"))
    suit_files  <- suit_files[file.exists(suit_files)]
    if (length(suit_files) >= 2) {
      all_suits   <- rast(suit_files)
      mean_future <- app(all_suits[[-1]], mean, na.rm = TRUE)
      change_map  <- (mean_future - current_suit) / (current_suit + 1e-6)
      change_file <- file.path(output_dir, "scenario_change_map.tif")
      writeRaster(change_map, change_file, overwrite = TRUE)
      log_info("Change map saved (relative to first scenario): %s", change_file)
    }
  }, error = function(e) {
    log_warn("Change map computation failed: %s. Skipping.", conditionMessage(e))
  })
}

# ── Step 7: Summary plot ───────────────────────────────────────────────────────
log_step(7, "Generating scenario summary plot")
tryCatch({
  suppressPackageStartupMessages(library(ggplot2))
  p <- ggplot(comparison_df, aes(x = scenario, y = suitable_area_km2,
                                  fill = pct_suitable)) +
    geom_col() +
    geom_text(aes(label = paste0(pct_suitable, "%")), vjust = -0.3, size = 3) +
    scale_fill_gradient(low = "#d4e6f1", high = "#1a5276",
                        name = "% Suitable") +
    labs(title = "Suitable Area by Scenario",
         x = "Scenario", y = "Suitable Area (km²)") +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  plot_file <- file.path(output_dir, "scenario_summary_plot.png")
  ggsave(plot_file, p, width = max(6, length(tif_files) * 1.5), height = 5, dpi = 150)
  log_info("Summary plot saved: %s", plot_file)
}, error = function(e) {
  log_warn("ggplot2 summary plot failed: %s. Skipping.", conditionMessage(e))
})

log_step(8, "Done — all scenario projections in: %s", output_dir)
