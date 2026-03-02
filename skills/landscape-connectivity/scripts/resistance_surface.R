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

suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  cat("Usage: Rscript resistance_surface.R <landcover_tif> <resistance_csv>",
      "<output_dir> [dem_tif] [road_shp]\n")
  quit(status = 1)
}

lc_path     <- args[1]
res_csv     <- args[2]
output_dir  <- args[3]
dem_path    <- if (length(args) >= 4 && args[4] != "NA") args[4] else NULL
road_path   <- if (length(args) >= 5 && args[5] != "NA") args[5] else NULL

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Load inputs ──────────────────────────────────────────────────────────────
lc <- rast(lc_path)
rt <- read.csv(res_csv)

required_cols <- c("lc_code", "resistance")
if (!all(required_cols %in% names(rt))) {
  stop("resistance_csv must contain columns: lc_code, resistance. Found: ",
       paste(names(rt), collapse = ", "))
}

cat(sprintf("Land cover raster: %d rows × %d cols, CRS: %s\n",
            nrow(lc), ncol(lc), crs(lc, describe = TRUE)$name))
cat(sprintf("Resistance table: %d classes.\n", nrow(rt)))

# ── Reclassify land cover to resistance ──────────────────────────────────────
rcl_mat <- as.matrix(rt %>%
  arrange(lc_code) %>%
  mutate(from = lc_code - 0.5, to = lc_code + 0.5) %>%
  select(from, to, resistance))

res_lc <- classify(lc, rcl_mat, include.lowest = TRUE, right = FALSE)
names(res_lc) <- "resistance"

# Check for unmatched codes
lc_vals    <- unique(values(lc, na.rm = TRUE))
unmatched  <- setdiff(lc_vals, rt$lc_code)
if (length(unmatched) > 0) {
  warning(sprintf("%d land cover codes have no resistance assignment: %s\n",
                  length(unmatched), paste(unmatched, collapse = ", ")))
}

lc_path_out <- file.path(output_dir, "resistance_lc.tif")
writeRaster(res_lc, lc_path_out, overwrite = TRUE)
cat(sprintf("LC resistance written: %s\n", lc_path_out))

# ── Optional: slope penalty ──────────────────────────────────────────────────
if (!is.null(dem_path)) {
  cat("Adding slope-based resistance...\n")
  dem       <- rast(dem_path)
  dem_proj  <- project(dem, lc, method = "bilinear")
  slope_deg <- terrain(dem_proj, v = "slope", unit = "degrees")
  # Exponential cost: doubles every ~10° of slope
  slope_res  <- exp(slope_deg / 15)
  slope_res  <- slope_res / global(slope_res, "min", na.rm = TRUE)[[1]]
  names(slope_res) <- "slope_resistance"
  writeRaster(slope_res, file.path(output_dir, "slope_resistance.tif"),
              overwrite = TRUE)
} else {
  slope_res <- NULL
}

# ── Optional: road proximity penalty ─────────────────────────────────────────
if (!is.null(road_path)) {
  cat("Adding road-proximity resistance...\n")
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
} else {
  road_res <- NULL
}

# ── Combine resistance layers ─────────────────────────────────────────────────
combined <- res_lc
if (!is.null(slope_res)) combined <- combined * slope_res
if (!is.null(road_res))  combined <- combined * road_res

# Cap at maximum to avoid instability
max_cap <- 1000
combined[combined > max_cap] <- max_cap

# Rescale so minimum = 1
min_val  <- global(combined, "min", na.rm = TRUE)[[1]]
combined <- combined / min_val
combined_path <- file.path(output_dir, "resistance_combined.tif")
writeRaster(combined, combined_path, overwrite = TRUE)
cat(sprintf("Combined resistance written: %s\n", combined_path))

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
cat("Resistance surface statistics:\n")
print(stats_df)

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
  cat(sprintf("Resistance map saved: %s\n", map_path))
}, error = function(e) {
  warning("Could not produce resistance map: ", conditionMessage(e))
})

cat("\nResistance surface construction complete.\n")
