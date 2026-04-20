#!/usr/bin/env Rscript
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later
#
# verify_env.R — Functional smoke test for the R geospatial stack.
#
# Goes beyond "library(x) succeeds" and actually exercises the native
# GDAL/GEOS/PROJ bindings that commonly mismatch on conda envs, Rtools,
# and Homebrew. A green run means terra + sf can read, reproject, and
# write real data end-to-end.
#
# Exit codes:
#   0 — all checks passed
#   1 — at least one check failed (details printed)

suppressPackageStartupMessages({
  # no-op — we import per-check so missing packages report individually
})

results <- list()

record <- function(name, ok, detail = "") {
  status <- if (isTRUE(ok)) "PASS" else "FAIL"
  msg <- if (nzchar(detail)) sprintf("  [%s] %s — %s", status, name, detail)
         else                 sprintf("  [%s] %s", status, name)
  message(msg)
  results[[length(results) + 1L]] <<- list(name = name, ok = isTRUE(ok), detail = detail)
}

try_require <- function(pkg) {
  ok <- suppressWarnings(suppressMessages(
    requireNamespace(pkg, quietly = TRUE)
  ))
  if (!ok) {
    record(sprintf("library(%s)", pkg), FALSE, "package not installed")
    return(FALSE)
  }
  ver <- tryCatch(as.character(packageVersion(pkg)), error = function(e) "?")
  record(sprintf("library(%s)", pkg), TRUE, sprintf("v%s", ver))
  TRUE
}

`%||%` <- function(a, b) if (!is.null(a) && nzchar(a)) a else b

# Locate the repo root across invocation modes (Rscript, source(), R CMD BATCH).
script_path <- tryCatch({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
  if (length(file_arg) == 1L && nzchar(file_arg)) {
    normalizePath(file_arg, mustWork = FALSE)
  } else if (!is.null(sys.frame(1)$ofile)) {
    normalizePath(sys.frame(1)$ofile, mustWork = FALSE)
  } else {
    ""
  }
}, error = function(e) "")

repo_root <- if (nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
} else {
  getwd()
}
if (!dir.exists(file.path(repo_root, "tests"))) {
  repo_root <- getwd()
}

fixture_tif <- file.path(repo_root, "tests", "data", "rasters", "bio1.tif")

message("=== R geospatial smoke test ===")
message(sprintf("  R:        %s", R.version.string))
message(sprintf("  platform: %s", R.version$platform))
message("")

message("--- Imports ---")
have_terra <- try_require("terra")
have_sf    <- try_require("sf")
have_units <- try_require("units")
message("")

message("--- Functional checks ---")

# -- terra: create + reproject --------------------------------------------
if (have_terra) {
  ok <- tryCatch({
    if (!file.exists(fixture_tif)) {
      record(
        "terra read + reproject",
        FALSE,
        sprintf("fixture missing: %s",
                sub(paste0("^", repo_root, "/?"), "", fixture_tif))
      )
    } else {
      r  <- terra::rast(fixture_tif)
      r2 <- terra::project(r, "EPSG:4326", method = "bilinear")
      vals <- terra::values(r2)
      n_valid <- sum(!is.na(vals))
      record(
        "terra read + reproject",
        TRUE,
        sprintf("source EPSG:%s -> 4326, %d valid cells",
                terra::crs(r, describe = TRUE)$code, n_valid)
      )
    }
    TRUE
  }, error = function(e) {
    record("terra read + reproject", FALSE, conditionMessage(e))
    FALSE
  })
} else {
  record("terra read + reproject", FALSE, "terra not available")
}

# -- sf: vector round-trip ------------------------------------------------
if (have_sf) {
  tryCatch({
    pts <- sf::st_as_sf(
      data.frame(id = 1:3, x = c(-47.9, -46.6, -48.4), y = c(-15.8, -23.6, -22.9)),
      coords = c("x", "y"),
      crs    = 4326
    )
    projected <- sf::st_transform(pts, 3857)
    tmp <- tempfile(fileext = ".gpkg")
    sf::st_write(projected, tmp, quiet = TRUE)
    back <- sf::st_read(tmp, quiet = TRUE)
    ok <- nrow(back) == 3L && sf::st_crs(back)$epsg == 3857L
    unlink(tmp)
    record(
      "sf reproject + GPKG I/O",
      ok,
      sprintf("3 points round-tripped (EPSG:%s)", sf::st_crs(back)$epsg)
    )
  }, error = function(e) {
    record("sf reproject + GPKG I/O", FALSE, conditionMessage(e))
  })
} else {
  record("sf reproject + GPKG I/O", FALSE, "sf not available")
}

# -- GEOS via sf ----------------------------------------------------------
if (have_sf) {
  tryCatch({
    a <- sf::st_polygon(list(rbind(c(0,0), c(10,0), c(10,10), c(0,10), c(0,0))))
    b <- sf::st_buffer(sf::st_point(c(5, 5)), dist = 2)
    inter <- sf::st_intersection(a, b)
    area  <- as.numeric(sf::st_area(inter))
    record(
      "sf GEOS ops",
      area > 0,
      sprintf("intersection area=%.2f", area)
    )
  }, error = function(e) {
    record("sf GEOS ops", FALSE, conditionMessage(e))
  })
}

# -- PROJ version ---------------------------------------------------------
if (have_sf) {
  tryCatch({
    pv <- sf::sf_extSoftVersion()
    record(
      "PROJ/GEOS/GDAL versions",
      TRUE,
      sprintf("GDAL %s, GEOS %s, PROJ %s",
              pv["GDAL"], pv["GEOS"], pv["PROJ"])
    )
  }, error = function(e) {
    record("PROJ/GEOS/GDAL versions", FALSE, conditionMessage(e))
  })
}

message("")

passed <- sum(vapply(results, function(r) r$ok, logical(1L)))
total  <- length(results)
failed <- total - passed

message(sprintf("=== Summary: %d/%d passed, %d failed ===", passed, total, failed))

if (failed > 0L) {
  message("")
  message("Failed checks:")
  for (r in results) {
    if (!r$ok) message(sprintf("  - %s: %s", r$name, r$detail))
  }
  quit(status = 1L)
}
quit(status = 0L)
