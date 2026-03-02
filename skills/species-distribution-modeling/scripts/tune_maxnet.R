# Usage: Rscript tune_maxnet.R <points_with_env_csv> <output_dir> [rm_values] [fc_values]
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
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  # Defaults for interactive/test use
  occ_csv    <- "tests/data/points_with_env.csv"
  output_dir <- "output/sdm_calibration"
  rm_vals    <- c(0.5, 1, 1.5, 2, 3, 4, 6)
  fc_vals    <- c("L", "LQ", "LQH", "LQHP", "LQHPT")
} else {
  occ_csv    <- args[1]
  output_dir <- args[2]
  rm_vals    <- if (length(args) >= 3) as.numeric(strsplit(args[3], ",")[[1]]) else c(0.5, 1, 1.5, 2, 3, 4, 6)
  fc_vals    <- if (length(args) >= 4) strsplit(args[4], ",")[[1]] else c("L", "LQ", "LQH", "LQHP", "LQHPT")
}

# ── 2. Create output directory ───────────────────────────────────────────────
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
message("Output directory: ", output_dir)

# ── 3. Load occurrence data ──────────────────────────────────────────────────
message("Loading occurrence data from: ", occ_csv)
occ_data <- read.csv(occ_csv)

# Identify coordinate columns (standard names)
lon_col <- intersect(c("decimalLongitude", "longitude", "lon", "x"), names(occ_data))[1]
lat_col <- intersect(c("decimalLatitude",  "latitude",  "lat", "y"), names(occ_data))[1]

if (is.na(lon_col) || is.na(lat_col)) {
  stop("Cannot find coordinate columns. Expected: decimalLongitude/decimalLatitude")
}

occ_pts <- occ_data[, c(lon_col, lat_col)]
names(occ_pts) <- c("x", "y")

# Environmental predictor columns = everything except coordinates and species metadata
meta_cols <- c(lon_col, lat_col, "species", "scientificName", "gbifID",
               "occurrenceID", "datasetKey")
env_cols  <- setdiff(names(occ_data), meta_cols)

message("Found ", nrow(occ_pts), " occurrence records")
message("Environmental variables: ", paste(env_cols, collapse = ", "))

if (nrow(occ_pts) < 10) {
  stop("Too few occurrences (", nrow(occ_pts), ") for calibration. Minimum required: 10")
}

# ── 4. Build environmental SpatRaster from occurrence columns ────────────────
# When a raster stack is not provided, construct a mock raster for ENMeval
# using the env values in the CSV. In full use, load a real raster stack instead.
message("Note: building background from env values in CSV. For production use,")
message("pass a SpatRaster object to ENMevaluate() instead.")

env_mat <- as.matrix(occ_data[, env_cols])

# Background: if CSV has a 'background' column flagging bg points, use them;
# otherwise use a random sample of all non-occurrence rows.
if ("type" %in% names(occ_data)) {
  bg_idx  <- occ_data$type == "background"
  bg_pts  <- occ_data[bg_idx, c(lon_col, lat_col)]
  bg_env  <- occ_data[bg_idx, env_cols]
  occ_env <- occ_data[!bg_idx, env_cols]
} else {
  # Use all points as both occurrences and generate background by jittering
  # In production: load bg from a proper background CSV
  message("WARNING: No 'type' column found. Generating pseudo-background by jittering.")
  set.seed(42)
  n_bg   <- min(10000, nrow(occ_data) * 10)
  bg_pts <- data.frame(
    x = occ_pts$x + runif(n_bg, -2, 2),
    y = occ_pts$y + runif(n_bg, -2, 2)
  )
  bg_env  <- occ_data[sample(nrow(occ_data), n_bg, replace = TRUE), env_cols]
  occ_env <- occ_data[, env_cols]
}

names(bg_pts) <- c("x", "y")

# ── 5. Run ENMeval grid search ───────────────────────────────────────────────
message("Starting ENMeval calibration grid...")
message("  RM values: ", paste(rm_vals, collapse = ", "))
message("  FC values: ", paste(fc_vals, collapse = ", "))
message("  Total models: ", length(rm_vals) * length(fc_vals))

# ENMevaluate with maxnet and spatial block CV
# block partitioning divides geographic space into quadrants for spatial CV
eval_out <- ENMevaluate(
  occs       = occ_pts,
  envs       = NULL,          # using occs.testing below when envs is NULL
  bg         = bg_pts,
  occs.testing = NULL,
  algorithm  = "maxnet",
  partitions = "block",       # spatial cross-validation — avoids autocorrelation inflation
  tune.args  = list(
    rm = rm_vals,
    fc = fc_vals
  ),
  other.settings = list(
    abs.auc.diff = FALSE
  ),
  occs.grp   = NULL,
  bg.grp     = NULL
)

message("Calibration complete.")

# ── 6. Extract and process results table ─────────────────────────────────────
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
message("Saved: ", calib_path)

# ── 7. Select best models by OR_AICc criterion ───────────────────────────────
# Rule: OR10 <= 0.15 (allows slight tolerance above 0.10 expected)
#       AND delta_AICc < 2 (equivalent models by Burnham & Anderson)
or_threshold   <- 0.15
aicc_threshold <- 2

best_models <- res %>%
  filter(OR10 <= or_threshold, delta.AICc < aicc_threshold) %>%
  arrange(OR10, delta.AICc)

if (nrow(best_models) == 0) {
  # Fallback: relax OR threshold and take AICc-best model
  message("WARNING: No model meets OR10 <= ", or_threshold, " AND delta_AICc < ", aicc_threshold)
  message("Falling back to AICc-best model regardless of omission rate.")
  best_models <- res[1, ]
}

best_path <- file.path(output_dir, "best_model_params.csv")
write.csv(best_models, best_path, row.names = FALSE)
message("Saved: ", best_path)
message("Best model(s):")
print(best_models[, c("tune.args.rm", "tune.args.fc", "OR10", "AICc", "delta.AICc")])

# ── 8. Calibration plot ───────────────────────────────────────────────────────
# Scatterplot: delta_AICc (x) vs OR10 (y), colour by FC, size by RM
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
message("Saved: ", plot_path)

# ── 9. Fit final model with best parameters ────────────────────────────────
# Use the top-ranked model (first row of best_models after sorting)
best_rm <- best_models$tune.args.rm[1]
best_fc <- best_models$tune.args.fc[1]
message("Fitting final model: RM = ", best_rm, ", FC = ", best_fc)

# Retrieve the fitted model object from ENMeval results
best_idx <- which(res$tune.args.rm == best_rm & res$tune.args.fc == best_fc)[1]
best_model_obj <- eval.models(eval_out)[[best_idx]]

# Save as RDS for downstream projection
rds_path <- file.path(output_dir, "best_maxnet.rds")
saveRDS(best_model_obj, rds_path)
message("Saved: ", rds_path)

# ── 10. Summary ──────────────────────────────────────────────────────────────
message("\n========== CALIBRATION SUMMARY ==========")
message("Total models evaluated : ", nrow(res))
message("Models meeting OR_AICc : ", nrow(best_models))
message("Selected RM            : ", best_rm)
message("Selected FC            : ", best_fc)
message("Best OR10              : ", round(best_models$OR10[1], 3))
message("Best AUC (val)         : ", round(best_models$AUC_val[1], 3))
message("Best delta_AICc        : ", round(best_models$delta.AICc[1], 3))
message("=========================================\n")
