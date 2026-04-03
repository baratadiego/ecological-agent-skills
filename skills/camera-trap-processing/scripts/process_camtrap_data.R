# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript process_camtrap_data.R <image_dir> <camera_metadata_csv> <output_dir> [indep_threshold_min]

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "camera-trap-processing"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages(library(camtrapR))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(lubridate))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  log_error("Uso: Rscript process_camtrap_data.R <image_dir> <camera_metadata_csv> <output_dir> [indep_threshold_min]")
  cat("Usage: Rscript process_camtrap_data.R <image_dir> <camera_metadata_csv> <output_dir> [indep_threshold_min]\n")
  cat("  indep_threshold_min: independence threshold in minutes (default: 30)\n")
  quit(status = 1)
}

image_dir    <- args[1]
metadata_csv <- args[2]
output_dir   <- args[3]
thresh_min   <- ifelse(length(args) >= 4, as.integer(args[4]), 30L)

# ── Input precondition checks ────────────────────────────────────────────────
if (!dir.exists(image_dir)) {
  log_error("Input not found: %s\nProbable cause: incorrect path or directory not mounted\nCheck: se o image directory exists and has read permission\nPrevious skill: [none — initial step]", image_dir)
  stop("Missing image_dir: ", image_dir)
}
if (!file.exists(metadata_csv)) {
  log_error("Input not found: %s\nProbable cause: metadata CSV file not generated or incorrect name\nCheck: that the file exists and path is correct\nPrevious skill: [none — initial step]", metadata_csv)
  stop("Missing metadata_csv: ", metadata_csv)
}

log_decision("indep_threshold_min", thresh_min,
             "limiar padrao de 30 min para independencia de registros; ajuste por especie se necessario")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_step(1, "Loading camera metadata")
cam_meta <- tryCatch({
  read.csv(metadata_csv, stringsAsFactors = FALSE)
}, error = function(e) {
  log_error("Failed to read metadata CSV: %s\nProbable cause: corrupted file or incorrect format\nCheck: CSV structure\nPrevious skill: [none]", conditionMessage(e))
  stop(e)
})
log_info("Metadata loaded: %d stations", nrow(cam_meta))

required_cols <- c("Station", "Setup_date", "Retrieval_date")
missing <- setdiff(required_cols, names(cam_meta))
if (length(missing) > 0) {
  log_error("Required columns missing in metadata CSV: %s\nProbable cause: incorrect spreadsheet format\nCheck: se o CSV contem Station, Setup_date, Retrieval_date", paste(missing, collapse = ", "))
  stop("Camera metadata missing required columns: ", paste(missing, collapse = ", "))
}

log_step(2, "Building camera operation matrix")
has_problems <- all(c("Problem1_from", "Problem1_to") %in% names(cam_meta))
log_decision("has_problems", has_problems,
             "indica se ha colunas de problemas tecnicas nas cameras no CSV")

cam_op <- tryCatch({
  cameraOperation(
    CTtable      = cam_meta,
    stationCol   = "Station",
    setupCol     = "Setup_date",
    retrievalCol = "Retrieval_date",
    hasProblems  = has_problems,
    dateFormat   = "yyyy-mm-dd"
  )
}, error = function(e) {
  log_error("Failed in cameraOperation(): %s\nProbable cause: dates in incorrect format or duplicate stations\nCheck: yyyy-mm-dd format in date columns\nPrevious skill: [none]", conditionMessage(e))
  stop(e)
})

# Trap effort per station
trap_effort <- data.frame(
  Station    = rownames(cam_op),
  trap_nights = apply(cam_op, 1, sum, na.rm = TRUE)
)
low_effort <- trap_effort$Station[trap_effort$trap_nights < 100]
if (length(low_effort) > 0) {
  log_warn("Stations with < 100 trap-nights (insufficient data for occupancy): %s",
           paste(low_effort, collapse = ", "))
}

log_step(3, "Building record table from images")
log_info("Independence threshold: %d min", thresh_min)
record_table <- tryCatch({
  recordTable(
    inDir               = image_dir,
    IDfrom              = "directory",
    minDeltaTime        = thresh_min,
    deltaTimeComparedTo = "lastIndependentRecord",
    timeZone            = Sys.timezone(),
    removeDuplicateRecords = TRUE
  )
}, error = function(e) {
  log_error("Failed in recordTable(): %s\nProbable cause: incorrect directory structure\nCheck: that images follow <Station>/<Species>/<images>\nPrevious skill: [none]", conditionMessage(e))
  stop("recordTable() failed: ", conditionMessage(e),
       "\nCheck that image directory follows <Station>/<Species>/<images> structure.")
})
log_info("Record table built: %d independent events", nrow(record_table))

log_step(4, "Computing record summary per species")
# Records per species summary
records_per_species <- record_table %>%
  group_by(Species) %>%
  summarise(
    n_events       = n(),
    n_stations     = n_distinct(Station),
    first_detection = min(DateTimeOriginal),
    last_detection  = max(DateTimeOriginal),
    .groups = "drop"
  )

low_detections <- records_per_species$Species[records_per_species$n_events < 10]
if (length(low_detections) > 0) {
  log_warn("Species with < 10 independent events (RAI only; no occupancy): %s",
           paste(low_detections, collapse = ", "))
}

log_step(5, "Generating detection histories per species")
# Generate detection history for all species with >= 10 events
det_hist_list <- list()
for (sp in records_per_species$Species[records_per_species$n_events >= 10]) {
  sp_clean <- gsub(" ", "_", sp)
  dh <- tryCatch(
    detectionHistory(
      recordTable       = record_table,
      camOp             = cam_op,
      stationCol        = "Station",
      speciesCol        = "Species",
      recordDateTimeCol = "DateTimeOriginal",
      species           = sp,
      occasionLength    = 7,
      day1              = "station",
      output            = "binary"
    ),
    error = function(e) {
      log_warn("detectionHistory() failed for species '%s': %s", sp, conditionMessage(e))
      NULL
    }
  )
  if (!is.null(dh)) det_hist_list[[sp_clean]] <- dh$detection_history
}
log_info("Detection histories generated for %d species", length(det_hist_list))

log_step(6, "Writing output files")
# Write outputs
write.csv(record_table,        file.path(output_dir, "record_table.csv"),        row.names = FALSE)
write.csv(cam_op,              file.path(output_dir, "camera_operation.csv"),     row.names = TRUE)
write.csv(trap_effort,         file.path(output_dir, "trap_effort_summary.csv"),  row.names = FALSE)
write.csv(records_per_species, file.path(output_dir, "records_per_species.csv"),  row.names = FALSE)

if (length(det_hist_list) > 0) {
  # Write the first species' detection history as default output
  dh_df <- as.data.frame(det_hist_list[[1]])
  write.csv(dh_df, file.path(output_dir, "detection_history.csv"), row.names = TRUE)
  # Write all species if multiple
  for (sp_name in names(det_hist_list)) {
    dh_df_sp <- as.data.frame(det_hist_list[[sp_name]])
    write.csv(dh_df_sp,
              file.path(output_dir, paste0("detection_history_", sp_name, ".csv")),
              row.names = TRUE)
  }
}

log_info("Completed. Outputs saved to: %s", output_dir)
log_info("  record_table.csv: %d independent events", nrow(record_table))
log_info("  records_per_species.csv: %d especies", nrow(records_per_species))
log_info("  trap_effort_summary.csv: %d stations", nrow(trap_effort))
