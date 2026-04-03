# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript stack_and_extract.R <raster_dir> <points.csv> <study_area.shp> <output_dir>
# Clip rasters to study area and extract values at points
# Usage: Rscript stack_and_extract.R <raster_dir> <points_csv> <studyarea_shp> <output_dir>
# Requires: terra, sf

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "geoprocessing-for-ecology"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages({
  library(terra)
  library(sf)
})

args        <- commandArgs(trailingOnly = TRUE)
raster_dir  <- ifelse(length(args) >= 1, args[1], "data/predictors/raw")
points_file <- ifelse(length(args) >= 2, args[2], "data/processed/data_clean.csv")
area_file   <- ifelse(length(args) >= 3, args[3], "data/spatial/study_area.shp")
output_dir  <- ifelse(length(args) >= 4, args[4], "data/processed")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_info("Skill: %s | raster_dir=%s | points_file=%s | area_file=%s | output_dir=%s",
         SKILL_NAME, raster_dir, points_file, area_file, output_dir)

# ── Input precondition checks ─────────────────────────────────────────────────
if (!dir.exists(raster_dir)) {
  log_error(
    "Raster directory not found: %s\nProbable cause: incorrect path or rasters not yet downloaded/prepared.\nCheck: whether the directory exists and contains .tif files.\nPrevious skill: download-predictors or remote-sensing-analysis.",
    raster_dir
  )
  stop("Missing raster directory: ", raster_dir)
}

if (!file.exists(points_file)) {
  log_error(
    "Input not found: %s\nProbable cause: points CSV not generated or incorrect path.\nCheck: run the occurrence cleaning script first.\nPrevious skill: species-distribution-modeling (data cleaning step).",
    points_file
  )
  stop("Missing: ", points_file)
}

if (!file.exists(area_file)) {
  log_error(
    "Input not found: %s\nProbable cause: shapefile da study area missing ou incorrect path.\nCheck: that therquivo .shp existe e se os arquivos auxiliares (.dbf, .shx, .prj) estao no mesmo directory.\nPrevious skill: geoprocessing-for-ecology (study area definition step).",
    area_file
  )
  stop("Missing: ", area_file)
}

# ── 1. Load study area ─────────────────────────────────────────────────────────
log_step(1, "Load study area (shapefile)")
study_area <- tryCatch({
  vect(area_file)
}, error = function(e) {
  log_error(
    "Failed to load shapefile da study area: %s\nProbable cause: corrupted file, CRS missing (.prj faltando) ou invalid format.\nCheck: se todos os arquivos do shapefile (.shp, .dbf, .shx, .prj) estao presentes.\nPrevious skill: geoprocessing-for-ecology (study area definition step).",
    conditionMessage(e)
  )
  stop(e)
})
log_info("Study area loaded: CRS=%s | Features=%d", crs(study_area, describe=TRUE)$code, nrow(study_area))

# ── 2. Load and stack rasters ──────────────────────────────────────────────────
log_step(2, "List and stack .tif rasters from input directory")
tif_files <- list.files(raster_dir, pattern = "\\.tif$", full.names = TRUE)
log_info("Rasters encontrados: %d", length(tif_files))

if (length(tif_files) == 0) {
  log_error(
    "No .tif files found in: %s\nProbable cause: empty directory, rasters em subpasta nao listada ou extensao diferente (.tiff).\nCheck: o contents of directory e considere usar pattern='\\\\.tiff?$' se necessario.\nPrevious skill: download-predictors.",
    raster_dir
  )
  stop("No .tif files found in ", raster_dir)
}

log_decision("raster_pattern", "\\.tif$",
             "apenas arquivos com extensao .tif sao carregados; arquivos .tiff devem ser renomeados ou o padrao ajustado")

stack_raw <- tryCatch({
  rast(tif_files)
}, error = function(e) {
  log_error(
    "Failed to stack rasters: %s\nProbable cause: rasters with incompatible resolutions, extents, or CRS.\nCheck: all rasters must share the same resolution and CRS before stacking.\nPrevious skill: download-predictors.",
    conditionMessage(e)
  )
  stop(e)
})

log_info("Stack created: %d layers | resolution=%.4f x %.4f | CRS=%s",
         nlyr(stack_raw), res(stack_raw)[1], res(stack_raw)[2],
         crs(stack_raw, describe=TRUE)$code)

# ── 3. Reproject study area to raster CRS, then crop and mask ─────────────────
log_step(3, "Reproject study area and crop raster stack")
log_decision("reproject_target", "CRS of raster stack",
             "reprojetar o vetor (leve) e nao o raster (pesado) minimiza tempo de processamento e artefatos de interpolacao")

stack_crop <- tryCatch({
  study_proj <- project(study_area, crs(stack_raw))
  crop_result <- crop(stack_raw, study_proj)
  mask(crop_result, study_proj)
}, error = function(e) {
  log_error(
    "Failed to clip and mask rasters with study area: %s\nProbable cause: study area outside the raster extent or incompatible CRS.\nCheck: verify that the study area and rasters overlap geographically.\nPrevious skill: download-predictors.",
    conditionMessage(e)
  )
  stop(e)
})

log_info("Stack recortado: extensao=%.4f,%.4f,%.4f,%.4f (xmin,xmax,ymin,ymax)",
         ext(stack_crop)[1], ext(stack_crop)[2], ext(stack_crop)[3], ext(stack_crop)[4])

n_valid_cells <- sum(!is.na(values(stack_crop[[1]])))
if (n_valid_cells == 0) {
  log_warn("Masked stack contains no valid cells — the study area may not overlap the rasters.")
}

# ── 4. Write stack ─────────────────────────────────────────────────────────────
log_step(4, "Save processed raster stack")
stack_out <- file.path(output_dir, "predictors_stack.tif")
tryCatch({
  writeRaster(stack_crop, stack_out, overwrite = TRUE)
  log_info("Stack salvo: %s", stack_out)
}, error = function(e) {
  log_error(
    "Failed to salvar stack de rasters: %s\nProbable cause: disco cheio, permissao negada ou caminho invalido.\nCheck: espaco em disco e permissoes do output directory.\nPrevious skill: [none].",
    conditionMessage(e)
  )
  stop(e)
})

# ── 5. Load points and extract ─────────────────────────────────────────────────
log_step(5, "Load occurrence points and extract environmental values")
pts_df <- tryCatch({
  read.csv(points_file)
}, error = function(e) {
  log_error(
    "Failed to read CSV de pontos: %s\nProbable cause: corrupted file ou separador incorreto.\nCheck: formato do CSV de ocorrencias.\nPrevious skill: species-distribution-modeling (data cleaning step).",
    conditionMessage(e)
  )
  stop(e)
})

if (!all(c("decimalLongitude", "decimalLatitude") %in% names(pts_df))) {
  log_error(
    "Colunas de coordenadas missing no CSV de pontos (colunas presentes: %s).\nProbable cause: CSV exportado com nomes de colunas diferentes (ex.: 'lon'/'lat' ou 'x'/'y').\nCheck: renomeie as colunas para 'decimalLongitude' e 'decimalLatitude'.\nPrevious skill: species-distribution-modeling (data cleaning step).",
    paste(names(pts_df), collapse = ", ")
  )
  stop("Points CSV must have columns: decimalLongitude, decimalLatitude")
}

log_info("Pontos carregados: %d registros", nrow(pts_df))
log_decision("points_crs", "EPSG:4326",
             "assume coordenadas geograficas WGS84 (graus decimais); ajuste se os pontos estiverem em outro CRS")

n_na_coords <- sum(is.na(pts_df$decimalLongitude) | is.na(pts_df$decimalLatitude))
if (n_na_coords > 0) {
  log_warn("%d point(s) with NA coordinates — will be excluded during vectorisation.", n_na_coords)
}

pts_vect <- tryCatch({
  vect(pts_df, geom = c("decimalLongitude", "decimalLatitude"), crs = "EPSG:4326")
}, error = function(e) {
  log_error(
    "Failed to criar SpatVector de pontos: %s\nProbable cause: coordenadas fora do intervalo valido ou valores NA nao removidos.\nCheck: se longitude esta entre -180 e 180 e latitude entre -90 e 90.\nPrevious skill: species-distribution-modeling (data cleaning step).",
    conditionMessage(e)
  )
  stop(e)
})

pts_proj <- tryCatch({
  project(pts_vect, crs(stack_crop))
}, error = function(e) {
  log_error(
    "Failed to reproject points to stack CRS: %s\nProbable cause: invalid stack CRS or transformation not supported.\nCheck: raster stack CRS.\nPrevious skill: [none].",
    conditionMessage(e)
  )
  stop(e)
})

extracted <- tryCatch({
  terra::extract(stack_crop, pts_proj, ID = FALSE)
}, error = function(e) {
  log_error(
    "Failed to extrair valores do raster nos pontos: %s\nProbable cause: stack ou pontos invalidos, ou nenhum ponto dentro da extensao do raster.\nCheck: se os pontos estao dentro da study area.\nPrevious skill: [none].",
    conditionMessage(e)
  )
  stop(e)
})

n_complete <- sum(complete.cases(extracted))
n_total    <- nrow(extracted)
pct_complete <- round(100 * n_complete / n_total, 1)

if (pct_complete < 80) {
  log_warn("Only %.1f%% of points (%d/%d) have complete environmental data — many points outside masked area.", pct_complete, n_complete, n_total)
} else {
  log_info("Points with complete environmental data: %d/%d (%.1f%%)", n_complete, n_total, pct_complete)
}

pts_env <- cbind(pts_df, extracted)

env_out <- file.path(output_dir, "points_with_env.csv")
tryCatch({
  write.csv(pts_env, env_out, row.names = FALSE)
  log_info("Valores extraidos salvos: %s", env_out)
}, error = function(e) {
  log_error(
    "Failed to salvar points_with_env.csv: %s\nProbable cause: permissao negada ou disco cheio.\nCheck: permissoes do output directory.\nPrevious skill: [none].",
    conditionMessage(e)
  )
  stop(e)
})

log_info("Geoprocessamento completed. Outputs in: %s", output_dir)
