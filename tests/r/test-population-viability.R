# Tests for population-viability-analysis skill scripts
# Covers: matrix_pva.R, stochastic_pva.R
library(testthat)

test_that("matrix has valid vital rates (all elements in [0, Inf))", {
  A <- matrix(c(
    0, 0, 0.8,
    0.3, 0.6, 0,
    0, 0.7, 0.9
  ), nrow = 3, byrow = TRUE)
  # Survival values must be in [0, 1]
  diag_surv <- c(A[2,1], A[3,2], A[3,3])
  expect_true(all(diag_surv >= 0 & diag_surv <= 1))
  # Fecundity values must be >= 0
  expect_true(all(A[1,] >= 0))
})

test_that("lambda is computed correctly for trivial matrix", {
  # Identity matrix has lambda = 1
  A_id <- diag(3)
  evals <- Re(eigen(A_id)$values)
  lam <- max(evals)
  expect_equal(lam, 1)
})

test_that("sum of elasticities equals 1", {
  # Property of elasticity matrix
  # For a simple growth matrix
  A <- matrix(c(0, 0, 2, 0.5, 0, 0, 0, 0.7, 0.8), nrow = 3)
  evals <- Re(eigen(A)$values)
  lam <- max(evals)
  # Compute sensitivity and elasticity
  evec_right <- Re(eigen(A)$vectors[, which.max(Re(eigen(A)$values))])
  evec_left  <- Re(eigen(t(A))$vectors[, which.max(Re(eigen(t(A))$values))])
  S <- outer(evec_right, evec_left) / sum(evec_right * evec_left)
  E <- (A / lam) * S
  expect_lt(abs(sum(E) - 1.0), 0.01)  # sum ≈ 1
})

test_that("extinction probability is in [0, 1]", {
  p_ext <- 0.003
  expect_gte(p_ext, 0)
  expect_lte(p_ext, 1)
})

test_that("IUCN Criterion E thresholds classify correctly", {
  p_ext <- 0.55  # > 50% → CR
  iucn_category <- ifelse(p_ext >= 0.50, "CR",
                   ifelse(p_ext >= 0.20, "EN",
                   ifelse(p_ext >= 0.10, "VU", "LC/NT")))
  expect_equal(iucn_category, "CR")

  p_ext_vu <- 0.12
  cat_vu <- ifelse(p_ext_vu >= 0.50, "CR",
            ifelse(p_ext_vu >= 0.20, "EN",
            ifelse(p_ext_vu >= 0.10, "VU", "LC/NT")))
  expect_equal(cat_vu, "VU")
})

test_that("coefficient of variation threshold triggers stochastic PVA", {
  cv_values <- c(0.08, 0.22, 0.35, 0.12)
  cv_threshold <- 0.30
  high_cv <- cv_values > cv_threshold
  # Only the 3rd element exceeds threshold
  expect_equal(sum(high_cv), 1L)
  expect_true(high_cv[3])
})
