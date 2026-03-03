# Usage: Rscript resistance_surface.R <landcover_tif> <resistance_csv> <output_dir>
#        [dem_tif] [road_shp]
#
# Constructs a resistance surface from a land cover raster and resistance
# lookup table. Optionally adds slope-based and road-proximity penalties.
#
# Arguments:
#   landcover_tif   — Land cover raster (.tif) with integer class codes
#   resistance_csv  — CSV with columns: lc_code (int), resistance (num), description (char)
#   output_dir      — Directory for output files
#   dem_tif         — (optional) DEM raster for slope penalty
#   road_shp        — (optional) Road vector layer for proximity penalty
#
# Outputs:
#   resistance_lc.tif       — Land cover resistance only
#   resistance_combined.tif — Combined resistance (lc + optional slope + road)
#   resistance_stats.csv    — Summary statistics of resistance surface
#   resistance_map.png      — Visualisation of combined resistance

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "landscape-connectivity"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  log_error("Argumentos insuficientes. Uso: Rscript resistance_surface.R <landcover_tif> <resistance_csv> <output_dir> [dem_tif] [road_shp]")
  cat("Usage: Rscript resistance_surface.R <landcover_tif> <resistance_csv>",
      "<output_dir> [dem_tif] [road_shp]\n")
  quit(status = 1)
}

lc_path     <- args[1]
res_csv     <- args[2]
output_dir  <- args[3]
dem_path    <- if (length(args) >= 4 && args[4] != "NA") args[4] else NULL
road_path   <- if (length(args) >= 5 && args[5] != "NA") args[5] else NULL

# ── Input precondition checks ────────────────────────────────────────────────
if (!file.exists(lc_path)) {
  log_error("Input nao encontrado: %s\nCausa provavel: raster de cobertura de terra nao existe\nVerifique: caminho e existencia do arquivo .tif\nSkill anterior: [nenhuma — entrada do usuario]", lc_path)
  stop("Missing landcover_tif: ", lc_path)
}
if (!file.exists(res_csv)) {
  log_error("Input nao encontrado: %s\nCausa provavel: CSV de resistencia nao existe\nVerifique: se o arquivo contem colunas lc_code e resistance\nSkill anterior: [nenhuma — entrada do usuario]", res_csv)
  stop("Missing resistance_csv: ", res_csv)
}
if (!is.null(dem_path) && !file.exists(dem_path)) {
  log_error("DEM opcional nao encontrado: %s\nCausa provavel: caminho incorreto para DEM\nVerifique: existencia do arquivo .tif do DEM\nSkill anterior: [nenhuma]", dem_path)
  stop("Missing dem_tif: ", dem_path)
}
if (!is.null(road_path) && !file.exists(road_path)) {
  log_error("Shapefile de estradas opcional nao encontrado: %s\nCausa provavel: caminho incorreto\nVerifique: existencia do shapefile de estradas\nSkill anterior: [nenhuma]", road_path)
  stop("Missing road_shp: ", road_path)
}

log_decision("dem_path", ifelse(is.null(dem_path), "NULL", dem_path),
             "DEM incluido na penalidade de declividade; NULL = sem penalidade de relevo")
log_decision("road_path", ifelse(is.null(road_path), "NULL", road_path),
             "shapefile de estradas para penalidade de proximidade; NULL = sem penalidade viaria")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_step(1, "Carregando raster de cobertura de terra e tabela de resistencia")
# ── Load inputs ──────────────────────────────────────────────────────────────
lc <- tryCatch({
  rast(lc_path)
}, error = function(e) {
  log_error("Falha ao carregar raster de cobertura de terra: %s\nCausa provavel: arquivo .tif corrompido ou formato invalido\nVerifique: integridade do raster\nSkill anterior: [nenhuma]", conditionMessage(e))
  stop(e)
})
rt <- tryCatch({
  read.csv(res_csv)
}, error = function(e) {
  log_error("Falha ao ler CSV de resistencia: %s\nCausa provavel: formato incorreto\nVerifique: colunas lc_code e resistance\nSkill anterior: [nenhuma]", conditionMessage(e))
  stop(e)
})

required_cols <- c("lc_code", "resistance")
if (!all(required_cols %in% names(rt))) {
  log_error("CSV de resistencia deve conter colunas: lc_code, resistance. Encontradas: %s\nCausa provavel: cabecalho do CSV incorreto\nVerifique: estrutura do arquivo resistance_csv\nSkill anterior: [nenhuma]",
            paste(names(rt), collapse = ", "))
  stop("resistance_csv must contain columns: lc_code, resistance. Found: ",
       paste(names(rt), collapse = ", "))
}

log_info("Raster de cobertura: %d linhas x %d colunas, CRS: %s",
         nrow(lc), ncol(lc), crs(lc, describe = TRUE)$name)
log_info("Tabela de resistencia: %d classes", nrow(rt))

log_step(2, "Reclassificando cobertura de terra para resistencia")
# ── Reclassify land cover to resistance ──────────────────────────────────────
rcl_mat <- as.matrix(rt %>%
  arrange(lc_code) %>%
  mutate(from = lc_code - 0.5, to = lc_code + 0.5) %>%
  select(from, to, resistance))

res_lc <- tryCatch({
  classify(lc, rcl_mat, include.lowest = TRUE, right = FALSE)
}, error = function(e) {
  log_error("Falha em reclassificacao: %s\nCausa provavel: codigos de classe no raster fora do intervalo da tabela\nVerifique: consistencia entre lc_code e valores do raster\nSkill anterior: [nenhuma]", conditionMessage(e))
  stop(e)
})
names(res_lc) <- "resistance"

# Check for unmatched codes
lc_vals    <- unique(values(lc, na.rm = TRUE))
unmatched  <- setdiff(lc_vals, rt$lc_code)
if (length(unmatched) > 0) {
  log_warn("%d codigos de cobertura de terra sem atribuicao de resistencia: %s",
           length(unmatched), paste(unmatched, collapse = ", "))
}

lc_path_out <- file.path(output_dir, "resistance_lc.tif")
writeRaster(res_lc, lc_path_out, overwrite = TRUE)
log_info("Resistencia LC gravada: %s", lc_path_out)

log_step(3, "Adicionando penalidades opcionais (declividade, estradas)")
# ── Optional: slope penalty ──────────────────────────────────────────────────
if (!is.null(dem_path)) {
  log_info("Adicionando resistencia baseada em declividade...")
  tryCatch({
    dem       <- rast(dem_path)
    dem_proj  <- project(dem, lc, method = "bilinear")
    slope_deg <- terrain(dem_proj, v = "slope", unit = "degrees")
    # Exponential cost: doubles every ~10° of slope
    slope_res  <- exp(slope_deg / 15)
    slope_res  <- slope_res / global(slope_res, "min", na.rm = TRUE)[[1]]
    names(slope_res) <- "slope_resistance"
    writeRaster(slope_res, file.path(output_dir, "slope_resistance.tif"),
                overwrite = TRUE)
    log_info("Resistencia de declividade gravada")
    log_decision("slope_decay_param", 15,
                 "parametro de decaimento exponencial; resistencia dobra a cada 15 graus de declividade")
  }, error = function(e) {
    log_error("Falha ao processar DEM para declividade: %s\nCausa provavel: DEM com CRS incompativel ou valores invalidos\nVerifique: CRS e extensao do DEM\nSkill anterior: [nenhuma]", conditionMessage(e))
    stop(e)
  })
} else {
  slope_res <- NULL
}

# ── Optional: road proximity penalty ─────────────────────────────────────────
if (!is.null(road_path)) {
  log_info("Adicionando resistencia de proximidade a estradas...")
  tryCatch({
    roads    <- st_read(road_path, quiet = TRUE)
    roads_v  <- vect(roads)
    # Compute distance to nearest road
    road_dist <- distance(res_lc, roads_v)
    road_dist <- project(road_dist, lc, method = "bilinear")
    # Resistance peaks at road (dist=0) and decays with distance
    # max_penalty = 10× at road edge, decays to 1 at 500 m
    road_res <- pmax(1, 10 * exp(-road_dist / 200))
    names(road_res) <- "road_resistance"
    writeRaster(road_res, file.path(output_dir, "road_resistance.tif"),
                overwrite = TRUE)
    log_info("Resistencia de estradas gravada")
    log_decision("road_max_penalty", 10,
                 "penalidade maxima na beira da estrada (10x); decai a 1 a 500 m")
  }, error = function(e) {
    log_error("Falha ao processar shapefile de estradas: %s\nCausa provavel: shapefile invalido ou CRS incompativel\nVerifique: integridade do shapefile de estradas\nSkill anterior: [nenhuma]", conditionMessage(e))
    stop(e)
  })
} else {
  road_res <- NULL
}

log_step(4, "Combinando camadas de resistencia e normalizando")
# ── Combine resistance layers ─────────────────────────────────────────────────
combined <- res_lc
if (!is.null(slope_res)) combined <- combined * slope_res
if (!is.null(road_res))  combined <- combined * road_res

# Cap at maximum to avoid instability
max_cap <- 1000
combined[combined > max_cap] <- max_cap
log_decision("max_cap_resistance", max_cap,
             "resistencia maxima para evitar instabilidade numerica nos algoritmos de menor custo")

# Rescale so minimum = 1
min_val  <- global(combined, "min", na.rm = TRUE)[[1]]
combined <- combined / min_val
combined_path <- file.path(output_dir, "resistance_combined.tif")
writeRaster(combined, combined_path, overwrite = TRUE)
log_info("Resistencia combinada gravada: %s", combined_path)

log_step(5, "Calculando estatisticas da superficie de resistencia")
# ── Statistics ────────────────────────────────────────────────────────────────
vals <- values(combined, na.rm = TRUE)
stats_df <- data.frame(
  statistic = c("min", "q25", "median", "mean", "q75", "q95", "max"),
  value     = round(quantile(vals, c(0, 0.25, 0.5, NA, 0.75, 0.95, 1),
                              na.rm = TRUE), 3)
)
stats_df$value[4] <- round(mean(vals, na.rm = TRUE), 3)
stats_path <- file.path(output_dir, "resistance_stats.csv")
write.csv(stats_df, stats_path, row.names = FALSE)
log_info("Estatisticas da superficie de resistencia:")
for (r in seq_len(nrow(stats_df))) {
  log_info("  %s = %.3f", stats_df$statistic[r], stats_df$value[r])
}

log_step(6, "Gerando visualizacao do mapa de resistencia")
# ── Visualisation ─────────────────────────────────────────────────────────────
tryCatch({
  plot_r   <- aggregate(combined, fact = max(1, floor(nrow(combined) / 500)))
  plot_df  <- as.data.frame(plot_r, xy = TRUE)
  names(plot_df)[3] <- "resistance"

  p <- ggplot(plot_df, aes(x = x, y = y, fill = log1p(resistance))) +
    geom_raster() +
    scale_fill_viridis_c(option = "magma", name = "log(resistance + 1)") +
    coord_equal() +
    labs(x = "Easting", y = "Northing",
         title = "Combined resistance surface") +
    theme_minimal(base_size = 10)

  map_path <- file.path(output_dir, "resistance_map.png")
  ggsave(map_path, p, width = 8, height = 7, dpi = 150)
  log_info("Mapa de resistencia salvo: %s", map_path)
}, error = function(e) {
  log_warn("Nao foi possivel gerar mapa de resistencia: %s", conditionMessage(e))
})

log_info("Construcao da superficie de resistencia concluida")
