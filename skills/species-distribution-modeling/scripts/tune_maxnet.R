# Usage: Rscript tune_maxnet.R <points_with_env_csv> <output_dir> [rm_values] [fc_values]

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "species-distribution-modeling"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

#
# Arguments:
#   points_with_env_csv : CSV with columns decimalLongitude, decimalLatitude + env variables
#   output_dir          : Directory to write all outputs (created if absent)
#   rm_values           : Optional comma-separated RM grid (default: "0.5,1,1.5,2,3,4,6")
#   fc_values           : Optional comma-separated FC grid (default: "L,LQ,LQH,LQHP,LQHPT")
#
# Outputs:
#   calibration_results.csv  — all 35 model combinations with metrics
#   best_model_params.csv    — models selected by OR_AICc criterion
#   calibration_plot.png     — delta_AICc × OR10 scatterplot
#   best_maxnet.rds          — fitted maxnet model with best parameters

suppressPackageStartupMessages(library(ENMeval))
suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))

# ── 1. Parse arguments ──────────────────────────────────────────────────────
log_step(1, "Analisar argumentos da linha de comando")
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  # Defaults for interactive/test use
  occ_csv    <- "tests/data/points_with_env.csv"
  output_dir <- "output/sdm_calibration"
  rm_vals    <- c(0.5, 1, 1.5, 2, 3, 4, 6)
  fc_vals    <- c("L", "LQ", "LQH", "LQHP", "LQHPT")
  log_warn("Menos de 2 argumentos. Usando valores padrao para teste interativo.")
} else {
  occ_csv    <- args[1]
  output_dir <- args[2]
  rm_vals    <- if (length(args) >= 3) as.numeric(strsplit(args[3], ",")[[1]]) else c(0.5, 1, 1.5, 2, 3, 4, 6)
  fc_vals    <- if (length(args) >= 4) strsplit(args[4], ",")[[1]] else c("L", "LQ", "LQH", "LQHP", "LQHPT")
}

log_info("Script: tune_maxnet.R | Skill: %s", SKILL_NAME)
log_info("OCC CSV    : %s", occ_csv)
log_info("Output dir : %s", output_dir)

# ── Input precondition check ──────────────────────────────────────────────────
if (!file.exists(occ_csv)) {
  log_error(
    "Input nao encontrado: %s\nCausa provavel: arquivo nao gerado pelo passo anterior.\nVerifique a saida de: ecological-data-foundation (clean_occurrences)\nSkill anterior: ecological-data-foundation",
    occ_csv
  )
  stop("Missing: ", occ_csv)
}

# ── 2. Create output directory ───────────────────────────────────────────────
log_step(2, "Criar diretorio de saida")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
log_info("Diretorio de saida pronto: %s", output_dir)

log_decision("rm_vals", paste(rm_vals, collapse = ","), "grade de multiplicadores de regularizacao para busca em grade MaxEnt")
log_decision("fc_vals", paste(fc_vals, collapse = ","), "grade de classes de features para busca em grade MaxEnt")
log_decision("total_models", length(rm_vals) * length(fc_vals), "numero total de combinacoes RM x FC")

# ── 3. Load occurrence data ──────────────────────────────────────────────────
log_step(3, "Carregar dados de ocorrencia com variaveis ambientais")
tryCatch({
  occ_data <- read.csv(occ_csv)
  log_info("Registros carregados: %d | Colunas: %d", nrow(occ_data), ncol(occ_data))
}, error = function(e) {
  log_error(
    "Falha ao ler CSV de ocorrencias '%s': %s\nCausa provavel: arquivo corrompido ou formato invalido.\nVerifique: %s\nSkill anterior: ecological-data-foundation",
    occ_csv, conditionMessage(e), occ_csv
  )
  stop(e)
})

# Identify coordinate columns (standard names)
lon_col <- intersect(c("decimalLongitude", "longitude", "lon", "x"), names(occ_data))[1]
lat_col <- intersect(c("decimalLatitude",  "latitude",  "lat", "y"), names(occ_data))[1]

if (is.na(lon_col) || is.na(lat_col)) {
  log_error(
    "Colunas de coordenadas nao encontradas.\nEsperadas: decimalLongitude/decimalLatitude (ou longitude/latitude, lon/lat, x/y).\nColunas presentes: %s\nCausa provavel: CSV nao processado por clean_occurrences.\nSkill anterior: ecological-data-foundation",
    paste(names(occ_data), collapse = ", ")
  )
  stop("Cannot find coordinate columns. Expected: decimalLongitude/decimalLatitude")
}

log_info("Coluna de longitude: '%s' | Coluna de latitude: '%s'", lon_col, lat_col)
occ_pts <- occ_data[, c(lon_col, lat_col)]
names(occ_pts) <- c("x", "y")

# Environmental predictor columns = everything except coordinates and species metadata
meta_cols <- c(lon_col, lat_col, "species", "scientificName", "gbifID",
               "occurrenceID", "datasetKey")
env_cols  <- setdiff(names(occ_data), meta_cols)

log_info("Registros de ocorrencia: %d", nrow(occ_pts))
log_info("Variaveis ambientais (%d): %s", length(env_cols), paste(env_cols, collapse = ", "))

if (nrow(occ_pts) < 10) {
  log_error(
    "Registros de ocorrencia insuficientes (%d). Minimo requerido: 10.\nCausa provavel: filtragem excessiva em clean_occurrences ou especie com distribuicao muito restrita.\nSkill anterior: ecological-data-foundation",
    nrow(occ_pts)
  )
  stop("Too few occurrences (", nrow(occ_pts), ") for calibration. Minimum required: 10")
}

if (nrow(occ_pts) < 30) {
  log_warn(
    "Poucos registros de ocorrencia (%d). Resultados de calibracao podem ser instáveis. Recomendado: >= 30.",
    nrow(occ_pts)
  )
}

# ── 4. Build environmental SpatRaster from occurrence columns ────────────────
log_step(4, "Preparar dados ambientais e pontos de background")
# When a raster stack is not provided, construct a mock raster for ENMeval
# using the env values in the CSV. In full use, load a real raster stack instead.
log_warn("Construindo background a partir de valores env no CSV. Para uso em producao, use um SpatRaster real.")

env_mat <- as.matrix(occ_data[, env_cols])

# Background: if CSV has a 'background' column flagging bg points, use them;
# otherwise use a random sample of all non-occurrence rows.
if ("type" %in% names(occ_data)) {
  bg_idx  <- occ_data$type == "background"
  bg_pts  <- occ_data[bg_idx, c(lon_col, lat_col)]
  bg_env  <- occ_data[bg_idx, env_cols]
  occ_env <- occ_data[!bg_idx, env_cols]
  log_info("Coluna 'type' encontrada. Usando %d pontos de background definidos.", sum(bg_idx))
  log_decision("background_source", "type column", "coluna 'type' presente no CSV define pontos de background")
} else {
  # Use all points as both occurrences and generate background by jittering
  # In production: load bg from a proper background CSV
  log_warn("Coluna 'type' ausente. Gerando pseudo-background por jitter. Use um CSV de background real em producao.")
  log_decision("background_source", "jitter", "coluna 'type' ausente; pseudo-background gerado por jitter aleatorio")
  set.seed(42)
  n_bg   <- min(10000, nrow(occ_data) * 10)
  bg_pts <- data.frame(
    x = occ_pts$x + runif(n_bg, -2, 2),
    y = occ_pts$y + runif(n_bg, -2, 2)
  )
  bg_env  <- occ_data[sample(nrow(occ_data), n_bg, replace = TRUE), env_cols]
  occ_env <- occ_data[, env_cols]
  log_info("Pseudo-background gerado: %d pontos", n_bg)
}

names(bg_pts) <- c("x", "y")

# ── 5. Run ENMeval grid search ───────────────────────────────────────────────
log_step(5, "Executar busca em grade ENMeval (MaxNet)")
log_info("Valores de RM  : %s", paste(rm_vals, collapse = ", "))
log_info("Valores de FC  : %s", paste(fc_vals, collapse = ", "))
log_info("Total de modelos: %d", length(rm_vals) * length(fc_vals))
log_decision(
  "partitions", "block",
  "particao espacial por blocos geograficos — evita inflacao de AUC por autocorrelacao espacial"
)

# ENMevaluate with maxnet and spatial block CV
# block partitioning divides geographic space into quadrants for spatial CV
eval_out <- tryCatch({
  ENMevaluate(
    occs       = occ_pts,
    envs       = NULL,          # using occs.testing below when envs is NULL
    bg         = bg_pts,
    occs.testing = NULL,
    algorithm  = "maxnet",
    partitions = "block",       # spatial cross-validation — avoids autocorrelation inflation
    tune.args  = list(
      rm = rm_vals,
      fc = fc_vals
    ),
    other.settings = list(
      abs.auc.diff = FALSE
    ),
    occs.grp   = NULL,
    bg.grp     = NULL
  )
}, error = function(e) {
  log_error(
    "Falha em ENMevaluate: %s\nCausa provavel: dados ambientais insuficientes, pacote ENMeval nao instalado, ou pontos de ocorrencia fora do extent dos preditores.\nVerifique: install.packages('ENMeval') e a qualidade dos dados de entrada.\nSkill anterior: ecological-data-foundation",
    conditionMessage(e)
  )
  stop(e)
})

log_info("Calibracao ENMeval concluida.")

# ── 6. Extract and process results table ─────────────────────────────────────
log_step(6, "Extrair e processar tabela de resultados da calibracao")
tryCatch({
  res <- eval.results(eval_out)

  # Compute delta_AICc relative to the best (lowest AICc) model
  res$delta.AICc <- res$AICc - min(res$AICc, na.rm = TRUE)

  # Rename for clarity
  res <- res %>%
    rename(
      OR10 = or.10p.avg,
      AUC_train = auc.train,
      AUC_val   = auc.val.avg
    ) %>%
    arrange(delta.AICc)

  # Save full calibration table
  calib_path <- file.path(output_dir, "calibration_results.csv")
  write.csv(res, calib_path, row.names = FALSE)
  log_info("Gravado: %s", calib_path)
}, error = function(e) {
  log_error(
    "Falha ao extrair resultados da calibracao: %s\nCausa provavel: objeto ENMeval com estrutura inesperada ou colunas renomeadas na versao do pacote.\nVerifique a versao do ENMeval instalada.\nSkill anterior: species-distribution-modeling",
    conditionMessage(e)
  )
  stop(e)
})

# ── 7. Select best models by OR_AICc criterion ───────────────────────────────
log_step(7, "Selecionar melhores modelos pelo criterio OR_AICc")
# Rule: OR10 <= 0.15 (allows slight tolerance above 0.10 expected)
#       AND delta_AICc < 2 (equivalent models by Burnham & Anderson)
or_threshold   <- 0.15
aicc_threshold <- 2

log_decision("or_threshold",   or_threshold,   "tolerancia acima de 0.10 conforme Anderson et al. 2010")
log_decision("aicc_threshold", aicc_threshold, "modelos equivalentes por Burnham & Anderson 2002 (delta_AICc < 2)")

best_models <- tryCatch({
  bm <- res %>%
    filter(OR10 <= or_threshold, delta.AICc < aicc_threshold) %>%
    arrange(OR10, delta.AICc)

  if (nrow(bm) == 0) {
    # Fallback: relax OR threshold and take AICc-best model
    log_warn(
      "Nenhum modelo atende OR10 <= %.2f E delta_AICc < %.1f. Usando modelo com menor AICc como fallback.",
      or_threshold, aicc_threshold
    )
    log_decision(
      "selection_fallback", "aicc_best",
      "nenhum modelo no quadrante ideal; selecionado o melhor por AICc para prosseguir"
    )
    bm <- res[1, ]
  } else {
    log_info("%d modelo(s) atendem ao criterio OR_AICc.", nrow(bm))
  }
  bm
}, error = function(e) {
  log_error(
    "Falha ao selecionar melhores modelos: %s\nCausa provavel: colunas OR10 ou AICc ausentes na tabela de resultados.\nSkill anterior: species-distribution-modeling",
    conditionMessage(e)
  )
  stop(e)
})

best_path <- file.path(output_dir, "best_model_params.csv")
write.csv(best_models, best_path, row.names = FALSE)
log_info("Gravado: %s", best_path)
log_info("Melhores modelos (primeiras linhas):")
message(capture.output(print(best_models[, c("tune.args.rm", "tune.args.fc", "OR10", "AICc", "delta.AICc")])))

# ── 8. Calibration plot ───────────────────────────────────────────────────────
log_step(8, "Gerar grafico de calibracao (delta_AICc x OR10)")
tryCatch({
  p <- ggplot(res, aes(x = delta.AICc, y = OR10,
                        colour = tune.args.fc, size = tune.args.rm)) +
    geom_point(alpha = 0.8) +
    geom_hline(yintercept = or_threshold, linetype = "dashed", colour = "red",
               linewidth = 0.7) +
    geom_vline(xintercept = aicc_threshold, linetype = "dashed", colour = "blue",
               linewidth = 0.7) +
    annotate("text", x = aicc_threshold + 0.5, y = max(res$OR10) * 0.95,
             label = "delta_AICc = 2", colour = "blue", hjust = 0, size = 3) +
    annotate("text", x = max(res$delta.AICc) * 0.7, y = or_threshold + 0.005,
             label = "OR10 = 0.15", colour = "red", size = 3) +
    labs(
      title    = "MaxEnt Calibration: OR10 vs delta_AICc",
      subtitle = "Lower-left quadrant = best models (low omission + parsimonious)",
      x        = "delta AICc (relative to best model)",
      y        = "OR10 (omission rate at 10% training threshold)",
      colour   = "Feature Class",
      size     = "Regularization Multiplier"
    ) +
    theme_bw(base_size = 12)

  plot_path <- file.path(output_dir, "calibration_plot.png")
  ggsave(plot_path, p, width = 10, height = 7, dpi = 150)
  log_info("Gravado: %s", plot_path)
}, error = function(e) {
  log_error(
    "Falha ao gerar grafico de calibracao: %s\nCausa provavel: pacote ggplot2 nao instalado ou colunas ausentes na tabela de resultados.\nVerifique: install.packages('ggplot2')\nSkill anterior: species-distribution-modeling",
    conditionMessage(e)
  )
  stop(e)
})

# ── 9. Fit final model with best parameters ────────────────────────────────
log_step(9, "Ajustar modelo final com os melhores parametros")
best_rm <- best_models$tune.args.rm[1]
best_fc <- best_models$tune.args.fc[1]
log_info("Ajustando modelo final: RM = %s | FC = %s", best_rm, best_fc)
log_decision("final_rm", best_rm, "RM do modelo de melhor desempenho no criterio OR_AICc")
log_decision("final_fc", best_fc, "FC do modelo de melhor desempenho no criterio OR_AICc")

tryCatch({
  # Retrieve the fitted model object from ENMeval results
  best_idx <- which(res$tune.args.rm == best_rm & res$tune.args.fc == best_fc)[1]
  best_model_obj <- eval.models(eval_out)[[best_idx]]

  # Save as RDS for downstream projection
  rds_path <- file.path(output_dir, "best_maxnet.rds")
  saveRDS(best_model_obj, rds_path)
  log_info("Gravado: %s", rds_path)
}, error = function(e) {
  log_error(
    "Falha ao ajustar ou salvar modelo final: %s\nCausa provavel: indice do modelo nao encontrado nos resultados ENMeval ou erro ao serializar o objeto.\nSkill anterior: species-distribution-modeling",
    conditionMessage(e)
  )
  stop(e)
})

# ── 10. Summary ──────────────────────────────────────────────────────────────
log_step(10, "Exibir resumo da calibracao")
log_info("========== RESUMO DA CALIBRACAO ==========")
log_info("Modelos avaliados      : %d", nrow(res))
log_info("Modelos OR_AICc-ok     : %d", nrow(best_models))
log_info("RM selecionado         : %s", best_rm)
log_info("FC selecionado         : %s", best_fc)
log_info("Melhor OR10            : %.3f", best_models$OR10[1])
log_info("Melhor AUC (val)       : %.3f", best_models$AUC_val[1])
log_info("Melhor delta_AICc      : %.3f", best_models$delta.AICc[1])
log_info("==========================================")
