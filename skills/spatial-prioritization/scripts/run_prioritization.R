# Usage: Rscript run_prioritization.R <pu_raster> <features_dir> <output_dir>
#        [targets] [locked_in_raster] [locked_out_raster] [blm] [budget]
#
# Runs systematic conservation prioritization using prioritizr (minimum-set
# or maximum-coverage ILP problem solved with HiGHS solver).
#
# Arguments:
#   pu_raster         — Planning unit cost raster (.tif); NA = excluded
#   features_dir      — Directory of feature rasters (.tif, one per species/habitat)
#   output_dir        — Directory for output files
#   targets           — Single value (applied to all features) or path to CSV
#                       with columns feature_name, target (default: 0.30)
#   locked_in_raster  — Binary raster, 1 = must select (default: none)
#   locked_out_raster — Binary raster, 1 = must exclude (default: none)
#   blm               — Boundary length modifier (default: 0)
#   budget            — For maximum coverage problem; if provided, switches
#                       objective to max-features (default: NA = min-set)
#
# Outputs:
#   solution.tif               — Binary raster: 1 = selected PU
#   feature_representation.csv — Amount of each feature in solution
#   cost_summary.csv           — Total cost and number of PUs selected
#   irreplaceability.tif       — Rarity-weighted importance of each PU
#   prioritization_map.png     — Visual output

suppressPackageStartupMessages(library(prioritizr))
suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  cat("Usage: Rscript run_prioritization.R <pu_raster> <features_dir>",
      "<output_dir> [targets] [locked_in] [locked_out] [blm] [budget]\n")
  quit(status = 1)
}

pu_path       <- args[1]
features_dir  <- args[2]
output_dir    <- args[3]
targets_arg   <- if (length(args) >= 4 && args[4] != "NA") args[4] else "0.30"
locked_in_p   <- if (length(args) >= 5 && args[5] != "NA") args[5] else NULL
locked_out_p  <- if (length(args) >= 6 && args[6] != "NA") args[6] else NULL
blm           <- if (length(args) >= 7) as.numeric(args[7]) else 0
budget        <- if (length(args) >= 8 && args[8] != "NA") as.numeric(args[8]) else NA_real_

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Load planning units ───────────────────────────────────────────────────────
pu <- rast(pu_path)
cat(sprintf("Planning units: %d × %d cells, CRS: %s\n",
            nrow(pu), ncol(pu), crs(pu, describe = TRUE)$name))

n_pu_total <- sum(!is.na(values(pu)))
cat(sprintf("Valid planning units: %d\n", n_pu_total))

# ── Load features ─────────────────────────────────────────────────────────────
feat_files <- list.files(features_dir, pattern = "\\.tif$",
                          full.names = TRUE, ignore.case = TRUE)
if (length(feat_files) == 0) {
  stop("No .tif feature files found in: ", features_dir)
}
cat(sprintf("Loading %d feature layers...\n", length(feat_files)))

features <- rast(feat_files)
# Ensure same extent/resolution as planning units
features <- resample(features, pu, method = "bilinear")
names(features) <- tools::file_path_sans_ext(basename(feat_files))

# Check for zero-sum features
feat_sums <- global(features, "sum", na.rm = TRUE)[[1]]
zero_feats <- names(features)[feat_sums == 0]
if (length(zero_feats) > 0) {
  warning(sprintf("%d features have zero total — excluding: %s",
                  length(zero_feats), paste(zero_feats, collapse = ", ")))
  features <- features[[!names(features) %in% zero_feats]]
}
n_feats <- nlyr(features)
cat(sprintf("Features loaded: %d\n", n_feats))

# ── Set targets ────────────────────────────────────────────────────────────────
if (file.exists(targets_arg)) {
  target_df <- read.csv(targets_arg)
  targets_vec <- target_df$target[match(names(features), target_df$feature_name)]
  na_targets  <- is.na(targets_vec)
  targets_vec[na_targets] <- 0.30  # default for unmatched features
  if (any(na_targets)) {
    warning("Target not found for features: ",
            paste(names(features)[na_targets], collapse = ", "),
            "; using default 0.30")
  }
} else {
  targets_vec <- rep(as.numeric(targets_arg), n_feats)
}
cat(sprintf("Targets: min=%.2f, mean=%.2f, max=%.2f\n",
            min(targets_vec), mean(targets_vec), max(targets_vec)))

# ── Build problem ─────────────────────────────────────────────────────────────
if (is.na(budget)) {
  # Minimum set problem
  p <- problem(pu, features) %>%
    add_min_set_objective() %>%
    add_relative_targets(targets_vec)
  cat("Objective: minimum cost (min-set)\n")
} else {
  # Maximum coverage problem
  p <- problem(pu, features) %>%
    add_max_features_objective(budget = budget) %>%
    add_absolute_targets(1e-6)  # minimum feasibility constraint
  cat(sprintf("Objective: maximum coverage (budget = %g)\n", budget))
}

p <- p %>%
  add_binary_decisions()

# Locked-in
if (!is.null(locked_in_p)) {
  li <- rast(locked_in_p)
  li <- resample(li, pu, method = "near")
  p  <- p %>% add_locked_in_constraints(li)
  cat(sprintf("Locked-in: %d PUs\n", sum(values(li) == 1, na.rm = TRUE)))
}

# Locked-out
if (!is.null(locked_out_p)) {
  lo <- rast(locked_out_p)
  lo <- resample(lo, pu, method = "near")
  p  <- p %>% add_locked_out_constraints(lo)
  cat(sprintf("Locked-out: %d PUs\n", sum(values(lo) == 1, na.rm = TRUE)))
}

# Boundary penalty
if (blm > 0) {
  p <- p %>% add_boundary_penalties(penalty = blm, data = NULL)
  cat(sprintf("Boundary length modifier: %g\n", blm))
}

# Solver (HiGHS preferred)
p <- p %>%
  add_highs_solver(gap = 0.01, time_limit = 600, verbose = TRUE)

# ── Solve ─────────────────────────────────────────────────────────────────────
cat("\nSolving...\n")
s <- tryCatch(
  solve(p),
  error = function(e) {
    message("HiGHS failed: ", conditionMessage(e))
    message("Falling back to lpsymphony solver...")
    p2 <- p %>% add_lpsymphony_solver(gap = 0.05, time_limit = 600)
    solve(p2)
  }
)

# ── Write solution raster ─────────────────────────────────────────────────────
sol_path <- file.path(output_dir, "solution.tif")
writeRaster(s, sol_path, overwrite = TRUE)
n_selected <- sum(values(s) == 1, na.rm = TRUE)
cat(sprintf("Solution: %d PUs selected (%.1f%% of valid PUs)\n",
            n_selected, n_selected / n_pu_total * 100))

# ── Feature representation ────────────────────────────────────────────────────
rep_df <- eval_feature_representation_summary(p, s)
rep_df$target <- targets_vec
rep_df$target_met <- rep_df$relative_held >= targets_vec

write.csv(rep_df, file.path(output_dir, "feature_representation.csv"),
          row.names = FALSE)
n_targets_met <- sum(rep_df$target_met, na.rm = TRUE)
cat(sprintf("Targets met: %d / %d features\n", n_targets_met, n_feats))

# ── Cost summary ──────────────────────────────────────────────────────────────
cost_df <- data.frame(
  metric = c("total_cost", "n_pu_selected", "n_pu_total",
             "pct_pu_selected", "n_targets_met", "n_features"),
  value  = c(eval_cost_summary(p, s)$cost,
             n_selected, n_pu_total,
             n_selected / n_pu_total * 100,
             n_targets_met, n_feats)
)
write.csv(cost_df, file.path(output_dir, "cost_summary.csv"), row.names = FALSE)
cat("Cost summary:\n"); print(cost_df)

# ── Irreplaceability ──────────────────────────────────────────────────────────
irr <- eval_rare_richness_importance(p, s)
writeRaster(irr, file.path(output_dir, "irreplaceability.tif"), overwrite = TRUE)
cat("Irreplaceability map written.\n")

# ── Map visualisation ─────────────────────────────────────────────────────────
tryCatch({
  s_agg  <- aggregate(s, fact = max(1, floor(nrow(s) / 300)))
  df_sol <- as.data.frame(s_agg, xy = TRUE)
  names(df_sol)[3] <- "selected"
  df_sol$selected <- factor(df_sol$selected, levels = c(0, 1),
                             labels = c("Not selected", "Selected"))

  p_map <- ggplot(df_sol, aes(x = x, y = y, fill = selected)) +
    geom_raster() +
    scale_fill_manual(values = c("Not selected" = "grey90", "Selected" = "#2166AC"),
                      na.value = "white") +
    coord_equal() +
    labs(x = "Easting", y = "Northing", fill = "",
         title = sprintf("Conservation solution — %d PUs selected, %d/%d targets met",
                         n_selected, n_targets_met, n_feats)) +
    theme_minimal(base_size = 10)

  ggsave(file.path(output_dir, "prioritization_map.png"), p_map,
         width = 9, height = 7, dpi = 150)
  cat("Prioritization map saved.\n")
}, error = function(e) {
  warning("Could not produce map: ", conditionMessage(e))
})

cat("\nPrioritization complete.\n")
