"""
Tests for predictive-modeling-best-practices skill scripts.
Run: pytest tests/python/test_predictive_modeling.py -v
"""
import pytest
import sys
import numpy as np
import pandas as pd
from pathlib import Path

DATA   = Path(__file__).parents[1] / "data"
SCRIPT = Path(__file__).parents[2] / "skills" / "predictive-modeling-best-practices" / "scripts" / "spatial_cv.py"

sys.path.insert(0, str(SCRIPT.parent))
import importlib.util
spec = importlib.util.spec_from_file_location("spatial_cv", SCRIPT)
mod  = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class TestSpatialBlocks:
    def make_df(self, n=100, seed=42):
        rng = np.random.default_rng(seed)
        return pd.DataFrame({
            "decimalLongitude": rng.uniform(-60, -45, n),
            "decimalLatitude":  rng.uniform(-15, -5,  n),
            "pa": rng.integers(0, 2, n),
        })

    def test_all_points_get_fold(self):
        df = self.make_df()
        np.random.seed(42)
        df["cv_fold"] = mod.assign_spatial_blocks(
            df, "decimalLongitude", "decimalLatitude", 1.0, 5)
        assert df["cv_fold"].isna().sum() == 0

    def test_fold_values_in_range(self):
        df = self.make_df()
        np.random.seed(42)
        df["cv_fold"] = mod.assign_spatial_blocks(
            df, "decimalLongitude", "decimalLatitude", 1.0, 5)
        assert df["cv_fold"].min() >= 1
        assert df["cv_fold"].max() <= 5

    def test_n_folds_correct(self):
        df = self.make_df(500)
        np.random.seed(42)
        df["cv_fold"] = mod.assign_spatial_blocks(
            df, "decimalLongitude", "decimalLatitude", 1.0, 5)
        n_folds = df["cv_fold"].nunique()
        assert n_folds == 5

    def test_spatial_clustering_preserved(self):
        """Points close together should tend to fall in the same fold."""
        np.random.seed(42)
        # Create two distant clusters
        lons = np.concatenate([np.random.uniform(-60,-58,50), np.random.uniform(-47,-45,50)])
        lats = np.concatenate([np.random.uniform(-15,-14,50), np.random.uniform(-6,-5,50)])
        df   = pd.DataFrame({"decimalLongitude":lons,"decimalLatitude":lats})
        df["cv_fold"] = mod.assign_spatial_blocks(df,"decimalLongitude","decimalLatitude", 2.0, 5)
        cluster1 = df.iloc[:50]["cv_fold"]
        cluster2 = df.iloc[50:]["cv_fold"]
        # Within a cluster, variance of fold assignment should be low
        assert cluster1.nunique() <= 3
        assert cluster2.nunique() <= 3


class TestCollinearityReport:
    def test_high_correlation_detected(self):
        rng = np.random.default_rng(42)
        x = rng.normal(0, 1, 100)
        df = pd.DataFrame({"var1": x, "var2": x + rng.normal(0, 0.05, 100),
                           "var3": rng.normal(0, 1, 100)})
        result = mod.collinearity_report(df, ["var1","var2","var3"], r_thresh=0.7)
        assert len(result) >= 1
        assert "var1" in result["var1"].values or "var1" in result["var2"].values

    def test_uncorrelated_not_flagged(self):
        rng = np.random.default_rng(42)
        df = pd.DataFrame({
            "a": rng.normal(0, 1, 200),
            "b": rng.normal(0, 1, 200),
            "c": rng.normal(0, 1, 200),
        })
        result = mod.collinearity_report(df, ["a","b","c"], r_thresh=0.7)
        assert len(result) == 0

    def test_report_has_correct_columns(self):
        rng = np.random.default_rng(42)
        x = rng.normal(0, 1, 100)
        df = pd.DataFrame({"a": x, "b": x + rng.normal(0, 0.01, 100)})
        result = mod.collinearity_report(df, ["a","b"], r_thresh=0.7)
        assert "var1" in result.columns
        assert "var2" in result.columns
        assert "spearman_r" in result.columns


class TestEndToEnd:
    def test_script_on_env_data(self, tmp_path):
        import subprocess, sys
        result = subprocess.run(
            [sys.executable, str(SCRIPT),
             str(DATA / "points_with_env.csv"),
             str(tmp_path), "5", "300"],
            capture_output=True, text=True
        )
        assert result.returncode == 0, f"Script failed:\n{result.stderr}"
        out_csv = tmp_path / "data_with_cv_folds.csv"
        assert out_csv.exists()
        df = pd.read_csv(out_csv)
        assert "cv_fold" in df.columns
        assert df["cv_fold"].nunique() == 5
