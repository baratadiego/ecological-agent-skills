"""
Tests for environmental-time-series skill scripts.
Run: pytest tests/python/test_environmental_time_series.py -v
"""
import pytest
import sys
import numpy as np
import pandas as pd
from pathlib import Path

DATA   = Path(__file__).parents[1] / "data"
SCRIPT = Path(__file__).parents[2] / "skills" / "environmental-time-series" / "scripts" / "trend_analysis.py"
RECOVERY = Path(__file__).parents[2] / "skills" / "environmental-time-series" / "scripts" / "recovery_trajectory.py"

sys.path.insert(0, str(SCRIPT.parent))

import importlib.util

def load_mod(path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

trend_mod    = load_mod(SCRIPT)
recovery_mod = load_mod(RECOVERY)


class TestAnomalyComputation:
    def test_zero_anomaly_at_mean(self):
        values = np.array([1.0, 2.0, 3.0, 2.0, 1.0, 3.0, 2.0, 2.0, 2.0, 2.0])
        baseline_n = 8
        anomalies = trend_mod.compute_anomalies(values, baseline_n)
        # The baseline mean is 2.0; the mean of the baseline period should produce z≈0
        assert abs(np.mean(anomalies[:baseline_n])) < 0.5

    def test_positive_anomaly_above_mean(self):
        baseline = np.ones(20) * 0.5
        spike    = np.array([1.5])
        values   = np.concatenate([baseline, spike])
        anomalies = trend_mod.compute_anomalies(values, 20)
        assert anomalies[-1] > 2.0  # 1.5 is far above baseline of 0.5

    def test_anomaly_same_length_as_input(self):
        values = np.random.rand(60)
        anomalies = trend_mod.compute_anomalies(values, 24)
        assert len(anomalies) == len(values)


class TestDecomposition:
    def test_decompose_returns_three_components(self):
        t = np.arange(60)
        seasonal = np.sin(2 * np.pi * t / 12) * 0.1
        trend    = 0.5 + 0.001 * t
        values   = trend + seasonal + np.random.default_rng(42).normal(0, 0.01, 60)
        tr, se, re = trend_mod.seasonal_decompose_simple(values, freq=12)
        assert len(tr) == len(values)
        assert len(se) == len(values)
        assert len(re) == len(values)

    def test_trend_component_monotonic_for_linear_trend(self):
        t = np.arange(48)
        values = 0.5 + 0.005 * t  # pure linear trend, no seasonal
        tr, se, re = trend_mod.seasonal_decompose_simple(values, freq=12)
        # Trend component (ignoring edges) should be mostly increasing
        mid = tr[6:-6]
        diffs = np.diff(mid[~np.isnan(mid)])
        assert np.sum(diffs > 0) > len(diffs) * 0.8


class TestRecovery:
    def test_recovery_on_test_data(self, tmp_path):
        df = pd.read_csv(DATA / "ndvi_monthly_series.csv")
        assert len(df) == 240
        # Call core recovery logic
        dist_dt  = pd.to_datetime("2010-01-01")
        date_col = df.columns[0]
        val_col  = "value"
        df[date_col] = pd.to_datetime(df[date_col])
        pre  = df[df[date_col] < dist_dt]
        post = df[df[date_col] >= dist_dt].copy()
        baseline_mean = pre.tail(24)[val_col].mean()
        from scipy.ndimage import uniform_filter1d
        smooth  = uniform_filter1d(post[val_col].values, size=3)
        min_val = np.nanmin(smooth)
        min_idx = np.nanargmin(smooth)
        # Minimum should occur within first 18 months after disturbance
        assert min_idx < 18, f"Minimum too late: month {min_idx}"
        # Baseline should be higher than minimum (disturbance caused drop)
        assert baseline_mean > min_val

    def test_ri_at_minimum_is_zero(self):
        baseline_mean = 0.70
        min_val       = 0.50
        values        = np.array([0.50, 0.55, 0.60, 0.65, 0.70])
        ri = (values - min_val) / (baseline_mean - min_val + 1e-10)
        assert ri[0] == pytest.approx(0.0, abs=0.01)

    def test_ri_at_baseline_is_one(self):
        baseline_mean = 0.70
        min_val       = 0.50
        ri_at_baseline = (baseline_mean - min_val) / (baseline_mean - min_val + 1e-10)
        assert ri_at_baseline == pytest.approx(1.0, abs=0.01)

    def test_recovery_script_produces_files(self, tmp_path):
        recovery_mod.main.__code__  # just confirm module loaded
        import subprocess, sys
        result = subprocess.run(
            [sys.executable, str(RECOVERY),
             str(DATA / "ndvi_monthly_series.csv"),
             "2010-01-01",
             str(tmp_path)],
            capture_output=True, text=True
        )
        assert result.returncode == 0, f"Script failed:\n{result.stderr}"
        assert (tmp_path / "recovery_metrics.csv").exists()
        assert (tmp_path / "recovery_trajectory.png").exists()
        assert (tmp_path / "recovery_indicator.csv").exists()
        metrics = pd.read_csv(tmp_path / "recovery_metrics.csv")
        assert metrics["magnitude_decline_pct"].iloc[0] > 5  # real drop visible


class TestTrendEndToEnd:
    def test_trend_script_on_ndvi_data(self, tmp_path):
        import subprocess, sys
        result = subprocess.run(
            [sys.executable, str(SCRIPT),
             str(DATA / "ndvi_monthly_series.csv"),
             str(tmp_path), "12"],
            capture_output=True, text=True
        )
        assert result.returncode == 0, f"Script failed:\n{result.stderr}"
        assert (tmp_path / "anomaly_series.csv").exists()
        assert (tmp_path / "anomaly_plot.png").exists()
