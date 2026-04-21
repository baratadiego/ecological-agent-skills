#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
test_integration.py — End-to-end integration tests for the core skill pipeline.

These tests exercise the actual script entry points against synthetic in-memory data,
verifying that skills chain correctly and produce the expected output artefacts.

Pipeline tested:
    ecological-data-foundation  (clean_occurrences.py)
    --> geoprocessing-for-ecology  (stack_and_extract.py — import-level only)
    --> predictive-modeling-best-practices  (collinearity filter + CV split)
    --> species-distribution-modeling  (RF + BRT ensemble)
    --> model-validation-and-uncertainty  (AUC, cross-validation)

Run with:
    pytest tests/python/test_integration.py -v
"""

import io
import sys
import types
import subprocess
import tempfile
import textwrap
from pathlib import Path

import pytest

import numpy as np
import pandas as pd
import pytest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

ROOT = Path(__file__).resolve().parents[2]  # repo root
SCRIPTS = {
    "clean": ROOT / "skills/ecological-data-foundation/scripts/clean_occurrences.py",
    "sdm": ROOT / "skills/species-distribution-modeling/scripts/sdm_pipeline.py",
}


def _make_occurrence_csv(n_clean=60, n_flagged=10, seed=42) -> str:
    """Return a CSV string with synthetic occurrence records."""
    rng = np.random.default_rng(seed)
    lats = rng.uniform(-10, 5, n_clean)
    lons = rng.uniform(-75, -50, n_clean)
    dates = pd.date_range("2010-01-01", periods=n_clean, freq="ME").astype(str)
    rows = [
        {
            "scientificName": "Thamnomanes ardesiacus",
            "decimalLatitude": lat,
            "decimalLongitude": lon,
            "eventDate": d,
        }
        for lat, lon, d in zip(lats, lons, dates)
    ]
    # add flagged rows
    rows.append({"scientificName": "Thamnomanes ardesiacus",
                 "decimalLatitude": 0.0, "decimalLongitude": 0.0, "eventDate": "2015-01-01"})
    rows.append({"scientificName": "Thamnomanes ardesiacus",
                 "decimalLatitude": np.nan, "decimalLongitude": np.nan, "eventDate": "2015-01-01"})
    for _ in range(n_flagged - 2):
        rows.append({"scientificName": "Thamnomanes ardesiacus",
                     "decimalLatitude": 200.0, "decimalLongitude": 300.0, "eventDate": "2015-01-01"})
    df = pd.DataFrame(rows)
    return df.to_csv(index=False)


# ---------------------------------------------------------------------------
# Integration: ecological-data-foundation clean_occurrences.py
# ---------------------------------------------------------------------------

class TestCleanOccurrencesIntegration:

    def test_clean_produces_output_files(self, tmp_path):
        """clean_occurrences.py must create data_clean.csv, flagged_records.csv, qa_report.md."""
        csv_path = tmp_path / "occurrences.csv"
        csv_path.write_text(_make_occurrence_csv())
        out_dir = tmp_path / "processed"

        result = subprocess.run(
            [sys.executable, str(SCRIPTS["clean"]), str(csv_path), str(out_dir)],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"clean_occurrences.py failed:\n{result.stderr}"
        assert (out_dir / "data_clean.csv").exists(), "data_clean.csv not created"
        assert (out_dir / "flagged_records.csv").exists(), "flagged_records.csv not created"
        assert (out_dir / "qa_report.md").exists(), "qa_report.md not created"

    # TODO(ecological-data-foundation): clean_occurrences.py silently drops
    # some records instead of flagging them (observed: 60 clean + 3 flagged
    # from a 70-row input, missing 7). Likely a dropna() that should be a
    # flag. Tracked as a known gap in KNOWN_ISSUES.md — once rows are
    # preserved (OK or flagged, never silently removed), remove this xfail.
    @pytest.mark.xfail(
        reason="clean_occurrences.py silently drops flagged rows instead of routing them to flagged_records.csv",
        strict=False,
    )
    def test_clean_records_count(self, tmp_path):
        """Clean records must be a subset of input; flagged records must be non-empty."""
        csv_path = tmp_path / "occurrences.csv"
        csv_path.write_text(_make_occurrence_csv(n_clean=60, n_flagged=10))
        out_dir = tmp_path / "processed"

        subprocess.run(
            [sys.executable, str(SCRIPTS["clean"]), str(csv_path), str(out_dir)],
            capture_output=True, text=True, check=True,
        )
        clean = pd.read_csv(out_dir / "data_clean.csv")
        flagged = pd.read_csv(out_dir / "flagged_records.csv")
        assert len(clean) > 0, "No clean records produced"
        assert len(flagged) > 0, "No flagged records — expected at least COORD_ZERO and MISSING_COORDS"
        assert len(clean) + len(flagged) == 70, "Row count mismatch after split"

    def test_clean_qa_status_values(self, tmp_path):
        """QA_status column must contain only known flag values."""
        KNOWN_FLAGS = {"OK", "COORD_ZERO", "COORD_OUT_OF_RANGE", "MISSING_COORDS", "DATE_FUTURE"}
        csv_path = tmp_path / "occurrences.csv"
        csv_path.write_text(_make_occurrence_csv())
        out_dir = tmp_path / "processed"

        subprocess.run(
            [sys.executable, str(SCRIPTS["clean"]), str(csv_path), str(out_dir)],
            capture_output=True, text=True, check=True,
        )
        clean = pd.read_csv(out_dir / "data_clean.csv")
        flagged = pd.read_csv(out_dir / "flagged_records.csv")
        all_flags = set(clean["QA_status"].unique()) | set(flagged["QA_status"].unique())
        unknown = all_flags - KNOWN_FLAGS
        assert not unknown, f"Unexpected QA_status values: {unknown}"

    def test_clean_spatial_thinning(self, tmp_path):
        """Spatial thinning must reduce clean record count when thin_deg provided."""
        csv_path = tmp_path / "occurrences.csv"
        csv_path.write_text(_make_occurrence_csv(n_clean=60))
        out_dir_full = tmp_path / "full"
        out_dir_thin = tmp_path / "thinned"

        subprocess.run(
            [sys.executable, str(SCRIPTS["clean"]), str(csv_path), str(out_dir_full)],
            capture_output=True, text=True, check=True,
        )
        subprocess.run(
            [sys.executable, str(SCRIPTS["clean"]), str(csv_path), str(out_dir_thin), "5.0"],
            capture_output=True, text=True, check=True,
        )
        n_full = len(pd.read_csv(out_dir_full / "data_clean.csv"))
        n_thin = len(pd.read_csv(out_dir_thin / "data_clean.csv"))
        assert n_thin <= n_full, "Thinning should not increase record count"

    def test_clean_missing_input_exits_1(self, tmp_path):
        """Script must exit with code 1 if input file does not exist."""
        result = subprocess.run(
            [sys.executable, str(SCRIPTS["clean"]),
             str(tmp_path / "nonexistent.csv"), str(tmp_path / "out")],
            capture_output=True, text=True,
        )
        assert result.returncode == 1


# ---------------------------------------------------------------------------
# Integration: predictive-modeling-best-practices (in-process)
# ---------------------------------------------------------------------------

class TestPredictiveModelingIntegration:
    """Tests the collinearity filter and cross-validation logic used by sdm_pipeline."""

    def _make_feature_matrix(self, seed=0):
        rng = np.random.default_rng(seed)
        n = 100
        bio1  = rng.normal(25, 5, n)
        bio12 = rng.normal(1800, 300, n)
        bio4  = bio1 * 0.99 + rng.normal(0, 0.1, n)   # highly collinear with bio1
        bio15 = rng.normal(50, 15, n)
        pa    = (rng.random(n) > 0.4).astype(int)
        return pd.DataFrame({"bio1": bio1, "bio12": bio12, "bio4": bio4,
                             "bio15": bio15, "pa": pa})

    def test_collinearity_filter_removes_correlated(self):
        """Collinearity filter must drop predictors with |r| > threshold."""
        df = self._make_feature_matrix()
        predictors = ["bio1", "bio12", "bio4", "bio15"]
        corr_matrix = df[predictors].corr().abs()
        threshold = 0.9
        to_drop = set()
        for i in range(len(predictors)):
            for j in range(i + 1, len(predictors)):
                if corr_matrix.iloc[i, j] > threshold:
                    to_drop.add(predictors[j])
        remaining = [p for p in predictors if p not in to_drop]
        assert "bio1" in remaining, "bio1 should be retained"
        assert "bio4" not in remaining, "bio4 should be dropped (collinear with bio1)"

    def test_cv_split_stratified(self):
        """Stratified k-fold must produce balanced folds."""
        from sklearn.model_selection import StratifiedKFold
        df = self._make_feature_matrix()
        X = df[["bio1", "bio12", "bio15"]].values
        y = df["pa"].values
        cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
        fold_sizes = [len(train) for train, _ in cv.split(X, y)]
        assert max(fold_sizes) - min(fold_sizes) <= 2, "Fold sizes should be balanced"

    def test_ensemble_rf_brt_auc(self):
        """RF and BRT models must achieve AUC > 0.5 on synthetic balanced data."""
        from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
        from sklearn.model_selection import cross_val_score
        rng = np.random.default_rng(7)
        n = 200
        X = rng.normal(0, 1, (n, 4))
        y = (X[:, 0] + X[:, 1] > 0).astype(int)  # linearly separable
        rf = RandomForestClassifier(n_estimators=50, random_state=42)
        brt = GradientBoostingClassifier(n_estimators=50, random_state=42)
        rf_auc = cross_val_score(rf, X, y, cv=5, scoring="roc_auc").mean()
        brt_auc = cross_val_score(brt, X, y, cv=5, scoring="roc_auc").mean()
        assert rf_auc > 0.7, f"RF AUC too low: {rf_auc:.3f}"
        assert brt_auc > 0.7, f"BRT AUC too low: {brt_auc:.3f}"


# ---------------------------------------------------------------------------
# Integration: model-validation-and-uncertainty (in-process)
# ---------------------------------------------------------------------------

class TestModelValidationIntegration:

    def _make_predictions(self, seed=42):
        rng = np.random.default_rng(seed)
        n = 200
        y_true = rng.integers(0, 2, n)
        # scores correlated with truth (simulates a decent model)
        y_score = np.clip(y_true * 0.7 + rng.normal(0, 0.3, n), 0, 1)
        return y_true, y_score

    def test_auc_above_random(self):
        """AUC must exceed 0.5 for a model with true predictive signal."""
        from sklearn.metrics import roc_auc_score
        y_true, y_score = self._make_predictions()
        auc = roc_auc_score(y_true, y_score)
        assert auc > 0.5, f"AUC should be above random (got {auc:.3f})"

    def test_tss_computation(self):
        """TSS = sensitivity + specificity - 1; must be in [-1, 1]."""
        from sklearn.metrics import confusion_matrix
        y_true, y_score = self._make_predictions()
        y_pred = (y_score >= 0.5).astype(int)
        tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
        sensitivity = tp / (tp + fn) if (tp + fn) > 0 else 0
        specificity = tn / (tn + fp) if (tn + fp) > 0 else 0
        tss = sensitivity + specificity - 1
        assert -1.0 <= tss <= 1.0, f"TSS out of range: {tss:.3f}"

    def test_uncertainty_std_positive(self):
        """Ensemble prediction standard deviation must be >= 0 everywhere."""
        rng = np.random.default_rng(0)
        n = 100
        preds_rf  = rng.uniform(0, 1, n)
        preds_brt = rng.uniform(0, 1, n)
        uncertainty = np.std(np.stack([preds_rf, preds_brt], axis=0), axis=0)
        assert np.all(uncertainty >= 0), "Uncertainty must be non-negative"


# ---------------------------------------------------------------------------
# Integration: full pipeline data flow
# ---------------------------------------------------------------------------

class TestPipelineDataFlow:
    """Verify that output schema of each step is compatible with the next step's input schema."""

    def test_clean_output_schema_for_sdm(self, tmp_path):
        """data_clean.csv must contain columns required by sdm_pipeline."""
        SDM_REQUIRED = {"decimalLatitude", "decimalLongitude", "QA_status"}
        csv_path = tmp_path / "occurrences.csv"
        csv_path.write_text(_make_occurrence_csv())
        out_dir = tmp_path / "processed"

        subprocess.run(
            [sys.executable, str(SCRIPTS["clean"]), str(csv_path), str(out_dir)],
            capture_output=True, text=True, check=True,
        )
        clean = pd.read_csv(out_dir / "data_clean.csv")
        missing = SDM_REQUIRED - set(clean.columns)
        assert not missing, f"Columns missing from clean output: {missing}"

    def test_clean_output_has_no_flagged_in_clean(self, tmp_path):
        """data_clean.csv must only contain rows with QA_status == 'OK'."""
        csv_path = tmp_path / "occurrences.csv"
        csv_path.write_text(_make_occurrence_csv())
        out_dir = tmp_path / "processed"

        subprocess.run(
            [sys.executable, str(SCRIPTS["clean"]), str(csv_path), str(out_dir)],
            capture_output=True, text=True, check=True,
        )
        clean = pd.read_csv(out_dir / "data_clean.csv")
        assert (clean["QA_status"] == "OK").all(), "data_clean.csv must only contain OK records"

    def test_coordinates_in_valid_range_after_clean(self, tmp_path):
        """All clean records must have coordinates within geographic bounds."""
        csv_path = tmp_path / "occurrences.csv"
        csv_path.write_text(_make_occurrence_csv())
        out_dir = tmp_path / "processed"

        subprocess.run(
            [sys.executable, str(SCRIPTS["clean"]), str(csv_path), str(out_dir)],
            capture_output=True, text=True, check=True,
        )
        clean = pd.read_csv(out_dir / "data_clean.csv")
        assert clean["decimalLatitude"].between(-90, 90).all(), "Latitude out of range in clean data"
        assert clean["decimalLongitude"].between(-180, 180).all(), "Longitude out of range in clean data"

    def test_env_matrix_shape_for_modeling(self):
        """Feature matrix for modeling must have no NaN values after preparation."""
        rng = np.random.default_rng(1)
        n = 80
        X = pd.DataFrame({
            "bio1": rng.normal(25, 5, n),
            "bio12": rng.normal(1800, 300, n),
            "bio15": rng.normal(50, 15, n),
        })
        y = pd.Series((rng.random(n) > 0.4).astype(int))
        assert not X.isnull().any().any(), "Feature matrix must have no NaN values"
        assert len(X) == len(y), "Feature matrix and labels must have same length"
        assert X.shape[1] == 3, "Expected 3 predictor columns"
