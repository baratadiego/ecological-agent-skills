# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# test-baci-impact.R
library(testthat)

DATA_DIR <- if (dir.exists("tests/data")) "tests/data" else file.path("..", "data")

test_that("BACI dataset loads correctly", {
  df <- read.csv(file.path(DATA_DIR, "baci_data.csv"), stringsAsFactors = FALSE)
  expect_equal(nrow(df), 96)
  for (col in c("site","treatment","period","abundance")) {
    expect_true(col %in% names(df))
  }
})

test_that("design is balanced: 8 control, 8 impact sites", {
  df <- read.csv(file.path(DATA_DIR, "baci_data.csv"), stringsAsFactors = FALSE)
  n_sites <- tapply(df$site, df$treatment, function(x) length(unique(x)))
  expect_equal(as.integer(n_sites["control"]), 8)
  expect_equal(as.integer(n_sites["impact"]),  8)
})

test_that("BACI interaction is negative (impact after decline)", {
  df <- read.csv(file.path(DATA_DIR, "baci_data.csv"), stringsAsFactors = FALSE)
  df$period    <- factor(df$period,    levels = c("before","after"))
  df$treatment <- factor(df$treatment, levels = c("control","impact"))
  m <- glm(abundance ~ period * treatment, data = df, family = quasipoisson())
  coefs <- coef(m)
  baci_coef <- coefs[grep("period.*treatment|treatment.*period", names(coefs))]
  expect_lt(baci_coef, 0)
})

test_that("impact decline is ~25-40% as designed", {
  df    <- read.csv(file.path(DATA_DIR, "baci_data.csv"), stringsAsFactors = FALSE)
  means <- tapply(df$abundance, list(df$treatment, df$period), mean)
  control_change <- (means["control","after"] - means["control","before"]) / means["control","before"]
  impact_change  <- (means["impact","after"]  - means["impact","before"])  / means["impact","before"]
  baci_effect <- impact_change - control_change
  expect_lt(baci_effect, -0.15)   # at least 15% relative decline
  expect_gt(baci_effect, -0.60)   # not more than 60%
})

test_that("glmmTMB BACI model converges", {
  skip_if_not_installed("glmmTMB")
  df <- read.csv(file.path(DATA_DIR, "baci_data.csv"), stringsAsFactors = FALSE)
  df$period    <- factor(df$period,    levels = c("before","after"))
  df$treatment <- factor(df$treatment, levels = c("control","impact"))
  m <- glmmTMB::glmmTMB(abundance ~ period * treatment + (1|site),
                         data = df, family = glmmTMB::nbinom2())
  expect_true(!is.null(m))
  expect_false(any(is.na(coef(m)$cond[[1]])))
})
