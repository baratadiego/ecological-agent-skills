# Usage: Rscript recovery_trajectory.R <timeseries.csv> <disturbance_date> <output_dir>
# Estimate post-disturbance vegetation recovery trajectory
# Usage: Rscript recovery_trajectory.R <timeseries_csv> <disturbance_date> <output_dir>
# Requires: dplyr, ggplot2, zoo, broom, lubridate

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(zoo)
  library(broom)
})

args             <- commandArgs(trailingOnly = TRUE)
ts_file          <- ifelse(length(args) >= 1, args[1], "tests/data/ndvi_monthly_series.csv")
disturbance_date <- ifelse(length(args) >= 2, args[2], "2010-01-01")
output_dir       <- ifelse(length(args) >= 3, args[3], "outputs/recovery")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── 1. Load and parse ──────────────────────────────────────────────────────
dat <- read.csv(ts_file)
val_col <- if ("value" %in% names(dat)) "value" else names(dat)[ncol(dat)]
date_col <- if ("date" %in% names(dat)) "date" else names(dat)[1]

dat[[date_col]] <- as.Date(dat[[date_col]])
dist_date <- as.Date(disturbance_date)
cat("Series length:", nrow(dat), "| Disturbance date:", format(dist_date), "\n")

# ── 2. Define periods ──────────────────────────────────────────────────────
pre  <- dat[dat[[date_col]] <  dist_date, ]
post <- dat[dat[[date_col]] >= dist_date, ]
cat("Pre-disturbance obs:", nrow(pre), "| Post:", nrow(post), "\n")

if (nrow(pre) < 12) stop("Need at least 12 pre-disturbance observations for baseline.")

# ── 3. Baseline statistics ─────────────────────────────────────────────────
# Use last 2 years before disturbance as immediate pre-disturbance baseline
recent_pre <- tail(pre, 24)
baseline_mean <- mean(recent_pre[[val_col]], na.rm = TRUE)
baseline_sd   <- sd(recent_pre[[val_col]],   na.rm = TRUE)
cat("Pre-disturbance baseline:", round(baseline_mean, 4), "±", round(baseline_sd, 4), "\n")

# ── 4. Minimum post-disturbance value ─────────────────────────────────────
post_smooth <- rollapply(post[[val_col]], width = 3, FUN = mean,
                          align = "center", fill = NA)
min_val     <- min(post_smooth, na.rm = TRUE)
min_idx     <- which.min(post_smooth)
min_date    <- post[[date_col]][min_idx]
cat("Post-disturbance minimum:", round(min_val, 4), "at", format(min_date), "\n")

# ── 5. Recovery Indicator (RI) ─────────────────────────────────────────────
# RI_t = (value_t - min_val) / (baseline_mean - min_val)
post$RI <- (post[[val_col]] - min_val) / (baseline_mean - min_val + 1e-10)
write.csv(post[, c(date_col, val_col, "RI")],
          file.path(output_dir, "recovery_indicator.csv"), row.names = FALSE)

# ── 6. Fit recovery curves ─────────────────────────────────────────────────
# t = months since minimum
post$t_months <- as.numeric(difftime(post[[date_col]], min_date, units = "days")) / 30.44
post_fit <- post[post$t_months >= 0, ]

results_list <- list()

# Linear model
m_lin <- lm(RI ~ t_months, data = post_fit)
results_list$linear <- broom::glance(m_lin) |>
  mutate(model = "linear", formula = "RI ~ t")

# Exponential (log-linear)
post_fit_pos <- post_fit[post_fit$RI > 0.01, ]  # avoid log(0)
if (nrow(post_fit_pos) > 5) {
  m_exp <- lm(log(RI) ~ t_months, data = post_fit_pos)
  results_list$exponential <- broom::glance(m_exp) |>
    mutate(model = "exponential", formula = "log(RI) ~ t")
}

# ── 7. Estimate time to 80% and 100% recovery ─────────────────────────────
# Use linear model for simplicity; refine with best-fit if available
slope <- coef(m_lin)[["t_months"]]
intercept <- coef(m_lin)[["(Intercept)"]]
# RI = intercept + slope * t → t = (RI_target - intercept) / slope
t_80  <- if (slope > 0) round((0.80 - intercept) / slope, 1) else NA
t_100 <- if (slope > 0) round((1.00 - intercept) / slope, 1) else NA

cat("Estimated time to 80% recovery:",  t_80,  "months\n")
cat("Estimated time to 100% recovery:", t_100, "months\n")

recovery_metrics <- data.frame(
  baseline_mean        = round(baseline_mean, 4),
  baseline_sd          = round(baseline_sd,   4),
  disturbance_date     = format(dist_date),
  post_minimum_value   = round(min_val, 4),
  post_minimum_date    = format(min_date),
  magnitude_of_decline = round((baseline_mean - min_val) / baseline_mean * 100, 2),
  RI_current           = round(tail(post$RI, 1), 4),
  slope_linear         = round(slope, 6),
  r2_linear            = round(summary(m_lin)$r.squared, 4),
  t_to_80pct_months    = t_80,
  t_to_100pct_months   = t_100
)
write.csv(recovery_metrics, file.path(output_dir, "recovery_metrics.csv"), row.names = FALSE)

# ── 8. Plot ────────────────────────────────────────────────────────────────
pred_df <- data.frame(t_months = seq(0, max(post_fit$t_months, na.rm=TRUE), by=1))
pred_df$RI_pred <- intercept + slope * pred_df$t_months

p <- ggplot() +
  geom_hline(yintercept = 1.0, linetype = "dashed", colour = "forestgreen", alpha = 0.7) +
  geom_hline(yintercept = 0.8, linetype = "dashed", colour = "orange",      alpha = 0.7) +
  geom_line(data = post_fit, aes(x = t_months, y = RI), colour = "grey50", linewidth = 0.8) +
  geom_point(data = post_fit, aes(x = t_months, y = RI), size = 1.5, alpha = 0.7) +
  geom_line(data = pred_df, aes(x = t_months, y = RI_pred),
            colour = "#2166ac", linewidth = 1.1, linetype = "solid") +
  annotate("text", x = max(post_fit$t_months)*0.05, y = 1.02, label = "100% recovery",
           colour = "forestgreen", size = 3, hjust = 0) +
  annotate("text", x = max(post_fit$t_months)*0.05, y = 0.82, label = "80% recovery",
           colour = "orange", size = 3, hjust = 0) +
  labs(x = "Months since post-disturbance minimum",
       y = "Recovery Indicator (RI)",
       title = "Post-Disturbance Recovery Trajectory",
       subtitle = paste0("Disturbance: ", format(dist_date),
                         " | Linear model R² = ", round(summary(m_lin)$r.squared, 3))) +
  theme_bw()

ggsave(file.path(output_dir, "recovery_trajectory.png"), p, width = 8, height = 5, dpi = 150)

# ── 9. Full time series context plot ──────────────────────────────────────
p2 <- ggplot(dat, aes(x = .data[[date_col]], y = .data[[val_col]])) +
  geom_line(colour = "grey60", linewidth = 0.6) +
  geom_vline(xintercept = as.numeric(dist_date), linetype = "dashed",
             colour = "red", linewidth = 0.8) +
  geom_hline(yintercept = baseline_mean, linetype = "dotted",
             colour = "forestgreen", linewidth = 0.8) +
  annotate("text", x = dist_date, y = max(dat[[val_col]], na.rm=TRUE),
           label = " Disturbance", hjust = 0, colour = "red", size = 3.2) +
  annotate("text", x = min(dat[[date_col]]), y = baseline_mean + 0.005,
           label = "Pre-disturbance baseline", hjust = 0, colour = "forestgreen", size = 3) +
  labs(x = NULL, y = val_col, title = "Full NDVI Time Series with Disturbance Event") +
  theme_bw()
ggsave(file.path(output_dir, "timeseries_context.png"), p2, width = 10, height = 4, dpi = 150)

cat("\nRecovery analysis complete. Outputs in:", output_dir, "\n")
cat("Key metrics:\n")
print(t(recovery_metrics))
