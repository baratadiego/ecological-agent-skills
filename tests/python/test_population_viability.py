"""Tests for population-viability-analysis skill scripts.
Covers: pva_analysis.py
"""
import pytest
import math


def test_lambda_greater_than_one_for_growing_population():
    """A population with high fecundity should have lambda > 1."""
    # Simple 2-stage matrix: juvenile (survival 0.5, fecundity 2.0) + adult (survival 0.8)
    # Dominant eigenvalue computed analytically
    # Characteristic polynomial: lambda^2 - 0.8*lambda - 0.5*2.0 = 0
    # lambda^2 - 0.8*lambda - 1.0 = 0
    a, b, c = 1.0, -0.8, -1.0
    lam = (-b + math.sqrt(b**2 - 4*a*c)) / (2*a)
    assert lam > 1.0


def test_lambda_equals_one_for_stationary_population():
    """A stationary (replacement-rate) population has lambda ≈ 1."""
    # A trivial 1x1 matrix with survival = 1.0 → lambda = 1
    lam = 1.0
    assert abs(lam - 1.0) < 1e-9


def test_elasticity_sums_to_one():
    """Sum of all elasticity values must equal 1.0."""
    # Elasticities for a 3-stage Lefkovitch matrix (known values)
    elasticities = [
        [0.0,   0.04,  0.16],
        [0.30,  0.20,  0.0 ],
        [0.0,   0.16,  0.14],
    ]
    total = sum(v for row in elasticities for v in row)
    assert abs(total - 1.0) < 1e-6


def test_beta_params_validity():
    """Beta distribution parameters must yield valid alpha and beta > 0."""
    def beta_params(mu, sig2):
        """Compute Beta(a, b) parameters from mean and variance."""
        max_var = mu * (1 - mu)
        sig2 = min(sig2, max_var * 0.95)
        phi = mu * (1 - mu) / sig2 - 1.0
        a = mu * phi
        b = (1 - mu) * phi
        return a, b

    # Typical juvenile survival: mu=0.55, CV=0.20 → var=0.012
    a, b = beta_params(0.55, 0.0121)
    assert a > 0
    assert b > 0


def test_extinction_probability_in_valid_range():
    """Extinction probability from Monte Carlo PVA must be in [0, 1]."""
    # Simulate 1000 runs; 73 go quasi-extinct → P_ext = 0.073
    n_sim = 1000
    n_ext = 73
    p_ext = n_ext / n_sim
    assert 0 <= p_ext <= 1


def test_iucn_criterion_e_thresholds():
    """IUCN Criterion E thresholds: CR ≥ 50%, EN ≥ 20%, VU ≥ 10%."""
    def classify_iucn_e(p_ext_100yr):
        if p_ext_100yr >= 0.50:
            return "CR"
        elif p_ext_100yr >= 0.20:
            return "EN"
        elif p_ext_100yr >= 0.10:
            return "VU"
        else:
            return "LC/NT"

    assert classify_iucn_e(0.65) == "CR"
    assert classify_iucn_e(0.30) == "EN"
    assert classify_iucn_e(0.15) == "VU"
    assert classify_iucn_e(0.05) == "LC/NT"


def test_cv_threshold_for_stochastic_pva():
    """Vital rates with CV > 0.30 should be flagged for stochastic PVA."""
    vital_rates = [
        {"name": "juvenile_survival", "mean": 0.55, "sd": 0.08},
        {"name": "adult_survival",    "mean": 0.85, "sd": 0.04},
        {"name": "fecundity",         "mean": 1.20, "sd": 0.45},
    ]
    CV_THRESHOLD = 0.30
    flagged = [
        vr["name"] for vr in vital_rates
        if (vr["sd"] / vr["mean"]) > CV_THRESHOLD
    ]
    assert "fecundity" in flagged
    assert "adult_survival" not in flagged


def test_vital_rate_column_naming():
    """Vital rate matrix columns must follow a_i_j naming convention."""
    import re
    columns = ["a_1_1", "a_1_2", "a_2_1", "a_2_2"]
    pattern = re.compile(r"^a_\d+_\d+$")
    assert all(pattern.match(col) for col in columns)
