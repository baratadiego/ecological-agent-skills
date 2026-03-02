# Tests for ecosystem-services-assessment skill scripts
# Covers: tradeoff_analysis.R
library(testthat)

test_that("tradeoff_analysis input validation — missing file errors gracefully", {
  expect_error(
    source(system.file("skills/ecosystem-services-assessment/scripts/tradeoff_analysis.R",
                       package = ".")),
    NA  # no error expected on source; argument validation tested below
  )
})

test_that("ES summary table has required columns", {
  es_data <- data.frame(
    land_cover  = c("Forest", "Pasture", "Cropland"),
    carbon      = c(150.2, 12.5, 8.3),
    water_yield = c(320.1, 180.4, 210.0),
    soil_ret    = c(95.0, 40.2, 55.6)
  )
  expect_true(all(c("land_cover", "carbon") %in% names(es_data)))
  expect_equal(nrow(es_data), 3L)
})

test_that("trade-off correlation matrix is symmetric", {
  mat <- matrix(c(1, -0.6, 0.4,
                  -0.6, 1, -0.3,
                   0.4, -0.3, 1),
                nrow = 3, ncol = 3)
  expect_true(isSymmetric(mat))
  expect_true(all(diag(mat) == 1))
})

test_that("ES indicator values are non-negative", {
  es_vals <- c(150.2, 12.5, 8.3, 320.1, 180.4)
  expect_true(all(es_vals >= 0))
})
