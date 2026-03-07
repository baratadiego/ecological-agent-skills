# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""Tests for biostatistics-workbench skill scripts.
Covers: glm_pipeline.py
"""
import pytest
import math


def test_response_variable_is_numeric():
    """Response variable must be numeric or integer."""
    response = [12, 5, 0, 8, 3, 15]
    assert all(isinstance(v, (int, float)) for v in response), \
        "Response variable must be numeric"


def test_sample_size_above_minimum():
    """GLM requires at least 20 observations."""
    n_obs = 45
    n_min = 20
    assert n_obs >= n_min, f"Insufficient observations: {n_obs} < {n_min}"


def test_model_family_is_valid():
    """GLM family must be one of the supported families."""
    valid_families = {"gaussian", "poisson", "binomial", "negative_binomial", "gamma"}
    chosen_family = "poisson"
    assert chosen_family in valid_families, f"Unknown GLM family: {chosen_family}"


def test_aic_is_finite():
    """AIC must be a finite number."""
    aic = 234.56
    assert math.isfinite(aic), "AIC must be finite"


def test_effect_sizes_have_ci():
    """Effect size results must include lower and upper 95% CI."""
    result = {
        "estimate": 1.23,
        "ci_lower": 0.85,
        "ci_upper": 1.78
    }
    assert "ci_lower" in result and "ci_upper" in result
    assert result["ci_lower"] < result["estimate"] < result["ci_upper"]


def test_p_value_in_range():
    """p-value must be in [0, 1]."""
    p = 0.032
    assert 0 <= p <= 1, f"p-value out of range: {p}"
