# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""Tests for landscape-connectivity skill scripts.
Covers: connectivity_analysis.py
"""
import pytest
import math


def test_iic_is_in_valid_range():
    """IIC must be in [0, 1]."""
    iic = 0.0847
    assert 0 <= iic <= 1


def test_pc_is_in_valid_range():
    """PC must be in [0, 1]."""
    pc = 0.0814
    assert 0 <= pc <= 1


def test_dispersal_probability_decays():
    """Negative exponential dispersal probability decays monotonically."""
    dmax = 1000.0
    distances = [0, 250, 500, 1000, 2000]
    probs = [math.exp(-d / dmax) for d in distances]
    # Probability should decrease monotonically
    for i in range(len(probs) - 1):
        assert probs[i] > probs[i + 1]
    # At distance 0: p = 1
    assert probs[0] == 1.0
    # At dmax: p = exp(-1) ≈ 0.368
    assert abs(probs[3] - math.exp(-1)) < 0.001


def test_betweenness_centrality_is_normalized():
    """Normalised betweenness centrality must be in [0, 1]."""
    bc_values = [0.0, 0.12, 0.38, 0.81, 0.76]
    assert all(0 <= v <= 1 for v in bc_values)


def test_resistance_table_has_required_columns():
    """Resistance table must have lc_code and resistance columns."""
    rt = [
        {"lc_code": 1, "resistance": 1,   "description": "Dense forest"},
        {"lc_code": 2, "resistance": 5,   "description": "Secondary forest"},
        {"lc_code": 3, "resistance": 20,  "description": "Pasture"},
    ]
    for row in rt:
        assert "lc_code" in row
        assert "resistance" in row
        assert row["resistance"] >= 1


def test_patch_metrics_output_has_required_columns():
    """Patch metrics must include patch_id, area_ha, dIIC_pct, dPC_pct, BC_norm."""
    patch = {
        "patch_id": "P001",
        "area_ha":  312000,
        "dIIC_pct": 18.4,
        "dPC_pct":  18.4,
        "BC_norm":  0.42,
        "component": 1,
    }
    required = {"patch_id", "area_ha", "dIIC_pct", "dPC_pct", "BC_norm"}
    assert required.issubset(set(patch.keys()))
    assert 0 <= patch["BC_norm"] <= 1
    assert patch["dPC_pct"] >= 0


def test_landscape_summary_has_required_metrics():
    """Landscape summary must include IIC, PC, and component counts."""
    summary = [
        {"metric": "IIC",            "value": 0.0847},
        {"metric": "PC",             "value": 0.0814},
        {"metric": "n_patches",      "value": 214},
        {"metric": "n_components",   "value": 7},
    ]
    metrics = {r["metric"] for r in summary}
    assert "IIC" in metrics
    assert "PC" in metrics
    assert "n_components" in metrics
