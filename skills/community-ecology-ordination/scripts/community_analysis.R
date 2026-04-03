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
    "Failed in validate inputs: species matrix file not found: %s\nProbable cause: incorrect path or file not generated\nCheck: the species_matrix_csv argument and working directory\nPrevious skill: data-cleaning",
    sp_file
  )
  stop("Species matrix file not found.")
}
if (!file.exists(meta_file)) {
  log_error(
    "Failed in validate inputs: metadata file not found: %s\nProbable cause: incorrect path or file not generated\nCheck: the metadata_csv argument and working directory\nPrevious skill: data-cleaning",
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
    "Failed in load data: %s\nProbable cause: malformed CSV or missing rownames column\nCheck: file structure (first column must be site ID)\nPrevious skill: data-cleaning",
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
    "Failed in alpha diversity: %s\nProbable cause: empty or non-numeric species matrix\nCheck: structure of the species CSV\nPrevious skill: data-cleaning",
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
    "Failed in NMDS: %s\nProbable cause: matrix with insufficient sites/species or all zeros\nCheck: number of sites (>= 3) and that the matrix is not all zeros\nPrevious skill: data-cleaning",
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
      "Failed in PERMANOVA/PERMDISP: %s\nProbable cause: group with only one level or insufficient sites per group\nCheck: 'group' column in metadata and balance\nPrevious skill: data-cleaning",
      conditionMessage(e)
    )
    stop(e)
  })
} else {
  log_warn("Column 'group' not found in metadata. PERMANOVA and PERMDISP skipped.")
}

log_info("Done. Outputs in: %s", output_dir)
