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

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Load data ─────────────────────────────────────────────────────────────────
pu       <- rast(pu_path)
feat_files <- list.files(features_dir, pattern = "\\.tif$",
                          full.names = TRUE, ignore.case = TRUE)
features   <- rast(feat_files)
features   <- resample(features, pu, method = "bilinear")
names(features) <- tools::file_path_sans_ext(basename(feat_files))

# Remove zero-sum features
feat_sums <- global(features, "sum", na.rm = TRUE)[[1]]
features  <- features[[feat_sums > 0]]
n_feats   <- nlyr(features)

# Baseline targets
if (file.exists(targets_arg)) {
  target_df   <- read.csv(targets_arg)
  targets_base <- target_df$target[match(names(features), target_df$feature_name)]
  targets_base[is.na(targets_base)] <- 0.30
} else {
  targets_base <- rep(as.numeric(targets_arg), n_feats)
}

# Helper: build and solve base problem with given cost and targets
solve_scenario <- function(cost_r, targets_v, blm_val = 0,
                            name = "scenario") {
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
    warning("Solver failed for scenario '", name, "': ", conditionMessage(e))
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
cat("Running BLM calibration...\n")
blm_values <- c(0, 0.001, 0.01, 0.05, 0.1, 0.5, 1.0)
blm_results <- lapply(blm_values, function(blm) {
  cat(sprintf("  BLM = %g\n", blm))
  res <- solve_scenario(pu, targets_base, blm_val = blm,
                          name = paste0("blm_", blm))
  if (is.null(res)) return(NULL)
  data.frame(blm = blm, cost = res$total_cost,
             boundary = res$boundary, n_selected = res$n_selected)
})
blm_df <- dplyr::bind_rows(Filter(Negate(is.null), blm_results))
write.csv(blm_df, file.path(output_dir, "blm_calibration.csv"), row.names = FALSE)
cat("BLM calibration done.\n")

# BLM elbow plot
if (nrow(blm_df) > 2) {
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
    error = function(e) warning("BLM plot failed: ", conditionMessage(e))
  )
}

# ── 2. Target Sensitivity ─────────────────────────────────────────────────────
cat("Running target sensitivity analysis...\n")
target_scalings <- c(0.50, 0.75, 1.00, 1.25, 1.50)
target_results <- lapply(target_scalings, function(sc) {
  cat(sprintf("  Target scaling = %.2f×\n", sc))
  tgts <- pmin(targets_base * sc, 0.999)
  res  <- solve_scenario(pu, tgts, name = paste0("target_", sc))
  if (is.null(res)) return(NULL)
  data.frame(target_scaling = sc,
             mean_target    = mean(tgts),
             cost           = res$total_cost,
             targets_met    = res$targets_met,
             n_selected     = res$n_selected)
})
target_df <- dplyr::bind_rows(Filter(Negate(is.null), target_results))
write.csv(target_df, file.path(output_dir, "target_sensitivity.csv"),
          row.names = FALSE)
cat("Target sensitivity done.\n")

# ── 3. Cost Scenario Sensitivity ──────────────────────────────────────────────
cat("Running cost scenario sensitivity analysis...\n")
cost_scenarios <- list(
  low      = pu * 0.70,
  baseline = pu,
  high     = pu * 1.30
)

cost_results <- lapply(names(cost_scenarios), function(name) {
  cat(sprintf("  Cost scenario: %s\n", name))
  res <- solve_scenario(cost_scenarios[[name]], targets_base, name = name)
  if (is.null(res)) return(NULL)
  data.frame(cost_scenario = name,
             total_cost    = res$total_cost,
             n_selected    = res$n_selected,
             targets_met   = res$targets_met)
})
cost_df <- dplyr::bind_rows(Filter(Negate(is.null), cost_results))
write.csv(cost_df, file.path(output_dir, "cost_scenario_sensitivity.csv"),
          row.names = FALSE)
cat("Cost scenario sensitivity done.\n")

# ── 4. Portfolio Irreplaceability ─────────────────────────────────────────────
cat("Building portfolio irreplaceability (selection frequency across scenarios)...\n")
# Collect all solutions computed above
all_solutions <- list()
for (blm in blm_values) {
  res <- solve_scenario(pu, targets_base, blm_val = blm, name = paste0("blm_", blm))
  if (!is.null(res)) all_solutions[[length(all_solutions) + 1]] <- res$solution
}
for (sc in target_scalings) {
  tgts <- pmin(targets_base * sc, 0.999)
  res  <- solve_scenario(pu, tgts, name = paste0("target_", sc))
  if (!is.null(res)) all_solutions[[length(all_solutions) + 1]] <- res$solution
}

if (length(all_solutions) > 1) {
  freq_raster <- Reduce("+", all_solutions) / length(all_solutions)
  names(freq_raster) <- "selection_frequency"
  writeRaster(freq_raster, file.path(output_dir, "portfolio_frequency.tif"),
              overwrite = TRUE)
  cat(sprintf("Portfolio frequency raster saved (%d scenarios).\n",
              length(all_solutions)))
} else {
  cat("Insufficient solutions for portfolio analysis.\n")
}

# ── Summary report ────────────────────────────────────────────────────────────
cat("\n=== Sensitivity Analysis Summary ===\n")
cat("BLM calibration:\n"); print(blm_df)
cat("\nTarget sensitivity:\n"); print(target_df)
cat("\nCost scenario sensitivity:\n"); print(cost_df)
cat("\nSensitivity analysis complete.\n")
