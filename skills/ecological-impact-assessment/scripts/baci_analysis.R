# baci_analysis.R
# BACI mixed-effects model for ecological impact assessment
# Usage: Rscript baci_analysis.R <data_csv> <response_var> <output_dir>
# Requires: glmmTMB, emmeans, ggplot2, dplyr

suppressPackageStartupMessages({
  library(glmmTMB)
  library(emmeans)
  library(ggplot2)
  library(dplyr)
})

args         <- commandArgs(trailingOnly = TRUE)
data_file    <- ifelse(length(args) >= 1, args[1], "data/baci_data.csv")
response_var <- ifelse(length(args) >= 2, args[2], "abundance")
output_dir   <- ifelse(length(args) >= 3, args[3], "outputs/baci")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

dat <- read.csv(data_file)
required_cols <- c("site", "period", "treatment", response_var)
missing_cols  <- setdiff(required_cols, names(dat))
if (length(missing_cols) > 0) stop("Missing columns: ", paste(missing_cols, collapse = ", "))

dat$period    <- factor(dat$period,    levels = c("before", "after"))
dat$treatment <- factor(dat$treatment, levels = c("control", "impact"))
cat("Sites:", n_distinct(dat$site),
    "| Before:", sum(dat$period == "before"),
    "| After:", sum(dat$period == "after"), "\n")

# ── Fit BACI model ────────────────────────────────────────────────────────
formula_str <- paste(response_var, "~ period * treatment + (1|site)")
cat("Formula:", formula_str, "\n")

m <- glmmTMB(as.formula(formula_str), data = dat, family = nbinom2())
cat("\nModel summary:\n")
print(summary(m))

# ── Extract BACI interaction ───────────────────────────────────────────────
coef_table <- as.data.frame(coef(summary(m))$cond)
baci_row   <- grep("period.*treatment|treatment.*period", rownames(coef_table))

if (length(baci_row) > 0) {
  baci_est <- coef_table[baci_row, ]
  cat("\n=== BACI Interaction ===\n")
  print(baci_est)
  cat("Effect on original scale (multiplicative):", round(exp(baci_est[, "Estimate"]), 3), "\n")
  write.csv(baci_est, file.path(output_dir, "baci_results.csv"))
}

# ── Before/After plot ──────────────────────────────────────────────────────
p_baci <- dat |>
  group_by(period, treatment) |>
  summarise(mean_y = mean(.data[[response_var]], na.rm = TRUE),
            se_y   = sd(.data[[response_var]], na.rm = TRUE) / sqrt(n()),
            .groups = "drop") |>
  ggplot(aes(x = period, y = mean_y, colour = treatment, group = treatment)) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = mean_y - se_y, ymax = mean_y + se_y), width = 0.1) +
  scale_colour_manual(values = c(control = "#2166ac", impact = "#d6604d")) +
  labs(y = response_var, title = "BACI: Control vs Impact") +
  theme_bw()
ggsave(file.path(output_dir, "baci_plot.png"), p_baci, width = 6, height = 5, dpi = 150)
cat("Outputs written to:", output_dir, "\n")
