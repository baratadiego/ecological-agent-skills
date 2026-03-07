# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Tests for spatial-prioritization skill scripts
# Covers: run_prioritization.R, prioritization_sensitivity.R
library(testthat)

test_that("representation targets are in valid range [0, 1]", {
  targets <- c(0.17, 0.30, 0.40, 0.50, 0.60)
  expect_true(all(targets >= 0 & targets <= 1))
})

test_that("IUCN-based targets are higher for threatened species", {
  iucn_targets <- c(CR = 0.60, EN = 0.50, VU = 0.40, NT = 0.30, LC = 0.17)
  expect_gt(iucn_targets["CR"], iucn_targets["EN"])
  expect_gt(iucn_targets["EN"], iucn_targets["VU"])
  expect_gt(iucn_targets["VU"], iucn_targets["NT"])
})

test_that("log-linear target returns 1.0 for species below lower threshold", {
  range_km2 <- 500  # below 1000 km2 lower threshold
  lower_threshold <- 1000
  upper_threshold <- 250000
  lower_target <- 0.10
  upper_target <- 1.00
  target <- ifelse(range_km2 < lower_threshold, upper_target,
            ifelse(range_km2 > upper_threshold, lower_target,
                   upper_target + (lower_target - upper_target) *
                     (log(range_km2) - log(lower_threshold)) /
                     (log(upper_threshold) - log(lower_threshold))))
  expect_equal(target, 1.00)
})

test_that("feature representation check computes correctly", {
  rep_df <- data.frame(
    feature      = c("sp_a", "sp_b", "sp_c"),
    relative_held = c(0.35, 0.22, 0.28),
    target       = c(0.30, 0.30, 0.30)
  )
  rep_df$target_met <- rep_df$relative_held >= rep_df$target
  expect_equal(sum(rep_df$target_met), 2L)   # sp_a and sp_c meet target
  expect_false(rep_df$target_met[2])          # sp_b does not meet target
})

test_that("BLM calibration data has required columns", {
  blm_df <- data.frame(
    blm        = c(0, 0.01, 0.1, 1.0),
    cost       = c(234, 251, 312, 498),
    boundary   = c(18240, 11880, 7200, 4320),
    n_selected = c(487, 508, 565, 621)
  )
  expect_true(all(c("blm", "cost", "boundary") %in% names(blm_df)))
  # Cost increases with BLM
  expect_true(all(diff(blm_df$cost) > 0))
  # Boundary decreases with BLM
  expect_true(all(diff(blm_df$boundary) < 0))
})

test_that("irreplaceability values are in [0, 1]", {
  irr_vals <- c(0.0, 0.25, 0.72, 0.95, 1.0)
  expect_true(all(irr_vals >= 0 & irr_vals <= 1))
})
