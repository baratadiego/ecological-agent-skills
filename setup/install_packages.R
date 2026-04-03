# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later
#
# install_packages.R -- Install R package dependencies per skill or phase
#
# Usage:
#   Rscript setup/install_packages.R --all              # install everything
#   Rscript setup/install_packages.R --phase 1          # install Phase 1 only
#   Rscript setup/install_packages.R --skill sdm        # install for one skill
#   Rscript setup/install_packages.R --missing           # install only missing packages (all skills)
#   Rscript setup/install_packages.R --missing --phase 2 # install only missing in Phase 2
#
# Tries pak for fast binary installs; falls back to install.packages().
# Reports success/failure per package with actionable error messages.
# ──────────────────────────────────────────────────────────────────────────────

# ── Source the package registry from check_packages.R ────────────────────────
# (reuse the same SKILL_PACKAGES list to keep one source of truth)

SCRIPT_DIR <- dirname(normalizePath(
  if (interactive()) rstudioapi::getSourceEditorContext()$path
  else (function() { args <- commandArgs(trailingOnly = FALSE)
                     sub("--file=", "", args[grep("--file=", args)]) })()
))

# ── Package registry (mirrors check_packages.R) ─────────────────────────────

SKILL_PACKAGES <- list(

  # Phase 1: Foundation
  `ecological-data-foundation` = list(
    phase = 1, display = "Ecological Data Foundation",
    packages = c("dplyr", "readr", "janitor", "CoordinateCleaner",
                 "rgbif", "rinat", "auk", "robis", "rredlist", "usethis")
  ),
  `geoprocessing-for-ecology` = list(
    phase = 1, display = "Geoprocessing for Ecology",
    packages = c("sf", "terra", "geodata", "digest")
  ),
  `biostatistics-workbench` = list(
    phase = 1, display = "Biostatistics Workbench",
    packages = c("dplyr", "glmmTMB", "DHARMa", "MuMIn", "emmeans")
  ),
  `predictive-modeling-best-practices` = list(
    phase = 1, display = "Predictive Modeling Best Practices",
    packages = c("dplyr", "usdm")
  ),
  `reproducible-ecology-pipeline` = list(
    phase = 1, display = "Reproducible Ecology Pipeline",
    packages = character(0)
  ),

  # Phase 2: Modeling
  `species-distribution-modeling` = list(
    phase = 2, display = "Species Distribution Modeling",
    packages = c("terra", "sf", "dplyr", "ggplot2", "yaml",
                 "maxnet", "biomod2", "ENMeval", "gbm",
                 "randomForest", "dismo", "tools")
  ),
  `model-validation-and-uncertainty` = list(
    phase = 2, display = "Model Validation & Uncertainty",
    packages = c("terra", "dplyr", "ggplot2", "dismo")
  ),
  `ecological-impact-assessment` = list(
    phase = 2, display = "Ecological Impact Assessment",
    packages = c("dplyr", "ggplot2", "glmmTMB", "emmeans",
                 "pwr", "patchwork", "scales")
  ),
  `environmental-time-series` = list(
    phase = 2, display = "Environmental Time Series",
    packages = c("dplyr", "ggplot2", "broom", "trend", "bfast", "zoo")
  ),

  # Phase 3: Specialist
  `occupancy-and-detection` = list(
    phase = 3, display = "Occupancy & Detection",
    packages = c("dplyr", "unmarked")
  ),
  `community-ecology-ordination` = list(
    phase = 3, display = "Community Ecology Ordination",
    packages = c("dplyr", "ggplot2", "vegan")
  ),
  `ecosystem-services-assessment` = list(
    phase = 3, display = "Ecosystem Services Assessment",
    packages = c("dplyr", "ggplot2", "tidyr", "corrplot", "ggrepel")
  ),

  # Phase 4: Advanced
  `camera-trap-processing` = list(
    phase = 4, display = "Camera Trap Processing",
    packages = c("dplyr", "ggplot2", "lubridate",
                 "camtrapR", "overlap", "circular")
  ),
  `acoustic-monitoring` = list(
    phase = 4, display = "Acoustic Monitoring",
    packages = c("dplyr", "ggplot2", "tidyr", "lubridate",
                 "soundecology", "tuneR", "tools")
  ),
  `landscape-connectivity` = list(
    phase = 4, display = "Landscape Connectivity",
    packages = c("sf", "terra", "dplyr", "ggplot2", "igraph")
  ),
  `population-viability-analysis` = list(
    phase = 4, display = "Population Viability Analysis",
    packages = c("dplyr", "ggplot2", "tidyr", "popbio", "scales")
  ),
  `spatial-prioritization` = list(
    phase = 4, display = "Spatial Prioritization",
    packages = c("terra", "sf", "dplyr", "ggplot2",
                 "ggrepel", "prioritizr", "tools")
  )
)

# ── Known system dependency hints ────────────────────────────────────────────

SYSTEM_DEP_HINTS <- list(
  sf = paste0(
    "sf requires system libraries: GDAL, GEOS, PROJ\n",
    "  Ubuntu/Debian : sudo apt install libgdal-dev libgeos-dev libproj-dev\n",
    "  macOS (brew)  : brew install gdal geos proj\n",
    "  Windows       : install Rtools + binary from CRAN (usually works)"),
  terra = paste0(
    "terra requires GDAL >= 3.0 and PROJ >= 6.0\n",
    "  Ubuntu/Debian : sudo apt install libgdal-dev libproj-dev\n",
    "  macOS (brew)  : brew install gdal\n",
    "  Windows       : binary from CRAN (usually works)"),
  soundecology = paste0(
    "soundecology requires libsndfile for audio I/O\n",
    "  Ubuntu/Debian : sudo apt install libsndfile1-dev\n",
    "  macOS (brew)  : brew install libsndfile\n",
    "  Windows       : binary from CRAN (usually works)"),
  tuneR = paste0(
    "tuneR may require libsndfile and ffmpeg for some audio formats\n",
    "  Ubuntu/Debian : sudo apt install libsndfile1-dev ffmpeg\n",
    "  macOS (brew)  : brew install libsndfile ffmpeg"),
  igraph = paste0(
    "igraph requires libxml2 and glpk\n",
    "  Ubuntu/Debian : sudo apt install libxml2-dev libglpk-dev\n",
    "  macOS (brew)  : brew install libxml2 glpk"),
  prioritizr = paste0(
    "prioritizr uses the HiGHS solver (installed as R package 'highs')\n",
    "  If prioritizr installs but solver fails, install: install.packages('highs')"),
  glmmTMB = paste0(
    "glmmTMB compiles C++ templates on first use; this can be slow.\n",
    "  If compilation fails, ensure Rtools (Windows) or Xcode CLI (macOS) is installed."),
  rgbif = "rgbif requires a GBIF account for occ_download(). occ_search() works without one.",
  auk = "auk requires eBird Basic Dataset (EBD) files downloaded from ebird.org/data/download."
)

# ── CLI argument parsing ─────────────────────────────────────────────────────

args <- commandArgs(trailingOnly = TRUE)

filter_phase  <- NULL
filter_skill  <- NULL
only_missing  <- FALSE
install_all   <- FALSE
dry_run       <- FALSE

i <- 1
while (i <= length(args)) {
  a <- args[i]
  if (a == "--phase" && i < length(args)) {
    filter_phase <- as.integer(args[i + 1]); i <- i + 2
  } else if (a == "--skill" && i < length(args)) {
    filter_skill <- args[i + 1]; i <- i + 2
  } else if (a == "--missing") {
    only_missing <- TRUE; i <- i + 1
  } else if (a == "--all") {
    install_all <- TRUE; i <- i + 1
  } else if (a == "--dry-run") {
    dry_run <- TRUE; i <- i + 1
  } else if (a %in% c("--help", "-h")) {
    cat("
Usage: Rscript install_packages.R [OPTIONS]

Options:
  --all             Install all packages for all skills
  --phase N         Install packages for Phase N (1-4)
  --skill NAME      Install packages for a single skill (partial match)
  --missing         Only install packages that are not yet installed
  --dry-run         Show what would be installed without installing
  --help            Show this message

Examples:
  Rscript setup/install_packages.R --all
  Rscript setup/install_packages.R --phase 1
  Rscript setup/install_packages.R --skill species-distribution --missing
  Rscript setup/install_packages.R --missing --dry-run
")
    quit(status = 0)
  } else {
    cat("Unknown argument:", a, "\nUse --help for usage.\n")
    quit(status = 1)
  }
}

if (!install_all && is.null(filter_phase) && is.null(filter_skill) && !only_missing) {
  cat("Please specify what to install. Use --help for options.\n")
  cat("Quick start:\n")
  cat("  Rscript setup/install_packages.R --phase 1          # foundation packages\n")
  cat("  Rscript setup/install_packages.R --missing           # install what's missing\n")
  cat("  Rscript setup/install_packages.R --all               # install everything\n")
  quit(status = 1)
}

# ── Filter skills ────────────────────────────────────────────────────────────

skills_to_install <- SKILL_PACKAGES

if (!is.null(filter_phase)) {
  skills_to_install <- Filter(function(s) s$phase == filter_phase, skills_to_install)
  if (length(skills_to_install) == 0) {
    cat("No skills found for Phase", filter_phase, "\n")
    quit(status = 1)
  }
}

if (!is.null(filter_skill)) {
  matched <- grep(filter_skill, names(SKILL_PACKAGES), ignore.case = TRUE, value = TRUE)
  if (length(matched) == 0) {
    cat("No skill matching '", filter_skill, "'\n", sep = "")
    cat("Available:\n", paste(" ", names(SKILL_PACKAGES), collapse = "\n"), "\n")
    quit(status = 1)
  }
  skills_to_install <- SKILL_PACKAGES[matched]
}

# ── Collect unique packages ──────────────────────────────────────────────────

all_pkgs <- unique(unlist(lapply(skills_to_install, `[[`, "packages")))

# Filter out base R packages that don't need installation
base_pkgs <- c("tools", "utils", "stats", "grDevices", "graphics", "methods")
all_pkgs  <- setdiff(all_pkgs, base_pkgs)

if (only_missing || install_all) {
  # Default: only install what's missing. --all overrides to reinstall everything.
  if (only_missing) {
    already    <- vapply(all_pkgs, requireNamespace, logical(1), quietly = TRUE)
    to_install <- all_pkgs[!already]
    n_skip     <- sum(already)
  } else {
    to_install <- all_pkgs
    n_skip     <- 0
  }
} else {
  to_install <- all_pkgs
  n_skip     <- 0
}

if (length(to_install) == 0) {
  cat("\nAll packages are already installed. Nothing to do.\n")
  quit(status = 0)
}

# ── Colour helpers ───────────────────────────────────────────────────────────

use_colour <- interactive() || Sys.getenv("NO_COLOR") == ""
green  <- function(x) if (use_colour) paste0("\033[32m", x, "\033[0m") else x
red    <- function(x) if (use_colour) paste0("\033[31m", x, "\033[0m") else x
yellow <- function(x) if (use_colour) paste0("\033[33m", x, "\033[0m") else x
bold   <- function(x) if (use_colour) paste0("\033[1m", x, "\033[0m") else x

# ── Report plan ──────────────────────────────────────────────────────────────

scope_label <- if (!is.null(filter_phase)) {
  paste("Phase", filter_phase)
} else if (!is.null(filter_skill)) {
  paste("skill:", paste(names(skills_to_install), collapse = ", "))
} else {
  "all skills"
}

cat(bold("\n=== ecological-agent-skills: R Package Installer ===\n\n"))
cat(sprintf("  Scope            : %s\n", scope_label))
cat(sprintf("  Packages total   : %d\n", length(all_pkgs)))
if (n_skip > 0) cat(sprintf("  Already installed : %d (skipped)\n", n_skip))
cat(sprintf("  To install       : %d\n", length(to_install)))
cat(sprintf("  Packages         : %s\n", paste(to_install, collapse = ", ")))
cat("\n")

if (dry_run) {
  cat(yellow("--dry-run: no packages will be installed.\n\n"))
  quit(status = 0)
}

# ── Detect installer ─────────────────────────────────────────────────────────

use_pak <- requireNamespace("pak", quietly = TRUE)

if (use_pak) {
  cat("Installer: pak (fast binary installs)\n\n")
} else {
  cat("Installer: install.packages() (pak not found; install pak for faster installs)\n")
  cat("  Tip: install.packages('pak') enables faster binary downloads\n\n")
}

# ── Set CRAN mirror if not set ───────────────────────────────────────────────

if (is.null(getOption("repos")) || getOption("repos")["CRAN"] == "@CRAN@") {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
}

# ── Install loop ─────────────────────────────────────────────────────────────

results  <- data.frame(
  package = to_install,
  status  = character(length(to_install)),
  message = character(length(to_install)),
  stringsAsFactors = FALSE
)

for (idx in seq_along(to_install)) {
  pkg <- to_install[idx]
  cat(sprintf("[%d/%d] Installing %s ... ", idx, length(to_install), bold(pkg)))

  ok <- tryCatch({
    if (use_pak) {
      pak::pkg_install(pkg, ask = FALSE, dependencies = TRUE)
    } else {
      install.packages(pkg, quiet = TRUE, dependencies = TRUE)
    }
    requireNamespace(pkg, quietly = TRUE)
  }, error = function(e) {
    results$message[idx] <<- conditionMessage(e)
    FALSE
  }, warning = function(w) {
    # Warnings during install are common; check if package is loadable
    suppressWarnings(
      tryCatch({
        if (!use_pak) install.packages(pkg, quiet = TRUE, dependencies = TRUE)
        requireNamespace(pkg, quietly = TRUE)
      }, error = function(e2) {
        results$message[idx] <<- conditionMessage(e2)
        FALSE
      })
    )
  })

  if (isTRUE(ok)) {
    results$status[idx] <- "OK"
    cat(green("OK\n"))
  } else {
    results$status[idx] <- "FAILED"
    cat(red("FAILED\n"))
    # Print hint if available
    if (pkg %in% names(SYSTEM_DEP_HINTS)) {
      cat(yellow(paste0("  Hint: ", SYSTEM_DEP_HINTS[[pkg]], "\n")))
    }
    if (nchar(results$message[idx]) > 0) {
      msg <- results$message[idx]
      # Truncate very long error messages
      if (nchar(msg) > 300) msg <- paste0(substr(msg, 1, 300), "...")
      cat(red(paste0("  Error: ", msg, "\n")))
    }
  }
}

# ── Final report ─────────────────────────────────────────────────────────────

n_ok     <- sum(results$status == "OK")
n_failed <- sum(results$status == "FAILED")

cat(bold("\n--- Installation Summary ---\n"))
cat(sprintf("  Installed : %s\n", green(n_ok)))
cat(sprintf("  Failed    : %s\n", if (n_failed > 0) red(n_failed) else green(0)))

if (n_failed > 0) {
  cat(red("\nFailed packages:\n"))
  failed <- results[results$status == "FAILED", ]
  for (r in seq_len(nrow(failed))) {
    cat(sprintf("  %s", red(failed$package[r])))
    if (failed$package[r] %in% names(SYSTEM_DEP_HINTS)) {
      cat(" (system dependency required)")
    }
    cat("\n")
  }
  cat(yellow("\nTroubleshooting:\n"))
  cat("  1. Run: bash setup/check_system_deps.sh\n")
  cat("  2. Fix system dependencies, then re-run this script with --missing\n")
  cat("  3. For Windows: ensure Rtools is installed (https://cran.r-project.org/bin/windows/Rtools/)\n")
  cat("  4. For macOS: ensure Xcode CLI tools are installed (xcode-select --install)\n\n")
  quit(status = 1)
} else {
  cat(green("\nAll packages installed successfully!\n"))
  cat("Run 'Rscript setup/check_packages.R' to verify.\n\n")
  quit(status = 0)
}
