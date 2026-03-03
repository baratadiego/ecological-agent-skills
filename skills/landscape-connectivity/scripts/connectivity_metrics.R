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
  log_error("Input nao encontrado: %s\nCausa provavel: arquivo shapefile/GeoPackage nao existe ou caminho incorreto\nVerifique: se o arquivo .shp ou .gpkg existe no caminho especificado\nSkill anterior: [nenhuma — etapa inicial ou saida de processamento GIS]", patches_path)
  stop("Missing patches file: ", patches_path)
}

log_decision("dmax_m", dmax_m,
             "distancia maxima de dispersao em metros; define conectividade estrutural entre manchas")
log_decision("area_col", area_col,
             "coluna de area das manchas; usada para calculo de IIC e PC ponderados por area")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_step(1, "Carregando camada de manchas de habitat")
# ── Load patches ────────────────────────────────────────────────────────────
patches <- tryCatch({
  sf::st_read(patches_path, quiet = TRUE)
}, error = function(e) {
  log_error("Falha ao ler shapefile de manchas: %s\nCausa provavel: arquivo corrompido ou CRS invalido\nVerifique: integridade do shapefile\nSkill anterior: [nenhuma]", conditionMessage(e))
  stop(e)
})

if (!area_col %in% names(patches)) {
  # Compute area from geometry if column missing
  log_warn("Coluna '%s' nao encontrada; calculando area a partir da geometria", area_col)
  patches[[area_col]] <- as.numeric(st_area(patches)) / 10000  # m² → ha
}

n   <- nrow(patches)
A   <- sum(patches[[area_col]])  # total landscape area proxy (sum of patch areas)
log_info("Manchas carregadas: %d. Area total das manchas: %.1f ha", n, A)

if (n < 3) {
  log_error("Minimo de 3 manchas necessario para analise de conectividade. Encontradas: %d\nCausa provavel: dado de entrada com poucas feicoes\nVerifique: arquivo de manchas e filtros de area minima\nSkill anterior: [nenhuma]", n)
  stop("At least 3 patches required for connectivity analysis. ",
       "Found ", n, " patches.")
}

log_step(2, "Calculando distancias entre centroides das manchas")
# ── Compute pairwise distances between patch centroids ──────────────────────
centroids <- st_centroid(patches)
# Reproject to projected CRS if needed
if (st_is_longlat(centroids)) {
  log_warn("Entrada em CRS geografico. Reprojetando para UTM para calculo de distancias")
  utm_crs <- 32700 + round((mean(st_coordinates(centroids)[, 1]) + 180) / 6) + 1
  centroids <- st_transform(centroids, crs = utm_crs)
  log_info("CRS UTM usado: EPSG:%d", utm_crs)
}
coords   <- st_coordinates(centroids)
dist_mat <- as.matrix(dist(coords))  # metres

log_step(3, "Construindo grafo de adjacencia binaria")
# ── Build adjacency matrix (binary, distance < dmax) ───────────────────────
adj_binary <- (dist_mat < dmax_m) * 1
diag(adj_binary) <- 0

g_binary <- graph_from_adjacency_matrix(adj_binary, mode = "undirected",
                                         weighted = FALSE)
sp_hops <- distances(g_binary, algorithm = "bfs")

n_edges <- sum(adj_binary) / 2
log_info("Grafo construido: %d nos, %d arestas (dmax = %g m)", n, n_edges, dmax_m)
if (n_edges == 0) {
  log_warn("Nenhuma mancha conectada dentro de dmax = %g m; aumente dmax_m ou verifique CRS", dmax_m)
}

log_step(4, "Calculando IIC — Integral Index of Connectivity")
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

log_step(5, "Calculando dIIC por mancha (leave-one-out)")
# ── dIIC per patch ──────────────────────────────────────────────────────────
log_info("Calculando dIIC para cada mancha (pode levar um momento)...")
dIIC_vec <- numeric(n)
for (i in seq_len(n)) {
  areas_i  <- areas[-i]
  adj_i    <- adj_binary[-i, -i]
  g_i      <- graph_from_adjacency_matrix(adj_i, mode = "undirected")
  sp_i     <- distances(g_i, algorithm = "bfs")
  IIC_i    <- compute_iic_internal(areas_i, sp_i)
  dIIC_vec[i] <- (IIC_full - IIC_i) / IIC_full * 100
}

log_step(6, "Calculando PC — Probability of Connectivity")
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

log_step(7, "Calculando dPC por mancha (leave-one-out)")
# ── dPC per patch ────────────────────────────────────────────────────────────
log_info("Calculando dPC para cada mancha...")
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

log_step(8, "Escrevendo resumo da paisagem e metricas por mancha")
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
log_info("Resumo da paisagem gravado: %s", sum_path)

if (components_g$no > n / 2) {
  log_warn("Paisagem altamente fragmentada: %d componentes para %d manchas; considere aumentar dmax_m",
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
log_info("Metricas por mancha gravadas: %s (%d manchas)", patch_path, n)

# Report top patches
log_info("Top 5 manchas por dPC:")
top5 <- head(patch_metrics[, c("patch_id", "area_ha", "dPC_pct", "BC_norm")], 5)
for (r in seq_len(nrow(top5))) {
  log_info("  patch_id=%s | area=%.1f ha | dPC=%.2f%% | BC=%.4f",
           top5$patch_id[r], top5$area_ha[r], top5$dPC_pct[r], top5$BC_norm[r])
}

log_step(9, "Gerando visualizacao do grafo de conectividade")
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
  log_info("Visualizacao do grafo salva: %s", plot_path)
}, error = function(e) {
  log_warn("Nao foi possivel salvar visualizacao do grafo: %s", conditionMessage(e))
})

log_info("Analise de conectividade concluida")
