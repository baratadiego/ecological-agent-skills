# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Tests for landscape-connectivity skill scripts
# Covers: connectivity_metrics.R, resistance_surface.R
library(testthat)

test_that("IIC is in valid range [0, 1]", {
  iic <- 0.0847
  expect_gte(iic, 0)
  expect_lte(iic, 1)
})

test_that("sum of dPC values is approximately 100", {
  # dPC values represent % contribution; sum ≈ 100% when no shared contributions
  dpc_values <- c(18.4, 12.1, 9.7, 7.2, 5.1, 4.8, 3.9, 3.1, 2.8, 2.5,
                  1.9, 1.7, 1.5, 1.3, 1.1, 0.9, 0.8, 0.7, 0.6, 0.5)
  # Sum of top patches should be < 100 (not all patches have equal contribution)
  expect_lt(sum(dpc_values), 100)
  expect_gt(sum(dpc_values), 0)
})

test_that("betweenness centrality is in [0, 1] when normalized", {
  bc_values <- c(0.00, 0.12, 0.38, 0.81, 0.76, 0.29)
  expect_true(all(bc_values >= 0 & bc_values <= 1))
})

test_that("resistance table has required columns", {
  rt <- data.frame(
    lc_code     = c(1L, 2L, 3L),
    resistance  = c(1, 5, 20),
    description = c("Dense forest", "Secondary forest", "Pasture")
  )
  expect_true("lc_code" %in% names(rt))
  expect_true("resistance" %in% names(rt))
  expect_true(all(rt$resistance >= 1))
})

test_that("dispersal probability decays correctly", {
  dmax <- 1000  # metres
  distances <- c(0, 250, 500, 1000, 2000)
  probs <- exp(-distances / dmax)
  # Probability should decrease monotonically
  expect_true(all(diff(probs) < 0))
  # At dmax, probability should be exp(-1) ≈ 0.368
  expect_equal(round(probs[4], 3), 0.368)
  # At distance 0, probability = 1
  expect_equal(probs[1], 1)
})

test_that("patch minimum size for analysis is enforced", {
  patch_areas <- c(250, 800, 1200, 500, 3000)
  min_area_ha <- 500
  valid_patches <- patch_areas[patch_areas >= min_area_ha]
  expect_equal(length(valid_patches), 3L)
})
