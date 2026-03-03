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
  log_error("Input nao encontrado: %s\nCausa provavel: caminho errado ou diretorio nao montado\nVerifique: se o diretorio de imagens existe e tem permissao de leitura\nSkill anterior: [nenhuma — etapa inicial]", image_dir)
  stop("Missing image_dir: ", image_dir)
}
if (!file.exists(metadata_csv)) {
  log_error("Input nao encontrado: %s\nCausa provavel: arquivo CSV de metadados nao gerado ou nome incorreto\nVerifique: se o arquivo existe e o caminho esta correto\nSkill anterior: [nenhuma — etapa inicial]", metadata_csv)
  stop("Missing metadata_csv: ", metadata_csv)
}

log_decision("indep_threshold_min", thresh_min,
             "limiar padrao de 30 min para independencia de registros; ajuste por especie se necessario")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_step(1, "Carregando metadados das cameras")
cam_meta <- tryCatch({
  read.csv(metadata_csv, stringsAsFactors = FALSE)
}, error = function(e) {
  log_error("Falha ao ler metadata CSV: %s\nCausa provavel: arquivo corrompido ou formato incorreto\nVerifique: estrutura do CSV\nSkill anterior: [nenhuma]", conditionMessage(e))
  stop(e)
})
log_info("Metadados carregados: %d estacoes", nrow(cam_meta))

required_cols <- c("Station", "Setup_date", "Retrieval_date")
missing <- setdiff(required_cols, names(cam_meta))
if (length(missing) > 0) {
  log_error("Colunas obrigatorias ausentes no CSV de metadados: %s\nCausa provavel: formato de planilha incorreto\nVerifique: se o CSV contem Station, Setup_date, Retrieval_date", paste(missing, collapse = ", "))
  stop("Camera metadata missing required columns: ", paste(missing, collapse = ", "))
}

log_step(2, "Construindo matriz de operacao das cameras")
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
  log_error("Falha em cameraOperation(): %s\nCausa provavel: datas em formato errado ou estacoes duplicadas\nVerifique: formato yyyy-mm-dd nas colunas de data\nSkill anterior: [nenhuma]", conditionMessage(e))
  stop(e)
})

# Trap effort per station
trap_effort <- data.frame(
  Station    = rownames(cam_op),
  trap_nights = apply(cam_op, 1, sum, na.rm = TRUE)
)
low_effort <- trap_effort$Station[trap_effort$trap_nights < 100]
if (length(low_effort) > 0) {
  log_warn("Estacoes com < 100 armadilhas-noite (dados insuficientes para ocupancia): %s",
           paste(low_effort, collapse = ", "))
}

log_step(3, "Construindo tabela de registros a partir das imagens")
log_info("Limiar de independencia: %d min", thresh_min)
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
  log_error("Falha em recordTable(): %s\nCausa provavel: estrutura de diretorios incorreta\nVerifique: se imagens seguem <Estacao>/<Especie>/<imagens>\nSkill anterior: [nenhuma]", conditionMessage(e))
  stop("recordTable() failed: ", conditionMessage(e),
       "\nCheck that image directory follows <Station>/<Species>/<images> structure.")
})
log_info("Tabela de registros construida: %d eventos independentes", nrow(record_table))

log_step(4, "Calculando resumo de registros por especie")
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
  log_warn("Especies com < 10 eventos independentes (apenas RAI; sem ocupancia): %s",
           paste(low_detections, collapse = ", "))
}

log_step(5, "Gerando historicos de deteccao por especie")
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
      log_warn("detectionHistory() falhou para especie '%s': %s", sp, conditionMessage(e))
      NULL
    }
  )
  if (!is.null(dh)) det_hist_list[[sp_clean]] <- dh$detection_history
}
log_info("Historicos de deteccao gerados para %d especies", length(det_hist_list))

log_step(6, "Escrevendo arquivos de saida")
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

log_info("Concluido. Saidas gravadas em: %s", output_dir)
log_info("  record_table.csv: %d eventos independentes", nrow(record_table))
log_info("  records_per_species.csv: %d especies", nrow(records_per_species))
log_info("  trap_effort_summary.csv: %d estacoes", nrow(trap_effort))
