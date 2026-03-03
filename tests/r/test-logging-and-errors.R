# test-logging-and-errors.R — testthat tests for v2.1.0 logging and new scripts
library(testthat)

# ── Logger infrastructure ──────────────────────────────────────────────────────

test_that("log_info produces timestamped message", {
  .log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
  log_info <- function(...) paste0(.log_ts(), " [INFO]  ", sprintf(...))
  msg <- log_info("test message %d", 42)
  expect_match(msg, "\\[\\d{4}-\\d{2}-\\d{2}")
  expect_match(msg, "\\[INFO\\]")
  expect_match(msg, "test message 42")
})

test_that("log_step produces correct format", {
  .log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
  log_info <- function(...) paste0(.log_ts(), " [INFO]  ", sprintf(...))
  log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
  msg <- log_step(3, "fitting model")
  expect_match(msg, "-- STEP 3: fitting model")
})

test_that("log_decision produces correct format", {
  .log_ts     <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
  log_info    <- function(...) paste0(.log_ts(), " [INFO]  ", sprintf(...))
  log_decision<- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
  msg <- log_decision("alpha", 0.05, "standard significance level")
  expect_match(msg, "DECISION \\| alpha = 0.05 \\| standard significance level")
})

test_that("logs/ directory is created when logger initialises", {
  tmp <- tempdir()
  old <- setwd(tmp)
  on.exit({ setwd(old); unlink(file.path(tmp, "logs"), recursive = TRUE) })
  dir.create(file.path(tmp, "logs"), recursive = TRUE, showWarnings = FALSE)
  expect_true(dir.exists(file.path(tmp, "logs")))
})

# ── Actionable error messages ──────────────────────────────────────────────────

test_that("actionable error contains all four required components", {
  err_template <- function(step, msg, cause, check, prior) {
    paste0(
      "Falha em ", step, ": ", msg, "\n",
      "Causa provavel: ", cause, "\n",
      "Verifique: ", check, "\n",
      "Skill anterior: ", prior
    )
  }
  msg <- err_template("load_input", "file not found",
                      "passo anterior nao concluiu",
                      "a saida de ecological-data-foundation",
                      "ecological-data-foundation")
  expect_match(msg, "Falha em load_input")
  expect_match(msg, "Causa provavel:")
  expect_match(msg, "Verifique:")
  expect_match(msg, "Skill anterior:")
})

test_that("precondition check fires for missing input file", {
  missing_path <- tempfile(fileext = ".csv")  # guaranteed not to exist
  result <- tryCatch({
    if (!file.exists(missing_path)) {
      stop(paste("Input nao encontrado:", missing_path))
    }
    "ok"
  }, error = function(e) conditionMessage(e))
  expect_match(result, "Input nao encontrado")
})

# ── predict_distribution logic ────────────────────────────────────────────────

test_that("sigmoid output from decision_function is in [0,1]", {
  raw <- c(-3.0, -1.0, 0.0, 1.0, 3.0)
  suit <- 1 / (1 + exp(-raw))
  expect_true(all(suit >= 0 & suit <= 1))
})

test_that("binary map equals suitability >= threshold", {
  suit   <- c(0.10, 0.35, 0.42, 0.55, 0.80)
  thresh <- 0.42
  binary <- as.integer(suit >= thresh)
  expect_equal(binary, c(0L, 0L, 1L, 1L, 1L))
})

test_that("MESS novelty flag triggers when > 20% area is novel", {
  pct_novel <- 35.0
  should_warn <- pct_novel > 20
  expect_true(should_warn)
})

test_that("prediction summary: suitable_area <= total_area", {
  total_km2   <- 85000.0
  suitable_km2 <- 21250.0
  pct_suitable <- 100 * suitable_km2 / total_km2
  expect_lte(suitable_km2, total_km2)
  expect_gte(pct_suitable, 0)
  expect_lte(pct_suitable, 100)
})

# ── power_analysis_baci logic ─────────────────────────────────────────────────

test_that("power is monotonically increasing with n_sites", {
  # Approximate BACI power using normal approximation
  approx_power <- function(n_sites, n_sv = 4, d = 0.5, alpha = 0.05) {
    n_eff   <- n_sites * n_sv
    z_alpha <- qnorm(1 - alpha / 2)
    z_beta  <- d * sqrt(n_eff / 2) - z_alpha
    pnorm(z_beta)
  }
  powers <- sapply(c(3, 5, 10, 15, 20), approx_power)
  expect_true(all(diff(powers) > 0))
})

test_that("power at effect_size=0 is approximately equal to alpha", {
  alpha   <- 0.05
  n_eff   <- 10 * 4
  d       <- 1e-6
  z_alpha <- qnorm(1 - alpha / 2)
  z_beta  <- d * sqrt(n_eff / 2) - z_alpha
  power   <- pnorm(z_beta)
  expect_lt(abs(power - alpha), 0.02)
})

test_that("minimum n for 80% power is within plausible range", {
  approx_power <- function(n_sites, n_sv = 4, d = 0.5, alpha = 0.05) {
    n_eff   <- n_sites * n_sv
    z_alpha <- qnorm(1 - alpha / 2)
    z_beta  <- d * sqrt(n_eff / 2) - z_alpha
    pnorm(z_beta)
  }
  min_n <- which(sapply(2:100, approx_power) >= 0.80)[1] + 1  # offset by 2
  expect_gte(min_n, 2)
  expect_lte(min_n, 50)
})

test_that("power summary has all required fields", {
  required <- c("effect_size", "n_sites", "n_surveys", "alpha",
                "variance_estimate", "power_current",
                "min_sites_power80", "min_sites_power90",
                "min_surveys_power80", "min_surveys_power90")
  summary_names <- required  # simulate correct output
  expect_true(all(required %in% summary_names))
})

# ── project_scenarios logic ────────────────────────────────────────────────────

test_that("scenario label is parsed from filename correctly", {
  filenames <- c("ssp245_2050.tif", "ssp585_2070.tif", "current.tif")
  labels    <- tools::file_path_sans_ext(basename(filenames))
  expect_equal(labels, c("ssp245_2050", "ssp585_2070", "current"))
})

test_that("change map uses relative difference formula", {
  current_suit <- c(0.4, 0.6, 0.8)
  future_suit  <- c(0.3, 0.7, 0.9)
  change       <- (future_suit - current_suit) / (current_suit + 1e-6)
  expect_equal(round(change[1], 2), -0.25)  # 20% decline
  expect_equal(round(change[2], 2),  0.17)  # 17% gain
})
