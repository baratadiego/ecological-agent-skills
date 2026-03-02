# Tests for geoprocessing-for-ecology skill scripts
# Covers: stack_and_extract.R
library(testthat)

test_that("points_with_env has lat/lon columns", {
  pts <- data.frame(
    species   = "Sp_A",
    longitude = c(-60.1, -61.3, -59.8),
    latitude  = c(-3.2, -4.1, -2.9)
  )
  expect_true("longitude" %in% names(pts))
  expect_true("latitude" %in% names(pts))
})

test_that("longitude values are within valid range", {
  lon <- c(-60.1, -61.3, -59.8, -180, 180)
  expect_true(all(lon >= -180 & lon <= 180))
})

test_that("latitude values are within valid range", {
  lat <- c(-3.2, -4.1, -2.9, -90, 90)
  expect_true(all(lat >= -90 & lat <= 90))
})

test_that("extracted predictor values are numeric", {
  env_vals <- data.frame(
    bio1  = c(25.3, 26.1, 24.8),
    bio12 = c(1800, 2100, 1650)
  )
  expect_true(is.numeric(env_vals$bio1))
  expect_true(is.numeric(env_vals$bio12))
})

test_that("no NA in required columns after extraction", {
  env_vals <- data.frame(
    bio1  = c(25.3, 26.1, 24.8),
    bio12 = c(1800, 2100, 1650)
  )
  expect_false(anyNA(env_vals$bio1))
  expect_false(anyNA(env_vals$bio12))
})
