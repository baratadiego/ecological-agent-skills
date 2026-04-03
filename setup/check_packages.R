# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later
#
# check_packages.R -- Preflight check for R package dependencies
#
# Usage:
#   Rscript setup/check_packages.R                  # check ALL skills
#   Rscript setup/check_packages.R --phase 1        # check Phase 1 only
#   Rscript setup/check_packages.R --skill sdm      # check one skill (partial match)
#   Rscript setup/check_packages.R --summary        # compact one-line-per-skill view
#
# Returns exit code 0 if all packages are installed, 1 if any are missing.
# ──────────────────────────────────────────────────────────────────────────────

# ── Package registry ─────────────────────────────────────────────────────────
# Each skill lists ONLY the CRAN packages its scripts actually load.
# "core" packages used by many skills are listed once at the top.

CORE_PACKAGES <- c("dplyr", "ggplot2", "readr", "tidyr", "sf", "terra", "yaml")

SKILL_PACKAGES <- list(

  # ── Phase 1: Foundation ──────────────────────────────────────────────────
  `ecological-data-foundation` = list(
    phase       = 1,
    display     = "Ecological Data Foundation",
    packages    = c("dplyr", "readr", "janitor", "CoordinateCleaner",
                    "rgbif", "rinat", "auk", "robis", "rredlist", "usethis")
  ),
  `geoprocessing-for-ecology` = list(
    phase       = 1,
    display     = "Geoprocessing for Ecology",
    packages    = c("sf", "terra", "geodata", "digest")
  ),
  `biostatistics-workbench` = list(
    phase       = 1,
    display     = "Biostatistics Workbench",
    packages    = c("dplyr", "glmmTMB", "DHARMa", "MuMIn", "emmeans")
  ),
  `predictive-modeling-best-practices` = list(
    phase       = 1,
    display     = "Predictive Modeling Best Practices",
    packages    = c("dplyr", "usdm")
  ),
  `reproducible-ecology-pipeline` = list(
    phase       = 1,
    display     = "Reproducible Ecology Pipeline",
    packages    = character(0)  # Python-only skill; no R packages required
  ),

  # ── Phase 2: Modeling ────────────────────────────────────────────────────
  `species-distribution-modeling` = list(
    phase       = 2,
    display     = "Species Distribution Modeling",
    packages    = c("terra", "sf", "dplyr", "ggplot2", "yaml",
                    "maxnet", "biomod2", "ENMeval", "gbm",
                    "randomForest", "dismo", "tools")
  ),
  `model-validation-and-uncertainty` = list(
    phase       = 2,
    display     = "Model Validation & Uncertainty",
    packages    = c("terra", "dplyr", "ggplot2", "dismo")
  ),
  `ecological-impact-assessment` = list(
    phase       = 2,
    display     = "Ecological Impact Assessment",
    packages    = c("dplyr", "ggplot2", "glmmTMB", "emmeans",
                    "pwr", "patchwork", "scales")
  ),
  `environmental-time-series` = list(
    phase       = 2,
    display     = "Environmental Time Series",
    packages    = c("dplyr", "ggplot2", "broom", "trend", "bfast", "zoo")
  ),

  # ── Phase 3: Specialist ─────────────────────────────────────────────────
  `occupancy-and-detection` = list(
    phase       = 3,
    display     = "Occupancy & Detection",
    packages    = c("dplyr", "unmarked")
  ),
  `community-ecology-ordination` = list(
    phase       = 3,
    display     = "Community Ecology Ordination",
    packages    = c("dplyr", "ggplot2", "vegan")
  ),
  `ecosystem-services-assessment` = list(
    phase       = 3,
    display     = "Ecosystem Services Assessment",
    packages    = c("dplyr", "ggplot2", "tidyr", "corrplot", "ggrepel")
  ),

  # ── Phase 4: Advanced ───────────────────────────────────────────────────
  `camera-trap-processing` = list(
    phase       = 4,
    display     = "Camera Trap Processing",
    packages    = c("dplyr", "ggplot2", "lubridate",
                    "camtrapR", "overlap", "circular")
  ),
  `acoustic-monitoring` = list(
    phase       = 4,
    display     = "Acoustic Monitoring",
    packages    = c("dplyr", "ggplot2", "tidyr", "lubridate",
                    "soundecology", "tuneR", "tools")
  ),
  `landscape-connectivity` = list(
    phase       = 4,
    display     = "Landscape Connectivity",
    packages    = c("sf", "terra", "dplyr", "ggplot2", "igraph")
  ),
  `population-viability-analysis` = list(
    phase       = 4,
    display     = "Population Viability Analysis",
    packages    = c("dplyr", "ggplot2", "tidyr", "popbio", "scales")
  ),
  `spatial-prioritization` = list(
    phase       = 4,
    display     = "Spatial Prioritization",
    packages    = c("terra", "sf", "dplyr", "ggplot2",
                    "ggrepel", "prioritizr", "tools")
  )
)

# ── CLI argument parsing ─────────────────────────────────────────────────────

args <- commandArgs(trailingOnly = TRUE)

filter_phase  <- NULL
filter_skill  <- NULL
summary_mode  <- FALSE

i <- 1
while (i <= length(args)) {
  if (args[i] == "--phase" && i < length(args)) {
    filter_phase <- as.integer(args[i + 1])
    i <- i + 2
  } else if (args[i] == "--skill" && i < length(args)) {
    filter_skill <- args[i + 1]
    i <- i + 2
  } else if (args[i] == "--summary") {
    summary_mode <- TRUE
    i <- i + 1
  } else if (args[i] %in% c("--help", "-h")) {
    cat("
Usage: Rscript check_packages.R [OPTIONS]

Options:
  --phase N       Check only skills in Phase N (1-4)
  --skill NAME    Check a single skill (partial match, e.g. 'sdm')
  --summary       Compact one-line-per-skill output
  --help          Show this message

Examples:
  Rscript setup/check_packages.R
  Rscript setup/check_packages.R --phase 1
  Rscript setup/check_packages.R --skill species-distribution
  Rscript setup/check_packages.R --summary
")
    quit(status = 0)
  } else {
    cat("Unknown argument:", args[i], "\nUse --help for usage.\n")
    quit(status = 1)
  }
}

# ── Filter skills ────────────────────────────────────────────────────────────

skills_to_check <- SKILL_PACKAGES

if (!is.null(filter_phase)) {
  skills_to_check <- Filter(function(s) s$phase == filter_phase, skills_to_check)
  if (length(skills_to_check) == 0) {
    cat("No skills found for Phase", filter_phase, "\n")
    quit(status = 1)
  }
}

if (!is.null(filter_skill)) {
  matched <- grep(filter_skill, names(SKILL_PACKAGES), ignore.case = TRUE, value = TRUE)
  if (length(matched) == 0) {
    cat("No skill matching '", filter_skill, "'\n", sep = "")
    cat("Available skills:\n")
    cat(paste(" ", names(SKILL_PACKAGES), collapse = "\n"), "\n")
    quit(status = 1)
  }
  skills_to_check <- SKILL_PACKAGES[matched]
}

# ── Check helper ─────────────────────────────────────────────────────────────

check_pkg <- function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
}

# ── Colour helpers (respects NO_COLOR) ───────────────────────────────────────

use_colour <- interactive() || Sys.getenv("NO_COLOR") == ""

green  <- function(x) if (use_colour) paste0("\033[32m", x, "\033[0m") else x
red    <- function(x) if (use_colour) paste0("\033[31m", x, "\033[0m") else x
yellow <- function(x) if (use_colour) paste0("\033[33m", x, "\033[0m") else x
bold   <- function(x) if (use_colour) paste0("\033[1m", x, "\033[0m") else x

# ── Run checks ───────────────────────────────────────────────────────────────

total_installed <- 0
total_missing   <- 0
missing_by_skill <- list()

phase_names <- c("Foundation", "Modeling", "Specialist", "Advanced")

cat(bold("\n=== ecological-agent-skills: R Package Check ===\n\n"))

if (!is.null(filter_phase)) {
  cat("Scope: Phase", filter_phase, "(", phase_names[filter_phase], ")\n\n")
} else if (!is.null(filter_skill)) {
  cat("Scope: skill matching '", filter_skill, "'\n\n", sep = "")
} else {
  cat("Scope: all 17 skills\n\n")
}

for (skill_id in names(skills_to_check)) {
  info <- skills_to_check[[skill_id]]
  pkgs <- unique(info$packages)

  if (length(pkgs) == 0) {
    if (!summary_mode) {
      cat(bold(sprintf("[Phase %d] %s\n", info$phase, info$display)))
      cat("  No R packages required (Python-only skill)\n\n")
    }
    next
  }

  installed <- vapply(pkgs, check_pkg, logical(1))
  n_ok      <- sum(installed)
  n_miss    <- sum(!installed)

  total_installed <- total_installed + n_ok
  total_missing   <- total_missing + n_miss

  if (n_miss > 0) {
    missing_by_skill[[skill_id]] <- pkgs[!installed]
  }

  if (summary_mode) {
    status <- if (n_miss == 0) green("OK") else red(sprintf("%d missing", n_miss))
    cat(sprintf("  [Phase %d] %-42s %s\n", info$phase, info$display, status))
  } else {
    cat(bold(sprintf("[Phase %d] %s\n", info$phase, info$display)))
    for (j in seq_along(pkgs)) {
      status <- if (installed[j]) green("INSTALLED") else red("MISSING")
      cat(sprintf("  %-28s %s\n", pkgs[j], status))
    }
    cat("\n")
  }
}

# ── Summary ──────────────────────────────────────────────────────────────────

cat(bold("\n--- Summary ---\n"))
cat(sprintf("  Packages checked : %d\n", total_installed + total_missing))
cat(sprintf("  Installed        : %s\n", green(total_installed)))
cat(sprintf("  Missing          : %s\n", if (total_missing > 0) red(total_missing) else green(0)))

if (total_missing > 0) {
  cat(yellow("\nMissing packages by skill:\n"))
  for (skill_id in names(missing_by_skill)) {
    cat(sprintf("  %s: %s\n", skill_id, paste(missing_by_skill[[skill_id]], collapse = ", ")))
  }

  # Build install command
  all_missing <- unique(unlist(missing_by_skill))
  cat(yellow("\nTo install all missing packages at once:\n"))
  cat(sprintf('  install.packages(c(%s))\n',
              paste0('"', all_missing, '"', collapse = ", ")))

  cat(yellow("\nOr install per skill:\n"))
  cat(sprintf("  Rscript setup/install_packages.R --skill <name>\n"))

  cat(yellow("\nIf sf or terra fail, check system dependencies first:\n"))
  cat("  bash setup/check_system_deps.sh\n\n")
  quit(status = 1)
} else {
  cat(green("\nAll R packages are installed. You are ready to go!\n\n"))
  quit(status = 0)
}
