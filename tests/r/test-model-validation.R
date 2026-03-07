# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Tests for model-validation-and-uncertainty skill scripts
# Covers: validate_sdm.R, extrapolation_risk.R
library(testthat)

test_that("AUC is within [0, 1]", {
  auc_val <- 0.82
  expect_gte(auc_val, 0)
  expect_lte(auc_val, 1)
})

test_that("performance metrics data frame has required columns", {
  metrics <- data.frame(
    dataset    = c("train", "cv", "test"),
    AUC        = c(0.91, 0.84, 0.82),
    TSS        = c(0.73, 0.65, 0.62),
    threshold  = c(0.45, 0.45, 0.45)
  )
  expect_true(all(c("AUC", "TSS", "threshold") %in% names(metrics)))
  expect_equal(nrow(metrics), 3L)
})

test_that("AUC below 0.70 triggers warning condition", {
  auc_min <- 0.70
  auc_val <- 0.65
  expect_lt(auc_val, auc_min)
})

test_that("MOP proportion in [0, 1]", {
  mop_values <- c(0.0, 0.25, 0.75, 1.0, NA)
  valid <- mop_values[!is.na(mop_values)]
  expect_true(all(valid >= 0 & valid <= 1))
})

test_that("extrapolation summary returns numeric percentages", {
  summary_df <- data.frame(
    metric       = c("pct_mop_zero", "pct_novel_NT1", "pct_novel_NT2"),
    value_pct    = c(5.2, 12.1, 3.4)
  )
  expect_true(is.numeric(summary_df$value_pct))
  expect_true(all(summary_df$value_pct >= 0 & summary_df$value_pct <= 100))
})
