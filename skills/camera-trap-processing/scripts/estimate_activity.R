# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript estimate_activity.R <record_table_csv> <species_name> <output_dir> [group_column]

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "camera-trap-processing"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages(library(overlap))
suppressPackageStartupMessages(library(circular))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(lubridate))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  log_error("Argumentos insuficientes. Uso: Rscript estimate_activity.R <record_table_csv> <species_name> <output_dir> [group_column]")
  cat("Usage: Rscript estimate_activity.R <record_table_csv> <species_name> <output_dir> [group_column]\n")
  cat("  group_column: optional column for comparing two groups (e.g., 'season')\n")
  quit(status = 1)
}

record_csv   <- args[1]
species_name <- args[2]
output_dir   <- args[3]
group_col    <- if (length(args) >= 4) args[4] else NULL

# ── Input precondition checks ────────────────────────────────────────────────
if (!file.exists(record_csv)) {
  log_error("Input nao encontrado: %s\nCausa provavel: process_camtrap_data.R nao foi executado ou falhou\nVerifique: se record_table.csv existe no diretorio de saida\nSkill anterior: camera-trap-processing (process_camtrap_data.R)", record_csv)
  stop("Missing record_csv: ", record_csv)
}

log_decision("species_name", species_name,
             "especie alvo para estimativa de atividade diaria")
log_decision("group_col", ifelse(is.null(group_col), "NULL", group_col),
             "coluna de grupo para comparacao de sobreposicao; NULL = sem comparacao")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_step(1, "Carregando e filtrando registros para a especie alvo")
records <- tryCatch({
  read.csv(record_csv, stringsAsFactors = FALSE)
}, error = function(e) {
  log_error("Falha ao ler record_table CSV: %s\nCausa provavel: arquivo corrompido ou formato invalido\nVerifique: saida de process_camtrap_data.R\nSkill anterior: camera-trap-processing", conditionMessage(e))
  stop(e)
})

records$DateTimeOriginal <- as.POSIXct(records$DateTimeOriginal,
                                        format = "%Y-%m-%d %H:%M:%S")

sp_data <- records[records$Species == species_name, ]
log_info("Registros para '%s': %d eventos", species_name, nrow(sp_data))

if (nrow(sp_data) < 10) {
  log_error("n_eventos_independentes < 10 para '%s' (%d encontrados)\nCausa provavel: especie rara ou limiar de independencia muito alto\nVerifique: especies disponiveis na tabela de registros\nSkill anterior: camera-trap-processing (process_camtrap_data.R)", species_name, nrow(sp_data))
  stop("n_independent_events < 10 for '", species_name,
       "'. Report RAI only; do not estimate activity overlap.")
}

log_step(2, "Convertendo horarios para radianos e estimando densidade de atividade")
# Convert to radians
to_rad <- function(dt) {
  (hour(dt) + minute(dt) / 60) * (2 * pi / 24)
}
sp_data$time_rad <- to_rad(sp_data$DateTimeOriginal)

# Overall activity density plot
tryCatch({
  png(file.path(output_dir, "activity_plot.png"), width = 900, height = 600, res = 120)
  overlapPlot(sp_data$time_rad, rug = TRUE,
              main = paste("Diel Activity —", gsub("_", " ", species_name)),
              xlab = "Time of day", col.main = "black")
  dev.off()
  log_info("Grafico de atividade salvo: activity_plot.png")
}, error = function(e) {
  log_error("Falha ao gerar grafico de atividade: %s\nCausa provavel: biblioteca overlap com problema\nVerifique: instalacao do pacote overlap\nSkill anterior: [nenhuma]", conditionMessage(e))
  stop(e)
})

log_step(3, "Calculando estatisticas circulares")
# Circular statistics
time_circ  <- circular(sp_data$time_rad, units = "radians", template = "clock24")
mean_rad   <- mean.circular(time_circ)
mean_hour  <- as.numeric(mean_rad) * 24 / (2 * pi)
kappa_est  <- tryCatch(mle.vonmises(time_circ)$kappa, error = function(e) {
  log_warn("mle.vonmises() falhou (kappa = NA): %s", conditionMessage(e))
  NA_real_
})
rayleigh_p <- rayleigh.test(time_circ)$p.value

log_decision("rayleigh_p", round(rayleigh_p, 4),
             "p < 0.05 indica distribuicao nao-uniforme (atividade diaria concentrada)")
if (rayleigh_p >= 0.05) {
  log_warn("Rayleigh p = %.4f >= 0.05: atividade diaria nao difere de uniforme para '%s'",
           rayleigh_p, species_name)
}

circ_stats <- data.frame(
  species         = species_name,
  n_events        = nrow(sp_data),
  mean_activity_hour = round(mean_hour %% 24, 2),
  kappa           = round(kappa_est, 3),
  rayleigh_p      = round(rayleigh_p, 4),
  non_uniform     = rayleigh_p < 0.05
)
write.csv(circ_stats, file.path(output_dir, "circular_stats.csv"), row.names = FALSE)
log_info("Estatisticas circulares salvas: hora media = %.1f h, kappa = %.3f",
         mean_hour %% 24, ifelse(is.na(kappa_est), 0, kappa_est))

log_step(4, "Calculando sobreposicao de atividade entre grupos (se aplicavel)")
# Diel overlap between two groups (if group_col provided)
overlap_result <- data.frame()
if (!is.null(group_col) && group_col %in% names(sp_data)) {
  groups <- unique(sp_data[[group_col]])
  if (length(groups) == 2) {
    groupA <- sp_data$time_rad[sp_data[[group_col]] == groups[1]]
    groupB <- sp_data$time_rad[sp_data[[group_col]] == groups[2]]

    if (length(groupA) >= 10 && length(groupB) >= 10) {
      log_info("Estimando sobreposicao Dhat4 entre '%s' (n=%d) e '%s' (n=%d)",
               groups[1], length(groupA), groups[2], length(groupB))
      boot_out  <- bootEst(groupA, groupB, nb = 1000, type = "Dhat4")
      delta4    <- boot_out["Dhat4"]
      ci_lower  <- boot_out["lwr"]
      ci_upper  <- boot_out["upr"]

      overlap_result <- data.frame(
        groupA  = groups[1],
        groupB  = groups[2],
        n_A     = length(groupA),
        n_B     = length(groupB),
        Dhat4   = round(delta4, 3),
        ci_lower = round(ci_lower, 3),
        ci_upper = round(ci_upper, 3)
      )

      png(file.path(output_dir, "activity_overlap.png"), width = 900, height = 600, res = 120)
      overlapPlot(groupA, groupB, rug = TRUE,
                  main = paste("Diel Overlap — Δ4 =", round(delta4, 2)),
                  linecol = c("blue", "red"))
      legend("topright", legend = groups, col = c("blue", "red"), lty = 1)
      dev.off()
      log_info("Sobreposicao Dhat4 = %.3f [%.3f, %.3f]",
               delta4, ci_lower, ci_upper)
    } else {
      log_warn("Um ou ambos os grupos tem < 10 eventos; sobreposicao nao calculada (n_A=%d, n_B=%d)",
               length(groupA), length(groupB))
    }
  } else {
    log_warn("group_col '%s' tem %d valores unicos; exatamente 2 necessarios para sobreposicao",
             group_col, length(groups))
  }
} else if (!is.null(group_col)) {
  log_warn("Coluna de grupo '%s' nao encontrada nos dados da especie", group_col)
}
write.csv(overlap_result, file.path(output_dir, "activity_overlap.csv"), row.names = FALSE)

log_info("Concluido. Saidas gravadas em: %s", output_dir)
log_info("  n eventos: %d", nrow(sp_data))
log_info("  Hora media de atividade: %.1f h", mean_hour %% 24)
log_info("  Rayleigh p: %.4f", round(rayleigh_p, 4))
