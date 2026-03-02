# Usage: Rscript occupancy_analysis.R <detection_history.csv> <site_covariates.csv> <output_dir>
# Single-season occupancy analysis with model selection
# Usage: Rscript occupancy_analysis.R <detection_history_csv> <site_cov_csv> <output_dir>
# Requires: unmarked, dplyr

suppressPackageStartupMessages({
  library(unmarked)
  library(dplyr)
})

args       <- commandArgs(trailingOnly = TRUE)
dh_file    <- ifelse(length(args) >= 1, args[1], "data/detection_history.csv")
sc_file    <- ifelse(length(args) >= 2, args[2], "data/site_covariates.csv")
output_dir <- ifelse(length(args) >= 3, args[3], "outputs/occupancy")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Load data ──────────────────────────────────────────────────────────────
dh <- as.matrix(read.csv(dh_file, row.names = 1))
sc <- read.csv(sc_file, row.names = 1)

cat("Sites:", nrow(dh), "| Survey occasions:", ncol(dh), "\n")
cat("Naive occupancy:", round(mean(rowSums(dh, na.rm=TRUE) > 0), 3), "\n")

# Standardise covariates
sc_std <- sc |> mutate(across(where(is.numeric), scale))

# ── Build unmarkedFrame ────────────────────────────────────────────────────
umf <- unmarkedFrameOccu(y = dh, siteCovs = sc_std)

# ── Fit candidate models ───────────────────────────────────────────────────
# Null model
m0 <- occu(~1 ~1, data = umf)

# Add your candidate models here:
# m1 <- occu(~effort ~forest_cover, data = umf)
# m2 <- occu(~effort ~forest_cover + dist_road, data = umf)

# ── Model selection ────────────────────────────────────────────────────────
model_list <- fitList(null = m0)
ms <- modSel(model_list)
cat("\nModel selection table:\n")
print(ms)
write.csv(as(ms, "data.frame"), file.path(output_dir, "model_selection_table.csv"))

# ── Best model summary ─────────────────────────────────────────────────────
cat("\nNull model summary:\n")
print(m0)

# Backpredict occupancy
psi_pred <- predict(m0, type = "state")
p_pred   <- predict(m0, type = "det")
cat("\nMean occupancy (ψ):", round(mean(psi_pred$Predicted), 3),
    "95% CI [", round(mean(psi_pred$lower), 3), ",",
    round(mean(psi_pred$upper), 3), "]\n")
cat("Mean detection (p) :", round(mean(p_pred$Predicted), 3),
    "95% CI [", round(mean(p_pred$lower), 3), ",",
    round(mean(p_pred$upper), 3), "]\n")

write.csv(psi_pred, file.path(output_dir, "occupancy_estimates.csv"), row.names = FALSE)
write.csv(p_pred,   file.path(output_dir, "detection_estimates.csv"),  row.names = FALSE)
cat("Outputs written to:", output_dir, "\n")
