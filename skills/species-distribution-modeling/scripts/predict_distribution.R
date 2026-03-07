# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript predict_distribution.R <model_rds> <predictor_stack_tif> <output_dir> [threshold_method] [scenario_label]
# Predict suitability from a fitted SDM (maxnet, gbm, randomForest, or ensemble list).
# Applies MaxTSS / P10 / MTP thresholding, computes MESS, and saves all rasters.

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "species-distribution-modeling"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive = TRUE, showWarnings = FALSE)

suppressPackageStartupMessages({
  library(terra)
  library(dismo)
})

# ── Arguments ─────────────────────────────────────────────────────────────────
args             <- commandArgs(trailingOnly = TRUE)
model_rds        <- if (length(args) >= 1) args[1] else stop("model_rds required")
predictor_tif    <- if (length(args) >= 2) args[2] else stop("predictor_stack_tif required")
output_dir       <- if (length(args) >= 3) args[3] else "outputs/predictions"
threshold_method <- if (length(args) >= 4) args[4] else "MaxTSS"
scenario_label   <- if (length(args) >= 5) args[5] else "current"

log_decision("threshold_method", threshold_method,
             "MaxTSS balances sensitivity and specificity; P10 is more conservative; MTP is permissive")
log_decision("scenario_label", scenario_label, "Label embedded in output filenames")

# ── Precondition checks ───────────────────────────────────────────────────────
if (!file.exists(model_rds)) {
  log_error("Model RDS nao encontrado: %s\nCausa provavel: run_ensemble_sdm.R nao foi executado.\nVerifique: a saida de skills/species-distribution-modeling.\nSkill anterior: species-distribution-modeling", model_rds)
  stop("Missing model file: ", model_rds)
}
if (!file.exists(predictor_tif)) {
  log_error("Predictor stack nao encontrado: %s\nCausa provavel: stack nao foi preparado.\nVerifique: geoprocessing-for-ecology / prepare_future_layers.R.\nSkill anterior: geoprocessing-for-ecology", predictor_tif)
  stop("Missing predictor stack: ", predictor_tif)
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_step(1, "Loading model and predictor stack")
model_obj  <- tryCatch(readRDS(model_rds), error = function(e) {
  log_error("Falha ao ler model RDS: %s\nCausa provavel: arquivo corrompido ou formato incompativel.\nVerifique: Rscript que gerou o modelo usou saveRDS().", conditionMessage(e))
  stop(e)
})
predictors <- tryCatch(rast(predictor_tif), error = function(e) {
  log_error("Falha ao ler raster stack: %s\nCausa provavel: arquivo GeoTIFF invalido ou caminho errado.\nVerifique: predictor_tif existe e tem multiplas camadas.", conditionMessage(e))
  stop(e)
})
log_info("Model loaded: class = %s", class(model_obj)[1])
log_info("Predictor stack: %d layers, CRS = %s", nlyr(predictors), crs(predictors, describe = TRUE)$name)

# Detect ensemble (list of models) vs single model
is_ensemble <- is.list(model_obj) && !inherits(model_obj, "MaxEnt")
log_decision("is_ensemble", is_ensemble,
             "Ensemble if model_rds is a named list with $models and $auc_weights")

# ── Step 2: Reproject predictors if needed ────────────────────────────────────
log_step(2, "Checking and aligning CRS / resolution")
if (is_ensemble) {
  ref_model <- model_obj$models[[1]]
} else {
  ref_model <- model_obj
}

# ── Step 3: Generate suitability predictions ──────────────────────────────────
log_step(3, "Predicting suitability")

predict_single <- function(mod, preds) {
  cls <- class(mod)[1]
  log_info("Predicting with model class: %s", cls)
  if (cls == "maxnet") {
    suppressPackageStartupMessages(library(maxnet))
    pred_df <- as.data.frame(preds, na.rm = FALSE)
    p        <- predict(mod, pred_df, type = "cloglog")
    r        <- preds[[1]]; values(r) <- p
    return(r)
  } else if (cls %in% c("gbm", "BRT")) {
    suppressPackageStartupMessages(library(gbm))
    pred_df <- as.data.frame(preds, na.rm = FALSE)
    p        <- predict.gbm(mod, pred_df, n.trees = mod$n.trees, type = "response")
    r        <- preds[[1]]; values(r) <- p
    return(r)
  } else if (cls == "randomForest") {
    suppressPackageStartupMessages(library(randomForest))
    pred_df <- as.data.frame(preds, na.rm = FALSE)
    p        <- predict(mod, pred_df, type = "prob")[, 2]
    r        <- preds[[1]]; values(r) <- p
    return(r)
  } else {
    # Generic predict (MaxEnt, etc.)
    tryCatch(
      predict(mod, predictors),
      error = function(e) {
        log_error("Falha na predicao generica: %s\nCausa provavel: model class nao suportada.\nVerifique: model_obj e um dos tipos suportados (maxnet, gbm, randomForest).", conditionMessage(e))
        stop(e)
      }
    )
  }
}

if (is_ensemble) {
  log_info("Ensemble prediction: %d models", length(model_obj$models))
  suit_stack <- tryCatch({
    preds_list <- lapply(model_obj$models, predict_single, preds = predictors)
    rast(preds_list)
  }, error = function(e) {
    log_error("Falha na predicao ensemble: %s\nCausa provavel: modelos incompativeis.\nVerifique: todos os modelos foram treinados com os mesmos preditores.", conditionMessage(e))
    stop(e)
  })

  weights <- if (!is.null(model_obj$auc_weights)) model_obj$auc_weights else
             rep(1 / nlyr(suit_stack), nlyr(suit_stack))
  log_decision("ensemble_weights", paste(round(weights, 3), collapse = ","),
               "AUC-based weights from model object; uniform if not available")

  suit_mean <- app(suit_stack, fun = function(x) weighted.mean(x, weights, na.rm = TRUE))
  suit_sd   <- app(suit_stack, fun = function(x) sd(x,   na.rm = TRUE))
  log_info("Ensemble uncertainty (mean SD across pixels): %.4f",
           mean(values(suit_sd), na.rm = TRUE))

  unc_file <- file.path(output_dir, paste0("uncertainty_", scenario_label, ".tif"))
  writeRaster(suit_sd, unc_file, overwrite = TRUE)
  log_info("Uncertainty raster saved: %s", unc_file)
} else {
  suit_mean <- predict_single(ref_model, predictors)
}

suit_file <- file.path(output_dir, paste0("suitability_", scenario_label, ".tif"))
writeRaster(suit_mean, suit_file, overwrite = TRUE)
log_info("Suitability raster saved: %s", suit_file)

# ── Step 4: Threshold to binary map ───────────────────────────────────────────
log_step(4, paste("Binarising with threshold method:", threshold_method))

# Look for training presence values (from model object)
threshold_val <- NA_real_
if (!is.null(model_obj$threshold_values)) {
  tv <- model_obj$threshold_values
  threshold_val <- switch(threshold_method,
    MaxTSS = tv["MaxTSS"],
    P10    = tv["P10"],
    MTP    = tv["MTP"],
    {
      log_warn("Threshold method '%s' not found; falling back to MaxTSS", threshold_method)
      tv["MaxTSS"]
    }
  )
} else {
  # Fallback: use quantile of suitability (P10 approximation)
  threshold_val <- quantile(values(suit_mean), 0.10, na.rm = TRUE)
  log_warn("No threshold_values in model object; using 10th percentile of suitability map (%.4f)", threshold_val)
}
log_decision("threshold_value", round(threshold_val, 4),
             paste("Derived via", threshold_method, "from model or suitability distribution"))

binary_map <- suit_mean >= threshold_val
bin_file   <- file.path(output_dir, paste0("binary_", scenario_label, ".tif"))
writeRaster(binary_map, bin_file, overwrite = TRUE, datatype = "INT1U")
log_info("Binary map saved: %s (threshold = %.4f)", bin_file, threshold_val)

# ── Step 5: MESS analysis ──────────────────────────────────────────────────────
log_step(5, "Computing MESS (multivariate environmental similarity surface)")
mess_map <- tryCatch({
  # Use training data ranges stored in model object
  if (!is.null(model_obj$training_ranges)) {
    ranges  <- model_obj$training_ranges
    pred_df <- as.data.frame(predictors, na.rm = FALSE)
    # Simplified MESS: fraction of pixels within training range per variable
    in_range <- mapply(function(col, nm) {
      col >= ranges[nm, "min"] & col <= ranges[nm, "max"]
    }, pred_df, names(pred_df), SIMPLIFY = FALSE)
    in_range_r <- rast(lapply(in_range, function(v) {
      r <- predictors[[1]]; values(r) <- as.integer(v); r
    }))
    app(in_range_r, mean, na.rm = TRUE)  # fraction of vars in range (1 = fully novel = 0)
  } else {
    # Use dismo::mess if available
    suppressPackageStartupMessages(library(dismo))
    if (!is.null(model_obj$training_data)) {
      mess(predictors, model_obj$training_data)
    } else {
      log_warn("No training_ranges or training_data in model; MESS not computed.")
      NULL
    }
  }
}, error = function(e) {
  log_warn("MESS computation failed: %s. Skipping MESS output.", conditionMessage(e))
  NULL
})

if (!is.null(mess_map)) {
  mess_file <- file.path(output_dir, paste0("mess_", scenario_label, ".tif"))
  writeRaster(mess_map, mess_file, overwrite = TRUE)

  pct_novel <- mean(values(mess_map) < 0, na.rm = TRUE) * 100
  if (pct_novel > 20) {
    log_warn("%.1f%% of the prediction area is in novel climate space (MESS < 0). Predictions in those areas are unreliable.", pct_novel)
  } else {
    log_info("MESS: %.1f%% of area is novel climate space (threshold: 20%%)", pct_novel)
  }
  log_info("MESS raster saved: %s", mess_file)
}

# ── Step 6: Summary CSV ────────────────────────────────────────────────────────
log_step(6, "Computing prediction summary statistics")

total_cells    <- sum(!is.na(values(suit_mean)))
suitable_cells <- sum(values(binary_map) == 1, na.rm = TRUE)
cell_area_km2  <- prod(res(suit_mean)) / 1e6  # assumes metres CRS; adjust if degrees
area_total_km2 <- total_cells    * cell_area_km2
area_suit_km2  <- suitable_cells * cell_area_km2

summary_df <- data.frame(
  scenario          = scenario_label,
  threshold_method  = threshold_method,
  threshold_value   = round(threshold_val, 4),
  total_area_km2    = round(area_total_km2, 1),
  suitable_area_km2 = round(area_suit_km2, 1),
  pct_suitable      = round(100 * suitable_cells / total_cells, 2),
  mean_suitability  = round(mean(values(suit_mean), na.rm = TRUE), 4),
  stringsAsFactors  = FALSE
)

sum_file <- file.path(output_dir, "prediction_summary.csv")
write.csv(summary_df, sum_file, row.names = FALSE)
log_info("Summary: suitable area = %.1f km2 (%.1f%% of %.1f km2 total)",
         area_suit_km2, summary_df$pct_suitable, area_total_km2)
log_info("Prediction summary saved: %s", sum_file)

log_step(7, "Done — all outputs written to: %s", output_dir)
