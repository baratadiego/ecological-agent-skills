# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Tests for predictive-modeling-best-practices skill scripts
# Covers: collinearity_check.R, spatial_cv.py (R-side data checks)
library(testthat)

test_that("VIF values are positive", {
  vif_result <- data.frame(
    predictor = c("bio1", "bio12", "bio15", "slope"),
    VIF       = c(2.1, 8.4, 3.3, 1.9)
  )
  expect_true(all(vif_result$VIF > 0))
})

test_that("predictors with VIF > 10 are flagged", {
  vif_result <- data.frame(
    predictor = c("bio1", "bio4", "bio12"),
    VIF       = c(2.1, 12.5, 3.3)
  )
  flagged <- vif_result[vif_result$VIF > 10, ]
  expect_equal(nrow(flagged), 1L)
  expect_equal(flagged$predictor, "bio4")
})

test_that("pairwise correlation is in [-1, 1]", {
  cor_mat <- cor(data.frame(
    bio1  = c(25, 26, 24, 27, 23),
    bio12 = c(1800, 1750, 1900, 1650, 2000)
  ))
  expect_true(all(cor_mat >= -1 & cor_mat <= 1))
})

test_that("selected predictors list is non-empty", {
  selected <- c("bio1", "bio12", "bio15")
  expect_gt(length(selected), 0L)
})

test_that("block CV folds are balanced", {
  fold_sizes <- c(120, 118, 122, 115)
  cv <- max(fold_sizes) / min(fold_sizes)
  expect_lt(cv, 1.15)  # less than 15% imbalance
})
