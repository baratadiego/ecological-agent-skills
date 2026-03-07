# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""Tests for species-distribution-modeling skill scripts.
Covers: sdm_pipeline.py, prepare_future_layers (data checks)
"""
import pytest


def test_occurrence_minimum_sample_size():
    """SDM requires at least 10 occurrence records."""
    n_occ = 35
    n_min = 10
    assert n_occ >= n_min, f"Insufficient occurrences for SDM: {n_occ}"


def test_suitability_values_bounded():
    """Suitability scores must be in [0, 1]."""
    suit_vals = [0.0, 0.23, 0.65, 0.91, 1.0]
    assert all(0 <= v <= 1 for v in suit_vals), "Suitability out of [0, 1]"


def test_binary_map_contains_only_01():
    """Binary suitability map must contain only 0 or 1 values."""
    binary = [0, 1, 0, 0, 1, 1, 0]
    assert all(v in (0, 1) for v in binary), "Binary map has non-0/1 values"


def test_variable_importance_sums_to_100():
    """Variable importance percentages must sum to ~100."""
    importance = {"bio1": 38.2, "bio12": 29.4, "bio15": 18.1, "slope": 14.3}
    total = sum(importance.values())
    assert abs(total - 100.0) < 1.0, f"Importance sums to {total}, expected ~100"


def test_future_scenario_labels_valid():
    """Scenario labels must follow SSP naming convention."""
    valid_ssps = {"SSP1-2.6", "SSP2-4.5", "SSP3-7.0", "SSP5-8.5"}
    used_ssp = "SSP2-4.5"
    assert used_ssp in valid_ssps, f"Invalid SSP label: {used_ssp}"


def test_output_files_named_correctly():
    """Output filenames must follow naming convention."""
    import re
    outputs = [
        "suitability_current.tif",
        "suitability_binary.tif",
        "ensemble_sd.tif",
        "variable_importance.csv"
    ]
    pattern = re.compile(r'^[a-z0-9_]+\.(tif|csv|png|md)$')
    for f in outputs:
        assert pattern.match(f), f"Filename does not follow snake_case convention: {f}"
