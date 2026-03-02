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

suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(igraph))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  cat("Usage: Rscript connectivity_metrics.R <patches_shp> <output_dir>",
      "[dmax_m] [area_col]\n")
  quit(status = 1)
}

patches_path <- args[1]
output_dir   <- args[2]
dmax_m       <- if (length(args) >= 3) as.numeric(args[3]) else 1000
area_col     <- if (length(args) >= 4) args[4] else "area_ha"

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Load patches ────────────────────────────────────────────────────────────
patches <- sf::st_read(patches_path, quiet = TRUE)

if (!area_col %in% names(patches)) {
  # Compute area from geometry if column missing
  message(sprintf("Column '%s' not found; computing area from geometry.", area_col))
  patches[[area_col]] <- as.numeric(st_area(patches)) / 10000  # m² → ha
}

n   <- nrow(patches)
A   <- sum(patches[[area_col]])  # total landscape area proxy (sum of patch areas)
cat(sprintf("Loaded %d patches. Total patch area: %.1f ha.\n", n, A))

if (n < 3) {
  stop("At least 3 patches required for connectivity analysis. ",
       "Found ", n, " patches.")
}

# ── Compute pairwise distances between patch centroids ──────────────────────
centroids <- st_centroid(patches)
# Reproject to projected CRS if needed
if (st_is_longlat(centroids)) {
  message("Input in geographic CRS. Reprojecting to UTM for distance computation.")
  utm_crs <- 32700 + round((mean(st_coordinates(centroids)[, 1]) + 180) / 6) + 1
  centroids <- st_transform(centroids, crs = utm_crs)
}
coords   <- st_coordinates(centroids)
dist_mat <- as.matrix(dist(coords))  # metres

# ── Build adjacency matrix (binary, distance < dmax) ───────────────────────
adj_binary <- (dist_mat < dmax_m) * 1
diag(adj_binary) <- 0

g_binary <- graph_from_adjacency_matrix(adj_binary, mode = "undirected",
                                         weighted = FALSE)
sp_hops <- distances(g_binary, algorithm = "bfs")

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
cat(sprintf("IIC (full landscape) = %.6f\n", IIC_full))

# ── dIIC per patch ──────────────────────────────────────────────────────────
cat("Computing dIIC for each patch (may take a moment)...\n")
dIIC_vec <- numeric(n)
for (i in seq_len(n)) {
  areas_i  <- areas[-i]
  adj_i    <- adj_binary[-i, -i]
  g_i      <- graph_from_adjacency_matrix(adj_i, mode = "undirected")
  sp_i     <- distances(g_i, algorithm = "bfs")
  IIC_i    <- compute_iic_internal(areas_i, sp_i)
  dIIC_vec[i] <- (IIC_full - IIC_i) / IIC_full * 100
}

# ── PC (Probability of Connectivity) ────────────────────────────────────────
# Dispersal probability: p = exp(-d / dmax)  (negative exponential kernel)
# dmax serves as mean dispersal distance parameter
p_mat <- exp(-dist_mat / dmax_m)
diag(p_mat) <- 0

# PC numerator: sum of product pij* × ai × aj
# Using shortest-path probability (product of edge probabilities along path)
# Simplified: for small graphs use all-paths, for large use shortest path

# Build weighted graph for shortest path probabilities
p_weight <- ifelse(p_mat > 0.001, -log(p_mat), Inf)
diag(p_weight) <- 0
g_prob <- graph_from_adjacency_matrix(p_weight, mode = "undirected",
                                       weighted = TRUE)
sp_prob_dist <- distances(g_prob, algorithm = "dijkstra")
pij_star <- exp(-sp_prob_dist)  # convert back to probability

PC_full <- sum(outer(areas, areas) * pij_star) / sum(areas)^2
cat(sprintf("PC (full landscape) = %.6f\n", PC_full))

# ── dPC per patch ────────────────────────────────────────────────────────────
cat("Computing dPC for each patch...\n")
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
cat(sprintf("Landscape summary written: %s\n", sum_path))

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
cat(sprintf("Patch metrics written: %s (%d patches)\n", patch_path, n))

# Report top patches
cat("\nTop 5 patches by dPC:\n")
print(head(patch_metrics[, c("patch_id", "area_ha", "dPC_pct", "BC_norm")], 5))

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
ggsave(plot_path, p, width = 8, height = 7, dpi = 150)
cat(sprintf("Graph visualisation saved: %s\n", plot_path))

cat("\nConnectivity analysis complete.\n")
