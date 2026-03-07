# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript collinearity_check.R <predictors.csv> <output_dir> [vif_threshold] [cor_threshold]
# Assess and reduce predictor collinearity
# Usage: Rscript collinearity_check.R <env_matrix_csv> <output_dir> [vif_threshold]
# Requires: usdm, corrplot, dplyr

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "predictive-modeling-best-practices"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages({
  library(usdm)
  library(dplyr)
})

args          <- commandArgs(trailingOnly = TRUE)
env_file      <- ifelse(length(args) >= 1, args[1], "data/processed/env_matrix.csv")
output_dir    <- ifelse(length(args) >= 2, args[2], "outputs")
vif_threshold <- ifelse(length(args) >= 3, as.numeric(args[3]), 5)

# ── Input precondition checks ─────────────────────────────────────────────────
if (!file.exists(env_file)) {
  log_error("Input nao encontrado: %s\nCausa provavel: passo anterior nao concluiu.\nVerifique: outputs do skill anterior.\nSkill anterior: species-distribution-modeling", env_file)
  stop("Missing input: ", env_file)
}

log_decision("vif_threshold", vif_threshold, "VIF threshold for stepwise predictor exclusion; standard ecological threshold is 5 or 10")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Load ───────────────────────────────────────────────────────────────────
log_step(1, "Load environmental predictor matrix")
tryCatch({
  log_info("Loading: %s", env_file)
  env <- read.csv(env_file) |> na.omit()
  log_info("Variables: %d | Rows: %d", ncol(env), nrow(env))

  if (nrow(env) < 30) {
    log_warn("Numero de linhas baixo (%d). Estimativas de correlacao podem ser instáveis com n < 30.", nrow(env))
  }
  if (ncol(env) < 2) {
    log_error("Apenas %d variavel encontrada. Analise de colinearidade requer pelo menos 2 preditores.\nCausa provavel: CSV incorreto ou sem preditores numericos.\nVerifique: formato do arquivo env_matrix_csv.\nSkill anterior: species-distribution-modeling", ncol(env))
    stop("At least 2 predictor columns required for collinearity analysis.")
  }
}, error = function(e) {
  log_error("Falha em load_env_matrix: %s\nCausa provavel: arquivo CSV ausente, malformado ou sem colunas numericas.\nVerifique: caminho e formato do CSV de preditores.\nSkill anterior: species-distribution-modeling", conditionMessage(e))
  stop(e)
})

# ── Pairwise correlation ───────────────────────────────────────────────────
log_step(2, "Compute pairwise Pearson correlations")
tryCatch({
  cor_mat <- cor(env, method = "pearson")
  high_cor <- which(abs(cor_mat) > 0.7 & cor_mat != 1, arr.ind = TRUE)
  high_cor_pairs <- data.frame(
    var1 = rownames(high_cor),
    var2 = colnames(cor_mat)[high_cor[, 2]],
    r    = cor_mat[high_cor]
  ) |> filter(var1 < var2) |> arrange(desc(abs(r)))

  log_info("Highly correlated pairs (|r| > 0.7): %d pairs found.", nrow(high_cor_pairs))
  if (nrow(high_cor_pairs) > 0) {
    log_warn("%d pares de preditores altamente correlacionados (|r| > 0.70) detectados. Reducao de colinearidade necessaria.", nrow(high_cor_pairs))
    log_info("Highly correlated pairs:\n%s",
             paste(capture.output(print(high_cor_pairs)), collapse = "\n"))
  }
}, error = function(e) {
  log_error("Falha em pairwise_correlation: %s\nCausa provavel: colunas nao numericas ou valores NA remanescentes.\nVerifique: tipos de dados do CSV e resultado do na.omit.\nSkill anterior: species-distribution-modeling", conditionMessage(e))
  stop(e)
})

# ── VIF stepwise reduction ─────────────────────────────────────────────────
log_step(3, "VIF stepwise predictor reduction")
tryCatch({
  log_info("Running VIF stepwise reduction (threshold: %g)...", vif_threshold)
  vif_result <- vifstep(env, th = vif_threshold)
  log_info("Variables retained after VIF reduction:\n%s",
           paste(capture.output(print(vif_result)), collapse = "\n"))

  selected <- vif_result@results$Variables
  log_info("Final selected predictors (%d): %s", length(selected), paste(selected, collapse = ", "))
  log_decision("selected_predictors", paste(selected, collapse = ", "),
               paste0("VIF stepwise retained these predictors below threshold ", vif_threshold))

  n_removed <- ncol(env) - length(selected)
  if (n_removed > 0) {
    log_warn("%d preditores removidos por VIF > %g. Revise se variaveis ecologicamente importantes foram excluidas.", n_removed, vif_threshold)
  }
}, error = function(e) {
  log_error("Falha em vif_stepwise_reduction: %s\nCausa provavel: matriz singular, preditores constantes, ou falha no pacote usdm.\nVerifique: variancia de cada preditor e instalacao do pacote usdm.\nSkill anterior: species-distribution-modeling", conditionMessage(e))
  stop(e)
})

# ── Outputs ────────────────────────────────────────────────────────────────
log_step(4, "Write collinearity outputs")
tryCatch({
  write.csv(high_cor_pairs, file.path(output_dir, "high_correlation_pairs.csv"), row.names = FALSE)
  write.csv(vif_result@results, file.path(output_dir, "vif_results.csv"), row.names = FALSE)
  writeLines(selected, file.path(output_dir, "selected_predictors.txt"))
  log_info("Outputs written to: %s", output_dir)
}, error = function(e) {
  log_error("Falha em write_outputs: %s\nCausa provavel: permissoes de escrita ou diretorio de saida inexistente.\nVerifique: output_dir e permissoes do sistema de arquivos.\nSkill anterior: species-distribution-modeling", conditionMessage(e))
  stop(e)
})
