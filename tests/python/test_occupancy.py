# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Tests for occupancy-and-detection skill scripts.
Run: pytest tests/python/test_occupancy.py -v
"""
import pytest
import sys
import numpy as np
import pandas as pd
from pathlib import Path

DATA   = Path(__file__).parents[1] / "data"
SCRIPT = Path(__file__).parents[2] / "skills" / "occupancy-and-detection" / "scripts" / "occupancy_analysis.py"

sys.path.insert(0, str(SCRIPT.parent))
import importlib.util
spec = importlib.util.spec_from_file_location("occupancy_analysis", SCRIPT)
mod  = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class TestNaiveOccupancy:
    def test_all_occupied(self):
        dh = np.ones((10, 3))
        assert mod.compute_naive_occ(dh) == pytest.approx(1.0)

    def test_none_occupied(self):
        dh = np.zeros((10, 3))
        assert mod.compute_naive_occ(dh) == pytest.approx(0.0)

    def test_half_occupied(self):
        dh = np.vstack([np.ones((5,3)), np.zeros((5,3))])
        assert mod.compute_naive_occ(dh) == pytest.approx(0.5)

    def test_with_nas(self):
        dh = np.array([[1, np.nan, 0],
                       [0, 0, 0],
                       [np.nan, 1, np.nan]])
        result = mod.compute_naive_occ(dh)
        # Sites 0 and 2 detected → 2/3
        assert result == pytest.approx(2/3, abs=0.01)

    def test_range(self):
        rng = np.random.default_rng(42)
        dh = rng.choice([0, 1], size=(20, 5)).astype(float)
        result = mod.compute_naive_occ(dh)
        assert 0.0 <= result <= 1.0


class TestDetectionSummary:
    def test_correct_n_surveyed_with_nas(self):
        dh = np.array([[1, np.nan, 0],
                       [0, 1, np.nan]])
        summary = mod.detection_summary(dh)
        assert list(summary["n_surveyed"]) == [2, 1, 1]

    def test_correct_detection_counts(self):
        dh = np.array([[1, 0, 1],
                       [1, 1, 0]])
        summary = mod.detection_summary(dh)
        assert list(summary["n_detections"]) == [2, 1, 1]

    def test_detection_rate_in_range(self):
        rng = np.random.default_rng(1)
        dh = rng.choice([0.0, 1.0], size=(20, 5))
        summary = mod.detection_summary(dh)
        assert (summary["detection_rate"] >= 0).all()
        assert (summary["detection_rate"] <= 1).all()


class TestValidation:
    def test_raises_on_invalid_values(self):
        dh = np.array([[1, 2, 0]])  # 2 is invalid
        with pytest.raises(ValueError, match="0, 1, or NA"):
            mod.validate_detection_history(dh)

    def test_raises_on_all_na_row(self):
        dh = np.array([[1, 0, 1], [np.nan, np.nan, np.nan]])
        with pytest.raises(ValueError):
            mod.validate_detection_history(dh)

    def test_valid_data_passes(self):
        dh = np.array([[1, 0, np.nan], [0, 0, 0], [1, 1, 1]])
        mod.validate_detection_history(dh)  # should not raise


class TestEndToEnd:
    def test_test_dataset_naive_occ_plausible(self):
        df = pd.read_csv(DATA / "detection_history.csv", index_col=0)
        dh = df.replace("", np.nan).values.astype(float)
        naive = mod.compute_naive_occ(dh)
        # Generated with true psi=0.65; naive should be in [0.4, 0.85]
        assert 0.40 <= naive <= 0.85, f"Naive occupancy implausible: {naive:.3f}"
