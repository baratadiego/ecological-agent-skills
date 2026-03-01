# community_analysis.R
# NMDS ordination, diversity metrics, PERMANOVA
# Usage: Rscript community_analysis.R <species_matrix_csv> <metadata_csv> <output_dir>
# Requires: vegan, ggplot2, dplyr

suppressPackageStartupMessages({
  library(vegan)
  library(ggplot2)
  library(dplyr)
})

args       <- commandArgs(trailingOnly = TRUE)
sp_file    <- ifelse(length(args) >= 1, args[1], "data/species_matrix.csv")
meta_file  <- ifelse(length(args) >= 2, args[2], "data/site_metadata.csv")
output_dir <- ifelse(length(args) >= 3, args[3], "outputs/community")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

set.seed(42)

# ── Load ───────────────────────────────────────────────────────────────────
sp   <- read.csv(sp_file, row.names = 1)
meta <- read.csv(meta_file, row.names = 1)
cat("Sites:", nrow(sp), "| Species:", ncol(sp), "\n")

# ── Alpha diversity ────────────────────────────────────────────────────────
div <- data.frame(
  site    = rownames(sp),
  richness = specnumber(sp),
  shannon  = diversity(sp, index = "shannon"),
  simpson  = diversity(sp, index = "simpson")
)
write.csv(div, file.path(output_dir, "diversity_metrics.csv"), row.names = FALSE)
cat("Alpha diversity computed.\n")

# ── NMDS ───────────────────────────────────────────────────────────────────
cat("Running NMDS (k=2, Bray-Curtis)...\n")
nmds <- metaMDS(sp, distance = "bray", k = 2, trymax = 50, trace = 0)
cat("NMDS stress:", round(nmds$stress, 4), "\n")

scores_df <- as.data.frame(scores(nmds, display = "sites")) |>
  mutate(site = rownames(sp)) |>
  left_join(meta |> mutate(site = rownames(meta)), by = "site")

p_ord <- ggplot(scores_df, aes(x = NMDS1, y = NMDS2)) +
  geom_point(size = 3) +
  annotate("text", x = Inf, y = -Inf, label = paste("Stress =", round(nmds$stress, 3)),
           hjust = 1.1, vjust = -0.5, size = 3.5) +
  theme_bw() + labs(title = "NMDS Ordination (Bray-Curtis)")
ggsave(file.path(output_dir, "ordination_plot.png"), p_ord, width = 7, height = 6, dpi = 150)

# ── PERMANOVA + PERMDISP ───────────────────────────────────────────────────
# Example: if metadata has a 'group' column
if ("group" %in% names(meta)) {
  dist_mat <- vegdist(sp, method = "bray")
  perm     <- adonis2(dist_mat ~ meta$group, permutations = 999)
  disp     <- betadisper(dist_mat, meta$group)
  disp_test <- permutest(disp, permutations = 999)
  cat("\nPERMANOVA:\n"); print(perm)
  cat("\nPERMDISP:\n"); print(disp_test)
  capture.output(perm, disp_test) |>
    writeLines(file.path(output_dir, "permanova_results.txt"))
}
cat("Done. Outputs in:", output_dir, "\n")
