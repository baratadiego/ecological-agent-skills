# Usage: Rscript trend_analysis.R <timeseries.csv> <output_dir> [frequency] [baseline_end]
# Mann-Kendall trend + Sen's slope + BFAST breakpoints
# Usage: Rscript trend_analysis.R <timeseries_csv> <output_dir> [frequency]
# Requires: trend, bfast, zoo, ggplot2

suppressPackageStartupMessages({
  library(trend)
  library(bfast)
  library(zoo)
  library(ggplot2)
})

args       <- commandArgs(trailingOnly = TRUE)
ts_file    <- ifelse(length(args) >= 1, args[1], "data/ndvi_series.csv")
output_dir <- ifelse(length(args) >= 2, args[2], "outputs/timeseries")
freq       <- ifelse(length(args) >= 3, as.integer(args[3]), 12L)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Load ───────────────────────────────────────────────────────────────────
dat <- read.csv(ts_file)
stopifnot("value" %in% names(dat))
cat("Observations:", nrow(dat), "| Frequency:", freq, "\n")

ts_obj <- ts(dat$value, frequency = freq)

# ── Mann-Kendall + Sen's slope ─────────────────────────────────────────────
mk  <- mk.test(dat$value)
sen <- sens.slope(dat$value)
cat("\nMann-Kendall:\n")
cat("  tau:", round(mk$statistic, 4), "| p:", round(mk$p.value, 4), "\n")
cat("  Sen's slope:", round(sen$estimates, 6), "(units/observation)\n")

mk_results <- data.frame(
  tau = mk$statistic, p_value = mk$p.value,
  sens_slope = as.numeric(sen$estimates),
  trend_direction = ifelse(mk$p.value < 0.05,
                           ifelse(mk$statistic > 0, "increasing", "decreasing"),
                           "no significant trend")
)
write.csv(mk_results, file.path(output_dir, "trend_results.csv"), row.names = FALSE)

# ── BFAST breakpoints ──────────────────────────────────────────────────────
if (length(ts_obj) >= 3 * freq) {
  cat("\nRunning BFAST...\n")
  tryCatch({
    bf <- bfast(ts_obj, h = 0.15, season = "harmonic", max.iter = 20)
    bp <- bf$output[[1]]$bp.Vt$breakpoints
    cat("Breakpoints detected at observations:", bp, "\n")
    write.csv(data.frame(breakpoint_obs = bp),
              file.path(output_dir, "breakpoints.csv"), row.names = FALSE)
    png(file.path(output_dir, "bfast_plot.png"), width = 1200, height = 600, res = 150)
    plot(bf); dev.off()
  }, error = function(e) cat("BFAST error:", conditionMessage(e), "\n"))
} else {
  cat("Series too short for BFAST (need ≥ 3 full cycles).\n")
}

# ── Anomalies ──────────────────────────────────────────────────────────────
baseline_n <- min(freq * 10, length(dat$value) %/% 2)
baseline_mean <- mean(dat$value[1:baseline_n], na.rm = TRUE)
baseline_sd   <- sd(dat$value[1:baseline_n], na.rm = TRUE)
dat$anomaly_z <- (dat$value - baseline_mean) / baseline_sd
write.csv(dat[, c(names(dat)[1], "value", "anomaly_z")],
          file.path(output_dir, "anomaly_series.csv"), row.names = FALSE)
cat("Anomalies computed relative to first", baseline_n, "observations.\n")
cat("Outputs in:", output_dir, "\n")
