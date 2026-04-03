# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript download_from_ebird.R <ebd_file> <species_name_or_list_csv> <output_dir> [year_from] [year_to] [country_code]

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
#   ebd_file                 : Path to the eBird Basic Dataset (EBD) text file
#                              (pre-downloaded from https://ebird.org/data/download)
#   species_name_or_list_csv : Common or scientific name, or CSV with column "scientificName"
#   output_dir               : Directory to write outputs (created if absent)
#   year_from                : Minimum year of observation (optional, default: 2000)
#   year_to                  : Maximum year of observation (optional, default: current year)
#   country_code             : ISO 3166-1 alpha-2 country code to filter (optional)
#
# Note: eBird data requires a pre-downloaded EBD file; this script parses it locally.
#       Apply for access at: https://ebird.org/data/download
#
# Outputs (per species):
#   occurrences_raw_eBird_{species}_{date}.csv  — standardised occurrence records
#   download_metadata_eBird_{species}.txt        — download provenance and citation
#
# Standard output schema:
#   species, decimalLatitude, decimalLongitude, eventDate, countryCode,
#   basisOfRecord, coordinateUncertaintyInMeters, datasetName, occurrenceID,
#   source, download_doi
# Extra eBird columns:
#   effort_distance_km, duration_minutes, observer_id

suppressPackageStartupMessages(library(auk))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(readr))

# ── 1. Parse arguments ───────────────────────────────────────────────────────
log_step(1, "Parse command-line arguments")
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
  ebd_file      <- "data/ebird/ebd_sample.txt"
  species_input <- "Jabiru mycteria"
  output_dir    <- "output/ebird"
  year_from     <- 2000
  year_to       <- as.integer(format(Sys.Date(), "%Y"))
  country_code  <- NULL
  log_warn("Fewer than 3 arguments provided. Using default values for testing.")
} else {
  ebd_file      <- args[1]
  species_input <- args[2]
  output_dir    <- args[3]
  year_from     <- if (length(args) >= 4) as.integer(args[4]) else 2000
  year_to       <- if (length(args) >= 5) as.integer(args[5]) else as.integer(format(Sys.Date(), "%Y"))
  country_code  <- if (length(args) >= 6 && args[6] != "") args[6] else NULL
}

log_info("Script: download_from_ebird.R | Skill: %s", SKILL_NAME)
log_info("EBD file       : %s", ebd_file)
log_info("Species input  : %s", species_input)
log_info("Output dir     : %s", output_dir)
log_info("Year range     : %d - %d", year_from, year_to)
log_info("Country code   : %s", ifelse(is.null(country_code), "none", country_code))

log_decision("protocol", "STATIONARY,TRAVELING",
             "apenas protocolos quantificaveis para modelagem de avistamentos")
log_decision("approved", "TRUE",
             "apenas listas aprovadas pelo eBird (revisao de qualidade aplicada)")
log_decision("year_from", year_from, "filtro temporal; 2000 equilibra tamanho e qualidade")

# ── 2. Check EBD file exists ─────────────────────────────────────────────────
log_step(2, "Check EBD file existence")
if (!file.exists(ebd_file)) {
  log_error(
    "Input not found: %s\nProbable cause: EBD file not downloaded from eBird.\nCheck: https://ebird.org/data/download — request access and download the EBD.\nPrevious skill: ecological-data-foundation",
    ebd_file
  )
  stop("EBD file not found: ", ebd_file)
}
log_info("EBD file found: %s", ebd_file)

# ── 3. Create output directory ───────────────────────────────────────────────
log_step(3, "Create output directory")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── 4. Build species list ────────────────────────────────────────────────────
log_step(4, "Build species list")
if (grepl("\\.csv$", species_input, ignore.case = TRUE) && file.exists(species_input)) {
  tryCatch({
    species_df <- read_csv(species_input, show_col_types = FALSE)
    if (!"scientificName" %in% names(species_df)) {
      log_error(
        "Coluna 'scientificName' nao encontrada em: %s\nProbable cause: CSV mal formatado.\nPrevious skill: ecological-data-foundation",
        species_input
      )
      stop("Missing column 'scientificName'")
    }
    species_list <- unique(trimws(species_df$scientificName))
    log_info("Modo batch: %d especies carregadas", length(species_list))
    log_decision("mode", "batch", "valid CSV with scientificName column")
  }, error = function(e) {
    log_error(
      "Failed to read lista de especies: %s\nProbable cause: CSV invalido.\nPrevious skill: ecological-data-foundation",
      conditionMessage(e)
    )
    stop(e)
  })
} else {
  species_list <- trimws(species_input)
  log_info("Modo especie unica: %s", species_list)
  log_decision("mode", "single_species", "argument is not a CSV file")
}

# ── 5. Filter and parse EBD ──────────────────────────────────────────────────
log_step(5, "Filter and load EBD with auk")

# Create a temporary filtered file for all species at once
tmp_filtered <- tempfile(fileext = ".txt")

auk_filter_obj <- tryCatch({
  flt <- auk_ebd(ebd_file) |>
    auk_species(species_list) |>
    auk_date(date = c(paste0(year_from, "-01-01"), paste0(year_to, "-12-31"))) |>
    auk_protocol(c("Stationary", "Traveling")) |>
    auk_complete()

  if (!is.null(country_code)) {
    flt <- auk_country(flt, country_code)
  }
  flt
}, error = function(e) {
  log_error(
    "Failed to configurar filtros auk: %s\nProbable cause: nome de especie not found no EBD ou parametros invalidos.\nCheck nomes usando auk_species_codes().\nPrevious skill: ecological-data-foundation",
    conditionMessage(e)
  )
  stop(e)
})

ebd_filtered <- tryCatch({
  auk_filter(auk_filter_obj, file = tmp_filtered, overwrite = TRUE)
  read_ebd(tmp_filtered)
}, error = function(e) {
  log_error(
    "Failed to filter or read EBD: %s\nProbable cause: corrupted EBD file or format incompatible with installed auk version.\nCheck: auk::auk_version_requirements().\nPrevious skill: ecological-data-foundation",
    conditionMessage(e)
  )
  stop(e)
})

n_filtered <- nrow(ebd_filtered)
log_info("Records after EBD filtering: %d", n_filtered)

if (n_filtered == 0) {
  log_warn("No records found after filtering. Check species names and date range.")
}

# ── 6. Standardise and save per-species ─────────────────────────────────────
log_step(6, "Standardise and write CSVs per species")
today_str <- format(Sys.Date(), "%Y%m%d")

for (sp in species_list) {
  sp_data <- ebd_filtered[ebd_filtered$scientific_name == sp |
                             ebd_filtered$common_name == sp, ]
  n_sp <- nrow(sp_data)
  log_info("Especie '%s': %d registros", sp, n_sp)

  if (n_sp == 0) {
    log_warn("No records for '%s'. Skipping.", sp)
    next
  }

  if (n_sp < 30) {
    log_warn(
      "Insufficient records for reliable SDM for '%s' (n = %d). Consider expanding the time period or geographic area.",
      sp, n_sp
    )
  }

  safe_name <- gsub(" ", "_", sp)

  # Standardised schema + extra eBird columns
  std <- data.frame(
    species                       = sp,
    decimalLatitude               = as.numeric(sp_data$latitude),
    decimalLongitude              = as.numeric(sp_data$longitude),
    eventDate                     = as.character(sp_data$observation_date),
    countryCode                   = as.character(sp_data$country_code),
    basisOfRecord                 = "HUMAN_OBSERVATION",
    coordinateUncertaintyInMeters = NA_real_,
    datasetName                   = "eBird Basic Dataset",
    occurrenceID                  = as.character(sp_data$sampling_event_identifier),
    source                        = "eBird",
    download_doi                  = NA_character_,
    effort_distance_km            = as.numeric(sp_data$effort_distance_km),
    duration_minutes              = as.numeric(sp_data$duration_minutes),
    observer_id                   = as.character(sp_data$observer_id),
    stringsAsFactors              = FALSE
  )

  std <- std[!is.na(std$decimalLatitude) & !is.na(std$decimalLongitude), ]

  csv_path <- file.path(output_dir,
                         paste0("occurrences_raw_eBird_", safe_name, "_", today_str, ".csv"))
  tryCatch({
    write_csv(std, csv_path)
    log_info("Written: %s (%d registros)", csv_path, nrow(std))
  }, error = function(e) {
    log_error(
      "Failed to gravar CSV para '%s': %s\nProbable cause: sem permissao de escrita.\nPrevious skill: ecological-data-foundation",
      sp, conditionMessage(e)
    )
    stop(e)
  })

  # Metadata
  meta_lines <- c(
    paste("Species:", sp),
    paste("Source: eBird Basic Dataset (https://ebird.org/data/download)"),
    paste("Protocols: Stationary, Traveling"),
    paste("Approved only: TRUE"),
    paste("Year range:", year_from, "-", year_to),
    paste("Country filter:", ifelse(is.null(country_code), "none", country_code)),
    paste("n_records:", nrow(std)),
    paste("Download date:", Sys.Date()),
    paste("Citation: eBird Basic Dataset. Version:", format(Sys.Date(), "%Y-%m"),
          ". Cornell Lab of Ornithology, Ithaca, New York.", Sys.Date()),
    paste("Note: eBird data requires a signed Data Use Agreement. Cite the dataset version used.")
  )
  meta_path <- file.path(output_dir, paste0("download_metadata_eBird_", safe_name, ".txt"))
  tryCatch({
    writeLines(meta_lines, meta_path)
    log_info("Metadata saved: %s", meta_path)
  }, error = function(e) {
    log_error(
      "Failed to save metadata for '%s': %s\nPrevious skill: ecological-data-foundation",
      sp, conditionMessage(e)
    )
  })
}

# Clean up temp file
if (file.exists(tmp_filtered)) file.remove(tmp_filtered)

log_info("All eBird downloads completed. Check: %s", output_dir)
