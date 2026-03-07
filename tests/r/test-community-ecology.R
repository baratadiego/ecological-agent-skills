# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# test-community-ecology.R
library(testthat)

DATA_DIR <- if (dir.exists("tests/data")) "tests/data" else file.path("..", "data")

bray_curtis <- function(a, b) {
  sum(abs(a - b)) / (sum(a) + sum(b))
}

alpha_diversity <- function(row) {
  row <- row[row > 0]
  if (length(row) == 0) return(c(richness=0, shannon=0, simpson=0))
  p <- row / sum(row)
  list(richness = length(row),
       shannon  = -sum(p * log(p)),
       simpson  = 1 - sum(p^2))
}

test_that("species matrix loads correctly", {
  df <- read.csv(file.path(DATA_DIR, "species_site_matrix.csv"), row.names = 1)
  expect_equal(nrow(df), 30)
  expect_true("group" %in% names(df))
})

test_that("three groups are balanced", {
  df <- read.csv(file.path(DATA_DIR, "species_site_matrix.csv"), row.names = 1,
                 stringsAsFactors = FALSE)
  counts <- table(df$group)
  expect_equal(as.integer(counts["forest"]),  10)
  expect_equal(as.integer(counts["savanna"]), 10)
  expect_equal(as.integer(counts["pasture"]), 10)
})

test_that("no negative abundances", {
  df <- read.csv(file.path(DATA_DIR, "species_site_matrix.csv"), row.names = 1)
  sp <- df[, !names(df) %in% "group"]
  expect_true(all(sp >= 0))
})

test_that("Bray-Curtis is 0 for identical sites", {
  a <- c(5, 3, 0, 2)
  b <- c(5, 3, 0, 2)
  expect_equal(bray_curtis(a, b), 0.0, tolerance = 1e-10)
})

test_that("Bray-Curtis is 1 for non-overlapping sites", {
  a <- c(5, 0, 0)
  b <- c(0, 3, 2)
  expect_equal(bray_curtis(a, b), 1.0, tolerance = 1e-10)
})

test_that("Shannon is 0 for monoculture", {
  div <- alpha_diversity(c(100, 0, 0))
  expect_equal(div$shannon, 0.0, tolerance = 1e-10)
})

test_that("Shannon is log(n) for perfectly even community", {
  div <- alpha_diversity(c(5, 5, 5, 5))
  expect_equal(div$shannon, log(4), tolerance = 0.01)
})

test_that("vegan NMDS runs on test data", {
  skip_if_not_installed("vegan")
  df <- read.csv(file.path(DATA_DIR, "species_site_matrix.csv"), row.names = 1)
  sp <- df[, !names(df) %in% "group"]
  set.seed(42)
  nmds <- vegan::metaMDS(sp, distance = "bray", k = 2, trymax = 20, trace = FALSE)
  expect_lt(nmds$stress, 0.25)
})

test_that("forest sites more similar to each other than to pasture", {
  skip_if_not_installed("vegan")
  df     <- read.csv(file.path(DATA_DIR, "species_site_matrix.csv"), row.names = 1)
  groups <- df$group
  sp     <- df[, !names(df) %in% "group"]
  dm     <- as.matrix(vegan::vegdist(sp, method = "bray"))
  ff_idx <- which(groups == "forest")
  pp_idx <- which(groups == "pasture")
  within  <- mean(dm[ff_idx, ff_idx][lower.tri(dm[ff_idx, ff_idx])])
  between <- mean(dm[ff_idx, pp_idx])
  expect_lt(within, between)
})

test_that("PERMANOVA detects group effect", {
  skip_if_not_installed("vegan")
  df     <- read.csv(file.path(DATA_DIR, "species_site_matrix.csv"), row.names = 1,
                     stringsAsFactors = FALSE)
  groups <- df$group
  sp     <- df[, !names(df) %in% "group"]
  set.seed(42)
  result <- vegan::adonis2(sp ~ groups, data = data.frame(groups), method = "bray",
                           permutations = 199)
  expect_lt(result$`Pr(>F)`[1], 0.05)
})
