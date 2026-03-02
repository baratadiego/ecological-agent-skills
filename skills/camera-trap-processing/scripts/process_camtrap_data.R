# Usage: Rscript process_camtrap_data.R <image_dir> <camera_metadata_csv> <output_dir> [indep_threshold_min]
suppressPackageStartupMessages(library(camtrapR))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(lubridate))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  cat("Usage: Rscript process_camtrap_data.R <image_dir> <camera_metadata_csv> <output_dir> [indep_threshold_min]\n")
  cat("  indep_threshold_min: independence threshold in minutes (default: 30)\n")
  quit(status = 1)
}

image_dir    <- args[1]
metadata_csv <- args[2]
output_dir   <- args[3]
thresh_min   <- ifelse(length(args) >= 4, as.integer(args[4]), 30L)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

message("Loading camera metadata from: ", metadata_csv)
cam_meta <- read.csv(metadata_csv, stringsAsFactors = FALSE)

required_cols <- c("Station", "Setup_date", "Retrieval_date")
missing <- setdiff(required_cols, names(cam_meta))
if (length(missing) > 0) {
  stop("Camera metadata missing required columns: ", paste(missing, collapse = ", "))
}

message("Building camera operation matrix ...")
has_problems <- all(c("Problem1_from", "Problem1_to") %in% names(cam_meta))
cam_op <- cameraOperation(
  CTtable      = cam_meta,
  stationCol   = "Station",
  setupCol     = "Setup_date",
  retrievalCol = "Retrieval_date",
  hasProblems  = has_problems,
  dateFormat   = "yyyy-mm-dd"
)

# Trap effort per station
trap_effort <- data.frame(
  Station    = rownames(cam_op),
  trap_nights = apply(cam_op, 1, sum, na.rm = TRUE)
)
low_effort <- trap_effort$Station[trap_effort$trap_nights < 100]
if (length(low_effort) > 0) {
  warning("Stations with < 100 trap-nights (flagged): ", paste(low_effort, collapse = ", "))
}

message("Building record table from images (threshold = ", thresh_min, " min) ...")
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
  stop("recordTable() failed: ", conditionMessage(e),
       "\nCheck that image directory follows <Station>/<Species>/<images> structure.")
})

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
  message("Species with < 10 independent events (RAI only, no occupancy): ",
          paste(low_detections, collapse = ", "))
}

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
    error = function(e) NULL
  )
  if (!is.null(dh)) det_hist_list[[sp_clean]] <- dh$detection_history
}

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

message("Done. Outputs written to: ", output_dir)
message("  record_table.csv: ", nrow(record_table), " independent events")
message("  records_per_species.csv: ", nrow(records_per_species), " species")
message("  trap_effort_summary.csv: ", nrow(trap_effort), " stations")
