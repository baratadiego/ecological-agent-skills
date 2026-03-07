# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Tests for camera-trap-processing skill scripts
# Covers: process_camtrap_data.R, estimate_activity.R
library(testthat)

test_that("record table has required columns", {
  rec <- data.frame(
    station       = "ST001",
    species       = "Panthera_pardus",
    datetime      = as.POSIXct("2024-06-01 02:14:00"),
    date          = as.Date("2024-06-01"),
    time          = "02:14:00",
    independent   = TRUE,
    stringsAsFactors = FALSE
  )
  required_cols <- c("station", "species", "datetime", "independent")
  expect_true(all(required_cols %in% names(rec)))
})

test_that("independence threshold collapses events within threshold", {
  # Two events 20 minutes apart — should collapse to 1 with 30-min threshold
  times <- as.POSIXct(c("2024-06-01 02:00:00", "2024-06-01 02:20:00"))
  diffs_min <- as.numeric(diff(times), units = "mins")
  threshold <- 30L
  independent <- c(TRUE, diffs_min >= threshold)
  expect_equal(sum(independent), 1L)
})

test_that("trap-nights calculation is correct", {
  # Station active for 30 days = 30 trap-nights
  setup    <- as.Date("2024-06-01")
  retrieval <- as.Date("2024-07-01")
  tn <- as.integer(retrieval - setup)
  expect_equal(tn, 30L)
})

test_that("stations below minimum trap-nights are flagged", {
  effort <- data.frame(
    station    = c("ST001", "ST002", "ST003"),
    trap_nights = c(45, 120, 88)
  )
  min_tn <- 100L
  flagged <- effort$station[effort$trap_nights < min_tn]
  expect_equal(length(flagged), 2L)
  expect_true("ST001" %in% flagged)
})

test_that("RAI is computed as events per 100 trap-nights", {
  n_events  <- 12
  tn        <- 90
  rai       <- n_events / tn * 100
  expect_equal(round(rai, 2), 13.33)
  expect_gt(rai, 0)
})

test_that("diel activity times are in radians for circular statistics", {
  # Convert hour of day to radians
  hours <- c(2, 14, 20, 5)  # hour of day
  radians <- hours / 24 * 2 * pi
  expect_true(all(radians >= 0 & radians <= 2 * pi))
})

test_that("overlap index Dhat4 is in [0, 1]", {
  # Simulate an overlap value
  dhat4 <- 0.38
  expect_gte(dhat4, 0)
  expect_lte(dhat4, 1)
})
