# logger_setup.R — Structured logging template for ecological-agent-skills
# Usage: source("../../templates/scripts/logger_setup.R"); setup_logger("skill-name")
# Requires: futile.logger (install.packages("futile.logger"))

suppressPackageStartupMessages(library(futile.logger))

#' Initialise logger for a skill script
#'
#' Sets up simultaneous console + file handlers.
#' Log file: logs/skill_{name}_{timestamp}.log (relative to working directory)
#'
#' @param skill_name  Short identifier, e.g. "sdm", "occupancy"
#' @param log_dir     Directory for log files (created if absent)
#' @param level       Futile.logger threshold: INFO, WARN, ERROR
setup_logger <- function(skill_name = "eco-skill",
                         log_dir    = "logs",
                         level      = INFO) {
  dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  ts       <- format(Sys.time(), "%Y%m%d_%H%M%S")
  log_file <- file.path(log_dir, paste0("skill_", skill_name, "_", ts, ".log"))

  # Console layout: coloured, compact
  flog.layout(layout.format("[~t] [~l] ~m"), name = ROOT)

  # File appender: full timestamp, same format
  flog.appender(appender.tee(log_file), name = ROOT)

  flog.threshold(level, name = ROOT)

  flog.info("Logger initialised | skill=%s | log_file=%s", skill_name, log_file)
  invisible(log_file)
}

# ── Wrapper functions ────────────────────────────────────────────────────────

#' Log an informational message
log_info <- function(...) flog.info(...)

#' Log a warning
log_warn <- function(...) flog.warn(...)

#' Log an error (does NOT stop execution — call stop() afterwards if needed)
log_error <- function(...) flog.error(...)

#' Mark the start of a numbered processing step
#'
#' @param step_number  Integer step counter
#' @param description  Short description of the step
log_step <- function(step_number, description) {
  flog.info("── STEP %d: %s", step_number, description)
}

#' Record an analytical decision with justification
#'
#' @param variable   Name of the parameter / variable
#' @param value      Value chosen
#' @param rationale  One-sentence justification
log_decision <- function(variable, value, rationale) {
  flog.info("DECISION | %s = %s | rationale: %s", variable, value, rationale)
}

#' Standard actionable error message
#'
#' @param step          Name of the failing step
#' @param error_msg     The error message (from conditionMessage(e))
#' @param probable_cause One-sentence explanation of likely cause
#' @param check_this    What the user should check
#' @param prior_skill   Which upstream skill should have produced the input
log_actionable_error <- function(step, error_msg, probable_cause,
                                 check_this, prior_skill = NULL) {
  prior_line <- if (!is.null(prior_skill))
    paste0("\n  Skill anterior que deveria ter produzido este input: ", prior_skill)
  else ""

  flog.error(
    "[ERROR] Falha em %s: %s\n  Causa provável: %s\n  Verifique: %s%s",
    step, error_msg, probable_cause, check_this, prior_line
  )
}
