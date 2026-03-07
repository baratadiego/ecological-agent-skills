# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# test-biostatistics-workbench.R
library(testthat)

DATA_DIR <- if (dir.exists("tests/data")) "tests/data" else file.path("..", "data")

# ── Helper functions matching skill script logic ──────────────────────────────
compute_dispersion_ratio <- function(model) {
  sum(residuals(model, type = "pearson")^2) / df.residual(model)
}

# ── Tests ──────────────────────────────────────────────────────────────────────

test_that("richness data loads with correct structure", {
  df <- read.csv(file.path(DATA_DIR, "richness_data.csv"))
  expect_true("richness"      %in% names(df))
  expect_true("group"         %in% names(df))
  expect_true("elevation"     %in% names(df))
  expect_true("forest_cover"  %in% names(df))
  expect_equal(nrow(df), 90)
})

test_that("three groups are present and balanced in richness data", {
  df <- read.csv(file.path(DATA_DIR, "richness_data.csv"), stringsAsFactors = FALSE)
  counts <- table(df$group)
  expect_equal(as.integer(counts["forest"]),  30)
  expect_equal(as.integer(counts["savanna"]), 30)
  expect_equal(as.integer(counts["pasture"]), 30)
})

test_that("richness values are non-negative integers", {
  df <- read.csv(file.path(DATA_DIR, "richness_data.csv"))
  expect_true(all(df$richness >= 0))
  expect_true(all(df$richness == floor(df$richness)))
})

test_that("Poisson GLM fits without error", {
  df <- read.csv(file.path(DATA_DIR, "richness_data.csv"), stringsAsFactors = FALSE)
  df$group <- factor(df$group)
  m <- glm(richness ~ group + elevation, data = df, family = poisson())
  expect_s3_class(m, "glm")
  expect_false(any(is.na(coef(m))))
})

test_that("forest richness significantly higher than pasture", {
  df <- read.csv(file.path(DATA_DIR, "richness_data.csv"), stringsAsFactors = FALSE)
  forest  <- df$richness[df$group == "forest"]
  pasture <- df$richness[df$group == "pasture"]
  kw <- kruskal.test(list(forest, pasture))
  expect_lt(kw$p.value, 0.05)
  expect_gt(mean(forest), mean(pasture))
})

test_that("dispersion check function works", {
  df <- read.csv(file.path(DATA_DIR, "richness_data.csv"), stringsAsFactors = FALSE)
  df$group <- factor(df$group)
  m <- glm(richness ~ group, data = df, family = poisson())
  disp <- compute_dispersion_ratio(m)
  expect_true(is.numeric(disp))
  expect_gt(disp, 0)
})

test_that("AIC comparison prefers more complex model", {
  df <- read.csv(file.path(DATA_DIR, "richness_data.csv"), stringsAsFactors = FALSE)
  df$group <- factor(df$group)
  m_null <- glm(richness ~ 1,     data = df, family = poisson())
  m_full <- glm(richness ~ group, data = df, family = poisson())
  expect_lt(AIC(m_full), AIC(m_null))
})
