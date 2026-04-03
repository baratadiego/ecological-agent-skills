# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript connectivity_metrics.R <patches_shp> <output_dir> [dmax_m] [area_col]
#
# Computes graph-based landscape connectivity metrics (IIC, PC, dIIC, dPC,
# betweenness centrality) for a set of habitat patches.
#
# Arguments:
#   patches_shp — Shapefile or GeoPackage of habitat patches (.shp or .gpkg)
#   output_dir  — Directory for output files
#   dmax_m      — Maximum dispersal distance in metres (default: 1000)
#   area_col    — Column name for patch area in patches layer (default: "area_ha")
#
# Outputs:
#   patch_metrics.csv        — IIC, PC, dIIC, dPC, BC per patch
#   landscape_summary.csv    — IIC, PC, number of components, largest component
#   connectivity_graph.png   — Network visualisation coloured by dPC

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "landscape-connectivity"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(igraph))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  log_error("Argumentos insuficientes. Uso: Rscript connectivity_metrics.R <patches_shp> <output_dir> [dmax_m] [area_col]")
  cat("Usage: Rscript connectivity_metrics.R <patches_shp> <output_dir>",
      "[dmax_m] [area_col]\n")
  quit(status = 1)
}

patches_path <- args[1]
output_dir   <- args[2]
dmax_m       <- if (length(args) >= 3) as.numeric(args[3]) else 1000
area_col     <- if (length(args) >= 4) args[4] else "area_ha"

# ── Input precondition checks ────────────────────────────────────────────────
if (!file.exists(patches_path)) {
  log_error("Input not found: %s\nProbable cause: shapefile/GeoPackage file does not exist or incorrect path\nCheck: that the .shp or .gpkg file exists at the specified path\nPrevious skill: [none — initial step or GIS processing output]", patches_path)
  stop("Missing patches file: ", patches_path)
}

log_decision("dmax_m", dmax_m,
             "maximum dispersal distance in metres; defines structural connectivity between patches")
log_decision("area_col", area_col,
             "coluna de area das manchas; usada para calculo de IIC e PC ponderados por area")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_step(1, "Loading habitat patch layer")
# ── Load patches ────────────────────────────────────────────────────────────
patches <- tryCatch({
  sf::st_read(patches_path, quiet = TRUE)
}, error = function(e) {
  log_error("Failed to read patch shapefile: %s\nProbable cause: corrupted file or invalid CRS\nCheck: shapefile integrity\nPrevious skill: [none]", conditionMessage(e))
  stop(e)
})

if (!area_col %in% names(patches)) {
  # Compute area from geometry if column missing
  log_warn("Column '%s' not found; computing area from geometry", area_col)
  patches[[area_col]] <- as.numeric(st_area(patches)) / 10000  # m² → ha
}

n   <- nrow(patches)
A   <- sum(patches[[area_col]])  # total landscape area proxy (sum of patch areas)
log_info("Manchas carregadas: %d. Area total das manchas: %.1f ha", n, A)

if (n < 3) {
  log_error("Minimum of 3 patches required for connectivity analysis. Found: %d\nProbable cause: input data with few features\nCheck: patch file and minimum area filters\nPrevious skill: [none]", n)
  stop("At least 3 patches required for connectivity analysis. ",
       "Found ", n, " patches.")
}

log_step(2, "Computing distances between patch centroids")
# ── Compute pairwise distances between patch centroids ──────────────────────
centroids <- st_centroid(patches)
# Reproject to projected CRS if needed
if (st_is_longlat(centroids)) {
  log_warn("Input in geographic CRS. Reprojecting to UTM for distance calculation")
  lon_mean <- mean(st_coordinates(centroids)[, 1])
  lat_mean <- mean(st_coordinates(centroids)[, 2])
  zone_num <- floor((lon_mean + 180) / 6) + 1
  utm_base <- if (lat_mean >= 0) 32600L else 32700L
  utm_crs  <- utm_base + zone_num
  centroids <- st_transform(centroids, crs = utm_crs)
  log_info("CRS UTM usado: EPSG:%d", utm_crs)
}
coords   <- st_coordinates(centroids)
dist_mat <- as.matrix(dist(coords))  # metres

log_step(3, "Building binary adjacency graph")
# ── Build adjacency matrix (binary, distance < dmax) ───────────────────────
adj_binary <- (dist_mat < dmax_m) * 1
diag(adj_binary) <- 0

g_binary <- graph_from_adjacency_matrix(adj_binary, mode = "undirected",
                                         weighted = FALSE)
sp_hops <- distances(g_binary, algorithm = "bfs")

n_edges <- sum(adj_binary) / 2
log_info("Grafo construido: %d nos, %d arestas (dmax = %g m)", n, n_edges, dmax_m)
if (n_edges == 0) {
  log_warn("No patches connected within dmax = %g m; increase dmax_m or check CRS", dmax_m)
}

log_step(4, "Computing IIC — Integral Index of Connectivity")
# ── IIC (Integral Index of Connectivity) ────────────────────────────────────
areas <- patches[[area_col]]

compute_iic_internal <- function(areas_vec, sp_hops_mat) {
  n   <- length(areas_vec)
  num <- 0
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      nij <- sp_hops_mat[i, j]
      if (is.finite(nij)) {
        num <- num + (areas_vec[i] * areas_vec[j]) / (1 + nij)
      }
    }
  }
  num / sum(areas_vec)^2
}

IIC_full <- compute_iic_internal(areas, sp_hops)
log_info("IIC (paisagem completa) = %.6f", IIC_full)

log_step(5, "Computing dIIC per patch (leave-one-out)")
# ── dIIC per patch ──────────────────────────────────────────────────────────
log_info("Computing dIIC for each patch (may take a moment)...")
dIIC_vec <- numeric(n)
for (i in seq_len(n)) {
  areas_i  <- areas[-i]
  adj_i    <- adj_binary[-i, -i]
  g_i      <- graph_from_adjacency_matrix(adj_i, mode = "undirected")
  sp_i     <- distances(g_i, algorithm = "bfs")
  IIC_i    <- compute_iic_internal(areas_i, sp_i)
  dIIC_vec[i] <- (IIC_full - IIC_i) / IIC_full * 100
}

log_step(6, "Computing PC — Probability of Connectivity")
# ── PC (Probability of Connectivity) ────────────────────────────────────────
# Dispersal probability: p = exp(-d / dmax)  (negative exponential kernel)
# dmax serves as mean dispersal distance parameter
p_mat <- exp(-dist_mat / dmax_m)
diag(p_mat) <- 0

log_decision("dispersal_kernel", "exponencial negativo exp(-d/dmax)",
             "nucleo padrao para probabilidade de colonizacao; ajuste se dados de telemetria disponíveis")

# Build weighted graph for shortest path probabilities
p_weight <- ifelse(p_mat > 0.001, -log(p_mat), Inf)
diag(p_weight) <- 0
g_prob <- graph_from_adjacency_matrix(p_weight, mode = "undirected",
                                       weighted = TRUE)
sp_prob_dist <- distances(g_prob, algorithm = "dijkstra")
pij_star <- exp(-sp_prob_dist)  # convert back to probability

PC_full <- sum(outer(areas, areas) * pij_star) / sum(areas)^2
log_info("PC (paisagem completa) = %.6f", PC_full)

log_step(7, "Computing dPC per patch (leave-one-out)")
# ── dPC per patch ────────────────────────────────────────────────────────────
log_info("Computing dPC for each patch...")
dPC_vec <- numeric(n)
for (i in seq_len(n)) {
  areas_i  <- areas[-i]
  p_mat_i  <- p_mat[-i, -i]
  pw_i     <- ifelse(p_mat_i > 0.001, -log(p_mat_i), Inf)
  g_i      <- graph_from_adjacency_matrix(pw_i, mode = "undirected",
                                           weighted = TRUE)
  sp_i     <- distances(g_i, algorithm = "dijkstra")
  pij_i    <- exp(-sp_i)
  PC_i     <- sum(outer(areas_i, areas_i) * pij_i) / sum(areas_i)^2
  dPC_vec[i] <- (PC_full - PC_i) / PC_full * 100
}

# ── Betweenness centrality ───────────────────────────────────────────────────
BC <- betweenness(g_binary, normalized = TRUE)

log_step(8, "Writing landscape summary and per-patch metrics")
# ── Landscape summary ────────────────────────────────────────────────────────
components_g <- components(g_binary)
largest_comp  <- max(components_g$csize)

summary_df <- data.frame(
  metric          = c("IIC", "PC", "n_patches", "n_components",
                      "largest_component_size", "dmax_m"),
  value           = c(IIC_full, PC_full, n, components_g$no,
                      largest_comp, dmax_m)
)
sum_path <- file.path(output_dir, "landscape_summary.csv")
write.csv(summary_df, sum_path, row.names = FALSE)
log_info("Landscape summary saved: %s", sum_path)

if (components_g$no > n / 2) {
  log_warn("Highly fragmented landscape: %d components for %d patches; consider increasing dmax_m",
           components_g$no, n)
}

# ── Patch metrics ────────────────────────────────────────────────────────────
patch_id <- if ("id" %in% names(patches)) patches$id else seq_len(n)
patch_metrics <- data.frame(
  patch_id  = patch_id,
  area_ha   = areas,
  dIIC_pct  = round(dIIC_vec, 4),
  dPC_pct   = round(dPC_vec,  4),
  BC_norm   = round(BC,       4),
  component = components_g$membership
)
patch_metrics <- patch_metrics[order(-patch_metrics$dPC_pct), ]

patch_path <- file.path(output_dir, "patch_metrics.csv")
write.csv(patch_metrics, patch_path, row.names = FALSE)
log_info("Per-patch metrics saved: %s (%d patches)", patch_path, n)

# Report top patches
log_info("Top 5 manchas por dPC:")
top5 <- head(patch_metrics[, c("patch_id", "area_ha", "dPC_pct", "BC_norm")], 5)
for (r in seq_len(nrow(top5))) {
  log_info("  patch_id=%s | area=%.1f ha | dPC=%.2f%% | BC=%.4f",
           top5$patch_id[r], top5$area_ha[r], top5$dPC_pct[r], top5$BC_norm[r])
}

log_step(9, "Generating connectivity graph visualisation")
# ── Network visualisation ────────────────────────────────────────────────────
V(g_binary)$dPC <- dPC_vec
V(g_binary)$area <- areas
layout_coords <- coords[, 1:2]

patch_df <- data.frame(
  x     = coords[, 1],
  y     = coords[, 2],
  dPC   = dPC_vec,
  area  = areas / max(areas) * 3 + 0.5  # size scaled
)

edges_df <- as.data.frame(get.edgelist(g_binary))
edges_df$x_from <- coords[as.integer(edges_df$V1), 1]
edges_df$y_from <- coords[as.integer(edges_df$V1), 2]
edges_df$x_to   <- coords[as.integer(edges_df$V2), 1]
edges_df$y_to   <- coords[as.integer(edges_df$V2), 2]

p <- ggplot() +
  geom_segment(data = edges_df,
               aes(x = x_from, y = y_from, xend = x_to, yend = y_to),
               colour = "grey60", linewidth = 0.5, alpha = 0.7) +
  geom_point(data = patch_df,
             aes(x = x, y = y, size = area, fill = dPC),
             shape = 21, colour = "grey30") +
  scale_fill_viridis_c(option = "plasma", name = "dPC (%)") +
  scale_size_continuous(range = c(2, 8), guide = "none") +
  labs(x = "Easting", y = "Northing",
       title = sprintf("Connectivity graph (dmax = %g m, IIC = %.4f)",
                       dmax_m, IIC_full)) +
  theme_minimal(base_size = 10) +
  coord_equal()

plot_path <- file.path(output_dir, "connectivity_graph.png")
tryCatch({
  ggsave(plot_path, p, width = 8, height = 7, dpi = 150)
  log_info("Graph visualisation saved: %s", plot_path)
}, error = function(e) {
  log_warn("Could not save graph visualisation: %s", conditionMessage(e))
})

log_info("Connectivity analysis completed")
