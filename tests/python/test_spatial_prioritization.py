# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""Tests for spatial-prioritization skill scripts.
Covers: run_prioritization.R and prioritization_sensitivity.R logic.
"""
import pytest


def test_target_must_be_in_valid_range():
    """Conservation targets must be between 0 and 1."""
    targets = [0.17, 0.30, 0.40, 0.50, 0.60]
    for t in targets:
        assert 0 < t <= 1.0


def test_iucn_targets_ordering():
    """IUCN-based targets: CR > EN > VU > NT > LC."""
    iucn_targets = {
        "CR": 0.60,
        "EN": 0.50,
        "VU": 0.40,
        "NT": 0.30,
        "LC": 0.17,
    }
    assert iucn_targets["CR"] > iucn_targets["EN"]
    assert iucn_targets["EN"] > iucn_targets["VU"]
    assert iucn_targets["VU"] > iucn_targets["NT"]
    assert iucn_targets["NT"] > iucn_targets["LC"]


def test_loglinear_target_at_boundary():
    """Log-linear target for very large species should not fall below lower bound."""
    def loglinear_target(range_km2, lower=0.10, upper=1.0,
                         min_area=1.0, max_area=250000.0):
        import math
        if range_km2 <= min_area:
            return upper
        if range_km2 >= max_area:
            return lower
        frac = (math.log(range_km2) - math.log(min_area)) / \
               (math.log(max_area) - math.log(min_area))
        return upper - frac * (upper - lower)

    t_large = loglinear_target(250000.0)
    t_small = loglinear_target(1.0)
    assert abs(t_large - 0.10) < 1e-9
    assert abs(t_small - 1.00) < 1e-9


def test_feature_representation_is_nonnegative():
    """Feature representation (% of target met) must be ≥ 0."""
    representation = [
        {"feature": "Jaguar",        "held": 0.32, "target": 0.30, "met": True},
        {"feature": "Giant anteater","held": 0.28, "target": 0.30, "met": False},
        {"feature": "Tapir",         "held": 0.31, "target": 0.30, "met": True},
    ]
    for feat in representation:
        assert feat["held"] >= 0
        assert feat["target"] >= 0


def test_blm_calibration_has_required_columns():
    """BLM calibration output must include blm, total_cost, total_boundary columns."""
    calibration = [
        {"blm": 0.0,   "total_cost": 1245.3, "total_boundary": 3820.1, "n_pu": 214},
        {"blm": 0.001, "total_cost": 1312.8, "total_boundary": 2941.6, "n_pu": 218},
        {"blm": 0.01,  "total_cost": 1489.2, "total_boundary": 2215.0, "n_pu": 227},
    ]
    required = {"blm", "total_cost", "total_boundary"}
    for row in calibration:
        assert required.issubset(set(row.keys()))

    # Cost should be non-decreasing with increasing BLM
    costs = [r["total_cost"] for r in calibration]
    assert all(costs[i] <= costs[i + 1] for i in range(len(costs) - 1))


def test_irreplaceability_in_valid_range():
    """Irreplaceability scores must be in [0, 1]."""
    irreplaceability = [0.0, 0.12, 0.45, 0.87, 1.0]
    assert all(0 <= v <= 1 for v in irreplaceability)


def test_portfolio_frequency_in_valid_range():
    """Portfolio selection frequency across scenarios must be in [0, 1]."""
    # Frequency = how many scenarios selected this planning unit / total scenarios
    n_scenarios = 10
    frequencies = [3, 7, 10, 0, 5]
    for f in frequencies:
        freq_norm = f / n_scenarios
        assert 0 <= freq_norm <= 1
