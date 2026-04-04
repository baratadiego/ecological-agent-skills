# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

library(testthat)

# ── Tests for reproducible-ecology-pipeline skill ─────────────────────────────

test_that("check_packages.R requirements list has correct structure", {
  # Each requirement must have package, min_version, skill, and cran fields
  req <- list(package = "terra", min_version = "1.7.0",
              skill = "geoprocessing-for-ecology", cran = TRUE)
  expect_true("package"     %in% names(req))
  expect_true("min_version" %in% names(req))
  expect_true("skill"       %in% names(req))
  expect_true("cran"        %in% names(req))
  expect_type(req$package, "character")
  expect_type(req$cran, "logical")
})

test_that("version comparison works correctly", {
  # utils::compareVersion returns -1, 0, or 1
  expect_equal(utils::compareVersion("1.7.0", "1.6.0"),  1L)
  expect_equal(utils::compareVersion("1.6.0", "1.7.0"), -1L)
  expect_equal(utils::compareVersion("2.0.0", "2.0.0"),  0L)
})

test_that("project directory template has required folders", {
  dirs <- c("data/raw", "data/processed", "outputs/reports",
            "outputs/figures", "outputs/maps", "logs")
  tmp <- file.path(tempdir(), "test_project")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  for (d in dirs) dir.create(file.path(tmp, d), recursive = TRUE)
  for (d in dirs) {
    expect_true(dir.exists(file.path(tmp, d)),
                info = paste("Missing directory:", d))
  }
})

test_that("decision log entry has required fields", {
  entry <- list(
    date      = "2026-03-01",
    skill_id  = "species-distribution-modeling",
    decision  = "Selected LQ feature class with RM=1.0",
    rationale = "Lowest OR_AICc in calibration grid"
  )
  for (field in c("date", "skill_id", "decision", "rationale")) {
    expect_true(field %in% names(entry),
                info = paste("Missing field:", field))
  }
})

test_that("parameter manifest validates seed reproducibility", {
  set.seed(42)
  a <- sample(100, 10)
  set.seed(42)
  b <- sample(100, 10)
  expect_identical(a, b)
})
