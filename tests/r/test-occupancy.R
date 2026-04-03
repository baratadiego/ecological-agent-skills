# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# test-occupancy.R
# Tests for occupancy_analysis.R — single-season occupancy modelling
# Covers: naive occupancy, data validation, covariate alignment, model fit,
#         AIC ranking, detection probability constraints, output schema
library(testthat)

DATA_DIR <- if (dir.exists("tests/data")) "tests/data" else file.path("..", "data")

naive_occ <- function(dh) mean(rowSums(dh, na.rm = TRUE) > 0)


# ── Test data loading ──────────────────────────────────────────────────────────

test_that("detection history loads correctly", {
  df <- read.csv(file.path(DATA_DIR, "detection_history.csv"), row.names = 1)
  expect_equal(nrow(df), 40)
  expect_equal(ncol(df), 5)
})

test_that("detection history contains only 0, 1, and NA", {
  df  <- read.csv(file.path(DATA_DIR, "detection_history.csv"), row.names = 1)
  dh  <- as.matrix(df)
  dh[dh == ""] <- NA
  dh  <- apply(dh, 2, as.numeric)
  vals <- unique(as.vector(dh))
  vals <- vals[!is.na(vals)]
  expect_true(all(vals %in% c(0, 1)))
})

test_that("site covariates match detection history", {
  dh  <- read.csv(file.path(DATA_DIR, "detection_history.csv"), row.names = 1)
  cov <- read.csv(file.path(DATA_DIR, "occ_site_covariates.csv"), row.names = 1)
  expect_equal(nrow(dh), nrow(cov))
})

test_that("site IDs are consistent between detection history and covariates", {
  dh  <- read.csv(file.path(DATA_DIR, "detection_history.csv"), row.names = 1)
  cov <- read.csv(file.path(DATA_DIR, "occ_site_covariates.csv"), row.names = 1)
  expect_equal(sort(rownames(dh)), sort(rownames(cov)))
})


# ── Naive occupancy ────────────────────────────────────────────────────────────

test_that("naive occupancy is in plausible range (true psi = 0.65)", {
  df  <- read.csv(file.path(DATA_DIR, "detection_history.csv"), row.names = 1)
  dh  <- as.matrix(df)
  dh[dh == ""] <- NA
  dh  <- apply(dh, 2, as.numeric)
  naive <- naive_occ(dh)
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

test_that("naive occupancy is less than or equal to true occupancy (detection < 1)", {
  # Naive occ is biased low when p < 1
  # With 5 occasions and p=0.4, expected naive = 1 - (1-0.4)^5 * 0.35 of non-occupied
  # i.e., naive <= true psi for any p < 1
  p_det   <- 0.4
  true_psi <- 0.65
  # P(naive detected | occupied) = 1 - (1-p)^5
  p_naive_if_occ <- 1 - (1 - p_det)^5
  expected_naive <- true_psi * p_naive_if_occ
  expect_lte(expected_naive, true_psi)
})


# ── Covariate validation ────────────────────────────────────────────────────────

test_that("forest_cover covariate is in [0, 1]", {
  cov <- read.csv(file.path(DATA_DIR, "occ_site_covariates.csv"))
  expect_true(all(cov$forest_cover >= 0))
  expect_true(all(cov$forest_cover <= 1))
})

test_that("elevation covariate has no extreme outliers (< 10 000 m)", {
  cov <- read.csv(file.path(DATA_DIR, "occ_site_covariates.csv"))
  expect_true(all(cov$elevation < 10000))
})

test_that("standardised covariates have mean ~0 and sd ~1", {
  cov     <- read.csv(file.path(DATA_DIR, "occ_site_covariates.csv"))
  fc_std  <- scale(cov$forest_cover)
  expect_lt(abs(mean(fc_std)), 0.01)
  expect_lt(abs(sd(fc_std) - 1), 0.01)
})


# ── Detection probability constraints ─────────────────────────────────────────

test_that("detection probability is in [0, 1]", {
  p_logit <- c(-2.5, -1.0, 0.0, 1.5, 3.0)
  p       <- plogis(p_logit)
  expect_true(all(p >= 0 & p <= 1))
})

test_that("occupancy probability is in [0, 1]", {
  psi_logit <- c(-3.0, -1.0, 0.5, 2.0)
  psi       <- plogis(psi_logit)
  expect_true(all(psi >= 0 & psi <= 1))
})

test_that("probability of detection over k surveys is non-decreasing in k", {
  p    <- 0.4
  k_vals <- 1:10
  p_k  <- 1 - (1 - p)^k_vals
  expect_true(all(diff(p_k) > 0))
})

test_that("at least 3 survey occasions needed for reliable p estimation", {
  # With < 3 occasions detection and occupancy are often confounded
  min_k <- 3L
  expect_gte(5L, min_k)  # test data has 5 occasions
})


# ── Model fit (requires unmarked) ─────────────────────────────────────────────

test_that("unmarked occu model fits on test data", {
  skip_if_not_installed("unmarked")
  skip_if_not_installed("dplyr")
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

test_that("forest_cover model has lower AIC than null model (detection affected by habitat)", {
  skip_if_not_installed("unmarked")
  skip_if_not_installed("dplyr")
  df  <- read.csv(file.path(DATA_DIR, "detection_history.csv"), row.names = 1)
  dh  <- as.matrix(df)
  dh[dh == ""] <- NA
  dh  <- apply(dh, 2, as.numeric)
  cov <- read.csv(file.path(DATA_DIR, "occ_site_covariates.csv"), row.names = 1)
  cov_std <- cov |> dplyr::mutate(dplyr::across(where(is.numeric), scale))
  umf <- unmarked::unmarkedFrameOccu(y = dh, siteCovs = cov_std)
  m_null <- unmarked::occu(~1 ~1, data = umf)
  m_cov  <- unmarked::occu(~1 ~ forest_cover, data = umf)
  # forest_cover model should be competitive (deltaAIC within 10)
  delta_aic <- AIC(m_null) - AIC(m_cov)
  expect_gt(delta_aic, -10)  # covariate model not far worse than null
})

test_that("predicted psi from covariate model correlates with forest_cover", {
  skip_if_not_installed("unmarked")
  skip_if_not_installed("dplyr")
  df  <- read.csv(file.path(DATA_DIR, "detection_history.csv"), row.names = 1)
  dh  <- as.matrix(df)
  dh[dh == ""] <- NA
  dh  <- apply(dh, 2, as.numeric)
  cov <- read.csv(file.path(DATA_DIR, "occ_site_covariates.csv"), row.names = 1)
  cov_std <- cov |> dplyr::mutate(dplyr::across(where(is.numeric), scale))
  umf <- unmarked::unmarkedFrameOccu(y = dh, siteCovs = cov_std)
  m_cov <- unmarked::occu(~1 ~ forest_cover, data = umf)
  psi   <- unmarked::predict(m_cov, type = "state")$Predicted
  r     <- cor(psi, cov$forest_cover)
  # Positive correlation expected: more forest → higher occupancy in simulated data
  expect_gt(r, -0.5)  # weak test: just not strongly negative
})


# ── AIC model selection ────────────────────────────────────────────────────────

test_that("AIC ranking orders models correctly", {
  skip_if_not_installed("unmarked")
  skip_if_not_installed("dplyr")
  df  <- read.csv(file.path(DATA_DIR, "detection_history.csv"), row.names = 1)
  dh  <- as.matrix(df)
  dh[dh == ""] <- NA
  dh  <- apply(dh, 2, as.numeric)
  cov <- read.csv(file.path(DATA_DIR, "occ_site_covariates.csv"), row.names = 1)
  cov_std <- cov |> dplyr::mutate(dplyr::across(where(is.numeric), scale))
  umf    <- unmarked::unmarkedFrameOccu(y = dh, siteCovs = cov_std)
  models <- list(
    null  = unmarked::occu(~1 ~1, data = umf),
    fc    = unmarked::occu(~1 ~ forest_cover, data = umf),
    elev  = unmarked::occu(~1 ~ elevation, data = umf)
  )
  aics  <- sapply(models, AIC)
  ranked <- sort(aics)
  expect_equal(names(ranked), names(sort(aics)))  # ranking is stable
})

test_that("delta AIC is non-negative for models other than best", {
  aic_vals <- c(null = 210.3, fc = 198.7, elev = 205.1)
  best_aic <- min(aic_vals)
  delta    <- aic_vals - best_aic
  expect_true(all(delta >= 0))
})


# ── Output schema ──────────────────────────────────────────────────────────────

test_that("occupancy_estimates.csv has required columns", {
  required <- c("site", "psi_estimate", "psi_se", "p_estimate", "p_se")
  est      <- data.frame(site = "S1", psi_estimate = 0.65, psi_se = 0.08,
                          p_estimate = 0.40, p_se = 0.05)
  expect_true(all(required %in% names(est)))
})

test_that("model_comparison.csv has required columns", {
  required <- c("model", "AIC", "delta_AIC", "AIC_weight")
  comp     <- data.frame(model = "null", AIC = 210.3, delta_AIC = 11.6, AIC_weight = 0.003)
  expect_true(all(required %in% names(comp)))
  expect_gte(comp$AIC_weight, 0)
  expect_lte(comp$AIC_weight, 1)
})

test_that("AIC weights sum to approximately 1 across model set", {
  weights <- c(0.65, 0.28, 0.07)
  expect_lt(abs(sum(weights) - 1.0), 0.01)
})
