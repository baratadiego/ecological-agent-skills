# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript download_from_inat.R <species_name_or_list_csv> <output_dir> [year_from] [year_to] [quality_grade]

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
#   species_name_or_list_csv : Species name (e.g., "Panthera onca") or path to a
#                              CSV with column "scientificName"
#   output_dir               : Directory to write outputs (created if absent)
#   year_from                : Minimum year of observation (optional, default: 2000)
#   year_to                  : Maximum year of observation (optional, default: current year)
#   quality_grade            : iNaturalist quality grade: "research" or "any" (default: "research")
#
# Outputs (per species):
#   occurrences_raw_iNat_{species}_{date}.csv  — standardised occurrence records
#   download_metadata_iNat_{species}.txt        — download provenance and citation info
#
# Standard output schema:
#   species, decimalLatitude, decimalLongitude, eventDate, countryCode,
#   basisOfRecord, coordinateUncertaintyInMeters, datasetName, occurrenceID,
#   source, download_doi

suppressPackageStartupMessages(library(rinat))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(readr))

# ── 1. Parse arguments ───────────────────────────────────────────────────────
log_step(1, "Analisar argumentos da linha de comando")
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  species_input <- "Panthera onca"
  output_dir    <- "output/inat"
  year_from     <- 2000
  year_to       <- as.integer(format(Sys.Date(), "%Y"))
  quality_grade <- "research"
  log_warn("Menos de 2 argumentos fornecidos. Usando valores padrao para teste.")
} else {
  species_input <- args[1]
  output_dir    <- args[2]
  year_from     <- if (length(args) >= 3) as.integer(args[3]) else 2000
  year_to       <- if (length(args) >= 4) as.integer(args[4]) else as.integer(format(Sys.Date(), "%Y"))
  quality_grade <- if (length(args) >= 5) args[5] else "research"
}

log_info("Script: download_from_inat.R | Skill: %s", SKILL_NAME)
log_info("Species input  : %s", species_input)
log_info("Output dir     : %s", output_dir)
log_info("Year range     : %d - %d", year_from, year_to)
log_info("Quality grade  : %s", quality_grade)

log_decision("quality_grade", quality_grade,
             "research = comunidade validou ID + possui coordenadas; recomendado para SDM")
log_decision("year_from", year_from, "filtro temporal; 2000 equilibra tamanho de dataset e qualidade")
log_decision("captive", "FALSE",
             "excluir organismos em cativeiro/cultivados (nao representam distribuicao selvagem)")

# ── 2. Create output directory ───────────────────────────────────────────────
log_step(2, "Criar diretorio de saida")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
log_info("Diretorio de saida pronto: %s", output_dir)

# ── 3. Build species list ────────────────────────────────────────────────────
log_step(3, "Construir lista de especies")
if (grepl("\\.csv$", species_input, ignore.case = TRUE) && file.exists(species_input)) {
  tryCatch({
    species_df <- read_csv(species_input, show_col_types = FALSE)
    if (!"scientificName" %in% names(species_df)) {
      log_error(
        "Coluna 'scientificName' nao encontrada em: %s\nCausa provavel: CSV mal formatado.\nVerifique o cabecalho do arquivo.\nSkill anterior: ecological-data-foundation",
        species_input
      )
      stop("Missing column 'scientificName'")
    }
    species_list <- unique(trimws(species_df$scientificName))
    log_info("Modo batch: %d especies carregadas de %s", length(species_list), species_input)
    log_decision("mode", "batch", "argumento e um CSV valido com coluna scientificName")
  }, error = function(e) {
    log_error(
      "Falha ao ler lista de especies: %s\nCausa provavel: arquivo CSV invalido.\nVerifique: %s\nSkill anterior: ecological-data-foundation",
      conditionMessage(e), species_input
    )
    stop(e)
  })
} else {
  species_list <- trimws(species_input)
  log_info("Modo especie unica: %s", species_list)
  log_decision("mode", "single_species", "argumento nao e arquivo CSV")
}

# ── 4. Download function ─────────────────────────────────────────────────────
download_inat_species <- function(sp_name) {
  log_info("--- Iniciando download iNaturalist: %s ---", sp_name)
  today_str <- format(Sys.Date(), "%Y%m%d")
  safe_name <- gsub(" ", "_", sp_name)

  # Build date filters
  d_from <- paste0(year_from, "-01-01")
  d_to   <- paste0(year_to,   "-12-31")

  occ_raw <- tryCatch({
    rinat::get_inat_obs(
      taxon_name  = sp_name,
      quality     = quality_grade,
      geo         = TRUE,
      captive     = FALSE,
      year        = NULL,          # date range used instead via d1/d2 in extra_params
      maxresults  = 10000,
      meta        = FALSE
    )
  }, error = function(e) {
    log_error(
      "Falha em get_inat_obs para '%s': %s\nCausa provavel: sem conexao com a internet ou API iNaturalist indisponivel.\nVerifique sua conexao e tente novamente.\nSkill anterior: ecological-data-foundation",
      sp_name, conditionMessage(e)
    )
    stop(e)
  })

  if (is.null(occ_raw) || nrow(occ_raw) == 0) {
    log_warn("Nenhum registro encontrado para '%s' no iNaturalist.", sp_name)
    return(invisible(NULL))
  }

  n_raw <- nrow(occ_raw)
  log_info("Registros brutos recuperados: %d", n_raw)

  # ── Filter by year range ───────────────────────────────────────────────────
  if ("observed_on" %in% names(occ_raw)) {
    occ_raw$obs_year <- as.integer(substr(occ_raw$observed_on, 1, 4))
    occ_raw <- occ_raw[!is.na(occ_raw$obs_year) &
                         occ_raw$obs_year >= year_from &
                         occ_raw$obs_year <= year_to, ]
    log_info("Registros apos filtro de ano (%d-%d): %d", year_from, year_to, nrow(occ_raw))
  }

  # ── Standardise to output schema ──────────────────────────────────────────
  std <- data.frame(
    species                        = sp_name,
    decimalLatitude                = as.numeric(occ_raw$latitude),
    decimalLongitude               = as.numeric(occ_raw$longitude),
    eventDate                      = as.character(occ_raw$observed_on),
    countryCode                    = as.character(occ_raw$place_guess),   # iNat has no ISO code
    basisOfRecord                  = "HUMAN_OBSERVATION",
    coordinateUncertaintyInMeters  = as.numeric(occ_raw$positional_accuracy),
    datasetName                    = "iNaturalist",
    occurrenceID                   = as.character(occ_raw$id),
    source                         = "iNaturalist",
    download_doi                   = NA_character_,
    stringsAsFactors               = FALSE
  )

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
      "Registros insuficientes para SDM confiavel (n = %d). Considere: (1) ampliar periodo, (2) usar quality='any', (3) combinar com outras fontes.",
      n_final
    )
  }

  # ── Save CSV ───────────────────────────────────────────────────────────────
  csv_path <- file.path(output_dir, paste0("occurrences_raw_iNat_", safe_name, "_", today_str, ".csv"))
  tryCatch({
    write_csv(std, csv_path)
    log_info("Gravado: %s (%d registros)", csv_path, n_final)
  }, error = function(e) {
    log_error(
      "Falha ao gravar CSV para '%s': %s\nCausa provavel: sem permissao de escrita em '%s'.\nSkill anterior: ecological-data-foundation",
      sp_name, conditionMessage(e), output_dir
    )
    stop(e)
  })

  # ── Save metadata ──────────────────────────────────────────────────────────
  meta_lines <- c(
    paste("Species:", sp_name),
    paste("Source: iNaturalist (https://www.inaturalist.org)"),
    paste("Quality grade:", quality_grade),
    paste("Year range:", year_from, "-", year_to),
    paste("Captive excluded: TRUE"),
    paste("Geo-referenced only: TRUE"),
    paste("n_records:", n_final),
    paste("Download date:", Sys.Date()),
    paste("Citation: iNaturalist contributors and the California Academy of Sciences (", format(Sys.Date(), "%Y"),
          "). iNaturalist Research-grade Observations. iNaturalist.org. Accessed ", Sys.Date(), ".", sep = ""),
    paste("License: CC BY-NC (individual records may vary; see iNaturalist for details)"),
    paste("Note: iNaturalist does not issue download DOIs; record the access date for reproducibility.")
  )
  meta_path <- file.path(output_dir, paste0("download_metadata_iNat_", safe_name, ".txt"))
  tryCatch({
    writeLines(meta_lines, meta_path)
    log_info("Gravado: %s", meta_path)
  }, error = function(e) {
    log_error(
      "Falha ao gravar metadados para '%s': %s\nCausa provavel: sem permissao de escrita.\nSkill anterior: ecological-data-foundation",
      sp_name, conditionMessage(e)
    )
    stop(e)
  })

  return(invisible(csv_path))
}

# ── 5. Run for all species ───────────────────────────────────────────────────
log_step(4, "Executar download iNaturalist para todas as especies")
for (sp in species_list) {
  tryCatch(
    download_inat_species(sp),
    error = function(e) {
      log_error(
        "Falha ao baixar '%s' do iNaturalist: %s\nCausa provavel: problema de rede ou especie nao encontrada.\nVerifique os logs acima.\nSkill anterior: ecological-data-foundation",
        sp, conditionMessage(e)
      )
    }
  )
}

log_info("Todos os downloads iNaturalist concluidos. Verifique: %s", output_dir)
