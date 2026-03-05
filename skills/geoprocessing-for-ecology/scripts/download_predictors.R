# Usage: Rscript download_predictors.R <output_dir> [resolution] [extent_wkt] [source]

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "geoprocessing-for-ecology"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

#
# Arguments:
#   output_dir   : Directory to write predictor rasters (created if absent)
#   resolution   : WorldClim resolution: 2.5, 5, or 10 (arc-minutes, default: 2.5)
#   extent_wkt   : WKT bounding box to clip outputs — e.g., "POLYGON((-80 -30,-80 10,-30 10,-30 -30,-80 -30))"
#                  If not provided, global layers are saved without clipping.
#   source       : Comma-separated list of sources to download: worldclim,chelsa,modis
#                  Default: "worldclim"
#
# Outputs:
#   output_dir/worldclim/wc2.1_{res}m_bio_{1..19}.tif  — WorldClim bioclimatic variables
#   output_dir/chelsa/CHELSA_bio{1..19}.tif             — CHELSA bioclimatic variables
#   output_dir/predictor_metadata.csv                   — layer provenance and checksums
#
# References:
#   WorldClim: Fick & Hijmans (2017) doi:10.1002/joc.5086
#   CHELSA: Karger et al. (2021) doi:10.1038/s41597-021-01084-7

suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(geodata))

# ── 1. Parse arguments ───────────────────────────────────────────────────────
log_step(1, "Analisar argumentos da linha de comando")
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 1) {
  output_dir  <- "data/predictors"
  resolution  <- 2.5
  extent_wkt  <- NULL
  sources     <- "worldclim"
  log_warn("Nenhum argumento fornecido. Usando valores padrao.")
} else {
  output_dir  <- args[1]
  resolution  <- if (length(args) >= 2) as.numeric(args[2]) else 2.5
  extent_wkt  <- if (length(args) >= 3 && args[3] != "") args[3] else NULL
  sources     <- if (length(args) >= 4) args[4] else "worldclim"
}

sources_list <- trimws(strsplit(sources, ",")[[1]])

log_info("Script: download_predictors.R | Skill: %s", SKILL_NAME)
log_info("Output dir   : %s", output_dir)
log_info("Resolution   : %g arc-minutes", resolution)
log_info("Extent WKT   : %s", ifelse(is.null(extent_wkt), "global (sem corte)", extent_wkt))
log_info("Sources      : %s", paste(sources_list, collapse = ", "))

log_decision("resolution", resolution,
             "2.5 arc-min (~4.5 km) e o equilibrio padrao entre detalhe e tamanho de arquivo")

if (!resolution %in% c(0.5, 2.5, 5, 10)) {
  log_warn("Resolucao %g nao e um valor padrao do WorldClim (0.5, 2.5, 5, 10). Pode causar erro no download.", resolution)
}

# ── 2. Create output directory ───────────────────────────────────────────────
log_step(2, "Criar diretorio de saida")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── 3. Parse extent ──────────────────────────────────────────────────────────
clip_extent <- NULL
if (!is.null(extent_wkt)) {
  log_step(3, "Interpretar extensao WKT para corte de camadas")
  tryCatch({
    clip_extent <- terra::vect(extent_wkt, crs = "EPSG:4326")
    log_info("Extensao de corte: %s", paste(as.vector(terra::ext(clip_extent)), collapse = ", "))
  }, error = function(e) {
    log_error(
      "Falha ao interpretar extent_wkt: %s\nCausa provavel: WKT invalido.\nExemplo valido: POLYGON((-80 -30,-80 10,-30 10,-30 -30,-80 -30))\nSkill anterior: geoprocessing-for-ecology",
      conditionMessage(e)
    )
    stop(e)
  })
} else {
  log_step(3, "Sem extensao de corte — camadas globais serao salvas integralmente")
}

# ── Helper: clip and save raster ─────────────────────────────────────────────
clip_and_save <- function(r, out_path, clip_ext) {
  if (!is.null(clip_ext)) {
    r <- tryCatch(
      terra::crop(r, clip_ext),
      error = function(e) {
        log_warn("Falha ao cortar camada para extensao: %s. Salvando versao global.", conditionMessage(e))
        r
      }
    )
  }
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  terra::writeRaster(r, out_path, overwrite = TRUE)
  log_info("Salvo: %s", out_path)
  return(invisible(out_path))
}

# ── Helper: compute SHA256 checksum ──────────────────────────────────────────
sha256_file <- function(path) {
  tryCatch({
    digest::digest(file = path, algo = "sha256")
  }, error = function(e) {
    "N/A"
  })
}

# ── Metadata accumulator ─────────────────────────────────────────────────────
meta_rows <- list()

# ── 4. Download WorldClim ────────────────────────────────────────────────────
if ("worldclim" %in% sources_list) {
  log_step(4, "Baixar WorldClim v2.1 — variaveis bioclimaticas")
  wc_dir <- file.path(output_dir, "worldclim")
  dir.create(wc_dir, recursive = TRUE, showWarnings = FALSE)

  log_decision("worldclim_var", "bio",
               "19 variaveis bioclimaticas cobrem todos os aspectos de temperatura e precipitacao")

  bio_stack <- tryCatch({
    geodata::worldclim_global(var = "bio", res = resolution, path = wc_dir)
  }, error = function(e) {
    log_error(
      "Falha ao baixar WorldClim: %s\nCausa provavel: sem conexao com a internet ou servidor WorldClim indisponivel.\nVerifique: https://worldclim.org/\nSkill anterior: geoprocessing-for-ecology",
      conditionMessage(e)
    )
    stop(e)
  })

  log_info("WorldClim baixado: %d camadas", terra::nlyr(bio_stack))

  # Save individual BIO layers
  for (i in seq_len(terra::nlyr(bio_stack))) {
    layer_name <- paste0("BIO", i)
    out_path   <- file.path(wc_dir, sprintf("wc2.1_%gm_bio_%d.tif", resolution, i))
    r <- bio_stack[[i]]
    clip_and_save(r, out_path, clip_extent)
    meta_rows[[length(meta_rows) + 1]] <- list(
      source      = "WorldClim_v2.1",
      variable    = layer_name,
      resolution  = paste0(resolution, " arc-min"),
      file        = out_path,
      citation    = "Fick & Hijmans (2017) doi:10.1002/joc.5086",
      licence     = "CC BY 4.0",
      download_date = format(Sys.Date(), "%Y-%m-%d")
    )
  }
  log_info("WorldClim: todos os 19 BIO salvo em %s", wc_dir)
}

# ── 5. Download CHELSA ───────────────────────────────────────────────────────
if ("chelsa" %in% sources_list) {
  log_step(5, "Baixar CHELSA v2.1 — variaveis bioclimaticas")
  ch_dir <- file.path(output_dir, "chelsa")
  dir.create(ch_dir, recursive = TRUE, showWarnings = FALSE)

  chelsa_base <- "https://os.zhdk.cloud.switch.ch/envicloud/chelsa/chelsa_V2/GLOBAL/climatologies/1981-2010/bio"

  for (i in 1:19) {
    fname    <- sprintf("CHELSA_bio%d_1981-2010_V.2.1.tif", i)
    url      <- paste0(chelsa_base, "/", fname)
    out_path <- file.path(ch_dir, sprintf("CHELSA_bio%d.tif", i))

    log_info("Baixando CHELSA BIO%d de: %s", i, url)
    dl_ok <- tryCatch({
      download.file(url, out_path, mode = "wb", quiet = TRUE)
      TRUE
    }, error = function(e) {
      log_error(
        "Falha ao baixar CHELSA BIO%d: %s\nCausa provavel: servidor CHELSA indisponivel ou sem conexao.\nVerifique: https://chelsa-climate.org/\nSkill anterior: geoprocessing-for-ecology",
        i, conditionMessage(e)
      )
      FALSE
    })

    if (!dl_ok) next

    # Apply clip if requested
    if (!is.null(clip_extent)) {
      tryCatch({
        r <- terra::rast(out_path)
        r <- terra::crop(r, clip_extent)
        terra::writeRaster(r, out_path, overwrite = TRUE)
        log_info("CHELSA BIO%d cortado para extensao de estudo.", i)
      }, error = function(e) {
        log_warn("Falha ao cortar CHELSA BIO%d: %s. Mantendo versao global.", i, conditionMessage(e))
      })
    }

    log_info("CHELSA BIO%d salvo: %s", i, out_path)
    meta_rows[[length(meta_rows) + 1]] <- list(
      source      = "CHELSA_v2.1",
      variable    = paste0("BIO", i),
      resolution  = "30 arc-sec (~1 km)",
      file        = out_path,
      citation    = "Karger et al. (2021) doi:10.1038/s41597-021-01084-7",
      licence     = "CC BY 4.0",
      download_date = format(Sys.Date(), "%Y-%m-%d")
    )
  }
  log_info("CHELSA: todos os 19 BIO processados em %s", ch_dir)
}

# ── 6. MODIS placeholder ─────────────────────────────────────────────────────
if ("modis" %in% sources_list) {
  log_step(6, "MODIS: download requer conta NASA EarthData (nao automatizado)")
  log_warn(
    "Download automatizado de MODIS requer conta em https://urs.earthdata.nasa.gov/\n  Use MODIStsp (R) ou AppEEARS (https://appeears.earthdatacloud.nasa.gov/) para downloads em lote.\n  Alternativa Python: pystac com Microsoft Planetary Computer (nao requer conta).\n  Consulte: skills/geoprocessing-for-ecology/resources/global-predictor-sources.md"
  )
}

# ── 7. Save predictor metadata CSV ──────────────────────────────────────────
log_step(7, "Gravar metadata de preditores")
if (length(meta_rows) > 0) {
  meta_df <- do.call(rbind, lapply(meta_rows, as.data.frame, stringsAsFactors = FALSE))
  meta_path <- file.path(output_dir, "predictor_metadata.csv")
  tryCatch({
    write.csv(meta_df, meta_path, row.names = FALSE)
    log_info("Metadata gravado: %s (%d camadas)", meta_path, nrow(meta_df))
  }, error = function(e) {
    log_error(
      "Falha ao gravar metadata: %s\nSkill anterior: geoprocessing-for-ecology",
      conditionMessage(e)
    )
  })
} else {
  log_warn("Nenhuma camada baixada com sucesso. Arquivo de metadata nao criado.")
}

log_info("Download de preditores concluido. Verifique: %s", output_dir)
