# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript tradeoff_analysis.R <es_summary_table.csv> <output_dir>
# ES trade-off and synergy analysis across pixels or land cover units
# Usage: Rscript tradeoff_analysis.R <es_summary_csv> <output_dir>
# Requires: dplyr, ggplot2, corrplot, tidyr

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "ecosystem-services-assessment"
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
  library(corrplot)
  library(tidyr)
})

args       <- commandArgs(trailingOnly = TRUE)
es_file    <- ifelse(length(args) >= 1, args[1], "outputs/ecosystem_services/es_summary_table.csv")
output_dir <- ifelse(length(args) >= 2, args[2], "outputs/ecosystem_services")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_info("Skill: %s | es_file=%s | output_dir=%s", SKILL_NAME, es_file, output_dir)

# ── Input precondition check ──────────────────────────────────────────────────
if (!file.exists(es_file)) {
  log_error(
    "Input not found: %s\nProbable cause: o script de quantificacao de servicos ecossistemicos nao foi executado ou o caminho esta errado.\nCheck: execute primeiro o script de mapeamento/quantificacao de ES.\nPrevious skill: ecosystem-services-assessment (quantification step).",
    es_file
  )
  stop("Missing: ", es_file)
}

log_step(1, "Load ecosystem services table")
es <- tryCatch({
  read.csv(es_file)
}, error = function(e) {
  log_error(
    "Failed to read CSV de servicos ecossistemicos: %s\nProbable cause: corrupted file ou com separador incorreto.\nCheck: abra o arquivo em editor de texto e confira o formato.\nPrevious skill: ecosystem-services-assessment (quantification step).",
    conditionMessage(e)
  )
  stop(e)
})

log_info("ES table loaded: %d land use classes", nrow(es))

n_na_total <- sum(is.na(es))
if (n_na_total > 0) {
  log_warn("ES table contains %d NA values total — correlations will be computed with 'complete.obs'.", n_na_total)
}

# ── Identify numeric ES columns ───────────────────────────────────────────────
log_step(2, "Identify ES indicator columns and normalise 0-1")
es_cols <- names(es)[sapply(es, is.numeric) & !names(es) %in% c("lulc_code", "n_pixels")]
log_info("ES indicators: %s", paste(es_cols, collapse = ", "))
log_decision("es_cols", paste(es_cols, collapse = ", "),
             "colunas numericas excluindo lulc_code e n_pixels sao tratadas como indicadores de ES")

if (length(es_cols) < 2) {
  log_warn("Fewer than 2 ES indicators found — trade-off analysis not possible with only %d column(s).", length(es_cols))
  log_info("Exiting without error. Add more indicators to the input CSV.")
  quit(status = 0)
}

# ── Normalise to 0-1 ──────────────────────────────────────────────────────────
es_norm <- tryCatch({
  es |>
    mutate(across(all_of(es_cols),
                  ~ (. - min(., na.rm=TRUE)) / (max(., na.rm=TRUE) - min(., na.rm=TRUE) + 1e-10)))
}, error = function(e) {
  log_error(
    "Failed to normalise indicators 0-1: %s\nProbable cause: non-numeric columns incorrectly identified as indicators.\nCheck: column types in the input CSV.\nPrevious skill: ecosystem-services-assessment (quantification step).",
    conditionMessage(e)
  )
  stop(e)
})

log_decision("normalization", "min-max [0,1] with epsilon 1e-10",
             "evita divisao por zero quando todos os valores de um indicador sao iguais")

# ── Correlation matrix (Spearman) ─────────────────────────────────────────────
log_step(3, "Compute Spearman correlation matrix among ES indicators")
cor_mat <- tryCatch({
  cor(es_norm[es_cols], method = "spearman", use = "complete.obs")
}, error = function(e) {
  log_error(
    "Failed to compute correlation matrix: %s\nProbable cause: all values in some column are NA after normalisation.\nCheck: presence of variation in ES indicators.\nPrevious skill: ecosystem-services-assessment (quantification step).",
    conditionMessage(e)
  )
  stop(e)
})

log_decision("correlation_method", "Spearman",
             "metodo nao-parametrico robusto a distribuicoes assimetricas comuns em dados de ES")

tryCatch({
  write.csv(as.data.frame(cor_mat), file.path(output_dir, "tradeoff_matrix.csv"))
  log_info("tradeoff_matrix.csv saved in: %s", output_dir)
}, error = function(e) {
  log_error(
    "Failed to salvar tradeoff_matrix.csv: %s\nProbable cause: permissao negada ou disco cheio.\nCheck: permissoes do output directory.\nPrevious skill: [none].",
    conditionMessage(e)
  )
  stop(e)
})

# ── Correlation heatmap ────────────────────────────────────────────────────────
log_step(4, "Generate trade-off heatmap (corrplot)")
tryCatch({
  png(file.path(output_dir, "tradeoff_heatmap.png"), width = 800, height = 700, res = 150)
  corrplot(cor_mat, method = "color", type = "upper", tl.cex = 0.8,
           addCoef.col = "black", number.cex = 0.7, cl.cex = 0.7,
           title = "ES Trade-offs (Spearman r)", mar = c(0, 0, 2, 0))
  dev.off()
  log_info("tradeoff_heatmap.png saved in: %s", output_dir)
}, error = function(e) {
  log_error(
    "Failed to generate heatmap de trade-offs: %s\nProbable cause: corrplot not installed ou matriz de correlacao invalida.\nCheck: se o pacote corrplot esta disponivel e a matriz tem pelo menos 2 variaveis.\nPrevious skill: [none].",
    conditionMessage(e)
  )
  stop(e)
})

# ── Scatter plots for top pairs ───────────────────────────────────────────────
log_step(5, "Generate scatter plots for ES indicator pairs")
pair_combos <- combn(es_cols, 2, simplify = FALSE)
n_pairs     <- min(6, length(pair_combos))
log_info("Generating %d scatter plots (of %d possible pairs)", n_pairs, length(pair_combos))
log_decision("max_scatter_plots", as.character(n_pairs),
             "limitado a 6 pares para evitar geracao excessiva de arquivos")

for (pr in pair_combos[seq_len(n_pairs)]) {
  tryCatch({
    p <- ggplot(es |> mutate(label = lulc_code),
                aes(x = .data[[pr[1]]], y = .data[[pr[2]]], label = label)) +
      geom_point(size = 3, colour = "#2166ac") +
      ggrepel::geom_text_repel(size = 2.5, max.overlaps = 10) +
      labs(x = pr[1], y = pr[2],
           title = paste("Trade-off:", pr[1], "vs", pr[2])) +
      theme_bw()
    fname <- paste0("scatter_", pr[1], "_vs_", pr[2], ".png")
    ggsave(file.path(output_dir, fname), p, width = 5, height = 4, dpi = 150)
    log_info("Saved: %s", fname)
  }, error = function(e) {
    log_error(
      "Failed to generate scatter plot for pair %s vs %s: %s\nProbable cause: column missing after filtering or ggrepel error.\nCheck: columns '%s' and '%s' exist and have valid data.\nPrevious skill: [none].",
      pr[1], pr[2], conditionMessage(e), pr[1], pr[2]
    )
    stop(e)
  })
}

log_info("Trade-off analysis completed. Outputs in: %s", output_dir)
