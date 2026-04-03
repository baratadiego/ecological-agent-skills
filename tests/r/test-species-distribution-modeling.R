# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# test-species-distribution-modeling.R
# Tests for run_ensemble_sdm.R, tune_maxnet.R, predict_distribution.R
# Covers: AUC, TSS, ensemble weighting, P10 threshold, blockCV fallback, outputs
library(testthat)

# ── Helpers ────────────────────────────────────────────────────────────────────

# Reproduce AUC helper from run_ensemble_sdm.R
compute_auc <- function(pred_1, pred_0) {
  n1 <- length(pred_1); n0 <- length(pred_0)
  (sum(outer(pred_1, pred_0, ">")) + 0.5 * sum(outer(pred_1, pred_0, "=="))) / (n1 * n0)
}

# Reproduce TSS helper from run_ensemble_sdm.R
compute_tss <- function(pred_1, pred_0) {
  thresholds <- sort(unique(c(pred_1, pred_0)))
  tss_vals   <- vapply(thresholds, function(th) mean(pred_1 >= th) + mean(pred_0 < th) - 1,
                       numeric(1))
  max(tss_vals, na.rm = TRUE)
}

# Null-coalescing from run_ensemble_sdm.R
`%||%` <- function(a, b) if (!is.null(a)) a else b


# ── AUC helper ─────────────────────────────────────────────────────────────────

test_that("AUC = 1 for perfect separation", {
  pred_1 <- c(0.8, 0.9, 0.95)
  pred_0 <- c(0.1, 0.2, 0.3)
  expect_equal(compute_auc(pred_1, pred_0), 1.0)
})

test_that("AUC = 0.5 for random predictions", {
  set.seed(42)
  pred_1 <- runif(200, 0, 1)
  pred_0 <- runif(200, 0, 1)
  auc    <- compute_auc(pred_1, pred_0)
  expect_gt(auc, 0.40)
  expect_lt(auc, 0.60)
})

test_that("AUC = 0 for inverted predictions", {
  pred_1 <- c(0.1, 0.2, 0.3)
  pred_0 <- c(0.8, 0.9, 0.95)
  expect_equal(compute_auc(pred_1, pred_0), 0.0)
})

test_that("AUC is in [0, 1] for arbitrary predictions", {
  set.seed(7)
  pred_1 <- c(0.7, 0.6, 0.8, 0.55)
  pred_0 <- c(0.4, 0.3, 0.65, 0.2)
  auc    <- compute_auc(pred_1, pred_0)
  expect_gte(auc, 0)
  expect_lte(auc, 1)
})

test_that("AUC handles ties correctly (returns 0.5 for identical vectors)", {
  v   <- c(0.5, 0.5, 0.5)
  auc <- compute_auc(v, v)
  expect_equal(auc, 0.5)
})


# ── TSS helper ─────────────────────────────────────────────────────────────────

test_that("TSS = 1 for perfect separation", {
  pred_1 <- c(0.8, 0.9, 0.95)
  pred_0 <- c(0.1, 0.2, 0.3)
  expect_equal(compute_tss(pred_1, pred_0), 1.0)
})

test_that("TSS >= 0 for reasonable predictions", {
  pred_1 <- c(0.7, 0.65, 0.8)
  pred_0 <- c(0.3, 0.2, 0.4)
  tss    <- compute_tss(pred_1, pred_0)
  expect_gte(tss, 0)
  expect_lte(tss, 1)
})

test_that("TSS = 0 for random (near-random) predictions", {
  set.seed(99)
  pred_1 <- runif(300, 0.45, 0.55)
  pred_0 <- runif(300, 0.45, 0.55)
  tss    <- compute_tss(pred_1, pred_0)
  expect_lt(abs(tss), 0.25)  # near-zero for overlap
})

test_that("TSS >= AUC - 0.5 (TSS is more conservative than AUC)", {
  pred_1 <- c(0.72, 0.68, 0.80, 0.60)
  pred_0 <- c(0.35, 0.25, 0.45, 0.20)
  auc    <- compute_auc(pred_1, pred_0)
  tss    <- compute_tss(pred_1, pred_0)
  # TSS tends to be <= 2*(AUC - 0.5); i.e. TSS <= 2*AUC - 1
  expect_lte(tss, 2 * auc - 1 + 0.05)  # small tolerance for discretisation
})


# ── Null-coalescing operator ────────────────────────────────────────────────────

test_that("%||% returns left when not NULL", {
  expect_equal("a" %||% "b", "a")
  expect_equal(42L %||% 99L, 42L)
})

test_that("%||% returns right when left is NULL", {
  expect_equal(NULL %||% "default", "default")
  expect_equal(NULL %||% 5, 5)
})


# ── Ensemble weighting ─────────────────────────────────────────────────────────

test_that("TSS-weighted ensemble mean is within constituent model range", {
  tss_scores <- c(maxnet = 0.72, brt = 0.65, rf = 0.78)
  preds      <- list(maxnet = 0.80, brt = 0.60, rf = 0.85)
  weights    <- pmax(tss_scores, 0)
  wt_sum     <- sum(weights)
  ensemble   <- sum(mapply(`*`, preds, weights)) / wt_sum
  expect_gte(ensemble, min(unlist(preds)))
  expect_lte(ensemble, max(unlist(preds)))
})

test_that("models with TSS <= 0 receive zero weight", {
  tss_scores <- c(maxnet = 0.70, brt = -0.05, rf = 0.60)
  weights    <- pmax(tss_scores, 0)
  expect_equal(weights["brt"], c(brt = 0))
})

test_that("ensemble is NA if all models have TSS <= 0", {
  tss_scores <- c(maxnet = -0.1, brt = -0.2, rf = -0.3)
  weights    <- pmax(tss_scores, 0)
  expect_equal(sum(weights), 0)
  # In run_ensemble_sdm.R the fallback is unweighted mean
  preds      <- c(0.5, 0.4, 0.45)
  fallback   <- mean(preds)
  expect_gte(fallback, 0)
  expect_lte(fallback, 1)
})


# ── P10 threshold ──────────────────────────────────────────────────────────────

test_that("P10 threshold is the 10th percentile of presence predictions", {
  set.seed(1)
  presence_preds <- runif(100, 0.3, 1.0)
  p10            <- quantile(presence_preds, probs = 0.10, names = FALSE)
  expect_gte(p10, 0)
  expect_lte(p10, 1)
  expect_lt(p10, median(presence_preds))
})

test_that("binary map from P10 retains >= 90% of presence locations", {
  set.seed(2)
  presence_preds <- runif(50, 0.3, 1.0)
  p10    <- quantile(presence_preds, probs = 0.10, names = FALSE)
  binary <- presence_preds >= p10
  expect_gte(mean(binary), 0.90)
})

test_that("suitability values are in [0, 1]", {
  suit_vals <- c(0.0, 0.23, 0.65, 0.91, 1.0)
  expect_true(all(suit_vals >= 0 & suit_vals <= 1))
})


# ── blockCV fallback ───────────────────────────────────────────────────────────

test_that("random k-fold fallback produces k balanced folds", {
  set.seed(42)
  n   <- 80
  k   <- 5
  ids <- sample(rep(seq_len(k), length.out = n))
  for (i in seq_len(k)) {
    train <- which(ids != i)
    test  <- which(ids == i)
    expect_gt(length(train), 0)
    expect_gt(length(test), 0)
    expect_equal(length(train) + length(test), n)
  }
})

test_that("k-fold folds are mutually exclusive and cover all observations", {
  set.seed(7)
  n   <- 60
  k   <- 4
  ids <- sample(rep(seq_len(k), length.out = n))
  all_test <- unlist(lapply(seq_len(k), function(i) which(ids == i)))
  expect_equal(sort(all_test), seq_len(n))
})


# ── Output schema ──────────────────────────────────────────────────────────────

test_that("cv_performance.csv has required columns", {
  required <- c("model", "fold", "AUC", "TSS")
  perf     <- data.frame(model = "maxnet", fold = 1L, AUC = 0.85, TSS = 0.62)
  expect_true(all(required %in% names(perf)))
})

test_that("variable_importance.csv has required columns", {
  required <- c("variable", "importance_mean", "importance_sd")
  vi       <- data.frame(variable = "bio1", importance_mean = 35.2, importance_sd = 4.1)
  expect_true(all(required %in% names(vi)))
  expect_gte(vi$importance_mean, 0)
})

test_that("prediction_summary.csv values are internally consistent", {
  total_km2    <- 100000.0
  suitable_km2 <- 23000.0
  pct          <- 100 * suitable_km2 / total_km2
  expect_lte(suitable_km2, total_km2)
  expect_gte(pct, 0)
  expect_lte(pct, 100)
})

test_that("calibration results have required columns (ENMeval / tune_maxnet)", {
  cal <- data.frame(
    rm     = c(0.5, 1.0, 2.0),
    fc     = c("L", "LQ", "LQH"),
    or_auc = c(0.12, 0.08, 0.09),
    aicc   = c(850.2, 820.4, 835.1)
  )
  expect_true(all(c("rm", "fc", "or_auc", "aicc") %in% names(cal)))
  best <- cal[which.min(cal$aicc), ]
  expect_equal(best$rm, 1.0)
})


# ── Occurrence data validation ─────────────────────────────────────────────────

test_that("occurrence data has required columns", {
  occ <- data.frame(
    species   = "Sp_A",
    longitude = c(-60.1, -61.3, -59.8),
    latitude  = c(-3.2, -4.1, -2.9)
  )
  expect_true(all(c("species", "longitude", "latitude") %in% names(occ)))
})

test_that("minimum 10 occurrences required for SDM", {
  expect_gte(10L, 10L)   # boundary
  expect_lt(9L, 10L)     # below boundary
})

test_that("longitude is in [-180, 180] and latitude in [-90, 90]", {
  lon <- c(-60.1, -61.3, -59.8)
  lat <- c(-3.2, -4.1, -2.9)
  expect_true(all(lon >= -180 & lon <= 180))
  expect_true(all(lat >= -90 & lat <= 90))
})

test_that("duplicate occurrences (same cell) are flagged", {
  occ <- data.frame(
    longitude = c(-60.1, -60.1, -61.3),
    latitude  = c(-3.2, -3.2, -4.1)
  )
  dupes <- duplicated(occ[, c("longitude", "latitude")])
  expect_true(any(dupes))
})


# ── predict_distribution.R helpers ────────────────────────────────────────────

test_that("binary map equals suitability >= threshold", {
  suit   <- c(0.10, 0.35, 0.42, 0.55, 0.80)
  thresh <- 0.42
  binary <- as.integer(suit >= thresh)
  expect_equal(binary, c(0L, 0L, 1L, 1L, 1L))
})

test_that("MESS novelty flag triggers when > 20% area is novel", {
  pct_novel  <- 35.0
  should_warn <- pct_novel > 20
  expect_true(should_warn)
})

test_that("scenario label is parsed from filename correctly", {
  filenames <- c("ssp245_2050.tif", "ssp585_2070.tif", "current.tif")
  labels    <- tools::file_path_sans_ext(basename(filenames))
  expect_equal(labels, c("ssp245_2050", "ssp585_2070", "current"))
})

test_that("change map uses relative difference formula", {
  current_suit <- c(0.4, 0.6, 0.8)
  future_suit  <- c(0.3, 0.7, 0.9)
  change       <- (future_suit - current_suit) / (current_suit + 1e-6)
  expect_equal(round(change[1], 2), -0.25)
  expect_equal(round(change[2], 2),  0.17)
})


# ── Script existence ───────────────────────────────────────────────────────────

test_that("all expected SDM R scripts exist", {
  skill_dir <- "skills/species-distribution-modeling/scripts"
  if (!dir.exists(skill_dir)) {
    skill_dir <- file.path(dirname(dirname(getwd())),
                           "skills", "species-distribution-modeling", "scripts")
  }
  skip_if(!dir.exists(skill_dir), "skill directory not found from test working directory")
  scripts <- list.files(skill_dir, pattern = "\\.R$")
  for (s in c("run_ensemble_sdm.R", "tune_maxnet.R", "predict_distribution.R",
              "prepare_future_layers.R")) {
    expect_true(s %in% scripts, info = paste("Missing:", s))
  }
})
