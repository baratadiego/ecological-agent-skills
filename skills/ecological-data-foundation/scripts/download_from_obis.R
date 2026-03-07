# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript download_from_obis.R <species_name_or_list_csv> <output_dir> [year_from] [year_to] [wkt_geometry]

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "ecological-data-foundation"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

#
# Arguments:
#   species_name_or_list_csv : Species name (e.g., "Chelonia mydas") or path to CSV
#                              with column "scientificName"
#   output_dir               : Directory to write outputs (created if absent)
#   year_from                : Minimum year of observation (optional, default: 1950)
#   year_to                  : Maximum year of observation (optional, default: current year)
#   wkt_geometry             : WKT polygon to restrict query (optional, e.g., "POLYGON((-80 -30,-80 10,-30 10,-30 -30,-80 -30))")
#
# Outputs (per species):
#   occurrences_raw_OBIS_{species}_{date}.csv  — standardised occurrence records
#   download_metadata_OBIS_{species}.txt        — download provenance and citation
#
# Standard output schema:
#   species, decimalLatitude, decimalLongitude, eventDate, countryCode,
#   basisOfRecord, coordinateUncertaintyInMeters, datasetName, occurrenceID,
#   source, download_doi
# Extra OBIS columns:
#   depth, marine

suppressPackageStartupMessages(library(robis))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(readr))

# ── 1. Parse arguments ───────────────────────────────────────────────────────
log_step(1, "Analisar argumentos da linha de comando")
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  species_input <- "Chelonia mydas"
  output_dir    <- "output/obis"
  year_from     <- 1950
  year_to       <- as.integer(format(Sys.Date(), "%Y"))
  wkt_geometry  <- NULL
  log_warn("Menos de 2 argumentos fornecidos. Usando valores padrao para teste.")
} else {
  species_input <- args[1]
  output_dir    <- args[2]
  year_from     <- if (length(args) >= 3) as.integer(args[3]) else 1950
  year_to       <- if (length(args) >= 4) as.integer(args[4]) else as.integer(format(Sys.Date(), "%Y"))
  wkt_geometry  <- if (length(args) >= 5 && args[5] != "") args[5] else NULL
}

log_info("Script: download_from_obis.R | Skill: %s", SKILL_NAME)
log_info("Species input  : %s", species_input)
log_info("Output dir     : %s", output_dir)
log_info("Year range     : %d - %d", year_from, year_to)
log_info("WKT geometry   : %s", ifelse(is.null(wkt_geometry), "nenhum (global)", wkt_geometry))

log_decision("absence", "FALSE",
             "apenas registros de presenca confirmada; OBIS inclui dados de ausencia em alguns datasets")
log_decision("year_from", year_from, "filtro temporal; 1950 cobre era moderna de registros marinhos")

# ── 2. Create output directory ───────────────────────────────────────────────
log_step(2, "Criar diretorio de saida")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── 3. Build species list ────────────────────────────────────────────────────
log_step(3, "Construir lista de especies")
if (grepl("\\.csv$", species_input, ignore.case = TRUE) && file.exists(species_input)) {
  tryCatch({
    species_df <- read_csv(species_input, show_col_types = FALSE)
    if (!"scientificName" %in% names(species_df)) {
      log_error(
        "Coluna 'scientificName' nao encontrada em: %s\nCausa provavel: CSV mal formatado.\nSkill anterior: ecological-data-foundation",
        species_input
      )
      stop("Missing column 'scientificName'")
    }
    species_list <- unique(trimws(species_df$scientificName))
    log_info("Modo batch: %d especies carregadas", length(species_list))
    log_decision("mode", "batch", "CSV valido com coluna scientificName")
  }, error = function(e) {
    log_error(
      "Falha ao ler lista de especies: %s\nSkill anterior: ecological-data-foundation",
      conditionMessage(e)
    )
    stop(e)
  })
} else {
  species_list <- trimws(species_input)
  log_info("Modo especie unica: %s", species_list)
  log_decision("mode", "single_species", "argumento nao e arquivo CSV")
}

# ── 4. Download function ─────────────────────────────────────────────────────
download_obis_species <- function(sp_name) {
  log_info("--- Iniciando download OBIS: %s ---", sp_name)
  today_str <- format(Sys.Date(), "%Y%m%d")
  safe_name <- gsub(" ", "_", sp_name)

  # Build query
  query_args <- list(
    scientificname = sp_name,
    absence        = FALSE,
    startdate      = paste0(year_from, "-01-01"),
    enddate        = paste0(year_to,   "-12-31")
  )
  if (!is.null(wkt_geometry)) {
    query_args$geometry <- wkt_geometry
  }

  occ_raw <- tryCatch({
    do.call(robis::occurrence, query_args)
  }, error = function(e) {
    log_error(
      "Falha em robis::occurrence para '%s': %s\nCausa provavel: sem conexao com a internet ou API OBIS indisponivel.\nVerifique: https://api.obis.org/\nSkill anterior: ecological-data-foundation",
      sp_name, conditionMessage(e)
    )
    stop(e)
  })

  if (is.null(occ_raw) || nrow(occ_raw) == 0) {
    log_warn("Nenhum registro OBIS encontrado para '%s'.", sp_name)
    return(invisible(NULL))
  }

  n_raw <- nrow(occ_raw)
  log_info("Registros brutos recuperados: %d", n_raw)

  # ── Apply OBIS quality flags ───────────────────────────────────────────────
  # Remove records flagged as having coordinate issues
  qc_cols <- c("flags")
  if ("flags" %in% names(occ_raw)) {
    bad_flags <- c("NO_COORD", "ZERO_COORD", "ON_LAND", "DEPTH_EXCEEDS_BATH")
    occ_raw <- occ_raw[!grepl(paste(bad_flags, collapse = "|"),
                               occ_raw$flags, ignore.case = TRUE), ]
    log_info("Registros apos filtro de flags OBIS: %d", nrow(occ_raw))
  }

  # ── Standardise to output schema ──────────────────────────────────────────
  get_col <- function(df, ...) {
    cols <- c(...)
    for (col in cols) {
      if (col %in% names(df)) return(df[[col]])
    }
    return(rep(NA, nrow(df)))
  }

  std <- data.frame(
    species                       = sp_name,
    decimalLatitude               = as.numeric(get_col(occ_raw, "decimalLatitude", "latitude")),
    decimalLongitude              = as.numeric(get_col(occ_raw, "decimalLongitude", "longitude")),
    eventDate                     = as.character(get_col(occ_raw, "eventDate", "date_start")),
    countryCode                   = as.character(get_col(occ_raw, "countryCode", "country")),
    basisOfRecord                 = as.character(get_col(occ_raw, "basisOfRecord")),
    coordinateUncertaintyInMeters = as.numeric(get_col(occ_raw, "coordinateUncertaintyInMeters")),
    datasetName                   = as.character(get_col(occ_raw, "datasetName", "dataset_name")),
    occurrenceID                  = as.character(get_col(occ_raw, "occurrenceID", "id")),
    source                        = "OBIS",
    download_doi                  = NA_character_,
    depth                         = as.numeric(get_col(occ_raw, "depth")),
    marine                        = TRUE,
    stringsAsFactors              = FALSE
  )

  # Replace empty basisOfRecord
  std$basisOfRecord[is.na(std$basisOfRecord) | std$basisOfRecord == ""] <- "OCCURRENCE"

  # Remove records with missing coordinates
  n_before <- nrow(std)
  std <- std[!is.na(std$decimalLatitude) & !is.na(std$decimalLongitude), ]
  n_removed <- n_before - nrow(std)
  if (n_removed > 0) {
    log_warn("%d registros removidos por coordenadas ausentes.", n_removed)
  }

  n_final <- nrow(std)
  log_info("Registros com coordenadas validas: %d", n_final)

  if (n_final < 30) {
    log_warn(
      "Registros insuficientes para analise confiavel (n = %d). Considere relaxar filtros de datas ou area.",
      n_final
    )
  }

  # ── Save CSV ───────────────────────────────────────────────────────────────
  csv_path <- file.path(output_dir, paste0("occurrences_raw_OBIS_", safe_name, "_", today_str, ".csv"))
  tryCatch({
    write_csv(std, csv_path)
    log_info("Gravado: %s (%d registros)", csv_path, n_final)
  }, error = function(e) {
    log_error(
      "Falha ao gravar CSV para '%s': %s\nSkill anterior: ecological-data-foundation",
      sp_name, conditionMessage(e)
    )
    stop(e)
  })

  # ── Save metadata ──────────────────────────────────────────────────────────
  meta_lines <- c(
    paste("Species:", sp_name),
    paste("Source: Ocean Biodiversity Information System (OBIS) — https://obis.org"),
    paste("API endpoint: https://api.obis.org/v3/occurrence"),
    paste("Absence records excluded: TRUE"),
    paste("OBIS quality flags applied: TRUE (NO_COORD, ZERO_COORD, ON_LAND, DEPTH_EXCEEDS_BATH removed)"),
    paste("Year range:", year_from, "-", year_to),
    paste("WKT geometry:", ifelse(is.null(wkt_geometry), "none (global)", wkt_geometry)),
    paste("n_records:", n_final),
    paste("Download date:", Sys.Date()),
    paste("Citation: OBIS (", format(Sys.Date(), "%Y"), ") Ocean Biodiversity Information System. Intergovernmental Oceanographic Commission of UNESCO. www.obis.org. Accessed on", Sys.Date()),
    paste("License: CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/)")
  )
  meta_path <- file.path(output_dir, paste0("download_metadata_OBIS_", safe_name, ".txt"))
  tryCatch({
    writeLines(meta_lines, meta_path)
    log_info("Gravado: %s", meta_path)
  }, error = function(e) {
    log_error(
      "Falha ao gravar metadados para '%s': %s\nSkill anterior: ecological-data-foundation",
      sp_name, conditionMessage(e)
    )
  })

  return(invisible(csv_path))
}

# ── 5. Run for all species ───────────────────────────────────────────────────
log_step(4, "Executar download OBIS para todas as especies")
for (sp in species_list) {
  tryCatch(
    download_obis_species(sp),
    error = function(e) {
      log_error(
        "Falha ao baixar '%s' do OBIS: %s\nCausa provavel: problema de rede ou especie nao encontrada.\nSkill anterior: ecological-data-foundation",
        sp, conditionMessage(e)
      )
    }
  )
}

log_info("Todos os downloads OBIS concluidos. Verifique: %s", output_dir)
