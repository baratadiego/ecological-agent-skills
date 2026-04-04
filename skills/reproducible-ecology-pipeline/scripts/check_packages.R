# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript check_packages.R [--install]
# Validate that all R packages required by ecological-agent-skills are installed
# and meet minimum version requirements. Pass --install to auto-install missing packages.

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "reproducible-ecology-pipeline"
.log_ts   <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info  <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn  <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error <- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step  <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive = TRUE, showWarnings = FALSE)

suppressPackageStartupMessages(library(utils))

log_info("Script: check_packages.R | Skill: %s", SKILL_NAME)
log_info("R version: %s", R.version.string)

# ── Parse arguments ────────────────────────────────────────────────────────────
args        <- commandArgs(trailingOnly = TRUE)
auto_install <- "--install" %in% args
log_decision("auto_install", auto_install,
             if (auto_install) "passed --install flag; missing packages will be installed"
             else "no --install flag; missing packages will be reported only")

# ── Package requirements ───────────────────────────────────────────────────────
# Format: list(package = "name", min_version = "x.y.z", skill = "skill-id", cran = TRUE/FALSE)
requirements <- list(

  # ── Core spatial / raster ──────────────────────────────────────────────────
  list(package = "terra",            min_version = "1.7.0",  skill = "geoprocessing-for-ecology",          cran = TRUE),
  list(package = "sf",               min_version = "1.0.0",  skill = "geoprocessing-for-ecology",          cran = TRUE),
  list(package = "geodata",          min_version = "0.5.0",  skill = "geoprocessing-for-ecology",          cran = TRUE),

  # ── Occurrence data ────────────────────────────────────────────────────────
  list(package = "CoordinateCleaner",min_version = "2.0.20", skill = "ecological-data-foundation",         cran = TRUE),
  list(package = "rgbif",            min_version = "3.7.0",  skill = "ecological-data-foundation",         cran = TRUE),
  list(package = "auk",              min_version = "0.6.0",  skill = "ecological-data-foundation",         cran = TRUE),

  # ── SDM ───────────────────────────────────────────────────────────────────
  list(package = "maxnet",           min_version = "0.1.4",  skill = "species-distribution-modeling",      cran = TRUE),
  list(package = "ENMeval",          min_version = "2.0.0",  skill = "species-distribution-modeling",      cran = TRUE),
  list(package = "blockCV",          min_version = "3.1.0",  skill = "species-distribution-modeling",      cran = TRUE),
  list(package = "gbm",              min_version = "2.1.8",  skill = "species-distribution-modeling",      cran = TRUE),
  list(package = "randomForest",     min_version = "4.7.0",  skill = "species-distribution-modeling",      cran = TRUE),
  list(package = "dismo",            min_version = "1.3.14", skill = "species-distribution-modeling",      cran = TRUE),

  # ── Occupancy ─────────────────────────────────────────────────────────────
  list(package = "unmarked",         min_version = "1.3.0",  skill = "occupancy-and-detection",            cran = TRUE),

  # ── Camera traps ──────────────────────────────────────────────────────────
  list(package = "camtrapR",         min_version = "2.2.0",  skill = "camera-trap-processing",             cran = TRUE),
  list(package = "overlap",          min_version = "0.3.4",  skill = "camera-trap-processing",             cran = TRUE),

  # ── Conservation prioritization ───────────────────────────────────────────
  list(package = "prioritizr",       min_version = "8.0.0",  skill = "spatial-prioritization",             cran = TRUE),

  # ── Population viability analysis ────────────────────────────────────────
  list(package = "popbio",           min_version = "2.7",    skill = "population-viability-analysis",      cran = TRUE),

  # ── Landscape connectivity ────────────────────────────────────────────────
  list(package = "gdistance",        min_version = "1.6.4",  skill = "landscape-connectivity",             cran = TRUE),
  list(package = "igraph",           min_version = "1.5.0",  skill = "landscape-connectivity",             cran = TRUE),

  # ── Statistics and modelling ──────────────────────────────────────────────
  list(package = "lme4",             min_version = "1.1.30", skill = "biostatistics-workbench",            cran = TRUE),
  list(package = "MuMIn",            min_version = "1.47.5", skill = "biostatistics-workbench",            cran = TRUE),
  list(package = "car",              min_version = "3.1.0",  skill = "biostatistics-workbench",            cran = TRUE),

  # ── Community ecology ─────────────────────────────────────────────────────
  list(package = "vegan",            min_version = "2.6.0",  skill = "community-ecology-ordination",       cran = TRUE),

  # ── Time series ───────────────────────────────────────────────────────────
  list(package = "forecast",         min_version = "8.21",   skill = "environmental-time-series",          cran = TRUE),
  list(package = "strucchange",      min_version = "1.5.3",  skill = "environmental-time-series",          cran = TRUE),
  list(package = "changepoint",      min_version = "2.2.4",  skill = "environmental-time-series",          cran = TRUE),
  list(package = "zoo",              min_version = "1.8.11", skill = "environmental-time-series",          cran = TRUE),

  # ── Acoustic monitoring ───────────────────────────────────────────────────
  list(package = "soundecology",     min_version = "1.3.3",  skill = "acoustic-monitoring",                cran = TRUE),
  list(package = "tuneR",            min_version = "1.4.6",  skill = "acoustic-monitoring",                cran = TRUE),
  list(package = "seewave",          min_version = "2.2.3",  skill = "acoustic-monitoring",                cran = TRUE),

  # ── Utilities ────────────────────────────────────────────────────────────
  list(package = "yaml",             min_version = "2.3.7",  skill = "all",                                cran = TRUE),
  list(package = "dplyr",            min_version = "1.1.0",  skill = "all",                                cran = TRUE),
  list(package = "ggplot2",          min_version = "3.4.0",  skill = "all",                                cran = TRUE),
  list(package = "readr",            min_version = "2.1.4",  skill = "all",                                cran = TRUE)
)

# ── Version comparison helper ─────────────────────────────────────────────────
version_ok <- function(installed, required) {
  if (is.na(installed) || installed == "") return(FALSE)
  tryCatch(
    utils::compareVersion(as.character(installed), as.character(required)) >= 0,
    error = function(e) FALSE
  )
}

# ── Check loop ────────────────────────────────────────────────────────────────
log_step(1, "Check all required packages")

results <- lapply(requirements, function(req) {
  pkg      <- req$package
  min_ver  <- req$min_version
  skill    <- req$skill

  installed_ver <- tryCatch(
    as.character(utils::packageVersion(pkg)),
    error = function(e) NA_character_
  )

  status <- if (is.na(installed_ver)) {
    "MISSING"
  } else if (!version_ok(installed_ver, min_ver)) {
    "OUTDATED"
  } else {
    "OK"
  }

  list(package = pkg, required = min_ver, installed = installed_ver %||% "not installed",
       status = status, skill = skill)
})

# ── Null-coalescing helper ────────────────────────────────────────────────────
`%||%` <- function(a, b) if (!is.null(a) && !is.na(a)) a else b

# ── Report ────────────────────────────────────────────────────────────────────
log_step(2, "Generate package status report")

ok_pkgs      <- Filter(function(r) r$status == "OK",       results)
missing_pkgs <- Filter(function(r) r$status == "MISSING",  results)
outdated_pkgs<- Filter(function(r) r$status == "OUTDATED", results)

log_info("========== PACKAGE CHECK REPORT ==========")
log_info("Total packages checked : %d", length(results))
log_info("OK                     : %d", length(ok_pkgs))
log_info("Missing                : %d", length(missing_pkgs))
log_info("Outdated               : %d", length(outdated_pkgs))
log_info("==========================================")

if (length(ok_pkgs) > 0) {
  log_info("--- OK packages ---")
  for (r in ok_pkgs)
    log_info("  [OK]       %-25s %s (required >= %s | skill: %s)",
             r$package, r$installed, r$required, r$skill)
}

if (length(outdated_pkgs) > 0) {
  log_warn("--- OUTDATED packages ---")
  for (r in outdated_pkgs)
    log_warn("  [OUTDATED] %-25s installed %s | required >= %s | skill: %s",
             r$package, r$installed, r$required, r$skill)
}

if (length(missing_pkgs) > 0) {
  log_error("--- MISSING packages ---")
  for (r in missing_pkgs)
    log_error("  [MISSING]  %-25s required >= %s | skill: %s",
              r$package, r$required, r$skill)
}

# ── Auto-install ───────────────────────────────────────────────────────────────
to_install <- c(
  sapply(missing_pkgs,  function(r) r$package),
  sapply(outdated_pkgs, function(r) r$package)
)

if (length(to_install) > 0 && auto_install) {
  log_step(3, sprintf("Install/update %d package(s)", length(to_install)))
  log_decision("install_method", "install.packages (CRAN)",
               "all required packages are available on CRAN")

  for (pkg in to_install) {
    log_info("Installing: %s ...", pkg)
    tryCatch({
      utils::install.packages(pkg, repos = "https://cloud.r-project.org", quiet = TRUE)
      new_ver <- as.character(utils::packageVersion(pkg))
      log_info("  Installed %s %s", pkg, new_ver)
    }, error = function(e) {
      log_error("  Failed to install %s: %s\nProbable cause: network error, package not on CRAN, or compilation failure.\nCheck: internet connection and available system libraries.", pkg, conditionMessage(e))
    })
  }

  log_step(4, "Re-check after installation")
  re_results <- lapply(to_install, function(pkg) {
    ver <- tryCatch(as.character(utils::packageVersion(pkg)), error = function(e) NA_character_)
    req <- Filter(function(r) r$package == pkg, requirements)[[1]]
    ok  <- !is.na(ver) && version_ok(ver, req$min_version)
    log_info("  %-25s %s", pkg, if (ok) paste0("[OK] ", ver) else "[STILL FAILING]")
  })

} else if (length(to_install) > 0 && !auto_install) {
  log_warn("Run with --install flag to auto-install missing/outdated packages:")
  log_warn("  Rscript check_packages.R --install")
  log_warn("Or install manually in R:")
  log_warn("  install.packages(c(%s))",
           paste0('"', to_install, '"', collapse = ", "))
}

# ── Exit code ─────────────────────────────────────────────────────────────────
n_problems <- length(missing_pkgs) + length(outdated_pkgs)
if (n_problems == 0) {
  log_info("All packages OK. Environment is ready for ecological-agent-skills.")
  quit(status = 0)
} else {
  log_error(
    "%d package problem(s) detected. Resolve before running skills.\nProbable cause: fresh R installation or package updates broke compatibility.\nRun: Rscript check_packages.R --install\nPrevious skill: [none]",
    n_problems
  )
  quit(status = 1)
}
