# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript run_ensemble_sdm.R <occurrences.csv> <predictors_stack.tif> <study_area.shp> <output_dir>

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "species-distribution-modeling"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

# Fit MaxEnt + BRT + RF ensemble SDM
# Usage: Rscript run_ensemble_sdm.R <params_yaml> <output_dir>
# Requires: terra, sf, maxnet, gbm, randomForest, dismo, blockCV, yaml

suppressPackageStartupMessages({
  library(terra); library(sf); library(maxnet)
  library(gbm); library(randomForest); library(yaml)
})

log_step(1, "Analisar argumentos e carregar parametros YAML")
args       <- commandArgs(trailingOnly = TRUE)
params_f   <- ifelse(length(args) >= 1, args[1], "params.yaml")
output_dir <- ifelse(length(args) >= 2, args[2], "outputs/sdm")

log_info("Script: run_ensemble_sdm.R | Skill: %s", SKILL_NAME)
log_info("Params file : %s", params_f)
log_info("Output dir  : %s", output_dir)

# ── Input precondition check ──────────────────────────────────────────────────
if (!file.exists(params_f)) {
  log_error(
    "Input nao encontrado: %s\nCausa provavel: arquivo nao gerado pelo passo anterior.\nVerifique a saida de: species-distribution-modeling (tune_maxnet ou prepare_future_layers)\nSkill anterior: species-distribution-modeling",
    params_f
  )
  stop("Missing: ", params_f)
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
log_info("Diretorio de saida pronto: %s", output_dir)

log_step(2, "Ler parametros do arquivo YAML")
p <- tryCatch({
  yaml::read_yaml(params_f)
}, error = function(e) {
  log_error(
    "Falha ao ler arquivo YAML '%s': %s\nCausa provavel: YAML malformado ou encoding incorreto.\nVerifique a sintaxe do arquivo.\nSkill anterior: species-distribution-modeling",
    params_f, conditionMessage(e)
  )
  stop(e)
})

set.seed(p$random_seeds$global)
log_decision("random_seed", p$random_seeds$global, "semente global definida no params.yaml para reprodutibilidade")
log_decision("algorithms",  paste(p$modeling$algorithms, collapse = ","), "algoritmos definidos em params.yaml$modeling$algorithms")
log_decision("cv_method",   p$modeling$cv_method, "metodo de validacao cruzada definido em params.yaml")
log_decision("cv_folds",    p$modeling$cv_folds,  "numero de folds definido em params.yaml")

log_info("=== SDM Ensemble Pipeline ===")
log_info("Output    : %s", output_dir)
log_info("Algoritmos: %s", paste(p$modeling$algorithms, collapse = ", "))
log_info("CV method : %s | Folds: %d", p$modeling$cv_method, p$modeling$cv_folds)

# NOTE: This is a scaffold. Load your data and call your modeling functions below.
# Example structure:
#
# occ    <- read.csv("data/processed/occ_thinned.csv")
# bg     <- read.csv("data/processed/background.csv")
# stack  <- rast("data/predictors_stack.tif")
# predictors <- readLines("outputs/selected_predictors.txt")
#
# occ_env <- extract(stack[[predictors]], occ[, c("decimalLongitude","decimalLatitude")])
# bg_env  <- extract(stack[[predictors]], bg[, c("lon","lat")])
#
# train_df <- rbind(
#   cbind(pa = 1, occ_env),
#   cbind(pa = 0, bg_env)
# ) |> na.omit()
#
# # MaxEnt
# mx <- maxnet(p = train_df$pa, data = train_df[,-1],
#              regmult = p$hyperparameters$maxnet$regularization_multiplier[2])
#
# # Predict and ensemble — see biomod2 for full ensemble workflow

log_step(3, "Scaffold carregado — preencher com carregamento de dados e chamadas de modelo")
tryCatch({
  log_info("Scaffold carregado. Adicione o carregamento de dados e as chamadas de modelo para seu estudo.")
}, error = function(e) {
  log_error(
    "Falha no bloco principal do scaffold: %s\nCausa provavel: erro de configuracao ou dados ausentes.\nVerifique os arquivos de dados e o params.yaml.\nSkill anterior: species-distribution-modeling",
    conditionMessage(e)
  )
  stop(e)
})
