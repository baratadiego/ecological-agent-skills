# Usage: Rscript prepare_future_layers.R <current_stack.tif> <future_layers_dir> <study_area.shp> <output_dir> [ssp_label] [year_label]

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "species-distribution-modeling"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

#
# Arguments:
#   current_stack.tif   : Reference calibration raster stack (sets CRS, resolution, extent)
#   future_layers_dir   : Directory containing future climate .tif files (one per variable)
#   study_area.shp      : Shapefile / GeoPackage defining the projection area (G area)
#   output_dir          : Directory to write the prepared future stack (created if absent)
#   ssp_label           : Optional SSP label for output filename (default: "ssp245")
#   year_label          : Optional time horizon label for output filename (default: "2050")
#
# Output:
#   future_stack_{ssp_label}_{year_label}.tif  — prepared stack ready for model projection

suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(sf))

# ── 1. Parse arguments ──────────────────────────────────────────────────────
log_step(1, "Analisar argumentos da linha de comando")
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 4) {
  log_warn("Menos de 4 argumentos. Usando caminhos padrao para teste.")
  current_tif      <- "data/predictors/env_train.tif"
  future_dir       <- "data/chelsa_future/ssp245_2050/"
  study_area_path  <- "data/study_area/g_area.shp"
  output_dir       <- "output/future_layers"
  ssp_label        <- "ssp245"
  year_label       <- "2050"
} else {
  current_tif      <- args[1]
  future_dir       <- args[2]
  study_area_path  <- args[3]
  output_dir       <- args[4]
  ssp_label        <- if (length(args) >= 5) args[5] else "ssp245"
  year_label       <- if (length(args) >= 6) args[6] else "2050"
}

log_info("Script: prepare_future_layers.R | Skill: %s", SKILL_NAME)
log_info("Stack de calibracao : %s", current_tif)
log_info("Diretorio futuro    : %s", future_dir)
log_info("Area de estudo      : %s", study_area_path)
log_info("Output dir          : %s", output_dir)
log_info("SSP label           : %s", ssp_label)
log_info("Year label          : %s", year_label)

log_decision("ssp_label",  ssp_label,  "cenario SSP para rotular o arquivo de saida")
log_decision("year_label", year_label, "horizonte temporal para rotular o arquivo de saida")

# ── Input precondition checks ─────────────────────────────────────────────────
if (!file.exists(current_tif)) {
  log_error(
    "Input nao encontrado: %s\nCausa provavel: arquivo nao gerado pelo passo anterior.\nVerifique a saida de: species-distribution-modeling (prepare_predictors ou similar)\nSkill anterior: species-distribution-modeling",
    current_tif
  )
  stop("Calibration stack not found: ", current_tif)
}

if (!file.exists(study_area_path)) {
  log_error(
    "Input nao encontrado: %s\nCausa provavel: shapefile de area de estudo ausente.\nVerifique a saida de: ecological-data-foundation ou etapa de definicao da G area.\nSkill anterior: species-distribution-modeling",
    study_area_path
  )
  stop("Study area file not found: ", study_area_path)
}

if (!dir.exists(future_dir)) {
  log_error(
    "Diretorio de camadas futuras nao encontrado: %s\nCausa provavel: camadas CHELSA/WorldClim futuras nao baixadas.\nBaixe os GeoTIFFs futuros e coloque em: %s\nSkill anterior: species-distribution-modeling",
    future_dir, future_dir
  )
  stop("Future layers directory not found: ", future_dir)
}

# ── 2. Create output directory ───────────────────────────────────────────────
log_step(2, "Criar diretorio de saida")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
log_info("Diretorio de saida pronto: %s", output_dir)

# ── 3. Load reference calibration stack ─────────────────────────────────────
log_step(3, "Carregar stack de calibracao de referencia")
ref_stack <- tryCatch({
  rast(current_tif)
}, error = function(e) {
  log_error(
    "Falha ao carregar stack de calibracao '%s': %s\nCausa provavel: arquivo GeoTIFF corrompido ou formato nao suportado pelo terra.\nSkill anterior: species-distribution-modeling",
    current_tif, conditionMessage(e)
  )
  stop(e)
})

log_info("CRS    : %s", crs(ref_stack, describe = TRUE)$name)
log_info("Extent : %s", paste(round(as.vector(ext(ref_stack)), 3), collapse = ", "))
log_info("Res    : %s", paste(res(ref_stack), collapse = " x "))
log_info("Layers : %s", paste(names(ref_stack), collapse = ", "))

# ── 4. Load study area (G area) ──────────────────────────────────────────────
log_step(4, "Carregar area de estudo (G area)")
study_area <- tryCatch({
  vect(study_area_path)
}, error = function(e) {
  log_error(
    "Falha ao carregar area de estudo '%s': %s\nCausa provavel: shapefile corrompido, projecao invalida ou formato nao suportado.\nVerifique: ogrinfo '%s'\nSkill anterior: species-distribution-modeling",
    study_area_path, conditionMessage(e), study_area_path
  )
  stop(e)
})

# Reproject study area to match calibration CRS if needed
if (!identical(crs(study_area), crs(ref_stack))) {
  log_info("Reprojetando area de estudo para o CRS de calibracao...")
  study_area <- tryCatch(
    project(study_area, crs(ref_stack)),
    error = function(e) {
      log_error(
        "Falha ao reprojetar area de estudo: %s\nCausa provavel: CRS invalido ou incompativel.\nSkill anterior: species-distribution-modeling",
        conditionMessage(e)
      )
      stop(e)
    }
  )
  log_info("Reprojecao concluida.")
} else {
  log_info("CRS da area de estudo ja coincide com o de calibracao. Sem reprojecao necessaria.")
}

# ── 5. Load future climate layers ────────────────────────────────────────────
log_step(5, "Carregar camadas climaticas futuras")
future_files <- list.files(future_dir, pattern = "\\.tif$", full.names = TRUE,
                            recursive = FALSE)
if (length(future_files) == 0) {
  log_error(
    "Nenhum arquivo .tif encontrado em: %s\nCausa provavel: camadas futuras nao baixadas ou extensao diferente de .tif.\nVerifique o conteudo do diretorio.\nSkill anterior: species-distribution-modeling",
    future_dir
  )
  stop("No .tif files found in: ", future_dir)
}

log_info("Arquivos de camada futura encontrados: %d", length(future_files))

# Stack all future layers
future_raw <- tryCatch({
  rast(future_files)
}, error = function(e) {
  log_error(
    "Falha ao empilhar camadas futuras: %s\nCausa provavel: GeoTIFFs corrompidos ou com extents incompativeis.\nVerifique: gdalinfo nos arquivos em %s\nSkill anterior: species-distribution-modeling",
    conditionMessage(e), future_dir
  )
  stop(e)
})
log_info("Nomes das camadas futuras (brutos): %s", paste(names(future_raw), collapse = ", "))

# ── 6. Rename future layers to match calibration ─────────────────────────────
log_step(6, "Renomear camadas futuras para coincidir com a calibracao")
# Strategy: if layer names differ but count matches, rename by position.
# If counts differ, attempt name matching. Fail clearly if neither works.

ref_names    <- names(ref_stack)
future_names <- names(future_raw)

if (setequal(ref_names, future_names)) {
  # Names match already — reorder to calibration order
  future_raw <- future_raw[[ref_names]]
  log_info("Nomes das camadas coincidentes. Reordenados conforme calibracao.")
  log_decision("rename_strategy", "reorder", "nomes identicos, apenas reordenados")

} else if (length(future_names) == length(ref_names) &&
           !setequal(ref_names, future_names)) {
  # Same count but different names — rename by position (common with CHELSA long names)
  log_warn(
    "Nomes das camadas diferem da calibracao. Renomeando por posicao (%d camadas).",
    length(ref_names)
  )
  log_info("Nomes antigos: %s", paste(future_names, collapse = ", "))
  log_info("Novos nomes  : %s", paste(ref_names,    collapse = ", "))
  log_decision("rename_strategy", "by_position", "mesmo numero de camadas mas nomes diferentes (comum com CHELSA)")
  names(future_raw) <- ref_names

} else {
  # Different count — try to find matching layers by partial name
  log_warn("Numero de camadas difere. Tentando correspondencia por nome parcial...")
  matched <- sapply(ref_names, function(rn) {
    idx <- which(grepl(rn, future_names, fixed = TRUE))
    if (length(idx) == 1) idx else NA_integer_
  })

  if (any(is.na(matched))) {
    missing_layers <- ref_names[is.na(matched)]
    log_error(
      "Nao e possivel associar camadas futuras as de calibracao.\nCalibracao espera: %s\nCamadas futuras: %s\nSem correspondencia para: %s\nAcao: renomeie os .tif futuros para coincidir exatamente com os nomes de calibracao.\nSkill anterior: species-distribution-modeling",
      paste(ref_names,    collapse = ", "),
      paste(future_names, collapse = ", "),
      paste(missing_layers, collapse = ", ")
    )
    stop(
      "Cannot match future layers to calibration layers.\n",
      "  Calibration expects: ", paste(ref_names, collapse = ", "), "\n",
      "  Future layers found: ", paste(future_names, collapse = ", "), "\n",
      "  Could not find match for: ", paste(missing_layers, collapse = ", "), "\n",
      "  Action: rename future .tif files to match calibration layer names exactly."
    )
  }

  future_raw <- future_raw[[matched]]
  names(future_raw) <- ref_names
  log_info("Camadas associadas por nome parcial. Reordenadas conforme calibracao.")
  log_decision("rename_strategy", "partial_name_match", "contagem diferente; correspondencia por substring")
}

# ── 7. Reproject to calibration CRS ──────────────────────────────────────────
log_step(7, "Reprojetar stack futuro para o CRS de calibracao")
if (!identical(crs(future_raw), crs(ref_stack))) {
  log_info("Reprojetando stack futuro para CRS de calibracao...")
  log_decision("resample_method_reproj", "bilinear", "interpolacao bilinear para dados continuos de clima")
  future_raw <- tryCatch(
    project(future_raw, crs(ref_stack), method = "bilinear"),
    error = function(e) {
      log_error(
        "Falha ao reprojetar stack futuro: %s\nCausa provavel: CRS invalido ou falta de memoria para o raster.\nSkill anterior: species-distribution-modeling",
        conditionMessage(e)
      )
      stop(e)
    }
  )
  log_info("Reprojecao concluida.")
} else {
  log_info("CRS ja coincide com calibracao. Sem reprojecao necessaria.")
}

# ── 8. Crop and mask to study area (G area) ───────────────────────────────────
log_step(8, "Recortar e mascarar para a area de estudo")
tryCatch({
  future_cropped <- crop(future_raw,    study_area)
  future_masked  <- mask(future_cropped, study_area)
  log_info("Recorte e mascara aplicados. Celulas validas apos mascara: nao calculado (use global(future_masked, 'notNA')).")
}, error = function(e) {
  log_error(
    "Falha ao recortar/mascarar o stack futuro: %s\nCausa provavel: extent da area de estudo fora do extent do raster futuro.\nVerifique a projecao e o extent dos arquivos.\nSkill anterior: species-distribution-modeling",
    conditionMessage(e)
  )
  stop(e)
})

# ── 9. Resample to exactly match calibration grid ────────────────────────────
log_step(9, "Reamostrar para coincidir exatamente com o grid de calibracao")
log_decision("resample_method", "bilinear", "interpolacao bilinear para dados continuos de clima")
future_resampled <- tryCatch(
  resample(future_masked, ref_stack, method = "bilinear"),
  error = function(e) {
    log_error(
      "Falha na reamostragem do stack futuro: %s\nCausa provavel: incompatibilidade de CRS ou extent entre stack futuro e de calibracao.\nVerifique os passos 7 e 8.\nSkill anterior: species-distribution-modeling",
      conditionMessage(e)
    )
    stop(e)
  }
)

# ── 10. Geometry verification ────────────────────────────────────────────────
log_step(10, "Verificar geometria do stack futuro contra o de calibracao")
geom_ok <- tryCatch(
  compareGeom(ref_stack, future_resampled, stopOnError = FALSE,
              res = TRUE, orig = TRUE, crs = TRUE),
  error = function(e) {
    log_warn("compareGeom retornou erro: %s. Prosseguindo com cautela.", conditionMessage(e))
    FALSE
  }
)

if (!geom_ok) {
  log_error(
    "Verificacao de geometria FALHOU apos reamostragem.\nCalibracao: ext=%s res=%s crs=%s\nFuturo     : ext=%s res=%s crs=%s\nVerifique incompatibilidades de extent ou datum e re-execute.\nSkill anterior: species-distribution-modeling",
    as.character(ext(ref_stack)),
    paste(res(ref_stack), collapse = "x"),
    crs(ref_stack, describe = TRUE)$name,
    as.character(ext(future_resampled)),
    paste(res(future_resampled), collapse = "x"),
    crs(future_resampled, describe = TRUE)$name
  )
  stop(
    "Geometry verification FAILED after resampling.\n",
    "  Calibration: ext=", as.character(ext(ref_stack)),
    " res=", paste(res(ref_stack), collapse="x"),
    " crs=", crs(ref_stack, describe=TRUE)$name, "\n",
    "  Future:      ext=", as.character(ext(future_resampled)),
    " res=", paste(res(future_resampled), collapse="x"),
    " crs=", crs(future_resampled, describe=TRUE)$name, "\n",
    "  Check for extent or datum mismatches and re-run."
  )
}
log_info("Verificacao de geometria PASSOU.")

# ── 11. Final layer name verification ────────────────────────────────────────
log_step(11, "Verificar nomes finais das camadas")
if (!identical(names(future_resampled), names(ref_stack))) {
  name_diff <- setdiff(names(future_resampled), names(ref_stack))
  log_error(
    "Discrepancia de nomes de camadas no stack final.\nEsperado: %s\nObtido  : %s\nDivergentes: %s\nSkill anterior: species-distribution-modeling",
    paste(names(ref_stack),       collapse = ", "),
    paste(names(future_resampled), collapse = ", "),
    paste(name_diff, collapse = ", ")
  )
  stop(
    "Layer name mismatch in final stack.\n",
    "  Expected: ", paste(names(ref_stack), collapse = ", "), "\n",
    "  Got:      ", paste(names(future_resampled), collapse = ", "), "\n",
    "  Differing layers: ", paste(name_diff, collapse = ", ")
  )
}
log_info("Nomes das camadas verificados. Camadas: %s", paste(names(future_resampled), collapse = ", "))

# ── 12. Save output ───────────────────────────────────────────────────────────
log_step(12, "Gravar stack futuro preparado")
out_filename <- paste0("future_stack_", ssp_label, "_", year_label, ".tif")
out_path     <- file.path(output_dir, out_filename)

tryCatch({
  writeRaster(future_resampled, out_path, overwrite = TRUE)
  log_info("Gravado: %s", out_path)
}, error = function(e) {
  log_error(
    "Falha ao gravar raster de saida '%s': %s\nCausa provavel: sem permissao de escrita ou espaco em disco insuficiente.\nSkill anterior: species-distribution-modeling",
    out_path, conditionMessage(e)
  )
  stop(e)
})

# ── 13. Summary ───────────────────────────────────────────────────────────────
log_step(13, "Exibir resumo das camadas futuras preparadas")
log_info("========== RESUMO DAS CAMADAS FUTURAS ==========")
log_info("SSP                : %s", ssp_label)
log_info("Horizonte temporal : %s", year_label)
log_info("Camadas preparadas : %d", nlyr(future_resampled))
log_info("Nomes das camadas  : %s", paste(names(future_resampled), collapse = ", "))
log_info("CRS de saida       : %s", crs(future_resampled, describe = TRUE)$name)
log_info("Resolucao de saida : %s unidades", paste(res(future_resampled), collapse = " x "))
log_info("Arquivo de saida   : %s", out_path)
log_info("=================================================")
log_info("Pronto para: maxnet::predict(), biomod2::BIOMOD_Projection() ou sdm_pipeline.py")
