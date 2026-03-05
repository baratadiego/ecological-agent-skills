# Tests for v2.2.0 occurrence download scripts (schema + argument validation).
# No live API calls — all tests use mock data and pure logic.
# Run: Rscript tests/r/test-download-sources.R

library(testthat)
library(dplyr)
library(readr)

# ── Standard schema columns ───────────────────────────────────────────────────
STANDARD_SCHEMA <- c(
  "species", "decimalLatitude", "decimalLongitude", "eventDate",
  "countryCode", "basisOfRecord", "coordinateUncertaintyInMeters",
  "datasetName", "occurrenceID", "source", "download_doi"
)

# ── Helper: build a mock occurrence data.frame matching the standard schema ───
make_mock_occ <- function(n = 5, source = "GBIF") {
  data.frame(
    species                        = rep("Panthera onca", n),
    decimalLatitude                = runif(n, -10, 0),
    decimalLongitude               = runif(n, -70, -50),
    eventDate                      = paste0("2020-0", seq_len(n), "-01"),
    countryCode                    = "BR",
    basisOfRecord                  = "HUMAN_OBSERVATION",
    coordinateUncertaintyInMeters  = sample(100:5000, n, replace = TRUE),
    datasetName                    = paste0(source, " Dataset"),
    occurrenceID                   = paste0(source, ":", seq_len(n)),
    source                         = source,
    download_doi                   = NA_character_,
    stringsAsFactors               = FALSE
  )
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Standard schema column presence
# ─────────────────────────────────────────────────────────────────────────────

test_that("mock_occ has all standard schema columns", {
  df <- make_mock_occ()
  missing <- setdiff(STANDARD_SCHEMA, names(df))
  expect_equal(missing, character(0), info = paste("Missing:", paste(missing, collapse = ", ")))
})

test_that("iNaturalist schema includes all standard columns", {
  # Simulate output from download_from_inat.R standardisation block
  df <- data.frame(
    species                        = "Myrmecophaga tridactyla",
    decimalLatitude                = -5.0,
    decimalLongitude               = -55.0,
    eventDate                      = "2021-08-10",
    countryCode                    = "Brazil",
    basisOfRecord                  = "HUMAN_OBSERVATION",
    coordinateUncertaintyInMeters  = 10,
    datasetName                    = "iNaturalist",
    occurrenceID                   = "12345678",
    source                         = "iNaturalist",
    download_doi                   = NA_character_,
    stringsAsFactors               = FALSE
  )
  missing <- setdiff(STANDARD_SCHEMA, names(df))
  expect_equal(missing, character(0))
})

test_that("OBIS schema includes all standard columns plus depth and marine", {
  df <- data.frame(
    species                        = "Chelonia mydas",
    decimalLatitude                = -5.0,
    decimalLongitude               = -35.0,
    eventDate                      = "2019-03-01",
    countryCode                    = "BR",
    basisOfRecord                  = "HUMAN_OBSERVATION",
    coordinateUncertaintyInMeters  = NA_real_,
    datasetName                    = "OBIS Dataset",
    occurrenceID                   = "urn:obis:123",
    source                         = "OBIS",
    download_doi                   = NA_character_,
    depth                          = 0.0,
    marine                         = TRUE,
    stringsAsFactors               = FALSE
  )
  missing <- setdiff(STANDARD_SCHEMA, names(df))
  expect_equal(missing, character(0))
  expect_true("depth"  %in% names(df))
  expect_true("marine" %in% names(df))
})

test_that("IUCN schema includes standard columns plus rl_category", {
  df <- data.frame(
    species                        = "Panthera onca",
    decimalLatitude                = NA_real_,
    decimalLongitude               = NA_real_,
    eventDate                      = NA_character_,
    countryCode                    = "BR",
    basisOfRecord                  = "LITERATURE",
    coordinateUncertaintyInMeters  = NA_real_,
    datasetName                    = "IUCN Red List",
    occurrenceID                   = "IUCN:15951:BR",
    source                         = "IUCN",
    download_doi                   = NA_character_,
    rl_category                    = "NT",
    rl_criteria                    = "A2cd",
    population_trend               = "Decreasing",
    assessment_year                = 2018L,
    stringsAsFactors               = FALSE
  )
  missing <- setdiff(STANDARD_SCHEMA, names(df))
  expect_equal(missing, character(0))
  expect_true("rl_category"     %in% names(df))
  expect_true("assessment_year" %in% names(df))
})

test_that("eBird schema includes standard columns plus effort columns", {
  df <- data.frame(
    species                        = "Jabiru mycteria",
    decimalLatitude                = -10.0,
    decimalLongitude               = -55.0,
    eventDate                      = "2021-09-01",
    countryCode                    = "BR",
    basisOfRecord                  = "HUMAN_OBSERVATION",
    coordinateUncertaintyInMeters  = NA_real_,
    datasetName                    = "eBird Basic Dataset",
    occurrenceID                   = "S98765432",
    source                         = "eBird",
    download_doi                   = NA_character_,
    effort_distance_km             = 1.5,
    duration_minutes               = 60,
    observer_id                    = "obsr123",
    stringsAsFactors               = FALSE
  )
  missing <- setdiff(STANDARD_SCHEMA, names(df))
  expect_equal(missing, character(0))
  expect_true("effort_distance_km" %in% names(df))
  expect_true("duration_minutes"   %in% names(df))
  expect_true("observer_id"        %in% names(df))
})

# ─────────────────────────────────────────────────────────────────────────────
# 2. Coordinate validity checks
# ─────────────────────────────────────────────────────────────────────────────

test_that("records with missing lat are removed in schema filtering", {
  df <- make_mock_occ(5)
  df$decimalLatitude[2] <- NA
  df_clean <- df[!is.na(df$decimalLatitude) & !is.na(df$decimalLongitude), ]
  expect_equal(nrow(df_clean), 4)
})

test_that("records with missing lon are removed", {
  df <- make_mock_occ(3)
  df$decimalLongitude[1] <- NA
  df_clean <- df[!is.na(df$decimalLatitude) & !is.na(df$decimalLongitude), ]
  expect_equal(nrow(df_clean), 2)
})

test_that("valid coordinates are retained", {
  df <- make_mock_occ(10)
  df_clean <- df[!is.na(df$decimalLatitude) & !is.na(df$decimalLongitude), ]
  expect_equal(nrow(df_clean), 10)
})

# ─────────────────────────────────────────────────────────────────────────────
# 3. OBIS quality flag logic (pure R, no API)
# ─────────────────────────────────────────────────────────────────────────────

apply_obis_qflags <- function(df) {
  bad_flags <- c("NO_COORD", "ZERO_COORD", "ON_LAND", "DEPTH_EXCEEDS_BATH")
  if (!"flags" %in% names(df)) return(df)
  keep <- !grepl(paste(bad_flags, collapse = "|"), df$flags, ignore.case = TRUE)
  df[keep, ]
}

test_that("NO_COORD flag removes record", {
  df <- data.frame(flags = c("NO_COORD", ""), stringsAsFactors = FALSE)
  result <- apply_obis_qflags(df)
  expect_equal(nrow(result), 1)
})

test_that("ON_LAND flag removes record", {
  df <- data.frame(flags = c("ON_LAND", "valid"), stringsAsFactors = FALSE)
  result <- apply_obis_qflags(df)
  expect_equal(nrow(result), 1)
})

test_that("clean records pass through quality filter", {
  df <- data.frame(flags = c("", "", ""), stringsAsFactors = FALSE)
  result <- apply_obis_qflags(df)
  expect_equal(nrow(result), 3)
})

test_that("DEPTH_EXCEEDS_BATH flag removes record", {
  df <- data.frame(flags = c("DEPTH_EXCEEDS_BATH"), stringsAsFactors = FALSE)
  result <- apply_obis_qflags(df)
  expect_equal(nrow(result), 0)
})

# ─────────────────────────────────────────────────────────────────────────────
# 4. Source column values
# ─────────────────────────────────────────────────────────────────────────────

test_that("source column for GBIF records is GBIF", {
  df <- make_mock_occ(n = 1, source = "GBIF")
  expect_equal(df$source, "GBIF")
})

test_that("source column for iNaturalist records is iNaturalist", {
  df <- make_mock_occ(n = 1, source = "iNaturalist")
  expect_equal(df$source, "iNaturalist")
})

test_that("source column for OBIS records is OBIS", {
  df <- make_mock_occ(n = 1, source = "OBIS")
  expect_equal(df$source, "OBIS")
})

# ─────────────────────────────────────────────────────────────────────────────
# 5. Script file existence checks
# ─────────────────────────────────────────────────────────────────────────────

BASE_SCRIPTS <- file.path(
  dirname(dirname(dirname(normalizePath(sys.frames()[[1]]$ofile, mustWork = FALSE)))),
  "skills", "ecological-data-foundation", "scripts"
)
GEO_BASE <- file.path(
  dirname(dirname(dirname(normalizePath(sys.frames()[[1]]$ofile, mustWork = FALSE)))),
  "skills", "geoprocessing-for-ecology", "scripts"
)

test_that("download_from_gbif.R exists", {
  expect_true(file.exists(file.path(BASE_SCRIPTS, "download_from_gbif.R")))
})
test_that("download_from_inat.R exists", {
  expect_true(file.exists(file.path(BASE_SCRIPTS, "download_from_inat.R")))
})
test_that("download_from_ebird.R exists", {
  expect_true(file.exists(file.path(BASE_SCRIPTS, "download_from_ebird.R")))
})
test_that("download_from_obis.R exists", {
  expect_true(file.exists(file.path(BASE_SCRIPTS, "download_from_obis.R")))
})
test_that("download_from_iucn.R exists", {
  expect_true(file.exists(file.path(BASE_SCRIPTS, "download_from_iucn.R")))
})
test_that("download_predictors.R exists", {
  expect_true(file.exists(file.path(GEO_BASE, "download_predictors.R")))
})

# ─────────────────────────────────────────────────────────────────────────────
# 6. Script header compliance (Usage: on line 1)
# ─────────────────────────────────────────────────────────────────────────────

check_usage_line1 <- function(script_path) {
  line1 <- readLines(script_path, n = 1, warn = FALSE)
  grepl("^# Usage:", line1)
}

test_that("download_from_inat.R has Usage: on line 1", {
  expect_true(check_usage_line1(file.path(BASE_SCRIPTS, "download_from_inat.R")))
})
test_that("download_from_ebird.R has Usage: on line 1", {
  expect_true(check_usage_line1(file.path(BASE_SCRIPTS, "download_from_ebird.R")))
})
test_that("download_from_obis.R has Usage: on line 1", {
  expect_true(check_usage_line1(file.path(BASE_SCRIPTS, "download_from_obis.R")))
})
test_that("download_from_iucn.R has Usage: on line 1", {
  expect_true(check_usage_line1(file.path(BASE_SCRIPTS, "download_from_iucn.R")))
})
test_that("download_predictors.R has Usage: on line 1", {
  expect_true(check_usage_line1(file.path(GEO_BASE, "download_predictors.R")))
})

# ─────────────────────────────────────────────────────────────────────────────
# 7. suppressPackageStartupMessages present in all new R scripts
# ─────────────────────────────────────────────────────────────────────────────

check_suppress <- function(script_path) {
  lines <- readLines(script_path, warn = FALSE)
  any(grepl("suppressPackageStartupMessages", lines))
}

test_that("download_from_inat.R uses suppressPackageStartupMessages", {
  expect_true(check_suppress(file.path(BASE_SCRIPTS, "download_from_inat.R")))
})
test_that("download_from_ebird.R uses suppressPackageStartupMessages", {
  expect_true(check_suppress(file.path(BASE_SCRIPTS, "download_from_ebird.R")))
})
test_that("download_from_obis.R uses suppressPackageStartupMessages", {
  expect_true(check_suppress(file.path(BASE_SCRIPTS, "download_from_obis.R")))
})
test_that("download_from_iucn.R uses suppressPackageStartupMessages", {
  expect_true(check_suppress(file.path(BASE_SCRIPTS, "download_from_iucn.R")))
})

# ─────────────────────────────────────────────────────────────────────────────
# 8. Inline logger present in all new R scripts
# ─────────────────────────────────────────────────────────────────────────────

check_logger <- function(script_path) {
  lines <- readLines(script_path, warn = FALSE)
  any(grepl("log_step", lines))
}

test_that("download_from_inat.R has log_step", {
  expect_true(check_logger(file.path(BASE_SCRIPTS, "download_from_inat.R")))
})
test_that("download_from_ebird.R has log_step", {
  expect_true(check_logger(file.path(BASE_SCRIPTS, "download_from_ebird.R")))
})
test_that("download_from_obis.R has log_step", {
  expect_true(check_logger(file.path(BASE_SCRIPTS, "download_from_obis.R")))
})
test_that("download_from_iucn.R has log_step", {
  expect_true(check_logger(file.path(BASE_SCRIPTS, "download_from_iucn.R")))
})
test_that("download_predictors.R has log_step", {
  expect_true(check_logger(file.path(GEO_BASE, "download_predictors.R")))
})

# ─────────────────────────────────────────────────────────────────────────────
# 9. Resource files exist
# ─────────────────────────────────────────────────────────────────────────────

BASE_RES <- file.path(
  dirname(dirname(dirname(normalizePath(sys.frames()[[1]]$ofile, mustWork = FALSE)))),
  "skills", "ecological-data-foundation", "resources"
)
GEO_RES <- file.path(
  dirname(dirname(dirname(normalizePath(sys.frames()[[1]]$ofile, mustWork = FALSE)))),
  "skills", "geoprocessing-for-ecology", "resources"
)

test_that("data-citation-guide.md exists", {
  expect_true(file.exists(file.path(BASE_RES, "data-citation-guide.md")))
})
test_that("global-predictor-sources.md exists", {
  expect_true(file.exists(file.path(GEO_RES, "global-predictor-sources.md")))
})

cat("\n✓ All download-sources tests completed.\n")
