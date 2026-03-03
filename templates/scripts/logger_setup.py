"""logger_setup.py — Structured logging template for ecological-agent-skills.

Usage:
    from pathlib import Path
    import sys
    sys.path.insert(0, str(Path(__file__).parents[2] / "templates" / "scripts"))
    from logger_setup import setup_logger, log_step, log_decision, log_actionable_error

    logger = setup_logger("skill-name")

Log format : [TIMESTAMP] [LEVEL] [SKILL] message
Log file   : logs/skill_{name}_{timestamp}.log  (relative to cwd)
"""

import logging
import sys
from datetime import datetime
from pathlib import Path

_SKILL_NAME = "eco-skill"


def setup_logger(
    skill_name: str = "eco-skill",
    log_dir: str = "logs",
    level: int = logging.INFO,
) -> logging.Logger:
    """Initialise a logger that writes to console AND a dated log file.

    Parameters
    ----------
    skill_name : str
        Short identifier used in the log filename and every log record.
    log_dir : str
        Directory where log files are written (created if absent).
    level : int
        Logging level (logging.DEBUG / INFO / WARNING / ERROR).

    Returns
    -------
    logging.Logger
        Configured logger instance.
    """
    global _SKILL_NAME
    _SKILL_NAME = skill_name

    Path(log_dir).mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = Path(log_dir) / f"skill_{skill_name}_{ts}.log"

    fmt = f"[%(asctime)s] [%(levelname)s] [{skill_name}] %(message)s"
    datefmt = "%Y-%m-%d %H:%M:%S"
    formatter = logging.Formatter(fmt, datefmt=datefmt)

    logger = logging.getLogger(skill_name)
    logger.setLevel(level)
    logger.handlers.clear()

    # Console handler
    ch = logging.StreamHandler(sys.stdout)
    ch.setFormatter(formatter)
    logger.addHandler(ch)

    # File handler
    fh = logging.FileHandler(log_file, encoding="utf-8")
    fh.setFormatter(formatter)
    logger.addHandler(fh)

    logger.info("Logger initialised | skill=%s | log_file=%s", skill_name, log_file)
    return logger


# ── Convenience wrappers ─────────────────────────────────────────────────────

def log_step(logger: logging.Logger, step_number: int, description: str) -> None:
    """Mark the start of a numbered processing step."""
    logger.info("── STEP %d: %s", step_number, description)


def log_decision(
    logger: logging.Logger, variable: str, value, rationale: str
) -> None:
    """Record an analytical decision with justification."""
    logger.info("DECISION | %s = %s | rationale: %s", variable, value, rationale)


def log_actionable_error(
    logger: logging.Logger,
    step: str,
    error_msg: str,
    probable_cause: str,
    check_this: str,
    prior_skill: str | None = None,
) -> None:
    """Log a structured, actionable error message.

    Parameters
    ----------
    step           : Name of the failing processing step.
    error_msg      : The exception message.
    probable_cause : One-sentence explanation of likely cause.
    check_this     : What the user should inspect to diagnose.
    prior_skill    : Upstream skill that should have produced the missing input.
    """
    prior_line = (
        f"\n  Skill anterior que deveria ter produzido este input: {prior_skill}"
        if prior_skill
        else ""
    )
    logger.error(
        "[ERROR] Falha em %s: %s\n"
        "  Causa provável: %s\n"
        "  Verifique: %s%s",
        step,
        error_msg,
        probable_cause,
        check_this,
        prior_line,
    )
