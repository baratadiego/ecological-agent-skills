# test-ecological-data-foundation.R
# testthat tests for ecological-data-foundation skill
# Run: testthat::test_file("tests/r/test-ecological-data-foundation.R")
library(testthat)

DATA_DIR <- file.path(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)), "data")
# Fallback for non-RStudio
if (!dir.exists(DATA_DIR)) DATA_DIR <- file.path("tests", "data")

# ── Helpers ──────────────────────────────────────────────────────────────────
flag_coords <- function(df, lat_col = "decimalLatitude", lon_col = "decimalLongitude") {
  df$QA_status <- "OK"
  lat <- suppressWarnings(as.numeric(df[[lat_col]]))
  lon <- suppressWarnings(as.numeric(df[[lon_col]]))
  df$QA_status[abs(lat) > 90 | abs(lon) > 180] <- "COORD_OUT_OF_RANGE"
  df$QA_status[lat == 0 & lon == 0]             <- "COORD_ZERO"
  df$QA_status[is.na(lat) | is.na(lon)]         <- "MISSING_COORDS"
  df
}

remove_duplicates <- function(df, cols = c("scientificName","decimalLatitude","decimalLongitude","eventDate")) {
  cols_ok <- intersect(cols, names(df))
  df[!duplicated(df[, cols_ok, drop = FALSE]), ]
}

# ── Tests ─────────────────────────────────────────────────────────────────────

test_that("zero coordinates are flagged", {
  df <- data.frame(decimalLatitude = 0.0, decimalLongitude = 0.0, QA_status = "OK",
                   stringsAsFactors = FALSE)
  result <- flag_coords(df)
  expect_equal(result$QA_status[1], "COORD_ZERO")
})

test_that("out-of-range latitude is flagged", {
  df <- data.frame(decimalLatitude = 999.0, decimalLongitude = -50.0, QA_status = "OK",
                   stringsAsFactors = FALSE)
  result <- flag_coords(df)
  expect_equal(result$QA_status[1], "COORD_OUT_OF_RANGE")
})

test_that("valid coordinates pass", {
  df <- data.frame(decimalLatitude = -12.5, decimalLongitude = -55.3, QA_status = "OK",
                   stringsAsFactors = FALSE)
  result <- flag_coords(df)
  expect_equal(result$QA_status[1], "OK")
})

test_that("exact duplicates are removed", {
  df <- data.frame(
    scientificName  = rep("Panthera onca", 3),
    decimalLatitude = rep(-12.0, 3),
    decimalLongitude= rep(-55.0, 3),
    eventDate       = rep("2020-01-01", 3),
    stringsAsFactors = FALSE
  )
  result <- remove_duplicates(df)
  expect_equal(nrow(result), 1)
})

test_that("non-duplicates are retained", {
  df <- data.frame(
    scientificName  = c("Panthera onca", "Puma concolor"),
    decimalLatitude = c(-12.0, -15.0),
    decimalLongitude= c(-55.0, -52.0),
    eventDate       = c("2020-01-01", "2020-06-01"),
    stringsAsFactors = FALSE
  )
  result <- remove_duplicates(df)
  expect_equal(nrow(result), 2)
})

test_that("test dataset has required columns", {
  df <- read.csv(file.path(DATA_DIR, "occurrences_raw.csv"))
  expect_true("decimalLatitude"  %in% names(df))
  expect_true("decimalLongitude" %in% names(df))
  expect_true("scientificName"   %in% names(df))
  expect_true("eventDate"        %in% names(df))
})

test_that("test dataset contains known QA issues", {
  df <- read.csv(file.path(DATA_DIR, "occurrences_raw.csv"), stringsAsFactors = FALSE)
  expect_true("zero_coords"   %in% df$QA_issue)
  expect_true("future_date"   %in% df$QA_issue)
  expect_true("duplicate"     %in% df$QA_issue)
})

test_that("majority of test records are clean", {
  df <- read.csv(file.path(DATA_DIR, "occurrences_raw.csv"), stringsAsFactors = FALSE)
  clean_rate <- mean(df$QA_issue == "none")
  expect_gt(clean_rate, 0.7)
})

test_that("flagging reduces dataset size", {
  df <- read.csv(file.path(DATA_DIR, "occurrences_raw.csv"), stringsAsFactors = FALSE)
  flagged <- flag_coords(df)
  n_clean  <- sum(flagged$QA_status == "OK")
  expect_lt(n_clean, nrow(df))
})
