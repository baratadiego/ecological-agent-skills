# collinearity_check.R
# Assess and reduce predictor collinearity
# Usage: Rscript collinearity_check.R <env_matrix_csv> <output_dir> [vif_threshold]
# Requires: usdm, corrplot, dplyr

suppressPackageStartupMessages({
  library(usdm)
  library(dplyr)
})

args          <- commandArgs(trailingOnly = TRUE)
env_file      <- ifelse(length(args) >= 1, args[1], "data/processed/env_matrix.csv")
output_dir    <- ifelse(length(args) >= 2, args[2], "outputs")
vif_threshold <- ifelse(length(args) >= 3, as.numeric(args[3]), 5)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Load ───────────────────────────────────────────────────────────────────
cat("Loading:", env_file, "\n")
env <- read.csv(env_file) |> na.omit()
cat("Variables:", ncol(env), "| Rows:", nrow(env), "\n")

# ── Pairwise correlation ───────────────────────────────────────────────────
cor_mat <- cor(env, method = "pearson")
high_cor <- which(abs(cor_mat) > 0.7 & cor_mat != 1, arr.ind = TRUE)
high_cor_pairs <- data.frame(
  var1 = rownames(high_cor),
  var2 = colnames(cor_mat)[high_cor[, 2]],
  r    = cor_mat[high_cor]
) |> filter(var1 < var2) |> arrange(desc(abs(r)))

cat("\nHighly correlated pairs (|r| > 0.7):\n")
print(high_cor_pairs)

# ── VIF stepwise reduction ─────────────────────────────────────────────────
cat("\nRunning VIF stepwise reduction (threshold:", vif_threshold, ")...\n")
vif_result <- vifstep(env, th = vif_threshold)
cat("Variables retained after VIF reduction:\n")
print(vif_result)

selected <- vif_result@results$Variables
cat("\nFinal selected predictors:", paste(selected, collapse = ", "), "\n")

# ── Outputs ────────────────────────────────────────────────────────────────
write.csv(high_cor_pairs, file.path(output_dir, "high_correlation_pairs.csv"), row.names = FALSE)
write.csv(vif_result@results, file.path(output_dir, "vif_results.csv"), row.names = FALSE)
writeLines(selected, file.path(output_dir, "selected_predictors.txt"))
cat("Outputs written to:", output_dir, "\n")
