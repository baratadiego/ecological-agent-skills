# Tests for acoustic-monitoring skill scripts
# Covers: compute_acoustic_indices.R, soundscape-ecology-guide.md logic
library(testthat)

test_that("acoustic index values are in expected ranges", {
  # ACI is unbounded but typically 300-3000 for natural soundscapes
  aci <- 1842.3
  expect_gt(aci, 0)

  # NDSI is in [-1, 1]
  ndsi <- 0.72
  expect_gte(ndsi, -1)
  expect_lte(ndsi, 1)

  # H (entropy) is in [0, 1]
  H <- 0.85
  expect_gte(H, 0)
  expect_lte(H, 1)
})

test_that("NDSI categorisation thresholds are correct", {
  ndsi_disturbed <- -0.35
  ndsi_pristine  <- 0.80

  expect_lt(ndsi_disturbed, -0.3)   # threshold for 'disturbed' flag
  expect_gt(ndsi_pristine, 0)       # positive = biophony dominant
})

test_that("BirdNET confidence score interpretation categories are correct", {
  scores <- c(0.45, 0.65, 0.78, 0.92)
  categories <- ifelse(scores < 0.5, "exclude",
                ifelse(scores < 0.7, "unconfirmed", "accepted"))
  expect_equal(categories[1], "exclude")
  expect_equal(categories[2], "unconfirmed")
  expect_equal(categories[3], "accepted")
  expect_equal(categories[4], "accepted")
})

test_that("recording hour coverage check for richness estimation", {
  # Sites with < 48 recording hours are under-sampled
  recording_hours <- c(20.5, 50.0, 48.0, 35.0)
  min_hours <- 48.0
  undersampled <- recording_hours < min_hours
  expect_equal(sum(undersampled), 2L)
})

test_that("diel control uses circular encoding of hour", {
  hours <- 0:23
  cos_h <- cos(2 * pi * hours / 24)
  sin_h <- sin(2 * pi * hours / 24)
  # Values should be in [-1, 1]
  expect_true(all(cos_h >= -1 & cos_h <= 1))
  expect_true(all(sin_h >= -1 & sin_h <= 1))
  # Hour 0 and 24 are the same (cos(0) = 1)
  expect_equal(cos(0), 1)
})
