# tradeoff_analysis.R
# ES trade-off and synergy analysis across pixels or land cover units
# Usage: Rscript tradeoff_analysis.R <es_summary_csv> <output_dir>
# Requires: dplyr, ggplot2, corrplot, tidyr

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(corrplot)
  library(tidyr)
})

args       <- commandArgs(trailingOnly = TRUE)
es_file    <- ifelse(length(args) >= 1, args[1], "outputs/ecosystem_services/es_summary_table.csv")
output_dir <- ifelse(length(args) >= 2, args[2], "outputs/ecosystem_services")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

es <- read.csv(es_file)
cat("ES summary loaded:", nrow(es), "land cover classes\n")

# Identify numeric ES columns (exclude lulc codes and n_pixels)
es_cols <- names(es)[sapply(es, is.numeric) & !names(es) %in% c("lulc_code", "n_pixels")]
cat("ES indicators:", paste(es_cols, collapse = ", "), "\n")

if (length(es_cols) < 2) {
  cat("Need at least 2 ES indicators for trade-off analysis.\n")
  quit(status = 0)
}

# Normalise to 0-1
es_norm <- es |>
  mutate(across(all_of(es_cols), ~ (. - min(., na.rm=TRUE)) / (max(., na.rm=TRUE) - min(., na.rm=TRUE) + 1e-10)))

# Correlation matrix (Spearman)
cor_mat <- cor(es_norm[es_cols], method = "spearman", use = "complete.obs")
write.csv(as.data.frame(cor_mat), file.path(output_dir, "tradeoff_matrix.csv"))

# Correlation plot
png(file.path(output_dir, "tradeoff_heatmap.png"), width = 800, height = 700, res = 150)
corrplot(cor_mat, method = "color", type = "upper", tl.cex = 0.8,
         addCoef.col = "black", number.cex = 0.7, cl.cex = 0.7,
         title = "ES Trade-offs (Spearman r)", mar = c(0, 0, 2, 0))
dev.off()

# Scatter plots for top pairs
pair_combos <- combn(es_cols, 2, simplify = FALSE)
for (pr in pair_combos[seq_len(min(6, length(pair_combos)))]) {
  p <- ggplot(es |> mutate(label = lulc_code),
              aes(x = .data[[pr[1]]], y = .data[[pr[2]]], label = label)) +
    geom_point(size = 3, colour = "#2166ac") +
    ggrepel::geom_text_repel(size = 2.5, max.overlaps = 10) +
    labs(x = pr[1], y = pr[2],
         title = paste("Trade-off:", pr[1], "vs", pr[2])) +
    theme_bw()
  fname <- paste0("scatter_", pr[1], "_vs_", pr[2], ".png")
  ggsave(file.path(output_dir, fname), p, width = 5, height = 4, dpi = 150)
}
cat("Trade-off analysis complete. Outputs in:", output_dir, "\n")
