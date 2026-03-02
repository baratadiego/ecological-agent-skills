# Usage: Rscript compute_acoustic_indices.R <audio_dir> <output_dir> [time_resolution_min] [freq_min] [freq_max]
#
# Computes acoustic indices (ACI, BI, NDSI, H, ADI, AEI) for all .wav/.flac
# files in a directory, aggregates by time resolution, and produces summary
# outputs and a soundscape heatmap.
#
# Outputs:
#   acoustic_indices_timeseries.csv  — per-file index values with timestamps
#   indices_summary.csv              — mean ± SD per index per hour-of-day
#   soundscape_plot.png              — heatmap (hour × day × index)

suppressPackageStartupMessages(library(soundecology))
suppressPackageStartupMessages(library(tuneR))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(tidyr))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(ggplot2))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  cat("Usage: Rscript compute_acoustic_indices.R <audio_dir> <output_dir>",
      "[time_resolution_min] [freq_min_hz] [freq_max_hz]\n")
  cat("Defaults: time_resolution_min=1  freq_min_hz=0  freq_max_hz=22050\n")
  quit(status = 1)
}

audio_dir        <- args[1]
output_dir       <- args[2]
time_res_min     <- if (length(args) >= 3) as.integer(args[3]) else 1L
freq_min_hz      <- if (length(args) >= 4) as.numeric(args[4]) else 0
freq_max_hz      <- if (length(args) >= 5) as.numeric(args[5]) else 22050

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Discover audio files ────────────────────────────────────────────────────
wav_files  <- list.files(audio_dir, pattern = "\\.wav$",  full.names = TRUE,
                         recursive = TRUE, ignore.case = TRUE)
flac_files <- list.files(audio_dir, pattern = "\\.flac$", full.names = TRUE,
                         recursive = TRUE, ignore.case = TRUE)
audio_files <- c(wav_files, flac_files)

if (length(audio_files) == 0) {
  stop("No .wav or .flac files found in: ", audio_dir)
}
cat(sprintf("Found %d audio files.\n", length(audio_files)))

# ── Helper: extract timestamp from filename ─────────────────────────────────
# Supports common recorder filename patterns:
#   AUDIOMOTH_20240601_050000.wav
#   SMM07207_0+1_20240601$050000.wav (Wildlife Acoustics)
#   generic: any 8-digit date + 6-digit time
parse_timestamp <- function(fname) {
  base <- tools::file_path_sans_ext(basename(fname))
  m <- regmatches(base,
         regexpr("(\\d{8})[_$T](\\d{6})", base, perl = TRUE))
  if (length(m) == 0 || nchar(m) == 0) return(NA_POSIXct_)
  parts <- regmatches(m, regexpr("(\\d{8})[_$T](\\d{6})", m, perl = TRUE))
  dt_str <- sub("([_$T])", " ", parts)
  tryCatch(as.POSIXct(dt_str, format = "%Y%m%d %H%M%S", tz = "UTC"),
           error = function(e) NA_POSIXct_)
}

# ── Compute indices per file ────────────────────────────────────────────────
compute_file_indices <- function(fpath) {
  tryCatch({
    if (grepl("\\.flac$", fpath, ignore.case = TRUE)) {
      # Convert FLAC to temp WAV for tuneR compatibility
      tmp <- tempfile(fileext = ".wav")
      system2("ffmpeg", args = c("-y", "-i", shQuote(fpath),
                                 shQuote(tmp)), stdout = FALSE, stderr = FALSE)
      wave <- readWave(tmp)
      file.remove(tmp)
    } else {
      wave <- readWave(fpath)
    }

    sr <- wave@samp.rate
    freq_max_use <- min(freq_max_hz, sr / 2)

    # ACI — Acoustic Complexity Index
    aci_res  <- acoustic_complexity(wave, min_freq = freq_min_hz,
                                    max_freq = freq_max_use)
    aci_val  <- aci_res$AciTotAll_left

    # BI — Bioacoustic Index
    bi_res   <- bioacoustic_index(wave, min_freq = max(freq_min_hz, 2000),
                                  max_freq = min(freq_max_use, 8000))
    bi_val   <- bi_res$left_area

    # NDSI — Normalized Difference Soundscape Index
    ndsi_res <- ndsi(wave, fft_w = 1024,
                     anthro_min = max(freq_min_hz, 200),
                     anthro_max = 2000,
                     bio_min    = 2000,
                     bio_max    = min(freq_max_use, 8000))
    ndsi_val <- ndsi_res$ndsi_left

    # H — Spectral and temporal entropy
    h_res    <- acoustic_entropy(wave)
    h_val    <- h_res$H

    # ADI — Acoustic Diversity Index
    adi_res  <- acoustic_diversity(wave, max_freq = freq_max_use, db_threshold = -50)
    adi_val  <- adi_res$adi_left

    # AEI — Acoustic Evenness Index
    aei_res  <- acoustic_evenness(wave, max_freq = freq_max_use, db_threshold = -50)
    aei_val  <- aei_res$aei_left

    data.frame(
      file      = basename(fpath),
      datetime  = parse_timestamp(fpath),
      ACI       = aci_val,
      BI        = bi_val,
      NDSI      = ndsi_val,
      H         = h_val,
      ADI       = adi_val,
      AEI       = aei_val,
      stringsAsFactors = FALSE
    )
  }, error = function(e) {
    warning(sprintf("Skipping %s: %s", basename(fpath), conditionMessage(e)))
    NULL
  })
}

cat("Computing indices — this may take several minutes for large datasets...\n")
results_list <- lapply(audio_files, compute_file_indices)
results_list <- Filter(Negate(is.null), results_list)

if (length(results_list) == 0) {
  stop("No files could be processed. Check audio format and frequency range.")
}

indices_df <- dplyr::bind_rows(results_list)

# ── Aggregate by time resolution ────────────────────────────────────────────
if (!is.na(indices_df$datetime[1])) {
  indices_df <- indices_df %>%
    mutate(
      time_block = floor_date(datetime, unit = paste(time_res_min, "mins")),
      hour_of_day = hour(datetime),
      date        = as.Date(datetime)
    )
} else {
  # No timestamps extracted; use row order as proxy
  indices_df <- indices_df %>%
    mutate(time_block = seq_len(nrow(.)),
           hour_of_day = NA_integer_,
           date = NA)
  warning("No timestamps extracted from filenames. Heatmap will not be produced.")
}

# ── Write timeseries CSV ────────────────────────────────────────────────────
ts_path <- file.path(output_dir, "acoustic_indices_timeseries.csv")
write.csv(indices_df, ts_path, row.names = FALSE)
cat(sprintf("Timeseries written: %s (%d rows)\n", ts_path, nrow(indices_df)))

# ── Write summary CSV ───────────────────────────────────────────────────────
summary_df <- indices_df %>%
  group_by(hour_of_day) %>%
  summarise(
    across(c(ACI, BI, NDSI, H, ADI, AEI),
           list(mean = ~mean(.x, na.rm = TRUE),
                sd   = ~sd(.x,   na.rm = TRUE))),
    n_recordings = n(),
    .groups = "drop"
  )

sum_path <- file.path(output_dir, "indices_summary.csv")
write.csv(summary_df, sum_path, row.names = FALSE)
cat(sprintf("Summary written: %s\n", sum_path))

# ── Soundscape heatmap ──────────────────────────────────────────────────────
if (!all(is.na(indices_df$datetime))) {
  plot_df <- indices_df %>%
    select(date, hour_of_day, ACI, NDSI, H) %>%
    pivot_longer(cols = c(ACI, NDSI, H), names_to = "index", values_to = "value") %>%
    group_by(date, hour_of_day, index) %>%
    summarise(value = mean(value, na.rm = TRUE), .groups = "drop")

  p <- ggplot(plot_df, aes(x = hour_of_day, y = as.factor(date), fill = value)) +
    geom_tile() +
    scale_fill_viridis_c(option = "magma", na.value = "grey80") +
    facet_wrap(~index, ncol = 1, scales = "free_x") +
    labs(x = "Hour of day", y = "Date", fill = "Index value",
         title = "Soundscape index heatmap (ACI, NDSI, H)") +
    theme_minimal(base_size = 10) +
    theme(axis.text.y = element_text(size = 7))

  plot_path <- file.path(output_dir, "soundscape_plot.png")
  ggsave(plot_path, p, width = 10, height = max(4, nrow(unique(plot_df[, "date"])) * 0.4 + 2),
         dpi = 150)
  cat(sprintf("Heatmap saved: %s\n", plot_path))
} else {
  cat("Skipping heatmap: no timestamps available.\n")
}

cat("\nAcoustic index computation complete.\n")
