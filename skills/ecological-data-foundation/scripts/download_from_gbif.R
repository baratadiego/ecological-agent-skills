# Usage: Rscript download_from_gbif.R <species_name_or_list_csv> <output_dir> [country_code] [year_from] [year_to]
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
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  species_input <- "Panthera onca"
  output_dir    <- "output/gbif"
  country_code  <- NULL
  year_from     <- 1950
  year_to       <- as.integer(format(Sys.Date(), "%Y"))
} else {
  species_input <- args[1]
  output_dir    <- args[2]
  country_code  <- if (length(args) >= 3 && args[3] != "") args[3] else NULL
  year_from     <- if (length(args) >= 4) as.integer(args[4]) else 1950
  year_to       <- if (length(args) >= 5) as.integer(args[5]) else as.integer(format(Sys.Date(), "%Y"))
}

# ── 2. Create output directory ───────────────────────────────────────────────
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── 3. Build species list ────────────────────────────────────────────────────
# If input is a CSV file, read the scientificName column; otherwise treat as species name
if (grepl("\\.csv$", species_input, ignore.case = TRUE) && file.exists(species_input)) {
  species_df   <- read_csv(species_input, show_col_types = FALSE)
  species_list <- unique(trimws(species_df$scientificName))
  message("Batch mode: ", length(species_list), " species loaded from ", species_input)
} else {
  species_list <- trimws(species_input)
  message("Single species mode: ", species_list)
}

# ── 4. Default filters ───────────────────────────────────────────────────────
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

# ── 5. Download function (single species) ────────────────────────────────────
download_species <- function(sp_name) {
  message("\n--- Downloading: ", sp_name, " ---")
  today_str <- format(Sys.Date(), "%Y%m%d")
  safe_name <- gsub(" ", "_", sp_name)

  # Lookup GBIF taxon key (backbone match)
  taxon_match <- name_backbone(name = sp_name, rank = "SPECIES")
  if (is.null(taxon_match$usageKey)) {
    message("WARNING: Could not find GBIF taxon key for '", sp_name, "'. Skipping.")
    return(invisible(NULL))
  }
  taxon_key <- taxon_match$usageKey
  message("GBIF taxon key: ", taxon_key)

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
  }

  # Decide between occ_search (quick, no DOI) and occ_download (DOI, reproducible)
  # First, check approximate record count
  count_check <- occ_count(
    taxonKey   = taxon_key,
    hasCoordinate = TRUE,
    occurrenceStatus = "PRESENT"
  )
  message("Approximate record count (unfiltered): ", count_check)

  if (count_check > 50000) {
    # Large dataset: use full asynchronous download with DOI
    message("Using occ_download (large dataset, DOI will be generated)...")

    dl_key <- do.call(occ_download, preds)

    message("Download initiated. Waiting for completion (polling every 30s)...")
    occ_download_wait(dl_key, status_ping = 30)

    # Retrieve DOI from metadata
    meta <- occ_download_meta(dl_key)
    doi  <- meta$doi

    # Import data
    occ_raw <- occ_download_get(dl_key, path = tempdir()) |>
      occ_download_import()

  } else {
    # Small dataset: use occ_search (faster, but no DOI for citation)
    message("Using occ_search (small dataset)...")
    message("NOTE: occ_search does not generate a DOI. For publications, use occ_download.")
    doi <- NA_character_
    dl_key <- NA_character_

    occ_raw <- occ_search(
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
  }

  n_raw <- nrow(occ_raw)
  message("Records retrieved: ", n_raw)

  if (n_raw < 30) {
    message("WARNING: insufficient records for reliable SDM (n = ", n_raw, ")")
    message("  Consider: (1) relaxing filters, (2) expanding geographic scope,",
            " (3) using a different occurrence database.")
  }

  # ── Save occurrence CSV ───────────────────────────────────────────────────
  csv_name <- file.path(output_dir,
                         paste0("occurrences_raw_GBIF_", safe_name, "_", today_str, ".csv"))
  write_csv(occ_raw, csv_name)
  message("Saved: ", csv_name)

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
  writeLines(meta_text, meta_path)
  message("Saved: ", meta_path)

  return(invisible(csv_name))
}

# ── 6. Run for all species ───────────────────────────────────────────────────
for (sp in species_list) {
  tryCatch(
    download_species(sp),
    error = function(e) {
      message("ERROR downloading '", sp, "': ", conditionMessage(e))
    }
  )
}

message("\nAll downloads complete. Check ", output_dir, " for outputs.")
