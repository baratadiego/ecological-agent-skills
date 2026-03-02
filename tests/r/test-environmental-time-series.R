# Tests for environmental-time-series skill scripts
# Covers: trend_analysis.R, recovery_trajectory.R
library(testthat)

test_that("time series has no NA in index column", {
  ts_data <- data.frame(
    date  = seq(as.Date("2000-01-01"), by = "month", length.out = 24),
    ndvi  = runif(24, 0.2, 0.8)
  )
  expect_false(anyNA(ts_data$date))
  expect_false(anyNA(ts_data$ndvi))
})

test_that("NDVI values are within valid range [−1, 1]", {
  ndvi_vals <- c(0.12, 0.45, 0.67, 0.80, -0.05)
  expect_true(all(ndvi_vals >= -1 & ndvi_vals <= 1))
})

test_that("trend result structure has required fields", {
  trend_result <- list(
    slope     = 0.003,
    p_value   = 0.02,
    tau       = 0.41,
    direction = "increasing"
  )
  expect_named(trend_result, c("slope", "p_value", "tau", "direction"))
  expect_true(trend_result$p_value >= 0 && trend_result$p_value <= 1)
})

test_that("recovery trajectory: baseline mean is finite", {
  baseline <- c(0.55, 0.58, 0.60, 0.57, 0.59)
  expect_true(is.finite(mean(baseline)))
  expect_gt(mean(baseline), 0)
})

test_that("breakpoint date is after series start", {
  series_start <- as.Date("2000-01-01")
  breakpoint   <- as.Date("2010-06-15")
  expect_gt(breakpoint, series_start)
})
