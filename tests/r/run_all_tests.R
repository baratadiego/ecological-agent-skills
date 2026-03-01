#!/usr/bin/env Rscript
# run_all_tests.R
# Run the full testthat suite from the project root.
# Usage: Rscript tests/r/run_all_tests.R [--no-optional]
#
# Packages tested:
#   Required: testthat, dplyr
#   Optional (skip if missing): vegan, unmarked, glmmTMB, lme4

args <- commandArgs(trailingOnly = TRUE)
skip_optional <- "--no-optional" %in% args

# Must run from project root
if (!file.exists("tests/data/richness_data.csv")) {
  stop("Run from project root: Rscript tests/r/run_all_tests.R")
}

if (!requireNamespace("testthat", quietly = TRUE)) {
  install.packages("testthat", repos = "https://cloud.r-project.org")
}
library(testthat)

test_files <- list.files("tests/r", pattern = "^test-.*\\.R$", full.names = TRUE)
cat("Running", length(test_files), "test files...\n\n")

results <- testthat::test_dir(
  "tests/r",
  reporter   = testthat::default_reporter(),
  stop_on_failure = FALSE
)

summary_df <- as.data.frame(results)
cat("\n=== SUMMARY ===\n")
cat("Tests:    ", sum(summary_df$nb), "\n")
cat("Passed:   ", sum(summary_df$passed), "\n")
cat("Failed:   ", sum(summary_df$failed), "\n")
cat("Skipped:  ", sum(summary_df$skipped), "\n")
cat("Warnings: ", sum(summary_df$warning), "\n")

if (sum(summary_df$failed) > 0) {
  cat("\nFailed tests:\n")
  print(summary_df[summary_df$failed > 0, c("file","test","failed")])
  quit(status = 1)
} else {
  cat("\nAll tests passed!\n")
  quit(status = 0)
}
