# test-occupancy.R
library(testthat)

DATA_DIR <- if (dir.exists("tests/data")) "tests/data" else file.path("..", "data")

naive_occ <- function(dh) mean(rowSums(dh, na.rm = TRUE) > 0)

test_that("detection history loads correctly", {
  df <- read.csv(file.path(DATA_DIR, "detection_history.csv"), row.names = 1)
  expect_equal(nrow(df), 40)
  expect_equal(ncol(df), 5)
})

test_that("naive occupancy is in plausible range", {
  df <- read.csv(file.path(DATA_DIR, "detection_history.csv"), row.names = 1)
  dh <- as.matrix(df)
  dh[dh == ""] <- NA
  dh <- apply(dh, 2, as.numeric)
  naive <- naive_occ(dh)
  # Generated with true psi = 0.65
  expect_gt(naive, 0.35)
  expect_lt(naive, 0.90)
})

test_that("naive occupancy is 1 when all sites detected", {
  dh <- matrix(1, nrow = 10, ncol = 3)
  expect_equal(naive_occ(dh), 1.0)
})

test_that("naive occupancy is 0 when no sites detected", {
  dh <- matrix(0, nrow = 10, ncol = 3)
  expect_equal(naive_occ(dh), 0.0)
})

test_that("site covariates match detection history", {
  dh  <- read.csv(file.path(DATA_DIR, "detection_history.csv"), row.names = 1)
  cov <- read.csv(file.path(DATA_DIR, "occ_site_covariates.csv"), row.names = 1)
  expect_equal(nrow(dh), nrow(cov))
})

test_that("forest_cover covariate is in [0,1]", {
  cov <- read.csv(file.path(DATA_DIR, "occ_site_covariates.csv"))
  expect_true(all(cov$forest_cover >= 0))
  expect_true(all(cov$forest_cover <= 1))
})

test_that("unmarked occu model fits on test data", {
  skip_if_not_installed("unmarked")
  df  <- read.csv(file.path(DATA_DIR, "detection_history.csv"), row.names = 1)
  dh  <- as.matrix(df)
  dh[dh == ""] <- NA
  dh  <- apply(dh, 2, as.numeric)
  cov <- read.csv(file.path(DATA_DIR, "occ_site_covariates.csv"), row.names = 1)
  cov_std <- cov |> dplyr::mutate(dplyr::across(where(is.numeric), scale))
  umf <- unmarked::unmarkedFrameOccu(y = dh, siteCovs = cov_std)
  m0  <- unmarked::occu(~1 ~1, data = umf)
  psi <- unmarked::predict(m0, type = "state")$Predicted
  expect_gt(mean(psi), 0.2)
  expect_lt(mean(psi), 0.95)
})
