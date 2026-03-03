# Usage: Rscript occupancy_analysis.R <detection_history.csv> <site_covariates.csv> <output_dir>
# Single-season occupancy analysis with model selection
# Usage: Rscript occupancy_analysis.R <detection_history_csv> <site_cov_csv> <output_dir>
# Requires: unmarked, dplyr

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "occupancy-and-detection"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages({
  library(unmarked)
  library(dplyr)
})

args       <- commandArgs(trailingOnly = TRUE)
dh_file    <- ifelse(length(args) >= 1, args[1], "data/detection_history.csv")
sc_file    <- ifelse(length(args) >= 2, args[2], "data/site_covariates.csv")
output_dir <- ifelse(length(args) >= 3, args[3], "outputs/occupancy")

log_step(1, "Validate inputs")
if (!file.exists(dh_file)) {
  log_error(
    "Falha em validate inputs: arquivo de historico de deteccao nao encontrado: %s\nCausa provavel: caminho incorreto ou arquivo nao gerado\nVerifique: o argumento detection_history_csv e o diretorio de trabalho\nSkill anterior: data-cleaning",
    dh_file
  )
  stop("Detection history file not found.")
}
if (!file.exists(sc_file)) {
  log_error(
    "Falha em validate inputs: arquivo de covariadas de sitio nao encontrado: %s\nCausa provavel: caminho incorreto ou arquivo nao gerado\nVerifique: o argumento site_cov_csv e o diretorio de trabalho\nSkill anterior: data-cleaning",
    sc_file
  )
  stop("Site covariates file not found.")
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_step(2, "Load detection history and site covariates")
tryCatch({
  dh <- as.matrix(read.csv(dh_file, row.names = 1))
  sc <- read.csv(sc_file, row.names = 1)
}, error = function(e) {
  log_error(
    "Falha em load data: %s\nCausa provavel: CSV malformado ou sem coluna de rownames\nVerifique: estrutura dos arquivos (primeira coluna deve ser site ID)\nSkill anterior: data-cleaning",
    conditionMessage(e)
  )
  stop(e)
})

log_info("Sites: %d | Survey occasions: %d", nrow(dh), ncol(dh))

n_all_na <- sum(apply(is.na(dh), 1, all))
if (n_all_na > 0) {
  log_warn("%d sites have all-NA detection histories. These will cause issues in unmarked. Consider removing them.", n_all_na)
}

valid_vals <- dh[!is.na(dh)]
if (any(!valid_vals %in% c(0, 1))) {
  log_warn("Detection history contains values other than 0, 1, or NA. Check your input data for coding errors.")
}

naive_occ <- mean(rowSums(dh, na.rm=TRUE) > 0)
log_info("Naive occupancy: %.3f", naive_occ)
if (naive_occ < 0.05) {
  log_warn("Naive occupancy = %.3f is very low (<5%%). Occupancy models may have poor identifiability.", naive_occ)
}
if (naive_occ > 0.95) {
  log_warn("Naive occupancy = %.3f is very high (>95%%). Consider whether species is truly absent from any sites.", naive_occ)
}

log_step(3, "Standardise site covariates")
log_decision("covariate_scaling", "z-score (scale())", "standardisation improves model convergence and coefficient comparability")
tryCatch({
  sc_std <- sc |> mutate(across(where(is.numeric), scale))
  log_info("Covariates standardised: %s", paste(names(sc_std), collapse = ", "))
}, error = function(e) {
  log_error(
    "Falha em standardise covariates: %s\nCausa provavel: covariadas nao numericas ou com NA\nVerifique: tipos de dados e completude do arquivo de covariadas\nSkill anterior: data-cleaning",
    conditionMessage(e)
  )
  stop(e)
})

log_step(4, "Build unmarkedFrameOccu")
tryCatch({
  umf <- unmarkedFrameOccu(y = dh, siteCovs = sc_std)
  log_info("unmarkedFrameOccu built successfully.")
}, error = function(e) {
  log_error(
    "Falha em unmarkedFrameOccu: %s\nCausa provavel: numero de sites diverge entre dh e sc, ou valores invalidos em dh\nVerifique: que dh e sc tem o mesmo numero de linhas e mesmos site IDs\nSkill anterior: data-cleaning",
    conditionMessage(e)
  )
  stop(e)
})

log_step(5, "Fit candidate occupancy models")
tryCatch({
  m0 <- occu(~1 ~1, data = umf)
  log_info("Null model fitted.")

  # Add your candidate models here:
  # m1 <- occu(~effort ~forest_cover, data = umf)
  # m2 <- occu(~effort ~forest_cover + dist_road, data = umf)
}, error = function(e) {
  log_error(
    "Falha em occu() fitting: %s\nCausa provavel: dados insuficientes, covariadas com NA, ou singularidade numerica\nVerifique: numero de sitios detectados vs nao detectados e completude de covariadas\nSkill anterior: occupancy-and-detection (data formatting)",
    conditionMessage(e)
  )
  stop(e)
})

log_step(6, "Model selection")
tryCatch({
  model_list <- fitList(null = m0)
  ms <- modSel(model_list)
  log_info("Model selection table:\n%s", paste(capture.output(ms), collapse = "\n"))
  write.csv(as(ms, "data.frame"), file.path(output_dir, "model_selection_table.csv"))
  log_info("Model selection table saved.")
}, error = function(e) {
  log_error(
    "Falha em model selection: %s\nCausa provavel: nenhum modelo ajustado com sucesso\nVerifique: etapa de fitting para mensagens de erro anteriores\nSkill anterior: occupancy-and-detection (fitting)",
    conditionMessage(e)
  )
  stop(e)
})

log_step(7, "Summarise best model and back-predict occupancy")
tryCatch({
  log_info("Null model summary:\n%s", paste(capture.output(print(m0)), collapse = "\n"))

  psi_pred <- predict(m0, type = "state")
  p_pred   <- predict(m0, type = "det")
  log_info("Mean occupancy (psi): %.3f  95%% CI [%.3f, %.3f]",
           mean(psi_pred$Predicted), mean(psi_pred$lower), mean(psi_pred$upper))
  log_info("Mean detection (p):   %.3f  95%% CI [%.3f, %.3f]",
           mean(p_pred$Predicted), mean(p_pred$lower), mean(p_pred$upper))

  if (mean(psi_pred$Predicted) < 0.1) {
    log_warn("Estimated occupancy = %.3f is very low. Verify species is not cryptic or camera placement is adequate.", mean(psi_pred$Predicted))
  }

  write.csv(psi_pred, file.path(output_dir, "occupancy_estimates.csv"), row.names = FALSE)
  write.csv(p_pred,   file.path(output_dir, "detection_estimates.csv"),  row.names = FALSE)
  log_info("Outputs written to: %s", output_dir)
}, error = function(e) {
  log_error(
    "Falha em predict/summary: %s\nCausa provavel: modelo nao convergiu ou objeto umf invalido\nVerifique: avisos de convergencia do unmarked durante o fitting\nSkill anterior: occupancy-and-detection (fitting)",
    conditionMessage(e)
  )
  stop(e)
})
