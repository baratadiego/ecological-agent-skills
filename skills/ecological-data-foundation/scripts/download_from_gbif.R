# Usage: Rscript download_from_gbif.R <species_name_or_list_csv> <output_dir> [country_code] [year_from] [year_to]

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
#   species_name_or_list_csv : Either a species name (e.g., "Panthera onca") or
#                              path to a CSV file with column "scientificName"
#   output_dir               : Directory to write outputs (created if absent)
#   country_code             : ISO 3166-1 alpha-2 country code to restrict records (optional)
#   year_from                : Minimum year of occurrence records (optional, default: 1950)
#   year_to                  : Maximum year of occurrence records (optional, default: current year)
#
# Outputs (per species):
#   occurrences_raw_GBIF_{species}_{date}.csv  — cleaned occurrence records
#   download_metadata.txt                       — download info including DOI for citation

suppressPackageStartupMessages(library(rgbif))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(readr))

# ── 1. Parse arguments ──────────────────────────────────────────────────────
log_step(1, "Analisar argumentos da linha de comando")
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  species_input <- "Panthera onca"
  output_dir    <- "output/gbif"
  country_code  <- NULL
  year_from     <- 1950
  year_to       <- as.integer(format(Sys.Date(), "%Y"))
  log_warn("Menos de 2 argumentos fornecidos. Usando valores padrao para teste.")
} else {
  species_input <- args[1]
  output_dir    <- args[2]
  country_code  <- if (length(args) >= 3 && args[3] != "") args[3] else NULL
  year_from     <- if (length(args) >= 4) as.integer(args[4]) else 1950
  year_to       <- if (length(args) >= 5) as.integer(args[5]) else as.integer(format(Sys.Date(), "%Y"))
}

log_info("Script: download_from_gbif.R | Skill: %s", SKILL_NAME)
log_info("Species input : %s", species_input)
log_info("Output dir   : %s", output_dir)
log_info("Country code : %s", ifelse(is.null(country_code), "nenhum", country_code))
log_info("Year range   : %d - %d", year_from, year_to)

log_decision("year_from", year_from, "limite inferior do periodo de registros; 1950 = pos-era moderna")
log_decision("year_to",   year_to,   "limite superior do periodo de registros; ano corrente por padrao")
log_decision(
  "coord_uncertainty_max_m", "10000",
  "excluir registros com incerteza de coordenada > 10 km (imprecisao inaceitavel para SDM)"
)

# ── 2. Create output directory ───────────────────────────────────────────────
log_step(2, "Criar diretorio de saida")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
log_info("Diretorio de saida pronto: %s", output_dir)

# ── 3. Build species list ────────────────────────────────────────────────────
log_step(3, "Construir lista de especies")
# If input is a CSV file, read the scientificName column; otherwise treat as species name
if (grepl("\\.csv$", species_input, ignore.case = TRUE) && file.exists(species_input)) {
  tryCatch({
    species_df   <- read_csv(species_input, show_col_types = FALSE)
    if (!"scientificName" %in% names(species_df)) {
      log_error(
        "Coluna 'scientificName' nao encontrada em: %s\nCausa provavel: CSV de lista de especies mal formatado.\nVerifique o cabecalho do arquivo.\nSkill anterior: ecological-data-foundation",
        species_input
      )
      stop("Missing column 'scientificName' in: ", species_input)
    }
    species_list <- unique(trimws(species_df$scientificName))
    log_info("Modo batch: %d especies carregadas de %s", length(species_list), species_input)
    log_decision("mode", "batch", "argumento e um CSV valido com coluna scientificName")
  }, error = function(e) {
    log_error(
      "Falha ao ler lista de especies: %s\nCausa provavel: arquivo CSV invalido ou ausente.\nVerifique: %s\nSkill anterior: ecological-data-foundation",
      conditionMessage(e), species_input
    )
    stop(e)
  })
} else {
  species_list <- trimws(species_input)
  log_info("Modo especie unica: %s", species_list)
  log_decision("mode", "single_species", "argumento nao e um arquivo CSV existente")
}

# ── 4. Default filters ───────────────────────────────────────────────────────
log_step(4, "Definir filtros padrao de download")
# Applied to all downloads regardless of species:
# - hasCoordinate=TRUE: only georeferenced records
# - occurrenceStatus=PRESENT: no absence records
# - basisOfRecord: only field/specimen observations (no literature, fossils)
# - coordinateUncertaintyInMeters < 10000: exclude coarse records (> 10 km uncertainty)

basis_of_record_values <- c(
  "HUMAN_OBSERVATION",
  "MACHINE_OBSERVATION",
  "PRESERVED_SPECIMEN"
)
log_decision(
  "basis_of_record",
  paste(basis_of_record_values, collapse = ","),
  "apenas observacoes de campo/especimes; exclui literatura e fosseis"
)

# ── 5. Download function (single species) ────────────────────────────────────
download_species <- function(sp_name) {
  log_info("--- Iniciando download: %s ---", sp_name)
  today_str <- format(Sys.Date(), "%Y%m%d")
  safe_name <- gsub(" ", "_", sp_name)

  # Lookup GBIF taxon key (backbone match)
  taxon_match <- tryCatch(
    name_backbone(name = sp_name, rank = "SPECIES"),
    error = function(e) {
      log_error(
        "Falha ao buscar taxon key no backbone GBIF para '%s': %s\nCausa provavel: sem conexao com a internet ou API do GBIF indisponivel.\nVerifique sua conexao e tente novamente.\nSkill anterior: ecological-data-foundation",
        sp_name, conditionMessage(e)
      )
      stop(e)
    }
  )

  if (is.null(taxon_match$usageKey)) {
    log_warn("Taxon key GBIF nao encontrado para '%s'. Pulando.", sp_name)
    return(invisible(NULL))
  }
  taxon_key <- taxon_match$usageKey
  log_info("Taxon key GBIF: %d para '%s'", taxon_key, sp_name)

  # Build predicates for occ_download
  preds <- list(
    pred("taxonKey",       taxon_key),
    pred("hasCoordinate",  TRUE),
    pred("occurrenceStatus", "PRESENT"),
    pred_in("basisOfRecord", basis_of_record_values),
    pred_lt("coordinateUncertaintyInMeters", 10000),
    pred_gte("year", year_from),
    pred_lte("year", year_to)
  )
  if (!is.null(country_code)) {
    preds <- c(preds, list(pred("country", country_code)))
    log_info("Filtro de pais aplicado: %s", country_code)
  }

  # Decide between occ_search (quick, no DOI) and occ_download (DOI, reproducible)
  # First, check approximate record count
  count_check <- tryCatch(
    occ_count(
      taxonKey         = taxon_key,
      hasCoordinate    = TRUE,
      occurrenceStatus = "PRESENT"
    ),
    error = function(e) {
      log_warn("Falha ao consultar contagem de registros para '%s': %s. Assumindo dataset pequeno.", sp_name, conditionMessage(e))
      0L
    }
  )
  log_info("Contagem aproximada de registros (sem filtros): %d", count_check)

  if (count_check > 50000) {
    log_decision(
      "download_method", "occ_download",
      sprintf("dataset grande (%d registros) -> download assincrono com DOI para reprodutibilidade", count_check)
    )
    log_info("Usando occ_download (dataset grande; DOI sera gerado)...")

    dl_key <- tryCatch(
      do.call(occ_download, preds),
      error = function(e) {
        log_error(
          "Falha ao iniciar occ_download para '%s': %s\nCausa provavel: credenciais GBIF ausentes (GBIF_USER, GBIF_PWD, GBIF_EMAIL) ou API indisponivel.\nVerifique: usethis::edit_r_environ() e adicione as variaveis GBIF.\nSkill anterior: ecological-data-foundation",
          sp_name, conditionMessage(e)
        )
        stop(e)
      }
    )

    log_info("Download iniciado. Aguardando conclusao (verificacao a cada 30s)...")
    occ_download_wait(dl_key, status_ping = 30)

    # Retrieve DOI from metadata
    meta <- occ_download_meta(dl_key)
    doi  <- meta$doi
    log_info("DOI gerado: %s", ifelse(is.null(doi) || is.na(doi), "N/D", doi))

    # Import data
    occ_raw <- tryCatch({
      occ_download_get(dl_key, path = tempdir()) |>
        occ_download_import()
    }, error = function(e) {
      log_error(
        "Falha ao importar download do GBIF para '%s': %s\nCausa provavel: arquivo de download corrompido ou expirado.\nVerifique o status em: https://www.gbif.org/user/download\nSkill anterior: ecological-data-foundation",
        sp_name, conditionMessage(e)
      )
      stop(e)
    })

  } else {
    log_decision(
      "download_method", "occ_search",
      sprintf("dataset pequeno (%d registros) -> occ_search e mais rapido; sem DOI", count_check)
    )
    log_info("Usando occ_search (dataset pequeno)...")
    log_warn("occ_search nao gera DOI. Para publicacoes, use occ_download.")
    doi <- NA_character_
    dl_key <- NA_character_

    occ_raw <- tryCatch({
      occ_search(
        taxonKey              = taxon_key,
        hasCoordinate         = TRUE,
        occurrenceStatus      = "PRESENT",
        basisOfRecord         = basis_of_record_values,
        coordinateUncertaintyInMeters = c(0, 10000),
        year                  = paste(year_from, year_to, sep = ","),
        country               = country_code,
        limit                 = 100000,
        fields                = "minimal"
      )$data
    }, error = function(e) {
      log_error(
        "Falha em occ_search para '%s': %s\nCausa provavel: sem conexao com a internet ou API do GBIF indisponivel.\nVerifique sua conexao e tente novamente.\nSkill anterior: ecological-data-foundation",
        sp_name, conditionMessage(e)
      )
      stop(e)
    })
  }

  n_raw <- nrow(occ_raw)
  log_info("Registros recuperados: %d", n_raw)

  if (n_raw < 30) {
    log_warn(
      "Registros insuficientes para SDM confiavel (n = %d). Considere: (1) relaxar filtros, (2) ampliar escopo geografico, (3) usar outra base de dados.",
      n_raw
    )
  }

  # ── Save occurrence CSV ───────────────────────────────────────────────────
  csv_name <- file.path(output_dir,
                         paste0("occurrences_raw_GBIF_", safe_name, "_", today_str, ".csv"))
  tryCatch({
    write_csv(occ_raw, csv_name)
    log_info("Gravado: %s", csv_name)
  }, error = function(e) {
    log_error(
      "Falha ao gravar CSV de ocorrencias para '%s': %s\nCausa provavel: sem permissao de escrita em '%s'.\nSkill anterior: ecological-data-foundation",
      sp_name, conditionMessage(e), output_dir
    )
    stop(e)
  })

  # ── Save metadata (including DOI for citation) ────────────────────────────
  meta_text <- c(
    paste("Species:", sp_name),
    paste("GBIF taxon key:", taxon_key),
    paste("Download key:", dl_key),
    paste("DOI:", ifelse(is.na(doi), "NOT AVAILABLE (used occ_search)", doi)),
    paste("Citation:",
          ifelse(!is.na(doi),
                 paste0("GBIF.org (", format(Sys.Date(), "%Y"), ") GBIF Occurrence Download. ",
                        "https://doi.org/", doi, " Accessed on ", Sys.Date()),
                 "occ_search used — no citable DOI. Re-run with occ_download for publication.")),
    paste("Download date:", Sys.Date()),
    paste("n_records:", n_raw),
    paste("year_from:", year_from),
    paste("year_to:", year_to),
    paste("country_filter:", ifelse(is.null(country_code), "none", country_code)),
    paste("basisOfRecord:", paste(basis_of_record_values, collapse = ", ")),
    paste("coordinateUncertainty_max_m: 10000")
  )

  meta_path <- file.path(output_dir, paste0("download_metadata_", safe_name, ".txt"))
  tryCatch({
    writeLines(meta_text, meta_path)
    log_info("Gravado: %s", meta_path)
  }, error = function(e) {
    log_error(
      "Falha ao gravar metadados para '%s': %s\nCausa provavel: sem permissao de escrita em '%s'.\nSkill anterior: ecological-data-foundation",
      sp_name, conditionMessage(e), output_dir
    )
    stop(e)
  })

  return(invisible(csv_name))
}

# ── 6. Run for all species ───────────────────────────────────────────────────
log_step(5, "Executar download para todas as especies")
for (sp in species_list) {
  tryCatch(
    download_species(sp),
    error = function(e) {
      log_error(
        "Falha ao baixar '%s': %s\nCausa provavel: problema de rede, taxon nao encontrado ou credenciais GBIF invalidas.\nVerifique os logs acima para detalhes.\nSkill anterior: ecological-data-foundation",
        sp, conditionMessage(e)
      )
    }
  )
}

log_info("Todos os downloads concluidos. Verifique: %s", output_dir)
