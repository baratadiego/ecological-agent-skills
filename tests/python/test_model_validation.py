# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Tests for model-validation-and-uncertainty skill scripts.
Run: pytest tests/python/test_model_validation.py -v
"""
import pytest
import sys
import math
import numpy as np
import pandas as pd
from pathlib import Path

DATA   = Path(__file__).parents[1] / "data"
SCRIPT = Path(__file__).parents[2] / "skills" / "model-validation-and-uncertainty" / "scripts" / "validate_model.py"

sys.path.insert(0, str(SCRIPT.parent))
import importlib.util
spec = importlib.util.spec_from_file_location("validate_model", SCRIPT)
mod  = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class TestTSS:
    def test_perfect_classifier(self):
        y_true = np.array([1,1,1,0,0,0])
        y_pred = np.array([0.9,0.8,0.7,0.1,0.2,0.3])
        tss, thresh = mod.compute_tss(y_true, y_pred)
        assert tss == pytest.approx(1.0, abs=0.05)

    def test_random_classifier(self):
        rng = np.random.default_rng(42)
        y_true = rng.integers(0, 2, size=200)
        y_pred = rng.random(200)
        tss, thresh = mod.compute_tss(y_true, y_pred)
        assert abs(tss) < 0.25, f"Random classifier TSS should be near 0, got {tss:.3f}"

    def test_tss_range(self):
        rng = np.random.default_rng(0)
        y_true = rng.integers(0, 2, size=100)
        y_pred = rng.random(100)
        tss, thresh = mod.compute_tss(y_true, y_pred)
        assert -1.0 <= tss <= 1.0

    def test_threshold_in_range(self):
        rng = np.random.default_rng(1)
        y_true = rng.integers(0, 2, size=100)
        y_pred = rng.random(100)
        tss, thresh = mod.compute_tss(y_true, y_pred)
        assert 0.0 <= thresh <= 1.0


class TestCalibration:
    def test_perfect_calibration(self, tmp_path):
        """Well-calibrated predictions produce a plot without error."""
        rng = np.random.default_rng(42)
        y_true = rng.integers(0, 2, size=300)
        y_pred = np.clip(y_true + rng.normal(0, 0.2, 300), 0, 1)
        out = tmp_path / "calibration.png"
        mod.calibration_plot(y_true, y_pred, out)
        assert out.exists()
        assert out.stat().st_size > 1000

    def test_roc_plot(self, tmp_path):
        from sklearn.metrics import roc_auc_score
        rng = np.random.default_rng(42)
        y_true = rng.integers(0, 2, 200)
        y_pred = rng.random(200)
        auc = roc_auc_score(y_true, y_pred)
        out = tmp_path / "roc.png"
        mod.roc_plot(y_true, y_pred, auc, out)
        assert out.exists()


class TestEndToEnd:
    def test_on_test_dataset(self, tmp_path):
        df = pd.read_csv(DATA / "model_predictions.csv")
        assert "observed" in df.columns
        assert "predicted" in df.columns
        y_true = df["observed"].values
        y_pred = df["predicted"].values
        from sklearn.metrics import roc_auc_score
        auc = roc_auc_score(y_true, y_pred)
        tss, thresh = mod.compute_tss(y_true, y_pred)
        # The test data was generated with a real signal — AUC should be decent
        assert auc > 0.65, f"AUC too low for signal data: {auc:.3f}"
        assert tss > 0.2,  f"TSS too low: {tss:.3f}"
        assert 0 < thresh < 1
