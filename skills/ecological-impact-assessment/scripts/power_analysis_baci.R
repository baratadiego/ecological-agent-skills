# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript power_analysis_baci.R <output_dir> [effect_size] [n_sites] [n_surveys] [alpha] [variance_estimate]
# Compute statistical power for BACI designs and recommend minimum sample sizes.
# Outputs: power_curves.png, power_summary.csv, minimum_n_recommendation.md

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "ecological-impact-assessment"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages({
  library(ggplot2)
  library(pwr)
})

# ── Arguments ─────────────────────────────────────────────────────────────────
args              <- commandArgs(trailingOnly = TRUE)
output_dir        <- if (length(args) >= 1) args[1] else "outputs/power_analysis"
effect_size       <- if (length(args) >= 2) as.numeric(args[2]) else 0.5
n_sites           <- if (length(args) >= 3) as.integer(args[3]) else 10
n_surveys         <- if (length(args) >= 4) as.integer(args[4]) else 4
alpha             <- if (length(args) >= 5) as.numeric(args[5]) else 0.05
variance_estimate <- if (length(args) >= 6) as.numeric(args[6]) else 1.0

log_decision("effect_size", effect_size,
  "Cohen's d: 0.2=small, 0.5=medium, 0.8=large. Use 0.5 if no pilot data available.")
log_decision("n_sites",   n_sites,
  "Number of control + impact sites each side. Minimum recommended: 5 per group.")
log_decision("n_surveys", n_surveys,
  "Survey occasions before + after. Minimum recommended: 3 pre + 3 post = 6 total.")
log_decision("alpha",     alpha,
  "Type I error rate. Standard: 0.05. Use 0.10 for preliminary screening.")
log_decision("variance_estimate", variance_estimate,
  "Within-group variance from pilot data or literature. Affects Cohen's d calculation.")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Helper: BACI power ────────────────────────────────────────────────────────
# BACI interaction term is tested as a two-sample t-test on the difference-in-differences.
# Effective n per group = n_sites * n_surveys (repeated measures increase precision).
# Cohen's d adjusted for variance: d = effect_size / sqrt(variance_estimate)

baci_power <- function(n_s, n_sv, eff, var_est, a) {
  d_adj  <- eff / sqrt(var_est)
  n_eff  <- n_s * n_sv          # effective replication per group (control or impact)
  result <- tryCatch(
    pwr.t.test(n = n_eff, d = d_adj, sig.level = a, type = "two.sample",
               alternative = "two.sided"),
    error = function(e) NULL
  )
  if (is.null(result)) return(NA_real_)
  result$power
}

# ── Step 1: Curves — power × n_sites (n_surveys fixed) ───────────────────────
log_step(1, "Computing power × n_sites curve")
sites_range <- 2:30
pow_vs_sites <- data.frame(
  n_sites  = sites_range,
  power    = sapply(sites_range, baci_power,
                    n_sv = n_surveys, eff = effect_size,
                    var_est = variance_estimate, a = alpha)
)
log_info("Power at n_sites=%d (n_surveys=%d fixed): %.3f",
         n_sites, n_surveys, baci_power(n_sites, n_surveys, effect_size, variance_estimate, alpha))

# ── Step 2: Curves — power × n_surveys (n_sites fixed) ───────────────────────
log_step(2, "Computing power × n_surveys curve")
surveys_range <- 1:20
pow_vs_surveys <- data.frame(
  n_surveys = surveys_range,
  power     = sapply(surveys_range, function(sv)
    baci_power(n_sites, sv, effect_size, variance_estimate, alpha))
)

# ── Step 3: Curves — power × effect_size ─────────────────────────────────────
log_step(3, "Computing power × effect_size curve")
eff_range <- seq(0.1, 1.5, by = 0.05)
pow_vs_eff <- data.frame(
  effect_size = eff_range,
  power       = sapply(eff_range, baci_power,
                       n_s = n_sites, n_sv = n_surveys,
                       var_est = variance_estimate, a = alpha)
)

# ── Step 4: Minimum n calculations ────────────────────────────────────────────
log_step(4, "Calculating minimum n for power = 0.80 and 0.90")

find_min_n_sites <- function(target_power, n_sv, eff, var_est, a) {
  for (ns in 2:200) {
    if (!is.na(baci_power(ns, n_sv, eff, var_est, a)) &&
        baci_power(ns, n_sv, eff, var_est, a) >= target_power) return(ns)
  }
  return(NA_integer_)
}
find_min_n_surveys <- function(target_power, ns, eff, var_est, a) {
  for (nv in 1:100) {
    if (!is.na(baci_power(ns, nv, eff, var_est, a)) &&
        baci_power(ns, nv, eff, var_est, a) >= target_power) return(nv)
  }
  return(NA_integer_)
}

min_sites_80  <- find_min_n_sites(0.80, n_surveys, effect_size, variance_estimate, alpha)
min_sites_90  <- find_min_n_sites(0.90, n_surveys, effect_size, variance_estimate, alpha)
min_surveys_80<- find_min_n_surveys(0.80, n_sites, effect_size, variance_estimate, alpha)
min_surveys_90<- find_min_n_surveys(0.90, n_sites, effect_size, variance_estimate, alpha)

log_info("Min sites for power=0.80: %d | power=0.90: %d (surveys=%d fixed)",
         min_sites_80, min_sites_90, n_surveys)
log_info("Min surveys for power=0.80: %d | power=0.90: %d (sites=%d fixed)",
         min_surveys_80, min_surveys_90, n_sites)

if (is.na(min_sites_80)) {
  log_warn("Power 0.80 not achievable with sites<=200. Increase effect_size or reduce variance_estimate.")
}

# ── Step 5: Power curves plot ─────────────────────────────────────────────────
log_step(5, "Generating power curves plot")
tryCatch({
  p1 <- ggplot(pow_vs_sites, aes(n_sites, power)) +
    geom_line(colour = "#2471a3", linewidth = 1) +
    geom_hline(yintercept = c(0.80, 0.90), linetype = "dashed",
               colour = c("#e74c3c","#27ae60")) +
    geom_vline(xintercept = c(min_sites_80, min_sites_90), linetype = "dotted",
               colour = c("#e74c3c","#27ae60")) +
    annotate("text", x = min_sites_80 + 0.5, y = 0.05,
             label = paste0("n=", min_sites_80, "\n(80%)"), hjust = 0, size = 3, colour = "#e74c3c") +
    annotate("text", x = min_sites_90 + 0.5, y = 0.05,
             label = paste0("n=", min_sites_90, "\n(90%)"), hjust = 0, size = 3, colour = "#27ae60") +
    scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
    labs(title = paste0("BACI Power vs. Sites (n_surveys=", n_surveys, " fixed)"),
         x = "Number of sites per group", y = "Statistical Power") +
    theme_bw()

  p2 <- ggplot(pow_vs_surveys, aes(n_surveys, power)) +
    geom_line(colour = "#8e44ad", linewidth = 1) +
    geom_hline(yintercept = c(0.80, 0.90), linetype = "dashed",
               colour = c("#e74c3c","#27ae60")) +
    scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
    labs(title = paste0("BACI Power vs. Surveys (n_sites=", n_sites, " fixed)"),
         x = "Survey occasions (before + after)", y = "Statistical Power") +
    theme_bw()

  p3 <- ggplot(pow_vs_eff, aes(effect_size, power)) +
    geom_line(colour = "#e67e22", linewidth = 1) +
    geom_hline(yintercept = c(0.80, 0.90), linetype = "dashed",
               colour = c("#e74c3c","#27ae60")) +
    geom_vline(xintercept = effect_size, linetype = "dotted", colour = "grey40") +
    scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
    labs(title = paste0("BACI Power vs. Effect Size (n=", n_sites, " sites, ",
                        n_surveys, " surveys)"),
         x = "Effect size (Cohen's d)", y = "Statistical Power") +
    theme_bw()

  suppressPackageStartupMessages(library(patchwork))
  combined <- p1 / p2 / p3
  plot_file <- file.path(output_dir, "power_curves.png")
  ggsave(plot_file, combined, width = 8, height = 12, dpi = 150)
  log_info("Power curves plot saved: %s", plot_file)
}, error = function(e) {
  log_warn("Plot generation failed: %s. Trying base graphics fallback.", conditionMessage(e))
  tryCatch({
    png(file.path(output_dir, "power_curves.png"), width = 800, height = 900)
    par(mfrow = c(3, 1), mar = c(4, 4, 3, 1))
    plot(pow_vs_sites$n_sites, pow_vs_sites$power, type = "l", col = "#2471a3", lwd = 2,
         ylim = c(0,1), xlab = "Sites per group", ylab = "Power",
         main = paste0("BACI Power vs Sites (surveys=", n_surveys, ")"))
    abline(h = c(0.8, 0.9), lty = 2, col = c("red","darkgreen"))
    plot(pow_vs_surveys$n_surveys, pow_vs_surveys$power, type = "l", col = "#8e44ad", lwd = 2,
         ylim = c(0,1), xlab = "Survey occasions", ylab = "Power",
         main = paste0("BACI Power vs Surveys (sites=", n_sites, ")"))
    abline(h = c(0.8, 0.9), lty = 2, col = c("red","darkgreen"))
    plot(pow_vs_eff$effect_size, pow_vs_eff$power, type = "l", col = "#e67e22", lwd = 2,
         ylim = c(0,1), xlab = "Effect size (Cohen's d)", ylab = "Power",
         main = "BACI Power vs Effect Size")
    abline(h = c(0.8, 0.9), lty = 2, col = c("red","darkgreen"))
    dev.off()
    log_info("Base-graphics power curves saved.")
  }, error = function(e2) {
    log_error("Failed to generate power plot: %s\nProbable cause: pwr or ggplot2 not installed.\nCheck: install.packages(c('pwr','ggplot2','patchwork'))", conditionMessage(e2))
  })
})

# ── Step 6: Power summary CSV ──────────────────────────────────────────────────
log_step(6, "Saving power summary CSV")
power_current <- baci_power(n_sites, n_surveys, effect_size, variance_estimate, alpha)

summary_df <- data.frame(
  parameter           = c("effect_size","n_sites","n_surveys","alpha","variance_estimate",
                           "power_current","min_sites_power80","min_sites_power90",
                           "min_surveys_power80","min_surveys_power90"),
  value               = c(effect_size, n_sites, n_surveys, alpha, variance_estimate,
                           round(power_current, 4),
                           min_sites_80, min_sites_90,
                           min_surveys_80, min_surveys_90),
  stringsAsFactors    = FALSE
)
csv_file <- file.path(output_dir, "power_summary.csv")
write.csv(summary_df, csv_file, row.names = FALSE)
log_info("Power summary saved: %s", csv_file)

# ── Step 7: Recommendation markdown ───────────────────────────────────────────
log_step(7, "Writing minimum-n recommendation report")
adequacy <- if (!is.na(power_current) && power_current >= 0.80) "ADEQUATE" else "INSUFFICIENT"
rec_lines <- c(
  "# BACI Power Analysis — Field Protocol Recommendation",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## Input Parameters",
  paste0("- **Effect size (Cohen's d):** ", effect_size),
  paste0("- **Number of sites (per group):** ", n_sites),
  paste0("- **Survey occasions (before + after):** ", n_surveys),
  paste0("- **Significance level (α):** ", alpha),
  paste0("- **Variance estimate:** ", variance_estimate),
  "",
  "## Current Design Power",
  paste0("**Statistical power = ", round(power_current * 100, 1), "%** (", adequacy, ")"),
  "",
  ifelse(adequacy == "INSUFFICIENT",
    "> ⚠️ **WARNING:** The current design has insufficient power to detect the target effect.",
    "> ✅ The current design has adequate power to detect the target effect."),
  "",
  "## Minimum Sample Size Recommendations",
  "",
  paste0("### To achieve power = 80% (α = ", alpha, ")"),
  paste0("- **Sites per group:** ≥ ",
         ifelse(is.na(min_sites_80), "not achievable with ≤200 sites", min_sites_80),
         " (with ", n_surveys, " survey occasions)"),
  paste0("- **Survey occasions:** ≥ ",
         ifelse(is.na(min_surveys_80), "not achievable", min_surveys_80),
         " (with ", n_sites, " sites)"),
  "",
  paste0("### To achieve power = 90% (α = ", alpha, ")"),
  paste0("- **Sites per group:** ≥ ",
         ifelse(is.na(min_sites_90), "not achievable with ≤200 sites", min_sites_90),
         " (with ", n_surveys, " survey occasions)"),
  paste0("- **Survey occasions:** ≥ ",
         ifelse(is.na(min_surveys_90), "not achievable", min_surveys_90),
         " (with ", n_sites, " sites)"),
  "",
  "## Interpretation",
  paste0("- A Cohen's d of **", effect_size, "** corresponds to detecting a ",
         round(effect_size * sqrt(variance_estimate), 3),
         " unit difference between impact and control sites, adjusting for σ² = ", variance_estimate, "."),
  "- **Rule of thumb:** BACI studies should have ≥5 control and ≥5 impact sites,",
  "  with ≥3 survey occasions before and ≥3 after the impact.",
  "- If power is insufficient, prioritise adding **sites** (stronger than adding surveys)",
  "  because spatial replication reduces pseudo-replication bias.",
  "",
  "## How to Obtain Variance Estimate",
  "1. **From pilot data:** compute SD of the response variable across sites, then var = SD².",
  "2. **From literature:** use SD values reported for the same metric and habitat type.",
  "3. **Conservative default:** use variance_estimate = 1.0 (corresponds to Cohen's d units).",
  "",
  "## References",
  "- Cohen, J. (1988). *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.).",
  "- Underwood, A.J. (1994). On beyond BACI. *Ecological Applications*, 4(1), 3–15.",
  "- Stewart-Oaten, A. & Bence, J.R. (2001). Temporal and spatial variation in",
  "  environmental impact assessment. *Ecological Monographs*, 71(2), 305–339."
)
md_file <- file.path(output_dir, "minimum_n_recommendation.md")
writeLines(rec_lines, md_file)
log_info("Recommendation report saved: %s", md_file)

log_step(8, "Done — power analysis outputs in: %s", output_dir)
