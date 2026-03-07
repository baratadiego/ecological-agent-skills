# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript clean_occurrences.R <raw_occurrences.csv> <output_dir> [country_code]

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "ecological-data-foundation"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

# Standard occurrence cleaning pipeline
# Usage: Rscript clean_occurrences.R <input_csv> <output_dir>
# Requires: dplyr, readr, CoordinateCleaner, taxize, janitor

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(CoordinateCleaner)
  library(janitor)
})

args <- commandArgs(trailingOnly = TRUE)
input_file  <- ifelse(length(args) >= 1, args[1], "data/raw/occurrences.csv")
output_dir  <- ifelse(length(args) >= 2, args[2], "data/processed")

log_info("Script: clean_occurrences.R | Skill: %s", SKILL_NAME)
log_info("Input file : %s", input_file)
log_info("Output dir : %s", output_dir)

# ── Input precondition check ──────────────────────────────────────────────────
if (!file.exists(input_file)) {
  log_error(
    "Input nao encontrado: %s\nCausa provavel: arquivo nao gerado pelo passo anterior.\nVerifique a saida de: ecological-data-foundation (download_from_gbif)\nSkill anterior: ecological-data-foundation",
    input_file
  )
  stop("Missing: ", input_file)
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_decision("input_file", input_file, "caminho passado como args[1] ou padrao")
log_decision("output_dir", output_dir, "caminho passado como args[2] ou padrao")

# ── 1. Ingest ──────────────────────────────────────────────────────────────
log_step(1, "Ingerir dados brutos de ocorrencias")
tryCatch({
  raw <- read_csv(input_file, show_col_types = FALSE) |>
    clean_names()
  log_info("Registros brutos lidos: %d | Colunas: %d", nrow(raw), ncol(raw))
}, error = function(e) {
  log_error(
    "Falha ao ler CSV de entrada: %s\nCausa provavel: arquivo corrompido ou nao e CSV valido.\nVerifique: %s\nSkill anterior: ecological-data-foundation",
    conditionMessage(e), input_file
  )
  stop(e)
})

if (nrow(raw) == 0) {
  log_warn("Arquivo de entrada nao contem registros: %s", input_file)
}

# ── 2. Require minimum columns ─────────────────────────────────────────────
log_step(2, "Verificar colunas obrigatorias")
tryCatch({
  required_cols <- c("decimal_latitude", "decimal_longitude", "species")
  missing_req <- setdiff(required_cols, names(raw))
  if (length(missing_req) > 0) {
    log_error(
      "Colunas obrigatorias ausentes: %s\nCausa provavel: CSV gerado por fonte diferente ou com nomes de colunas alterados.\nVerifique o schema do arquivo: %s\nSkill anterior: ecological-data-foundation",
      paste(missing_req, collapse = ", "), input_file
    )
    stop("Missing required columns: ", paste(missing_req, collapse = ", "))
  }
  log_info("Todas as colunas obrigatorias presentes: %s", paste(required_cols, collapse = ", "))
}, error = function(e) {
  log_error("Falha na verificacao de colunas: %s", conditionMessage(e))
  stop(e)
})

# ── 3. Remove records with missing coordinates ─────────────────────────────
log_step(3, "Remover registros sem coordenadas e converter para numerico")
tryCatch({
  n_before_na <- nrow(raw)
  raw <- raw |>
    filter(!is.na(decimal_latitude), !is.na(decimal_longitude)) |>
    mutate(
      decimal_latitude  = as.numeric(decimal_latitude),
      decimal_longitude = as.numeric(decimal_longitude)
    )
  n_removed_na <- n_before_na - nrow(raw)
  if (n_removed_na > 0) {
    log_warn("Registros removidos por coordenadas ausentes: %d", n_removed_na)
  } else {
    log_info("Nenhum registro removido por coordenadas ausentes.")
  }
}, error = function(e) {
  log_error(
    "Falha ao filtrar coordenadas ausentes: %s\nCausa provavel: tipos de coluna inesperados no CSV.\nVerifique: %s\nSkill anterior: ecological-data-foundation",
    conditionMessage(e), input_file
  )
  stop(e)
})

if (nrow(raw) < 30) {
  log_warn("Poucos registros apos remocao de NAs (%d). Minimo recomendado para SDM: 30.", nrow(raw))
}

# ── 4. Coordinate cleaning ─────────────────────────────────────────────────
log_step(4, "Limpeza de coordenadas com CoordinateCleaner")
log_decision(
  "cc_tests",
  "capitals,centroids,equal,gbif,institutions,validity,zeros",
  "conjunto padrao de testes para detectar registros suspeitos"
)
tryCatch({
  flags <- clean_coordinates(
    x       = raw,
    lon     = "decimal_longitude",
    lat     = "decimal_latitude",
    species = "species",
    tests   = c("capitals", "centroids", "equal", "gbif",
                "institutions", "validity", "zeros"),
    verbose = FALSE
  )

  clean    <- raw[flags$.summary, ] |> mutate(QA_status = "OK")
  flagged  <- raw[!flags$.summary, ] |>
    mutate(QA_status = apply(
      flags[!flags$.summary, grep("^\\.", names(flags))], 1,
      function(r) paste(names(r)[!r], collapse = "|")
    ))

  log_info("Registros limpos: %d | Registros sinalizados: %d", nrow(clean), nrow(flagged))
  if (nrow(flagged) > 0) {
    log_warn("%d registros sinalizados pelo CoordinateCleaner (%.1f%% do total).",
             nrow(flagged), 100 * nrow(flagged) / nrow(raw))
  }
}, error = function(e) {
  log_error(
    "Falha na limpeza de coordenadas (CoordinateCleaner): %s\nCausa provavel: dados malformados ou pacote CoordinateCleaner nao instalado.\nVerifique: install.packages('CoordinateCleaner')\nSkill anterior: ecological-data-foundation",
    conditionMessage(e)
  )
  stop(e)
})

# ── 5. Remove exact duplicates ─────────────────────────────────────────────
log_step(5, "Remover duplicatas exatas")
tryCatch({
  n_before <- nrow(clean)
  clean <- clean |> distinct(species, decimal_latitude, decimal_longitude,
                              event_date, .keep_all = TRUE)
  n_dup <- n_before - nrow(clean)
  log_decision(
    "dedup_cols",
    "species,decimal_latitude,decimal_longitude,event_date",
    "combinacao padrao para identificar duplicatas espaciotemporais"
  )
  if (n_dup > 0) {
    log_warn("Duplicatas exatas removidas: %d", n_dup)
  } else {
    log_info("Nenhuma duplicata exata encontrada.")
  }
}, error = function(e) {
  log_error(
    "Falha ao remover duplicatas: %s\nCausa provavel: coluna event_date ausente ou mal formatada.\nVerifique o schema do CSV.\nSkill anterior: ecological-data-foundation",
    conditionMessage(e)
  )
  stop(e)
})

if (nrow(clean) < 30) {
  log_warn(
    "Apenas %d registros limpos apos todas as filtragens. SDMs requerem >= 30 registros confiaveis.",
    nrow(clean)
  )
}

# ── 6. Write outputs ───────────────────────────────────────────────────────
log_step(6, "Escrever arquivos de saida")
tryCatch({
  write_csv(clean,   file.path(output_dir, "data_clean.csv"))
  write_csv(flagged, file.path(output_dir, "flagged_records.csv"))
  log_info("Gravado: %s", file.path(output_dir, "data_clean.csv"))
  log_info("Gravado: %s", file.path(output_dir, "flagged_records.csv"))
}, error = function(e) {
  log_error(
    "Falha ao gravar arquivos de saida: %s\nCausa provavel: sem permissao de escrita em '%s'.\nVerifique permissoes do diretorio.\nSkill anterior: ecological-data-foundation",
    conditionMessage(e), output_dir
  )
  stop(e)
})

# ── 7. QA report ──────────────────────────────────────────────────────────
log_step(7, "Gerar relatorio de QA")
tryCatch({
  report <- c(
    "# QA Report — Occurrence Cleaning",
    "",
    paste("- Input file:", input_file),
    paste("- Raw records:", nrow(raw) + nrow(flagged)),
    paste("- Exact duplicates removed:", n_dup),
    paste("- Records flagged by CoordinateCleaner:", nrow(flagged)),
    paste("- Clean records written:", nrow(clean)),
    "",
    "## Flag Counts",
    ""
  )

  flag_cols <- grep("^\\.", names(flags), value = TRUE)
  for (fc in flag_cols) {
    n_fail <- sum(!flags[[fc]], na.rm = TRUE)
    if (n_fail > 0) report <- c(report, paste0("- `", fc, "`: ", n_fail))
  }

  writeLines(report, file.path(output_dir, "qa_report.md"))
  log_info("Gravado: %s", file.path(output_dir, "qa_report.md"))
}, error = function(e) {
  log_error(
    "Falha ao gerar relatorio QA: %s\nCausa provavel: problema ao escrever no diretorio '%s'.\nSkill anterior: ecological-data-foundation",
    conditionMessage(e), output_dir
  )
  stop(e)
})

log_info("Concluido. Registros limpos: %d | Sinalizados: %d", nrow(clean), nrow(flagged))
