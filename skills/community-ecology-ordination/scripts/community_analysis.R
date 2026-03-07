# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript community_analysis.R <species_site_matrix.csv> <metadata.csv> <output_dir> [method]
# NMDS ordination, diversity metrics, PERMANOVA
# Usage: Rscript community_analysis.R <species_matrix_csv> <metadata_csv> <output_dir>
# Requires: vegan, ggplot2, dplyr

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "community-ecology-ordination"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages({
  library(vegan)
  library(ggplot2)
  library(dplyr)
})

args       <- commandArgs(trailingOnly = TRUE)
sp_file    <- ifelse(length(args) >= 1, args[1], "data/species_matrix.csv")
meta_file  <- ifelse(length(args) >= 2, args[2], "data/site_metadata.csv")
output_dir <- ifelse(length(args) >= 3, args[3], "outputs/community")

log_step(1, "Validate inputs")
if (!file.exists(sp_file)) {
  log_error(
    "Falha em validate inputs: arquivo de matriz de especies nao encontrado: %s\nCausa provavel: caminho incorreto ou arquivo nao gerado\nVerifique: o argumento species_matrix_csv e o diretorio de trabalho\nSkill anterior: data-cleaning",
    sp_file
  )
  stop("Species matrix file not found.")
}
if (!file.exists(meta_file)) {
  log_error(
    "Falha em validate inputs: arquivo de metadados nao encontrado: %s\nCausa provavel: caminho incorreto ou arquivo nao gerado\nVerifique: o argumento metadata_csv e o diretorio de trabalho\nSkill anterior: data-cleaning",
    meta_file
  )
  stop("Metadata file not found.")
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
set.seed(42)
log_decision("random_seed", 42, "ensures reproducibility of NMDS and permutation tests")

log_step(2, "Load species matrix and metadata")
tryCatch({
  sp   <- read.csv(sp_file, row.names = 1)
  meta <- read.csv(meta_file, row.names = 1)
}, error = function(e) {
  log_error(
    "Falha em load data: %s\nCausa provavel: CSV malformado ou sem coluna de rownames\nVerifique: estrutura dos arquivos (primeira coluna deve ser site ID)\nSkill anterior: data-cleaning",
    conditionMessage(e)
  )
  stop(e)
})

log_info("Sites: %d | Species: %d", nrow(sp), ncol(sp))

if (any(sp < 0, na.rm = TRUE)) {
  log_warn("Species matrix contains negative values. Abundances must be >= 0. Check your input data.")
}
if (anyNA(sp)) {
  log_warn("Species matrix contains %d NA values. These will be treated as zero by vegan.", sum(is.na(sp)))
}

log_step(3, "Compute alpha diversity metrics")
tryCatch({
  div <- data.frame(
    site    = rownames(sp),
    richness = specnumber(sp),
    shannon  = diversity(sp, index = "shannon"),
    simpson  = diversity(sp, index = "simpson")
  )
  write.csv(div, file.path(output_dir, "diversity_metrics.csv"), row.names = FALSE)
  log_info("Alpha diversity computed. Mean richness: %.1f | Mean Shannon: %.2f",
           mean(div$richness), mean(div$shannon))
}, error = function(e) {
  log_error(
    "Falha em alpha diversity: %s\nCausa provavel: matriz de especies vazia ou nao numerica\nVerifique: estrutura do CSV de especies\nSkill anterior: data-cleaning",
    conditionMessage(e)
  )
  stop(e)
})

log_step(4, "Run NMDS ordination (Bray-Curtis, k=2)")
log_decision("distance_metric", "bray", "Bray-Curtis is standard for community composition data")
log_decision("nmds_k", 2, "2 dimensions for interpretable 2D ordination plot")
tryCatch({
  nmds <- metaMDS(sp, distance = "bray", k = 2, trymax = 50, trace = 0)
  log_info("NMDS stress: %.4f", nmds$stress)
  if (nmds$stress > 0.2) {
    log_warn("NMDS stress = %.4f exceeds 0.20. Ordination may be unreliable; consider k=3 or data transformation.", nmds$stress)
  }

  scores_df <- as.data.frame(scores(nmds, display = "sites")) |>
    mutate(site = rownames(sp)) |>
    left_join(meta |> mutate(site = rownames(meta)), by = "site")

  p_ord <- ggplot(scores_df, aes(x = NMDS1, y = NMDS2)) +
    geom_point(size = 3) +
    annotate("text", x = Inf, y = -Inf, label = paste("Stress =", round(nmds$stress, 3)),
             hjust = 1.1, vjust = -0.5, size = 3.5) +
    theme_bw() + labs(title = "NMDS Ordination (Bray-Curtis)")
  ggsave(file.path(output_dir, "ordination_plot.png"), p_ord, width = 7, height = 6, dpi = 150)
  log_info("Ordination plot saved.")
}, error = function(e) {
  log_error(
    "Falha em NMDS: %s\nCausa provavel: matriz com sites/especies insuficientes ou todos zeros\nVerifique: numero de sites (>= 3) e que a matriz nao seja toda zeros\nSkill anterior: data-cleaning",
    conditionMessage(e)
  )
  stop(e)
})

log_step(5, "PERMANOVA and PERMDISP (if 'group' column present)")
if ("group" %in% names(meta)) {
  log_decision("permanova_permutations", 999, "standard number for robust p-value estimation")
  tryCatch({
    dist_mat  <- vegdist(sp, method = "bray")
    perm      <- adonis2(dist_mat ~ meta$group, permutations = 999)
    disp      <- betadisper(dist_mat, meta$group)
    disp_test <- permutest(disp, permutations = 999)
    log_info("PERMANOVA:\n%s", paste(capture.output(perm), collapse = "\n"))
    log_info("PERMDISP:\n%s", paste(capture.output(disp_test), collapse = "\n"))
    capture.output(perm, disp_test) |>
      writeLines(file.path(output_dir, "permanova_results.txt"))
    log_info("PERMANOVA results saved.")
  }, error = function(e) {
    log_error(
      "Falha em PERMANOVA/PERMDISP: %s\nCausa provavel: grupo com apenas um nivel ou sites insuficientes por grupo\nVerifique: coluna 'group' nos metadados e balanceamento\nSkill anterior: data-cleaning",
      conditionMessage(e)
    )
    stop(e)
  })
} else {
  log_warn("Column 'group' not found in metadata. PERMANOVA and PERMDISP skipped.")
}

log_info("Done. Outputs in: %s", output_dir)
