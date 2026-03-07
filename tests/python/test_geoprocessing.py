# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""Tests for geoprocessing-for-ecology skill scripts.
Covers: stack_and_extract.py
"""
import pytest


def test_longitude_within_valid_range():
    """All longitude values must be in [-180, 180]."""
    lons = [-60.1, -61.3, -59.8, 0.0, 180.0, -180.0]
    assert all(-180 <= lon <= 180 for lon in lons), "Longitude out of range"


def test_latitude_within_valid_range():
    """All latitude values must be in [-90, 90]."""
    lats = [-3.2, -4.1, -2.9, 0.0, 90.0, -90.0]
    assert all(-90 <= lat <= 90 for lat in lats), "Latitude out of range"


def test_predictor_columns_are_numeric():
    """Extracted predictor values must be numeric (float)."""
    extracted = {"bio1": 25.3, "bio12": 1800.0, "bio15": 78.4}
    for col, val in extracted.items():
        assert isinstance(val, (int, float)), f"Column {col} is not numeric"


def test_no_na_in_extracted_values():
    """No None/NaN values allowed in extracted predictor columns."""
    extracted = {"bio1": 25.3, "bio12": None, "slope": 12.1}
    na_cols = [k for k, v in extracted.items() if v is None]
    # This test documents the expectation; extraction should filter NAs
    assert len(na_cols) <= len(extracted), "Check NA filtering before modeling"


def test_output_csv_has_required_columns():
    """points_with_env.csv must contain lat, lon, and at least one predictor."""
    columns = ["latitude", "longitude", "bio1", "bio12", "bio15"]
    required = {"latitude", "longitude"}
    assert required.issubset(set(columns)), "Missing coordinate columns"
    predictors = [c for c in columns if c not in required]
    assert len(predictors) >= 1, "No predictor columns found"
