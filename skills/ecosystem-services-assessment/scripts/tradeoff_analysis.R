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
    "Input nao encontrado: %s\nCausa provavel: o script de quantificacao de servicos ecossistemicos nao foi executado ou o caminho esta errado.\nVerifique: execute primeiro o script de mapeamento/quantificacao de ES.\nSkill anterior: ecosystem-services-assessment (quantification step).",
    es_file
  )
  stop("Missing: ", es_file)
}

log_step(1, "Carregar tabela de servicos ecossistemicos")
es <- tryCatch({
  read.csv(es_file)
}, error = function(e) {
  log_error(
    "Falha ao ler CSV de servicos ecossistemicos: %s\nCausa provavel: arquivo corrompido ou com separador incorreto.\nVerifique: abra o arquivo em editor de texto e confira o formato.\nSkill anterior: ecosystem-services-assessment (quantification step).",
    conditionMessage(e)
  )
  stop(e)
})

log_info("Tabela de ES carregada: %d classes de uso do solo", nrow(es))

n_na_total <- sum(is.na(es))
if (n_na_total > 0) {
  log_warn("Tabela de ES contem %d valores NA no total — correlacoes serao calculadas com 'complete.obs'.", n_na_total)
}

# ── Identify numeric ES columns ───────────────────────────────────────────────
log_step(2, "Identificar colunas de indicadores de ES e normalizar 0-1")
es_cols <- names(es)[sapply(es, is.numeric) & !names(es) %in% c("lulc_code", "n_pixels")]
log_info("Indicadores de ES: %s", paste(es_cols, collapse = ", "))
log_decision("es_cols", paste(es_cols, collapse = ", "),
             "colunas numericas excluindo lulc_code e n_pixels sao tratadas como indicadores de ES")

if (length(es_cols) < 2) {
  log_warn("Menos de 2 indicadores de ES encontrados — analise de trade-off nao e possivel com apenas %d coluna(s).", length(es_cols))
  log_info("Encerrando sem erro. Adicione mais indicadores ao CSV de entrada.")
  quit(status = 0)
}

# ── Normalise to 0-1 ──────────────────────────────────────────────────────────
es_norm <- tryCatch({
  es |>
    mutate(across(all_of(es_cols),
                  ~ (. - min(., na.rm=TRUE)) / (max(., na.rm=TRUE) - min(., na.rm=TRUE) + 1e-10)))
}, error = function(e) {
  log_error(
    "Falha na normalizacao 0-1 dos indicadores: %s\nCausa provavel: colunas nao numericas identificadas incorretamente.\nVerifique: os tipos de coluna no CSV de entrada.\nSkill anterior: ecosystem-services-assessment (quantification step).",
    conditionMessage(e)
  )
  stop(e)
})

log_decision("normalization", "min-max [0,1] com epsilon 1e-10",
             "evita divisao por zero quando todos os valores de um indicador sao iguais")

# ── Correlation matrix (Spearman) ─────────────────────────────────────────────
log_step(3, "Calcular matriz de correlacao de Spearman entre indicadores de ES")
cor_mat <- tryCatch({
  cor(es_norm[es_cols], method = "spearman", use = "complete.obs")
}, error = function(e) {
  log_error(
    "Falha ao calcular matriz de correlacao: %s\nCausa provavel: todos os valores de alguma coluna sao NA apos normalizacao.\nVerifique: presenca de variacao nos indicadores de ES.\nSkill anterior: ecosystem-services-assessment (quantification step).",
    conditionMessage(e)
  )
  stop(e)
})

log_decision("correlation_method", "Spearman",
             "metodo nao-parametrico robusto a distribuicoes assimetricas comuns em dados de ES")

tryCatch({
  write.csv(as.data.frame(cor_mat), file.path(output_dir, "tradeoff_matrix.csv"))
  log_info("tradeoff_matrix.csv salvo em: %s", output_dir)
}, error = function(e) {
  log_error(
    "Falha ao salvar tradeoff_matrix.csv: %s\nCausa provavel: permissao negada ou disco cheio.\nVerifique: permissoes do diretorio de saida.\nSkill anterior: nenhuma.",
    conditionMessage(e)
  )
  stop(e)
})

# ── Correlation heatmap ────────────────────────────────────────────────────────
log_step(4, "Gerar heatmap de trade-offs (corrplot)")
tryCatch({
  png(file.path(output_dir, "tradeoff_heatmap.png"), width = 800, height = 700, res = 150)
  corrplot(cor_mat, method = "color", type = "upper", tl.cex = 0.8,
           addCoef.col = "black", number.cex = 0.7, cl.cex = 0.7,
           title = "ES Trade-offs (Spearman r)", mar = c(0, 0, 2, 0))
  dev.off()
  log_info("tradeoff_heatmap.png salvo em: %s", output_dir)
}, error = function(e) {
  log_error(
    "Falha ao gerar heatmap de trade-offs: %s\nCausa provavel: corrplot nao instalado ou matriz de correlacao invalida.\nVerifique: se o pacote corrplot esta disponivel e a matriz tem pelo menos 2 variaveis.\nSkill anterior: nenhuma.",
    conditionMessage(e)
  )
  stop(e)
})

# ── Scatter plots for top pairs ───────────────────────────────────────────────
log_step(5, "Gerar graficos de dispersao para pares de indicadores de ES")
pair_combos <- combn(es_cols, 2, simplify = FALSE)
n_pairs     <- min(6, length(pair_combos))
log_info("Gerando %d graficos de dispersao (de %d pares possiveis)", n_pairs, length(pair_combos))
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
    log_info("Salvo: %s", fname)
  }, error = function(e) {
    log_error(
      "Falha ao gerar grafico de dispersao para par %s vs %s: %s\nCausa provavel: coluna ausente apos filtragem ou problema com ggrepel.\nVerifique: se as colunas '%s' e '%s' existem e possuem dados validos.\nSkill anterior: nenhuma.",
      pr[1], pr[2], conditionMessage(e), pr[1], pr[2]
    )
    stop(e)
  })
}

log_info("Analise de trade-off concluida. Saidas em: %s", output_dir)
