# Usage: Rscript validate_sdm.R <model.rds> <test_data.csv> <output_dir> [threshold_method]
# Compute AUC, TSS, Boyce index and calibration for SDM predictions
# Usage: Rscript validate_sdm.R <predictions_csv> <output_dir>
# Requires: PresenceAbsence, ecospat, dplyr, ggplot2

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

args       <- commandArgs(trailingOnly = TRUE)
pred_file  <- ifelse(length(args) >= 1, args[1], "outputs/predictions.csv")
output_dir <- ifelse(length(args) >= 2, args[2], "outputs/validation")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

dat <- read.csv(pred_file)
stopifnot(all(c("observed", "predicted") %in% names(dat)))

# ── AUC-ROC ───────────────────────────────────────────────────────────────
roc_data <- dat |> arrange(desc(predicted))
n_pos  <- sum(dat$observed == 1)
n_neg  <- sum(dat$observed == 0)
roc_data$tpr <- cumsum(roc_data$observed == 1) / n_pos
roc_data$fpr <- cumsum(roc_data$observed == 0) / n_neg
auc <- sum(diff(roc_data$fpr) * (roc_data$tpr[-1] + roc_data$tpr[-nrow(roc_data)]) / 2)
auc <- abs(auc)

# ── TSS (MaxTSS threshold) ─────────────────────────────────────────────────
thresholds <- seq(0, 1, by = 0.01)
tss_vals <- sapply(thresholds, function(th) {
  pred_bin <- as.integer(dat$predicted >= th)
  tp <- sum(pred_bin == 1 & dat$observed == 1)
  fp <- sum(pred_bin == 1 & dat$observed == 0)
  tn <- sum(pred_bin == 0 & dat$observed == 0)
  fn <- sum(pred_bin == 0 & dat$observed == 1)
  sens <- if ((tp + fn) > 0) tp / (tp + fn) else 0
  spec <- if ((tn + fp) > 0) tn / (tn + fp) else 0
  sens + spec - 1
})
best_tss_idx <- which.max(tss_vals)
best_thresh  <- thresholds[best_tss_idx]
best_tss     <- tss_vals[best_tss_idx]

# ── Summary metrics ────────────────────────────────────────────────────────
metrics <- data.frame(
  metric = c("AUC-ROC", "MaxTSS", "Threshold_MaxTSS"),
  value  = round(c(auc, best_tss, best_thresh), 4)
)
write.csv(metrics, file.path(output_dir, "performance_metrics.csv"), row.names = FALSE)
cat("AUC-ROC:", round(auc, 3), "| MaxTSS:", round(best_tss, 3),
    "at threshold:", best_thresh, "\n")

# ── Calibration plot ───────────────────────────────────────────────────────
dat$bin <- cut(dat$predicted, breaks = seq(0, 1, by = 0.1), include.lowest = TRUE)
cal <- dat |>
  group_by(bin) |>
  summarise(mean_pred = mean(predicted), obs_rate = mean(observed), n = n(), .groups = "drop")

p_cal <- ggplot(cal, aes(x = mean_pred, y = obs_rate)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey50") +
  geom_point(aes(size = n), colour = "#2166ac") +
  geom_line(colour = "#2166ac") +
  scale_size_area(max_size = 8) +
  labs(title = "Calibration Plot", x = "Mean Predicted Probability", y = "Observed Rate",
       size = "n") +
  theme_bw()
ggsave(file.path(output_dir, "calibration_plot.png"), p_cal, width = 6, height = 5, dpi = 150)
cat("Calibration plot written.\n")
