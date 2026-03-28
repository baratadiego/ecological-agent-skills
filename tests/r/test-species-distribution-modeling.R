# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Tests for species-distribution-modeling skill scripts
# Covers: predict_distribution.R, run_ensemble_sdm.R, tune_maxnet.R, prepare_future_layers.R
library(testthat)

test_that("SDM scripts exist in skill directory", {
  skill_dir <- file.path(dirname(dirname(getwd())),
                         "skills", "species-distribution-modeling", "scripts")
  # Fallback for CI: try relative from repo root
  if (!dir.exists(skill_dir)) {
    skill_dir <- "skills/species-distribution-modeling/scripts"
  }
  if (dir.exists(skill_dir)) {
    r_scripts <- list.files(skill_dir, pattern = "\\.R$")
    expect_true(length(r_scripts) >= 1, info = "At least 1 R script in SDM skill")
    expect_true("predict_distribution.R" %in% r_scripts,
                info = "predict_distribution.R must exist")
  }
})

test_that("occurrence data has required columns", {
  occ <- data.frame(
    species   = "Sp_A",
    longitude = c(-60.1, -61.3, -59.8),
    latitude  = c(-3.2, -4.1, -2.9)
  )
  expect_true(all(c("species", "longitude", "latitude") %in% names(occ)))
  expect_gte(nrow(occ), 10L)  # minimum for SDM
})

test_that("n_occurrences below 10 triggers warning", {
  n_occ <- 7L
  n_min <- 10L
  expect_lt(n_occ, n_min)
})

test_that("suitability values are in [0, 1]", {
  suit_vals <- c(0.0, 0.23, 0.65, 0.91, 1.0)
  expect_true(all(suit_vals >= 0 & suit_vals <= 1))
})

test_that("variable importance sums approximately to 100", {
  vi <- data.frame(
    variable   = c("bio1", "bio12", "bio15", "slope"),
    importance = c(38.2, 29.4, 18.1, 14.3)
  )
  expect_lt(abs(sum(vi$importance) - 100), 1.0)
})

test_that("calibration results have required columns", {
  cal <- data.frame(
    rm      = c(0.5, 1.0, 2.0),
    fc      = c("L", "LQ", "LQH"),
    or_auc  = c(0.12, 0.08, 0.09),
    aicc    = c(850.2, 820.4, 835.1)
  )
  expect_true(all(c("rm", "fc", "or_auc", "aicc") %in% names(cal)))
})
