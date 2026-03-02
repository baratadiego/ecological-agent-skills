# Usage: Rscript estimate_activity.R <record_table_csv> <species_name> <output_dir> [group_column]
suppressPackageStartupMessages(library(overlap))
suppressPackageStartupMessages(library(circular))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(lubridate))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  cat("Usage: Rscript estimate_activity.R <record_table_csv> <species_name> <output_dir> [group_column]\n")
  cat("  group_column: optional column for comparing two groups (e.g., 'season')\n")
  quit(status = 1)
}

record_csv   <- args[1]
species_name <- args[2]
output_dir   <- args[3]
group_col    <- ifelse(length(args) >= 4, args[4], NULL)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

records <- read.csv(record_csv, stringsAsFactors = FALSE)
records$DateTimeOriginal <- as.POSIXct(records$DateTimeOriginal,
                                        format = "%Y-%m-%d %H:%M:%S")

sp_data <- records[records$Species == species_name, ]
if (nrow(sp_data) < 10) {
  stop("n_independent_events < 10 for '", species_name,
       "'. Report RAI only; do not estimate activity overlap.")
}

# Convert to radians
to_rad <- function(dt) {
  (hour(dt) + minute(dt) / 60) * (2 * pi / 24)
}
sp_data$time_rad <- to_rad(sp_data$DateTimeOriginal)

# Overall activity density plot
png(file.path(output_dir, "activity_plot.png"), width = 900, height = 600, res = 120)
overlapPlot(sp_data$time_rad, rug = TRUE,
            main = paste("Diel Activity —", gsub("_", " ", species_name)),
            xlab = "Time of day", col.main = "black")
dev.off()

# Circular statistics
time_circ  <- circular(sp_data$time_rad, units = "radians", template = "clock24")
mean_rad   <- mean.circular(time_circ)
mean_hour  <- as.numeric(mean_rad) * 24 / (2 * pi)
kappa_est  <- tryCatch(mle.vonmises(time_circ)$kappa, error = function(e) NA_real_)
rayleigh_p <- rayleigh.test(time_circ)$p.value

circ_stats <- data.frame(
  species         = species_name,
  n_events        = nrow(sp_data),
  mean_activity_hour = round(mean_hour %% 24, 2),
  kappa           = round(kappa_est, 3),
  rayleigh_p      = round(rayleigh_p, 4),
  non_uniform     = rayleigh_p < 0.05
)
write.csv(circ_stats, file.path(output_dir, "circular_stats.csv"), row.names = FALSE)

# Diel overlap between two groups (if group_col provided)
overlap_result <- data.frame()
if (!is.null(group_col) && group_col %in% names(sp_data)) {
  groups <- unique(sp_data[[group_col]])
  if (length(groups) == 2) {
    groupA <- sp_data$time_rad[sp_data[[group_col]] == groups[1]]
    groupB <- sp_data$time_rad[sp_data[[group_col]] == groups[2]]

    if (length(groupA) >= 10 && length(groupB) >= 10) {
      boot_out  <- bootEst(groupA, groupB, nb = 1000, type = "Dhat4")
      delta4    <- boot_out["Dhat4"]
      ci_lower  <- boot_out["lwr"]
      ci_upper  <- boot_out["upr"]

      overlap_result <- data.frame(
        groupA  = groups[1],
        groupB  = groups[2],
        n_A     = length(groupA),
        n_B     = length(groupB),
        Dhat4   = round(delta4, 3),
        ci_lower = round(ci_lower, 3),
        ci_upper = round(ci_upper, 3)
      )

      png(file.path(output_dir, "activity_overlap.png"), width = 900, height = 600, res = 120)
      overlapPlot(groupA, groupB, rug = TRUE,
                  main = paste("Diel Overlap — Δ4 =", round(delta4, 2)),
                  linecol = c("blue", "red"))
      legend("topright", legend = groups, col = c("blue", "red"), lty = 1)
      dev.off()
    } else {
      message("One or both groups have < 10 events; overlap not calculated.")
    }
  } else {
    message("group_col '", group_col, "' has ", length(groups),
            " unique values; exactly 2 required for overlap.")
  }
}
write.csv(overlap_result, file.path(output_dir, "activity_overlap.csv"), row.names = FALSE)

message("Done. Outputs written to: ", output_dir)
message("  n events: ", nrow(sp_data))
message("  Mean activity hour: ", round(mean_hour %% 24, 1))
message("  Rayleigh test p: ", round(rayleigh_p, 4))
