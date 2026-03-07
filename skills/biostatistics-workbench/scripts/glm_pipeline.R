# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript glm_pipeline.R <data.csv> <response_col> <predictor_cols> <output_dir> [family]
# Fit candidate GLMs, check assumptions, model selection
# Usage: source this script or adapt interactively
# Requires: glmmTMB, DHARMa, MuMIn, emmeans, dplyr

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "biostatistics-workbench"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages({
  library(glmmTMB)
  library(DHARMa)
  library(MuMIn)
  library(emmeans)
  library(dplyr)
})

# ── Helper: fit and summarise a GLM ───────────────────────────────────────
fit_and_check <- function(formula, data, family, label, output_dir = "outputs") {
  log_info("Fitting model: %s", label)
  dir.create(file.path(output_dir, "diagnostics"), recursive = TRUE, showWarnings = FALSE)

  tryCatch({
    m <- glmmTMB(formula, data = data, family = family,
                 control = glmmTMBControl(optimizer = optim, optArgs = list(method = "BFGS")))
    log_info("Model %s converged. AIC = %.2f", label, AIC(m))
    log_info(paste(capture.output(summary(m)), collapse = "\n"))

    log_step(1, sprintf("DHARMa residual diagnostics for %s", label))
    sim_res <- simulateResiduals(m, plot = FALSE, n = 500)
    png(file.path(output_dir, "diagnostics", paste0(label, "_dharma.png")),
        width = 1200, height = 600, res = 150)
    plot(sim_res, main = label)
    dev.off()
    log_info("DHARMa diagnostic plot saved for %s", label)

    list(model = m, label = label, AIC = AIC(m))
  }, error = function(e) {
    log_error(
      "Falha em fit_and_check [%s]: %s\nCausa provavel: convergencia ou dados insuficientes para a familia escolhida\nVerifique: formula, familia de distribuicao, e dados de entrada\nSkill anterior: data-cleaning",
      label, conditionMessage(e)
    )
    stop(e)
  })
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
log_info("glm_pipeline.R loaded. Adapt the example usage section for your data.")
