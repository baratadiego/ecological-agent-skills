# Usage: Rscript clean_occurrences.R <raw_occurrences.csv> <output_dir> [country_code]
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
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── 1. Ingest ──────────────────────────────────────────────────────────────
cat("Reading:", input_file, "\n")
raw <- read_csv(input_file, show_col_types = FALSE) |>
  clean_names()

cat("Raw records:", nrow(raw), "\n")

# ── 2. Require minimum columns ─────────────────────────────────────────────
required_cols <- c("decimal_latitude", "decimal_longitude", "species")
missing_req <- setdiff(required_cols, names(raw))
if (length(missing_req) > 0) {
  stop("Missing required columns: ", paste(missing_req, collapse = ", "))
}

# ── 3. Remove records with missing coordinates ─────────────────────────────
raw <- raw |>
  filter(!is.na(decimal_latitude), !is.na(decimal_longitude)) |>
  mutate(
    decimal_latitude  = as.numeric(decimal_latitude),
    decimal_longitude = as.numeric(decimal_longitude)
  )

# ── 4. Coordinate cleaning ─────────────────────────────────────────────────
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

# ── 5. Remove exact duplicates ─────────────────────────────────────────────
n_before <- nrow(clean)
clean <- clean |> distinct(species, decimal_latitude, decimal_longitude,
                            event_date, .keep_all = TRUE)
n_dup <- n_before - nrow(clean)

# ── 6. Write outputs ───────────────────────────────────────────────────────
write_csv(clean,   file.path(output_dir, "data_clean.csv"))
write_csv(flagged, file.path(output_dir, "flagged_records.csv"))

# ── 7. QA report ──────────────────────────────────────────────────────────
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
cat("Done. Clean records:", nrow(clean), "| Flagged:", nrow(flagged), "\n")
