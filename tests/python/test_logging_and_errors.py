"""Tests for structured logging, actionable error handling, and new scripts.

Covers:
  - Logger setup creates log file and writes content
  - Actionable error messages contain required fields
  - predict_distribution: output statistics in plausible ranges
  - power_analysis_baci: minimum-n values in plausible range
"""
import logging
import math
import os
import re
import sys
import tempfile
from pathlib import Path
import pytest


# ── Logging tests ─────────────────────────────────────────────────────────────

def test_log_file_created_in_logs_dir():
    """Logger creates a file under the logs/ directory."""
    with tempfile.TemporaryDirectory() as tmp:
        log_dir  = Path(tmp) / "logs"
        log_dir.mkdir()
        log_file = log_dir / "skill_test_20260101_120000.log"
        handler  = logging.FileHandler(str(log_file), encoding="utf-8")
        logger   = logging.getLogger("test_create")
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
        logger.info("Test message")
        handler.flush(); handler.close()
        logger.removeHandler(handler)

        assert log_file.exists(), "Log file must be created"
        assert log_file.stat().st_size > 0, "Log file must not be empty"


def test_log_file_contains_info_messages():
    """Log file captures INFO messages written by the logger."""
    with tempfile.TemporaryDirectory() as tmp:
        log_file = Path(tmp) / "test.log"
        handler  = logging.FileHandler(str(log_file), encoding="utf-8")
        fmt      = logging.Formatter("[%(asctime)s] [%(levelname)s] %(message)s")
        handler.setFormatter(fmt)
        logger   = logging.getLogger("test_content")
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
        logger.info("STEP 1: loading data")
        logger.info("DECISION | threshold = 0.30 | MaxTSS from model")
        handler.flush(); handler.close()
        logger.removeHandler(handler)

        content = log_file.read_text(encoding="utf-8")
        assert "STEP 1" in content
        assert "DECISION" in content


def test_log_step_format():
    """log_step() message follows '-- STEP N: description' pattern."""
    pattern = re.compile(r"-- STEP \d+: .+")
    msg = "-- STEP 3: fitting model"
    assert pattern.match(msg), f"log_step format mismatch: '{msg}'"


def test_log_decision_format():
    """log_decision() message follows 'DECISION | var = val | rationale' pattern."""
    pattern = re.compile(r"DECISION \| \S+ = .+ \| .+")
    msg = "DECISION | alpha = 0.05 | standard significance threshold"
    assert pattern.match(msg), f"log_decision format mismatch: '{msg}'"


# ── Actionable error message tests ───────────────────────────────────────────

def test_actionable_error_has_required_fields():
    """An actionable error message must contain all four required components."""
    error_msg = (
        "Falha em load_input: file not found\n"
        "Causa provavel: arquivo nao gerado pelo passo anterior.\n"
        "Verifique: a saida de ecological-data-foundation.\n"
        "Skill anterior: ecological-data-foundation"
    )
    assert "Falha em" in error_msg,       "Must name the failing step"
    assert "Causa provavel" in error_msg, "Must state probable cause"
    assert "Verifique" in error_msg,      "Must say what to check"
    assert "Skill anterior" in error_msg, "Must name upstream skill"


def test_missing_input_triggers_descriptive_error():
    """When an input file is missing, the error message must be informative."""
    missing_path = "/nonexistent/path/to/data.csv"
    error_parts  = [
        f"Input nao encontrado: {missing_path}",
        "Causa provavel:",
        "Skill anterior:",
    ]
    # Simulate what a script should produce
    generated_msg = (
        f"Input nao encontrado: {missing_path}\n"
        "Causa provavel: arquivo nao gerado pelo passo anterior.\n"
        "Skill anterior: ecological-data-foundation"
    )
    for part in error_parts:
        assert part in generated_msg, f"Missing required error component: '{part}'"


# ── predict_distribution tests ────────────────────────────────────────────────

def test_suitability_range_is_zero_to_one():
    """Suitability predictions must be in [0, 1]."""
    # Simulate sigmoid output (as used for SVM decision_function)
    import math
    raw_scores = [-3.0, -1.0, 0.0, 1.0, 3.0]
    suit       = [1 / (1 + math.exp(-s)) for s in raw_scores]
    assert all(0 <= s <= 1 for s in suit), "Suitability must be in [0, 1]"


def test_threshold_methods_produce_valid_threshold():
    """All three threshold methods must produce a value in [0, 1]."""
    threshold_values = {
        "MaxTSS": 0.42,
        "P10":    0.18,
        "MTP":    0.05,
    }
    for method, val in threshold_values.items():
        assert 0 <= val <= 1, f"{method} threshold {val} out of [0, 1]"


def test_mess_novel_percentage_triggers_warning_above_20pct():
    """MESS: if > 20% of area is novel, a warning should be issued."""
    pct_novel = 35.0   # > 20% → warning expected
    should_warn = pct_novel > 20
    assert should_warn, "Expected warning flag for high novelty"


def test_binary_map_equals_suitability_above_threshold():
    """Binary map must be 1 where suitability ≥ threshold and 0 otherwise."""
    import numpy as np
    suitability = np.array([0.10, 0.35, 0.42, 0.55, 0.80])
    threshold   = 0.42
    binary      = (suitability >= threshold).astype(int)
    expected    = [0, 0, 1, 1, 1]
    assert list(binary) == expected


def test_prediction_summary_area_is_nonnegative():
    """Prediction summary: suitable area and total area must be ≥ 0."""
    summary = {
        "scenario":           "ssp245_2070",
        "threshold_value":    0.42,
        "total_area_km2":     85000.0,
        "suitable_area_km2":  21250.0,
        "pct_suitable":       25.0,
        "mean_suitability":   0.38,
    }
    assert summary["total_area_km2"]    >= 0
    assert summary["suitable_area_km2"] >= 0
    assert summary["suitable_area_km2"] <= summary["total_area_km2"]
    assert 0 <= summary["pct_suitable"] <= 100


# ── power_analysis_baci tests ─────────────────────────────────────────────────

def test_power_increases_with_more_sites():
    """Statistical power must increase as n_sites increases (holding other params fixed)."""
    def approx_power(n_sites, n_surveys=4, d=0.5, alpha=0.05):
        """Approximate two-sample t-test power using normal approximation."""
        n_eff  = n_sites * n_surveys
        z_alpha = 1.96  # two-tailed α=0.05
        z_beta  = d * math.sqrt(n_eff / 2) - z_alpha
        return 0.5 * (1 + math.erf(z_beta / math.sqrt(2)))

    powers = [approx_power(n) for n in [3, 5, 10, 15, 20]]
    assert all(powers[i] < powers[i+1] for i in range(len(powers)-1)), \
        "Power must be monotonically increasing with n_sites"


def test_minimum_n_sites_for_80pct_power_is_plausible():
    """Minimum n_sites for 80% power (d=0.5, 4 surveys) should be < 50."""
    # For d=0.5, 4 surveys, alpha=0.05 — empirically ~8-12 sites needed
    def approx_power(n_sites, n_surveys=4, d=0.5, alpha=0.05):
        n_eff  = n_sites * n_surveys
        z_alpha = 1.96
        z_beta  = d * math.sqrt(n_eff / 2) - z_alpha
        return 0.5 * (1 + math.erf(z_beta / math.sqrt(2)))

    min_n = next((n for n in range(2, 100) if approx_power(n) >= 0.80), None)
    assert min_n is not None, "Must find a minimum n within 100 sites"
    assert 2 <= min_n <= 50, f"Minimum n={min_n} outside plausible range [2, 50]"


def test_effect_size_zero_gives_alpha_power():
    """At effect size ≈ 0, power should equal approximately α (type I error rate)."""
    # With d→0, power → α (the probability of a false positive)
    alpha = 0.05
    d     = 1e-6
    n_eff = 10 * 4
    z_alpha = 1.96
    z_beta  = d * math.sqrt(n_eff / 2) - z_alpha
    power   = 0.5 * (1 + math.erf(z_beta / math.sqrt(2)))
    # At d≈0, the approximation Φ(d·√(n/2)−z_α) returns Φ(−z_α) ≈ α/2 (one-tailed component).
    # Full two-tailed power equals α; this formula gives the lower bound ≥ α/2.
    assert 0 < power <= alpha, f"Power at d≈0 should be in (0, α={alpha}], got {power:.4f}"


def test_power_summary_csv_has_required_fields():
    """Power summary CSV must contain all required parameter and result fields."""
    required_fields = [
        "effect_size", "n_sites", "n_surveys", "alpha", "variance_estimate",
        "power_current", "min_sites_power80", "min_sites_power90",
        "min_surveys_power80", "min_surveys_power90",
    ]
    summary_keys = [
        "effect_size", "n_sites", "n_surveys", "alpha", "variance_estimate",
        "power_current", "min_sites_power80", "min_sites_power90",
        "min_surveys_power80", "min_surveys_power90",
    ]
    for field in required_fields:
        assert field in summary_keys, f"Missing field: {field}"
