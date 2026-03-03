# Usage: Rscript validate_sdm.R <model.rds> <test_data.csv> <output_dir> [threshold_method]
# Compute AUC, TSS, Boyce index and calibration for SDM predictions
# Usage: Rscript validate_sdm.R <predictions_csv> <output_dir>
# Requires: PresenceAbsence, ecospat, dplyr, ggplot2

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "model-validation-and-uncertainty"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

args       <- commandArgs(trailingOnly = TRUE)
pred_file  <- ifelse(length(args) >= 1, args[1], "outputs/predictions.csv")
output_dir <- ifelse(length(args) >= 2, args[2], "outputs/validation")

log_step(1, "Validate inputs")
if (!file.exists(pred_file)) {
  log_error(
    "Falha em validate inputs: arquivo de predicoes nao encontrado: %s\nCausa provavel: caminho incorreto ou modelo nao gerou predicoes ainda\nVerifique: o argumento predictions_csv e que o modelo foi ajustado\nSkill anterior: species-distribution-modelling",
    pred_file
  )
  stop("Predictions file not found.")
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_step(2, "Load predictions data")
tryCatch({
  dat <- read.csv(pred_file)
}, error = function(e) {
  log_error(
    "Falha em load data: %s\nCausa provavel: CSV malformado ou permissoes insuficientes\nVerifique: encoding e estrutura do arquivo de predicoes\nSkill anterior: species-distribution-modelling",
    conditionMessage(e)
  )
  stop(e)
})

if (!all(c("observed", "predicted") %in% names(dat))) {
  log_error(
    "Falha em validate columns: colunas obrigatorias ausentes. Esperado: 'observed', 'predicted'. Encontrado: %s\nCausa provavel: cabecalho do CSV nao padronizado\nVerifique: que o arquivo tem colunas 'observed' (0/1) e 'predicted' (probabilidade)\nSkill anterior: species-distribution-modelling",
    paste(names(dat), collapse = ", ")
  )
  stop("Required columns 'observed' and 'predicted' not found.")
}

log_info("Loaded %d predictions. Prevalence: %.3f", nrow(dat), mean(dat$observed))

n_pos <- sum(dat$observed == 1)
n_neg <- sum(dat$observed == 0)
log_decision("evaluation_approach", "AUC + MaxTSS + calibration", "standard triad for binary SDM evaluation")
log_info("Presences: %d | Absences: %d", n_pos, n_neg)

if (n_pos < 10) {
  log_warn("Only %d presence records. AUC and TSS estimates will be highly uncertain with so few presences.", n_pos)
}
if (n_neg < 10) {
  log_warn("Only %d absence/background records. Consider increasing background sample size.", n_neg)
}

if (any(dat$predicted < 0 | dat$predicted > 1, na.rm = TRUE)) {
  log_warn("Some predicted values are outside [0, 1]. Check that predictions are probabilities.")
}

log_step(3, "Compute AUC-ROC")
tryCatch({
  roc_data <- dat |> arrange(desc(predicted))
  roc_data$tpr <- cumsum(roc_data$observed == 1) / n_pos
  roc_data$fpr <- cumsum(roc_data$observed == 0) / n_neg
  auc <- abs(sum(diff(roc_data$fpr) * (roc_data$tpr[-1] + roc_data$tpr[-nrow(roc_data)]) / 2))
  log_info("AUC-ROC: %.3f", auc)
  if (auc < 0.7) {
    log_warn("AUC = %.3f is below 0.70. Model discrimination is poor. Consider revisiting predictors or sampling design.", auc)
  }
}, error = function(e) {
  log_error(
    "Falha em AUC-ROC: %s\nCausa provavel: valores NA em 'observed' ou 'predicted', ou apenas uma classe\nVerifique: que 'observed' contem 0 e 1 e 'predicted' nao tem NA\nSkill anterior: species-distribution-modelling",
    conditionMessage(e)
  )
  stop(e)
})

log_step(4, "Compute MaxTSS and optimal threshold")
log_decision("threshold_method", "MaxTSS", "maximises sensitivity + specificity; robust for SDMs")
tryCatch({
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
  log_info("MaxTSS: %.3f at threshold: %.2f", best_tss, best_thresh)
  if (best_tss < 0.4) {
    log_warn("MaxTSS = %.3f is low. Model may have poor predictive performance.", best_tss)
  }
}, error = function(e) {
  log_error(
    "Falha em TSS computation: %s\nCausa provavel: valores NA ou classe unica em 'observed'\nVerifique: que 'observed' contem tanto 0 quanto 1\nSkill anterior: species-distribution-modelling",
    conditionMessage(e)
  )
  stop(e)
})

log_step(5, "Save performance metrics")
tryCatch({
  metrics <- data.frame(
    metric = c("AUC-ROC", "MaxTSS", "Threshold_MaxTSS"),
    value  = round(c(auc, best_tss, best_thresh), 4)
  )
  write.csv(metrics, file.path(output_dir, "performance_metrics.csv"), row.names = FALSE)
  log_info("Performance metrics saved.")
}, error = function(e) {
  log_error(
    "Falha em save metrics: %s\nCausa provavel: diretorio sem permissao de escrita\nVerifique: output_dir e permissoes do sistema de arquivos\nSkill anterior: model-validation-and-uncertainty (metrics computation)",
    conditionMessage(e)
  )
  stop(e)
})

log_step(6, "Generate calibration plot")
tryCatch({
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
  log_info("Calibration plot written.")
}, error = function(e) {
  log_error(
    "Falha em calibration plot: %s\nCausa provavel: dados insuficientes por bin ou valores extremos de predicao\nVerifique: distribuicao dos valores preditos e numero de registros\nSkill anterior: model-validation-and-uncertainty (metrics computation)",
    conditionMessage(e)
  )
  stop(e)
})
