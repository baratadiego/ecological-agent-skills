# Usage: Rscript matrix_pva.R <vital_rates_csv> <output_dir> [n_init] [t_max] [quasi_ext]
#
# Deterministic and stochastic population viability analysis using
# stage-structured matrix models (Leslie or Lefkovitch).
#
# Arguments:
#   vital_rates_csv — CSV with vital rate time series:
#                     columns: year, stage_i_to_j (survival/growth),
#                     fecundity_i (fecundity), population_N (total census count)
#   output_dir      — Directory for output files
#   n_init          — Initial population size (default: from vital_rates_csv last year N)
#   t_max           — Time horizon in years (default: 100)
#   quasi_ext       — Quasi-extinction threshold in individuals (default: 50)
#
# Alternatively, provide a matrix directly via --matrix_csv argument (rows=cols of A)
#
# Outputs:
#   lambda_summary.csv       — λ, sensitivity, elasticity matrices
#   stable_stage.csv         — Stable stage distribution
#   pva_trajectories.png     — Deterministic projection plot
#   elasticity_heatmap.png   — Elasticity visualisation

suppressPackageStartupMessages(library(popbio))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(tidyr))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  cat("Usage: Rscript matrix_pva.R <vital_rates_csv> <output_dir>",
      "[n_init] [t_max] [quasi_ext]\n")
  quit(status = 1)
}

vr_path   <- args[1]
output_dir <- args[2]
n_init    <- if (length(args) >= 3) as.integer(args[3]) else NA_integer_
t_max     <- if (length(args) >= 4) as.integer(args[4]) else 100L
quasi_ext <- if (length(args) >= 5) as.numeric(args[5]) else 50

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Load vital rates ─────────────────────────────────────────────────────────
vr <- read.csv(vr_path)
cat(sprintf("Loaded vital rates: %d rows, %d columns.\n", nrow(vr), ncol(vr)))

# Detect matrix structure from column names
# Expected pattern: a_i_j where i = row, j = col (1-indexed)
mat_cols <- grep("^a_[0-9]+_[0-9]+$", names(vr), value = TRUE)

if (length(mat_cols) == 0) {
  stop("No matrix element columns found. Columns should be named a_1_1, a_1_2, ...")
}

# Determine matrix dimension
indices <- regmatches(mat_cols, gregexpr("[0-9]+", mat_cols))
max_idx <- max(sapply(indices, function(x) max(as.integer(x))))
k       <- max_idx  # matrix dimension k×k

# Build mean matrix (average across years)
A_mean <- matrix(0, k, k)
for (col in mat_cols) {
  idx <- as.integer(regmatches(col, gregexpr("[0-9]+", col))[[1]])
  i <- idx[1]; j <- idx[2]
  A_mean[i, j] <- mean(vr[[col]], na.rm = TRUE)
}

cat(sprintf("Matrix dimension: %d × %d\n", k, k))
cat("Mean matrix A:\n"); print(round(A_mean, 4))

# ── Deterministic analysis ────────────────────────────────────────────────────
lambda_val <- lambda(A_mean)
cat(sprintf("\nλ (dominant eigenvalue) = %.4f\n", lambda_val))

if (lambda_val < 0.95) {
  cat("WARNING: λ < 0.95 — population is declining rapidly.\n")
  cat("  Recommend stochastic PVA and MTE calculation.\n")
} else if (lambda_val < 1.0) {
  cat("NOTE: λ < 1.0 — population declining (may be slow).\n")
}

SS  <- stable.stage(A_mean)
RV  <- reproductive.value(A_mean)
S   <- sensitivity(A_mean)
E   <- elasticity(A_mean)

cat("\nStable stage distribution:", round(SS, 3), "\n")
cat("Reproductive value:", round(RV, 3), "\n")
cat("\nElasticity matrix:\n"); print(round(E, 4))
cat(sprintf("Sum of elasticities = %.4f\n", sum(E)))

# ── Write λ summary CSV ───────────────────────────────────────────────────────
lam_df <- data.frame(
  metric     = c("lambda", "log_lambda", "doubling_time_yr", "halving_time_yr"),
  value      = c(
    lambda_val,
    log(lambda_val),
    ifelse(lambda_val > 1, log(2) / log(lambda_val), NA),
    ifelse(lambda_val < 1, log(0.5) / log(lambda_val), NA)
  )
)
write.csv(lam_df, file.path(output_dir, "lambda_summary.csv"), row.names = FALSE)

# Write stable stage
ss_df <- data.frame(stage = seq_len(k), proportion = round(SS, 4),
                    repro_value = round(RV, 4))
write.csv(ss_df, file.path(output_dir, "stable_stage.csv"), row.names = FALSE)

# Write sensitivity and elasticity (long format)
make_long_mat <- function(mat, name) {
  as.data.frame(as.table(mat)) %>%
    rename(row_stage = Var1, col_stage = Var2, !!name := Freq)
}
SE_df <- left_join(make_long_mat(S, "sensitivity"),
                   make_long_mat(E, "elasticity"),
                   by = c("row_stage", "col_stage"))
SE_df$row_stage <- as.integer(SE_df$row_stage)
SE_df$col_stage <- as.integer(SE_df$col_stage)
write.csv(SE_df, file.path(output_dir, "sensitivity_elasticity.csv"), row.names = FALSE)
cat(sprintf("\nSensitivity/elasticity written.\n"))

# ── Deterministic projection ──────────────────────────────────────────────────
n0 <- if (!is.na(n_init)) n_init else {
  if ("population_N" %in% names(vr)) as.integer(tail(vr$population_N, 1))
  else 1000L
}

# Stage distribution proportional to stable stage
n_vec  <- round(n0 * SS)

proj_df <- data.frame(time = 0, total_N = sum(n_vec))
n_cur   <- n_vec
for (t in seq_len(t_max)) {
  n_cur <- A_mean %*% n_cur
  proj_df <- rbind(proj_df, data.frame(time = t, total_N = sum(n_cur)))
}

p_proj <- ggplot(proj_df, aes(x = time, y = total_N)) +
  geom_line(linewidth = 1.2, colour = "#2166AC") +
  geom_hline(yintercept = quasi_ext, linetype = "dashed", colour = "red") +
  annotate("text", x = t_max * 0.9, y = quasi_ext * 1.2,
           label = sprintf("Ne = %g", quasi_ext), colour = "red", size = 3) +
  labs(x = "Time (years)", y = "Population size (N)",
       title = sprintf("Deterministic projection (λ = %.4f, N₀ = %d)", lambda_val, n0)) +
  scale_y_continuous(labels = scales::comma) +
  theme_minimal(base_size = 11)

ggsave(file.path(output_dir, "pva_trajectories.png"), p_proj,
       width = 8, height = 5, dpi = 150)
cat(sprintf("Projection plot saved.\n"))

# ── Elasticity heatmap ────────────────────────────────────────────────────────
stage_labels <- paste0("Stage ", seq_len(k))
E_df <- expand.grid(Row = seq_len(k), Col = seq_len(k))
E_df$Elasticity <- as.vector(E)

p_el <- ggplot(E_df, aes(x = Col, y = Row, fill = Elasticity)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = round(Elasticity, 3)), size = 3) +
  scale_fill_gradient2(low = "white", high = "steelblue", mid = "lightblue",
                       midpoint = max(E) / 2) +
  scale_x_continuous(breaks = seq_len(k), labels = stage_labels) +
  scale_y_reverse(breaks = seq_len(k), labels = stage_labels) +
  labs(x = "From stage (column)", y = "To stage (row)",
       fill = "Elasticity",
       title = "Elasticity matrix") +
  theme_minimal(base_size = 10)

ggsave(file.path(output_dir, "elasticity_heatmap.png"), p_el,
       width = 5, height = 4.5, dpi = 150)

# ── CV check ─────────────────────────────────────────────────────────────────
cat("\nVital rate coefficients of variation:\n")
cv_df <- data.frame(element = mat_cols)
cv_df$mean_val <- sapply(mat_cols, function(c) mean(vr[[c]], na.rm = TRUE))
cv_df$sd_val   <- sapply(mat_cols, function(c) sd(vr[[c]], na.rm = TRUE))
cv_df$CV       <- cv_df$sd_val / cv_df$mean_val
high_cv <- cv_df[!is.na(cv_df$CV) & cv_df$CV > 0.30, ]
if (nrow(high_cv) > 0) {
  cat("  ⚠ High CV elements (> 0.30) — stochastic PVA recommended:\n")
  print(high_cv[, c("element", "CV")])
}

write.csv(cv_df, file.path(output_dir, "vital_rate_cv.csv"), row.names = FALSE)
cat("\nMatrix PVA complete.\n")
