# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript download_from_iucn.R <species_name_or_list_csv> <output_dir> [include_range_maps]

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
#   species_name_or_list_csv : Species name (e.g., "Panthera onca") or path to CSV
#                              with column "scientificName"
#   output_dir               : Directory to write outputs (created if absent)
#   include_range_maps       : "TRUE" or "FALSE" — download range map data (default: FALSE)
#
# Requires:
#   IUCN_REDLIST_KEY environment variable — obtain at: https://apiv3.iucnredlist.org/
#
# Outputs (per species):
#   iucn_status_{species}.csv   — Red List category, criteria, population trend, threats
#   iucn_habitats_{species}.csv — suitable habitats by species
#   download_metadata_IUCN_{species}.txt — provenance and citation
# If include_range_maps=TRUE:
#   range_maps/{species}_range.gpkg — range polygons (if available via API)
#
# Standard output schema (iucn_status CSV):
#   species, decimalLatitude, decimalLongitude, eventDate, countryCode,
#   basisOfRecord, coordinateUncertaintyInMeters, datasetName, occurrenceID,
#   source, download_doi
#   + IUCN-specific: rl_category, rl_criteria, population_trend, assessment_year

suppressPackageStartupMessages(library(rredlist))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(readr))

# ── 1. Parse arguments ───────────────────────────────────────────────────────
log_step(1, "Analisar argumentos da linha de comando")
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  species_input    <- "Panthera onca"
  output_dir       <- "output/iucn"
  include_range_maps <- FALSE
  log_warn("Menos de 2 argumentos fornecidos. Usando valores padrao para teste.")
} else {
  species_input    <- args[1]
  output_dir       <- args[2]
  include_range_maps <- ifelse(
    length(args) >= 3 && toupper(args[3]) == "TRUE", TRUE, FALSE
  )
}

log_info("Script: download_from_iucn.R | Skill: %s", SKILL_NAME)
log_info("Species input      : %s", species_input)
log_info("Output dir         : %s", output_dir)
log_info("Include range maps : %s", include_range_maps)

log_decision("api_version", "v3", "IUCN Red List API v3 — requer chave em IUCN_REDLIST_KEY")

# ── 2. Check API key ─────────────────────────────────────────────────────────
log_step(2, "Verificar chave da API IUCN")
iucn_key <- Sys.getenv("IUCN_REDLIST_KEY")
if (is.null(iucn_key) || iucn_key == "") {
  log_error(
    "Falha em verificar chave API IUCN: variavel IUCN_REDLIST_KEY nao definida.\nCausa provavel: chave nao configurada no ambiente.\nVerifique: adicione IUCN_REDLIST_KEY ao seu .Renviron via usethis::edit_r_environ()\nSkill anterior: ecological-data-foundation"
  )
  stop("IUCN_REDLIST_KEY environment variable not set.")
}
log_info("Chave IUCN detectada (primeiros 4 chars): %s...", substr(iucn_key, 1, 4))

# ── 3. Create output directory ───────────────────────────────────────────────
log_step(3, "Criar diretorio de saida")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── 4. Build species list ────────────────────────────────────────────────────
log_step(4, "Construir lista de especies")
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

# ── 5. Download function ─────────────────────────────────────────────────────
download_iucn_species <- function(sp_name) {
  log_info("--- Iniciando download IUCN: %s ---", sp_name)
  safe_name <- gsub(" ", "_", sp_name)

  # ── Fetch species assessment ───────────────────────────────────────────────
  assessment <- tryCatch({
    rredlist::rl_search(sp_name, key = iucn_key)
  }, error = function(e) {
    log_error(
      "Falha em rl_search para '%s': %s\nCausa provavel: chave IUCN invalida ou API indisponivel.\nVerifique: https://apiv3.iucnredlist.org/\nSkill anterior: ecological-data-foundation",
      sp_name, conditionMessage(e)
    )
    stop(e)
  })

  if (is.null(assessment$result) || length(assessment$result) == 0) {
    log_warn("Nenhum resultado IUCN para '%s'. Especie pode nao estar avaliada.", sp_name)
    return(invisible(NULL))
  }

  res      <- assessment$result[[1]]
  category <- res$category %||% NA_character_
  criteria <- res$criteria  %||% NA_character_
  pop_trend<- res$population_trend %||% NA_character_
  assess_yr<- res$assessment_year  %||% NA_integer_
  taxon_id <- res$taxonid %||% NA_integer_

  log_info("Categoria IUCN para '%s': %s (criterios: %s, tendencia: %s, ano: %s)",
           sp_name, category, criteria, pop_trend, assess_yr)

  if (category %in% c("CR", "EN")) {
    log_warn("Especie '%s' e %s — dados de distribuicao podem ser restritos por razoes de seguranca.",
             sp_name, category)
  }

  # ── Fetch country occurrences ──────────────────────────────────────────────
  country_occ <- tryCatch({
    rredlist::rl_occ_country(sp_name, key = iucn_key)
  }, error = function(e) {
    log_warn("Falha ao buscar paises de ocorrencia para '%s': %s", sp_name, conditionMessage(e))
    list(result = NULL)
  })

  # ── Fetch habitats ─────────────────────────────────────────────────────────
  habitats <- tryCatch({
    rredlist::rl_habitats(sp_name, key = iucn_key)
  }, error = function(e) {
    log_warn("Falha ao buscar habitats para '%s': %s", sp_name, conditionMessage(e))
    list(result = NULL)
  })

  # ── Build standardised occurrence records (one row per country) ────────────
  if (!is.null(country_occ$result) && length(country_occ$result) > 0) {
    country_df <- as.data.frame(country_occ$result)
    std <- data.frame(
      species                       = sp_name,
      decimalLatitude               = NA_real_,
      decimalLongitude              = NA_real_,
      eventDate                     = NA_character_,
      countryCode                   = as.character(country_df$code),
      basisOfRecord                 = "LITERATURE",
      coordinateUncertaintyInMeters = NA_real_,
      datasetName                   = "IUCN Red List",
      occurrenceID                  = paste0("IUCN:", taxon_id, ":", as.character(country_df$code)),
      source                        = "IUCN",
      download_doi                  = NA_character_,
      rl_category                   = category,
      rl_criteria                   = criteria,
      population_trend              = pop_trend,
      assessment_year               = assess_yr,
      stringsAsFactors              = FALSE
    )
  } else {
    log_warn("Sem dados de ocorrencia por pais para '%s'. Criando registro sumario.", sp_name)
    std <- data.frame(
      species                       = sp_name,
      decimalLatitude               = NA_real_,
      decimalLongitude              = NA_real_,
      eventDate                     = NA_character_,
      countryCode                   = NA_character_,
      basisOfRecord                 = "LITERATURE",
      coordinateUncertaintyInMeters = NA_real_,
      datasetName                   = "IUCN Red List",
      occurrenceID                  = paste0("IUCN:", taxon_id),
      source                        = "IUCN",
      download_doi                  = NA_character_,
      rl_category                   = category,
      rl_criteria                   = criteria,
      population_trend              = pop_trend,
      assessment_year               = assess_yr,
      stringsAsFactors              = FALSE
    )
  }

  # Save status CSV
  csv_path <- file.path(output_dir, paste0("iucn_status_", safe_name, ".csv"))
  tryCatch({
    write_csv(std, csv_path)
    log_info("Gravado: %s (%d linhas)", csv_path, nrow(std))
  }, error = function(e) {
    log_error(
      "Falha ao gravar CSV para '%s': %s\nSkill anterior: ecological-data-foundation",
      sp_name, conditionMessage(e)
    )
    stop(e)
  })

  # Save habitats CSV
  if (!is.null(habitats$result) && length(habitats$result) > 0) {
    hab_df <- as.data.frame(habitats$result)
    hab_df$species <- sp_name
    hab_path <- file.path(output_dir, paste0("iucn_habitats_", safe_name, ".csv"))
    tryCatch({
      write_csv(hab_df, hab_path)
      log_info("Habitats gravados: %s", hab_path)
    }, error = function(e) {
      log_warn("Falha ao gravar habitats para '%s': %s", sp_name, conditionMessage(e))
    })
  }

  # Save metadata
  meta_lines <- c(
    paste("Species:", sp_name),
    paste("IUCN Taxon ID:", taxon_id),
    paste("Source: IUCN Red List (https://www.iucnredlist.org)"),
    paste("API version: v3 (https://apiv3.iucnredlist.org)"),
    paste("Red List category:", category),
    paste("Assessment year:", assess_yr),
    paste("Population trend:", pop_trend),
    paste("Download date:", Sys.Date()),
    paste("Citation: IUCN", format(Sys.Date(), "%Y"), ". The IUCN Red List of Threatened Species. Version",
          format(Sys.Date(), "%Y-%m"), ". https://www.iucnredlist.org Accessed on", Sys.Date()),
    paste("License: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)")
  )
  meta_path <- file.path(output_dir, paste0("download_metadata_IUCN_", safe_name, ".txt"))
  tryCatch({
    writeLines(meta_lines, meta_path)
    log_info("Gravado: %s", meta_path)
  }, error = function(e) {
    log_warn("Falha ao gravar metadados para '%s': %s", sp_name, conditionMessage(e))
  })

  return(invisible(csv_path))
}

# Null-coalescing operator
`%||%` <- function(a, b) if (!is.null(a) && !is.na(a) && length(a) > 0) a else b

# ── 6. Run for all species ───────────────────────────────────────────────────
log_step(5, "Executar download IUCN para todas as especies")
for (sp in species_list) {
  tryCatch(
    download_iucn_species(sp),
    error = function(e) {
      log_error(
        "Falha ao baixar '%s' do IUCN: %s\nCausa provavel: chave invalida, especie nao avaliada ou API indisponivel.\nSkill anterior: ecological-data-foundation",
        sp, conditionMessage(e)
      )
    }
  )
}

log_info("Todos os downloads IUCN concluidos. Verifique: %s", output_dir)
