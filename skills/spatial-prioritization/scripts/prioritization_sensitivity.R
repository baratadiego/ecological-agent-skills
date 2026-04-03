# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript prioritization_sensitivity.R <pu_raster> <features_dir>
#        <output_dir> [targets] [locked_in_raster] [locked_out_raster]
#
# Sensitivity analysis for conservation prioritization:
#   1. BLM calibration (cost vs compactness tradeoff)
#   2. Target sensitivity (50%, 75%, 100%, 125%, 150% of baseline targets)
#   3. Cost scenario sensitivity (-30%, baseline, +30%)
#   4. Portfolio irreplaceability (selection frequency across scenarios)
#
# Outputs:
#   blm_calibration.csv            — Cost and boundary at each BLM value
#   blm_calibration_plot.png       — Elbow plot for BLM selection
#   target_sensitivity.csv         — Targets met and cost at each target scaling
#   cost_scenario_sensitivity.csv  — Cost and PU selection under cost uncertainty
#   portfolio_frequency.tif        — Selection frequency raster across all scenarios

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "spatial-prioritization"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages(library(prioritizr))
suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  cat("Usage: Rscript prioritization_sensitivity.R <pu_raster> <features_dir>",
      "<output_dir> [targets] [locked_in] [locked_out]\n")
  quit(status = 1)
}

pu_path      <- args[1]
features_dir <- args[2]
output_dir   <- args[3]
targets_arg  <- if (length(args) >= 4 && args[4] != "NA") args[4] else "0.30"
locked_in_p  <- if (length(args) >= 5 && args[5] != "NA") args[5] else NULL
locked_out_p <- if (length(args) >= 6 && args[6] != "NA") args[6] else NULL

# ── Input precondition checks ─────────────────────────────────────────────────
if (!file.exists(pu_path)) {
  log_error("Input not found: %s\nProbable cause: previous step did not complete.\nCheck: outputs of the previous skill.\nPrevious skill: spatial-prioritization (run_prioritization)", pu_path)
  stop("Missing input: ", pu_path)
}
if (!dir.exists(features_dir)) {
  log_error("Features directory not found: %s\nProbable cause: previous step did not complete or incorrect path.\nCheck: outputs of the previous skill.\nPrevious skill: spatial-prioritization (run_prioritization)", features_dir)
  stop("Missing features directory: ", features_dir)
}

log_decision("targets_arg", targets_arg, "Baseline targets: single proportion applied to all features, or path to CSV with per-feature targets")
log_decision("locked_in_p", ifelse(is.null(locked_in_p), "none", locked_in_p), "Locked-in raster constrains solver to always select these PUs")
log_decision("locked_out_p", ifelse(is.null(locked_out_p), "none", locked_out_p), "Locked-out raster constrains solver to never select these PUs")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Load data ─────────────────────────────────────────────────────────────────
log_step(1, "Load planning unit raster and feature layers")
tryCatch({
  pu       <- rast(pu_path)
  feat_files <- list.files(features_dir, pattern = "\\.tif$",
                            full.names = TRUE, ignore.case = TRUE)
  if (length(feat_files) == 0) {
    log_error("No .tif files found in: %s\nProbable cause: incorrect features_dir or features not generated.\nCheck: contents of features directory.\nPrevious skill: spatial-prioritization (run_prioritization)", features_dir)
    stop("No .tif feature files found in: ", features_dir)
  }
  features   <- rast(feat_files)
  features   <- resample(features, pu, method = "bilinear")
  names(features) <- tools::file_path_sans_ext(basename(feat_files))

  # Remove zero-sum features
  feat_sums <- global(features, "sum", na.rm = TRUE)[[1]]
  zero_feats <- names(features)[feat_sums == 0]
  if (length(zero_feats) > 0) {
    log_warn("%d features with zero sum excluded: %s", length(zero_feats), paste(zero_feats, collapse = ", "))
  }
  features  <- features[[feat_sums > 0]]
  n_feats   <- nlyr(features)
  log_info("Planning unit raster loaded: %d x %d cells.", nrow(pu), ncol(pu))
  log_info("Feature layers loaded: %d (after removing zero-sum).", n_feats)

  if (n_feats < 1) {
    log_error("No valid features after zero-sum removal.\nProbable cause: all features have zero distribution in study area.\nCheck: spatial extent of feature rasters.\nPrevious skill: spatial-prioritization (run_prioritization)")
    stop("No valid feature layers remaining after zero-sum removal.")
  }
}, error = function(e) {
  log_error("Failed in load_data: %s\nProbable cause: corrupted or incompatible rasters, or incorrect path.\nCheck: .tif files and spatial resolution compatibility.\nPrevious skill: spatial-prioritization (run_prioritization)", conditionMessage(e))
  stop(e)
})

# Baseline targets
log_step(2, "Set baseline targets")
tryCatch({
  if (file.exists(targets_arg)) {
    target_df   <- read.csv(targets_arg)
    targets_base <- target_df$target[match(names(features), target_df$feature_name)]
    n_unmatched <- sum(is.na(targets_base))
    targets_base[is.na(targets_base)] <- 0.30
    if (n_unmatched > 0) {
      log_warn("%d features sem alvo no CSV; usando padrao 0.30.", n_unmatched)
    }
    log_decision("targets_base", "from_csv", paste0("Per-feature targets loaded from ", targets_arg))
  } else {
    targets_base <- rep(as.numeric(targets_arg), n_feats)
    log_decision("targets_base", targets_arg, "Single proportion applied uniformly to all features")
  }
  log_info("Baseline targets: min=%.2f, mean=%.2f, max=%.2f",
           min(targets_base), mean(targets_base), max(targets_base))
}, error = function(e) {
  log_error("Failed in set_targets: %s\nProbable cause: malformed targets CSV or invalid proportion.\nCheck: targets file format and feature names.\nPrevious skill: spatial-prioritization (run_prioritization)", conditionMessage(e))
  stop(e)
})

# Helper: build and solve base problem with given cost and targets
solve_scenario <- function(cost_r, targets_v, blm_val = 0, name = "scenario") {
  p <- problem(cost_r, features) %>%
    add_min_set_objective() %>%
    add_relative_targets(pmin(targets_v, 0.999)) %>%
    add_binary_decisions() %>%
    add_highs_solver(gap = 0.05, time_limit = 300, verbose = FALSE)

  if (!is.null(locked_in_p)) {
    li <- resample(rast(locked_in_p), cost_r, method = "near")
    p  <- p %>% add_locked_in_constraints(li)
  }
  if (!is.null(locked_out_p)) {
    lo <- resample(rast(locked_out_p), cost_r, method = "near")
    p  <- p %>% add_locked_out_constraints(lo)
  }
  if (blm_val > 0) {
    p <- p %>% add_boundary_penalties(penalty = blm_val, data = NULL)
  }

  s <- tryCatch(solve(p), error = function(e) {
    log_warn("Solver failed for scenario '%s': %s. Returning NULL.", name, conditionMessage(e))
    return(NULL)
  })
  if (is.null(s)) return(NULL)

  rep_s   <- eval_feature_representation_summary(p, s)
  cost_s  <- eval_cost_summary(p, s)$cost
  bound_s <- tryCatch(eval_boundary_summary(p, s)$boundary,
                       error = function(e) NA_real_)

  list(
    solution       = s,
    n_selected     = sum(values(s) == 1, na.rm = TRUE),
    total_cost     = cost_s,
    boundary       = bound_s,
    targets_met    = sum(rep_s$relative_held >= targets_v, na.rm = TRUE),
    mean_held      = mean(rep_s$relative_held, na.rm = TRUE)
  )
}

# ── 1. BLM Calibration ────────────────────────────────────────────────────────
log_step(3, "BLM calibration: cost vs compactness tradeoff")
log_info("Running BLM calibration...")
blm_values <- c(0, 0.001, 0.01, 0.05, 0.1, 0.5, 1.0)
log_decision("blm_values", paste(blm_values, collapse = ", "),
             "Standard BLM range spanning several orders of magnitude to identify elbow in cost-boundary tradeoff")

blm_solutions <- list()  # cache solutions for portfolio reuse
tryCatch({
  blm_results <- lapply(blm_values, function(blm) {
    log_info("  BLM = %g", blm)
    res <- solve_scenario(pu, targets_base, blm_val = blm,
                          name = paste0("blm_", blm))
    if (is.null(res)) {
      log_warn("BLM=%g scenario produced no solution.", blm)
      return(NULL)
    }
    blm_solutions[[paste0("blm_", blm)]] <<- res$solution
    data.frame(blm = blm, cost = res$total_cost,
               boundary = res$boundary, n_selected = res$n_selected)
  })
  blm_df <- dplyr::bind_rows(Filter(Negate(is.null), blm_results))
  write.csv(blm_df, file.path(output_dir, "blm_calibration.csv"), row.names = FALSE)
  log_info("BLM calibration done. %d / %d scenarios solved successfully.", nrow(blm_df), length(blm_values))

  if (nrow(blm_df) < 3) {
    log_warn("Fewer than 3 BLM scenarios solved. Elbow plot may be insufficient for BLM selection.")
  }
}, error = function(e) {
  log_error("Failed in blm_calibration: %s\nProbable cause: HiGHS solver failure or invalid raster data.\nCheck: HiGHS installation and raster integrity.\nPrevious skill: spatial-prioritization (run_prioritization)", conditionMessage(e))
  stop(e)
})

# BLM elbow plot
log_step(4, "Generate BLM elbow plot")
if (nrow(blm_df) > 2) {
  tryCatch({
    p_blm <- ggplot(blm_df, aes(x = boundary, y = cost, label = blm)) +
      geom_path(colour = "steelblue") +
      geom_point(size = 3, colour = "steelblue") +
      ggrepel::geom_text_repel(size = 3) +
      labs(x = "Total boundary length", y = "Total cost",
           title = "BLM calibration: cost vs compactness tradeoff") +
      theme_minimal(base_size = 10)
    tryCatch(
      ggsave(file.path(output_dir, "blm_calibration_plot.png"), p_blm,
             width = 7, height = 5, dpi = 150),
      error = function(e) log_warn("BLM plot failed to save: %s", conditionMessage(e))
    )
    log_info("BLM calibration plot saved.")
  }, error = function(e) {
    log_warn("Failed to generate plot BLM: %s. Continuando sem o grafico.", conditionMessage(e))
  })
} else {
  log_warn("Insufficient data for BLM plot (fewer than 3 points). Plot not generated.")
}

# ── 2. Target Sensitivity ─────────────────────────────────────────────────────
log_step(5, "Target sensitivity analysis")
log_info("Running target sensitivity analysis...")
target_scalings <- c(0.50, 0.75, 1.00, 1.25, 1.50)
log_decision("target_scalings", paste(target_scalings, collapse = ", "),
             "Scaling factors applied to baseline targets to assess sensitivity of solution cost and coverage")

target_solutions <- list()  # cache solutions for portfolio reuse
tryCatch({
  target_results <- lapply(target_scalings, function(sc) {
    log_info("  Target scaling = %.2fx", sc)
    tgts <- pmin(targets_base * sc, 0.999)
    res  <- solve_scenario(pu, tgts, name = paste0("target_", sc))
    if (is.null(res)) {
      log_warn("Target %.2fx scenario produced no solution.", sc)
      return(NULL)
    }
    target_solutions[[paste0("target_", sc)]] <<- res$solution
    data.frame(target_scaling = sc,
               mean_target    = mean(tgts),
               cost           = res$total_cost,
               targets_met    = res$targets_met,
               n_selected     = res$n_selected)
  })
  target_df <- dplyr::bind_rows(Filter(Negate(is.null), target_results))
  write.csv(target_df, file.path(output_dir, "target_sensitivity.csv"),
            row.names = FALSE)
  log_info("Target sensitivity done. %d / %d scenarios solved.", nrow(target_df), length(target_scalings))
}, error = function(e) {
  log_error("Failed in target_sensitivity: %s\nProbable cause: solver failure or targets outside range [0, 0.999].\nCheck: targets_base values and HiGHS installation.\nPrevious skill: spatial-prioritization (run_prioritization)", conditionMessage(e))
  stop(e)
})

# ── 3. Cost Scenario Sensitivity ──────────────────────────────────────────────
log_step(6, "Cost scenario sensitivity analysis")
log_info("Running cost scenario sensitivity analysis...")
log_decision("cost_scenarios", "low=-30%, baseline, high=+30%",
             "Standard cost uncertainty range to assess robustness of prioritization to cost data errors")

tryCatch({
  cost_scenarios <- list(
    low      = pu * 0.70,
    baseline = pu,
    high     = pu * 1.30
  )

  cost_results <- lapply(names(cost_scenarios), function(name) {
    log_info("  Cost scenario: %s", name)
    res <- solve_scenario(cost_scenarios[[name]], targets_base, name = name)
    if (is.null(res)) {
      log_warn("Cost '%s' scenario produced no solution.", name)
      return(NULL)
    }
    data.frame(cost_scenario = name,
               total_cost    = res$total_cost,
               n_selected    = res$n_selected,
               targets_met   = res$targets_met)
  })
  cost_df <- dplyr::bind_rows(Filter(Negate(is.null), cost_results))
  write.csv(cost_df, file.path(output_dir, "cost_scenario_sensitivity.csv"),
            row.names = FALSE)
  log_info("Cost scenario sensitivity done. %d / %d scenarios solved.", nrow(cost_df), length(cost_scenarios))
}, error = function(e) {
  log_error("Failed in cost_scenario_sensitivity: %s\nProbable cause: solver failure or invalid cost raster.\nCheck: pu raster values and HiGHS installation.\nPrevious skill: spatial-prioritization (run_prioritization)", conditionMessage(e))
  stop(e)
})

# ── 4. Portfolio Irreplaceability ─────────────────────────────────────────────
log_step(7, "Build portfolio irreplaceability (selection frequency across all scenarios)")
log_info("Building portfolio irreplaceability (selection frequency across scenarios)...")

tryCatch({
  # Reuse cached solutions from BLM and target analyses (avoid re-solving ILPs)
  all_solutions <- c(blm_solutions, target_solutions)

  if (length(all_solutions) < 2) {
    log_warn("Insufficient solutions for portfolio analysis (%d). At least 2 are required.", length(all_solutions))
  } else {
    freq_raster <- Reduce("+", all_solutions) / length(all_solutions)
    names(freq_raster) <- "selection_frequency"
    writeRaster(freq_raster, file.path(output_dir, "portfolio_frequency.tif"),
                overwrite = TRUE)
    log_info("Portfolio frequency raster saved (%d scenarios).", length(all_solutions))
  }
}, error = function(e) {
  log_error("Failed in portfolio_irreplaceability: %s\nProbable cause: incompatible solutions (different extents) or raster sum failure.\nCheck: spatial consistency of individual solutions.\nPrevious skill: spatial-prioritization (run_prioritization)", conditionMessage(e))
  stop(e)
})

# ── Summary report ────────────────────────────────────────────────────────────
log_step(8, "Print sensitivity analysis summary")
log_info("=== Sensitivity Analysis Summary ===")
log_info("BLM calibration:\n%s", paste(capture.output(print(blm_df)), collapse = "\n"))
log_info("Target sensitivity:\n%s", paste(capture.output(print(target_df)), collapse = "\n"))
log_info("Cost scenario sensitivity:\n%s", paste(capture.output(print(cost_df)), collapse = "\n"))
log_info("Sensitivity analysis complete.")
