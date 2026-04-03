# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript trend_analysis.R <timeseries.csv> <output_dir> [frequency] [baseline_end]
# Mann-Kendall trend + Sen's slope + BFAST breakpoints
# Usage: Rscript trend_analysis.R <timeseries_csv> <output_dir> [frequency]
# Requires: trend, bfast, zoo, ggplot2

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "environmental-time-series"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

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

log_info("Skill: %s | ts_file=%s | output_dir=%s | freq=%d",
         SKILL_NAME, ts_file, output_dir, freq)
log_decision("freq", as.character(freq),
             "time series frequency (observations per year); default 12 for monthly data")

# ── Input precondition check ──────────────────────────────────────────────────
if (!file.exists(ts_file)) {
  log_error(
    "Input not found: %s\nProbable cause: time series not generated or incorrect path.\nCheck: run the time series extraction/export script first.\nPrevious skill: geoprocessing-for-ecology.",
    ts_file
  )
  stop("Missing: ", ts_file)
}

# ── Load ───────────────────────────────────────────────────────────────────────
log_step(1, "Load time series and validate 'value' column")
dat <- tryCatch({
  read.csv(ts_file)
}, error = function(e) {
  log_error(
    "Failed to read time series CSV: %s\nProbable cause: corrupted file, incorrect encoding, or non-comma separator.\nCheck: open the file in a text editor and verify the format.\nPrevious skill: geoprocessing-for-ecology.",
    conditionMessage(e)
  )
  stop(e)
})

if (!"value" %in% names(dat)) {
  log_error(
    "Coluna 'value' nao encontrada no CSV (colunas presentes: %s).\nProbable cause: CSV exportado com nome de coluna diferente.\nCheck: renomeie a coluna de valores para 'value' ou ajuste o script.\nPrevious skill: geoprocessing-for-ecology.",
    paste(names(dat), collapse = ", ")
  )
  stop("Missing column: value")
}

n_na <- sum(is.na(dat$value))
if (n_na > 0) {
  log_warn("Coluna 'value' contem %d valores NA — Mann-Kendall pode ser afetado.", n_na)
}

log_info("Observations: %d | Frequencia: %d", nrow(dat), freq)

ts_obj <- ts(dat$value, frequency = freq)

# ── Mann-Kendall + Sen's slope ─────────────────────────────────────────────────
log_step(2, "Mann-Kendall test and Sen slope")
mk  <- tryCatch({
  mk.test(dat$value)
}, error = function(e) {
  log_error(
    "Mann-Kendall test failed: %s\nProbable cause: series with all equal values or excessive NA.\nCheck: variability of input data.\nPrevious skill: geoprocessing-for-ecology.",
    conditionMessage(e)
  )
  stop(e)
})

sen <- tryCatch({
  sens.slope(dat$value)
}, error = function(e) {
  log_error(
    "Failed to compute Sen slope: %s\nProbable cause: insufficient series or no variation.\nCheck: number of valid observations.\nPrevious skill: geoprocessing-for-ecology.",
    conditionMessage(e)
  )
  stop(e)
})

log_info("Mann-Kendall: tau=%.4f | p=%.4f", mk$statistic, mk$p.value)
log_info("Sen slope: %.6f (units/observation)", sen$estimates)

if (mk$p.value < 0.05) {
  trend_dir <- ifelse(mk$statistic > 0, "increasing", "decreasing")
  log_info("Significant trend detected (p<0.05): %s", trend_dir)
} else {
  log_info("No significant trend detected (p=%.4f >= 0.05).", mk$p.value)
}

mk_results <- data.frame(
  tau = mk$statistic, p_value = mk$p.value,
  sens_slope = as.numeric(sen$estimates),
  trend_direction = ifelse(mk$p.value < 0.05,
                           ifelse(mk$statistic > 0, "increasing", "decreasing"),
                           "no significant trend")
)

tryCatch({
  write.csv(mk_results, file.path(output_dir, "trend_results.csv"), row.names = FALSE)
  log_info("trend_results.csv saved in: %s", output_dir)
}, error = function(e) {
  log_error(
    "Failed to salvar trend_results.csv: %s\nProbable cause: permissao negada ou disco cheio.\nCheck: permissoes do output directory.\nPrevious skill: [none].",
    conditionMessage(e)
  )
  stop(e)
})

# ── BFAST breakpoints ──────────────────────────────────────────────────────────
log_step(3, "Detect structural breaks with BFAST")
min_length_bfast <- 3 * freq
if (length(ts_obj) >= min_length_bfast) {
  log_info("Series sufficient for BFAST (%d obs >= %d minimum). Running...", length(ts_obj), min_length_bfast)
  log_decision("bfast_h", "0.15",
               "h=0.15 requer pelo menos 15%% da serie entre quebras; equilibrio entre sensibilidade e estabilidade")
  log_decision("bfast_season", "harmonic",
               "modelo harmonico para sazonalidade adequado para series de vegetacao com ciclo anual")
  tryCatch({
    bf <- bfast(ts_obj, h = 0.15, season = "harmonic", max.iter = 20)
    bp <- bf$output[[1]]$bp.Vt$breakpoints
    if (length(bp) == 0 || all(is.na(bp))) {
      log_info("BFAST: no structural breakpoint detected.")
    } else {
      log_info("BFAST: quebras detectadas nas observacoes: %s", paste(bp, collapse = ", "))
    }
    write.csv(data.frame(breakpoint_obs = bp),
              file.path(output_dir, "breakpoints.csv"), row.names = FALSE)
    log_info("breakpoints.csv saved in: %s", output_dir)
    png(file.path(output_dir, "bfast_plot.png"), width = 1200, height = 600, res = 150)
    plot(bf)
    dev.off()
    log_info("bfast_plot.png saved in: %s", output_dir)
  }, error = function(e) {
    log_warn("BFAST failed: %s — continuing without break detection.", conditionMessage(e))
  })
} else {
  log_warn("Series too short for BFAST: %d obs < %d minimum (3 complete cycles of frequency %d).",
           length(ts_obj), min_length_bfast, freq)
}

# ── Anomalies ──────────────────────────────────────────────────────────────────
log_step(4, "Compute anomalies relative to baseline")
baseline_n    <- min(freq * 10, length(dat$value) %/% 2)
baseline_mean <- mean(dat$value[1:baseline_n], na.rm = TRUE)
baseline_sd   <- sd(dat$value[1:baseline_n],   na.rm = TRUE)

log_decision("baseline_n", as.character(baseline_n),
             "minimum of 10 years of data and half the series; prevents the baseline from spanning the change period")
log_info("Baseline: %.4f +/- %.4f (primeiras %d observacoes)", baseline_mean, baseline_sd, baseline_n)

if (baseline_sd == 0) {
  log_warn("Baseline standard deviation is zero — all anomalies will be infinite or NaN.")
}

dat$anomaly_z <- (dat$value - baseline_mean) / baseline_sd

n_extreme <- sum(abs(dat$anomaly_z) > 3, na.rm = TRUE)
if (n_extreme > 0) {
  log_warn("%d observation(s) with anomaly |Z| > 3 detected — possible outliers or extreme events.", n_extreme)
}

tryCatch({
  write.csv(dat[, c(names(dat)[1], "value", "anomaly_z")],
            file.path(output_dir, "anomaly_series.csv"), row.names = FALSE)
  log_info("anomaly_series.csv saved in: %s", output_dir)
}, error = function(e) {
  log_error(
    "Failed to salvar anomaly_series.csv: %s\nProbable cause: permissao negada ou disco cheio.\nCheck: permissoes do output directory.\nPrevious skill: [none].",
    conditionMessage(e)
  )
  stop(e)
})

log_info("Anomalies computed relative to first %d observations.", baseline_n)
log_info("Trend analysis completed. Outputs in: %s", output_dir)
