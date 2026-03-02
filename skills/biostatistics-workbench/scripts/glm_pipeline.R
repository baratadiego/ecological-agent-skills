# Usage: Rscript glm_pipeline.R <data.csv> <response_col> <predictor_cols> <output_dir> [family]
# Fit candidate GLMs, check assumptions, model selection
# Usage: source this script or adapt interactively
# Requires: glmmTMB, DHARMa, MuMIn, emmeans, dplyr

suppressPackageStartupMessages({
  library(glmmTMB)
  library(DHARMa)
  library(MuMIn)
  library(emmeans)
  library(dplyr)
})

# ── Helper: fit and summarise a GLM ───────────────────────────────────────
fit_and_check <- function(formula, data, family, label, output_dir = "outputs") {
  cat("\n=== Fitting:", label, "===\n")
  dir.create(file.path(output_dir, "diagnostics"), recursive = TRUE, showWarnings = FALSE)

  m <- glmmTMB(formula, data = data, family = family,
               control = glmmTMBControl(optimizer = optim, optArgs = list(method = "BFGS")))
  cat(capture.output(summary(m)), sep = "\n")

  # DHARMa diagnostics
  sim_res <- simulateResiduals(m, plot = FALSE, n = 500)
  png(file.path(output_dir, "diagnostics", paste0(label, "_dharma.png")),
      width = 1200, height = 600, res = 150)
  plot(sim_res, main = label)
  dev.off()

  list(model = m, label = label, AIC = AIC(m))
}

# ── Example usage ─────────────────────────────────────────────────────────
# Uncomment and adapt:
#
# dat <- read.csv("data/processed/richness_data.csv")
#
# candidates <- list(
#   fit_and_check(richness ~ vegetation_type + elevation, dat, poisson(), "m1_poisson"),
#   fit_and_check(richness ~ vegetation_type + elevation, dat, nbinom2(),  "m2_nbinom"),
#   fit_and_check(richness ~ vegetation_type + elevation + precipitation, dat, nbinom2(), "m3_nbinom_full")
# )
#
# # Model selection table
# aic_table <- do.call(rbind, lapply(candidates, function(x) data.frame(
#   model = x$label, AIC = x$AIC
# ))) |> arrange(AIC) |> mutate(deltaAIC = AIC - min(AIC))
# print(aic_table)
# write.csv(aic_table, "outputs/model_selection_table.csv", row.names = FALSE)
#
# # Best model effects
# best <- candidates[[which.min(sapply(candidates, function(x) x$AIC))]]$model
# em <- emmeans(best, ~ vegetation_type)
# print(em)
cat("glm_pipeline.R loaded. Adapt the example usage section for your data.\n")
