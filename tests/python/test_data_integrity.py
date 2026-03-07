# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Tests that validate the integrity of all test datasets.
These run first and act as the safety net for all other tests.
Run: pytest tests/python/test_data_integrity.py -v
"""
import pytest
import numpy as np
import pandas as pd
from pathlib import Path

DATA = Path(__file__).parents[1] / "data"


class TestDataFilesExist:
    expected_files = [
        "occurrences_raw.csv", "species_site_matrix.csv", "site_metadata.csv",
        "detection_history.csv", "occ_site_covariates.csv", "points_with_env.csv",
        "model_predictions.csv", "ndvi_monthly_series.csv", "baci_data.csv",
        "es_summary_table.csv", "richness_data.csv",
    ]

    @pytest.mark.parametrize("fname", expected_files)
    def test_file_exists(self, fname):
        assert (DATA / fname).exists(), f"Missing test dataset: {fname}"

    @pytest.mark.parametrize("fname", expected_files)
    def test_file_not_empty(self, fname):
        assert (DATA / fname).stat().st_size > 100, f"File too small: {fname}"


class TestOccurrencesRaw:
    def test_known_qa_issues_present(self):
        df = pd.read_csv(DATA / "occurrences_raw.csv")
        issues = df["QA_issue"].unique()
        assert "zero_coords" in issues
        assert "future_date" in issues
        assert "duplicate" in issues

    def test_has_darwin_core_fields(self):
        df = pd.read_csv(DATA / "occurrences_raw.csv")
        for col in ["scientificName", "decimalLatitude", "decimalLongitude", "eventDate"]:
            assert col in df.columns

    def test_majority_clean(self):
        df = pd.read_csv(DATA / "occurrences_raw.csv")
        assert (df["QA_issue"] == "none").mean() > 0.7


class TestSpeciesMatrix:
    def test_dimensions(self):
        df = pd.read_csv(DATA / "species_site_matrix.csv", index_col=0)
        assert len(df) == 30
        assert len(df.columns) >= 21  # group + 20 species

    def test_three_groups_balanced(self):
        df = pd.read_csv(DATA / "species_site_matrix.csv", index_col=0)
        counts = df["group"].value_counts()
        assert set(counts.index) == {"forest", "savanna", "pasture"}
        assert all(counts == 10)

    def test_no_negative_abundances(self):
        df = pd.read_csv(DATA / "species_site_matrix.csv", index_col=0).drop(columns=["group"])
        assert (df >= 0).all().all()


class TestDetectionHistory:
    def test_dimensions(self):
        df = pd.read_csv(DATA / "detection_history.csv", index_col=0)
        assert len(df) == 40
        assert len(df.columns) == 5

    def test_values_are_zero_one_or_na(self):
        df = pd.read_csv(DATA / "detection_history.csv", index_col=0)
        flat = df.values.flatten()
        valid = [v for v in flat if not (isinstance(v, float) and np.isnan(v)) and v != ""]
        assert all(int(v) in [0, 1] for v in valid if str(v).strip() not in ["", "nan"])

    def test_some_detections_present(self):
        df = pd.read_csv(DATA / "detection_history.csv", index_col=0)
        total = df.replace("", np.nan).astype(float).sum().sum()
        assert total > 20


class TestNDVISeries:
    def test_length(self):
        df = pd.read_csv(DATA / "ndvi_monthly_series.csv")
        assert len(df) == 240

    def test_date_column_parseable(self):
        df = pd.read_csv(DATA / "ndvi_monthly_series.csv", parse_dates=["date"])
        assert pd.api.types.is_datetime64_any_dtype(df["date"])

    def test_breakpoint_visible(self):
        """Values just after breakpoint (2010) should be lower than pre-breakpoint."""
        df = pd.read_csv(DATA / "ndvi_monthly_series.csv", parse_dates=["date"])
        pre_mean  = df[df["date"] < "2010-01-01"]["value"].tail(24).mean()
        post_min  = df[(df["date"] >= "2010-01-01") & (df["date"] < "2012-01-01")]["value"].min()
        assert post_min < pre_mean, "Breakpoint signal not visible in NDVI series"

    def test_values_in_plausible_range(self):
        df = pd.read_csv(DATA / "ndvi_monthly_series.csv")
        assert df["value"].min() > 0.2
        assert df["value"].max() < 1.0


class TestBACIData:
    def test_dimensions(self):
        df = pd.read_csv(DATA / "baci_data.csv")
        assert len(df) == 96
        assert "treatment" in df.columns
        assert "period" in df.columns
        assert "abundance" in df.columns

    def test_two_treatments_balanced(self):
        df = pd.read_csv(DATA / "baci_data.csv")
        counts = df.groupby("treatment")["site"].nunique()
        assert counts["control"] == counts["impact"] == 8

    def test_baci_signal_present(self):
        """Impact sites should show decline; control sites should not."""
        df = pd.read_csv(DATA / "baci_data.csv")
        def change(grp):
            pre  = grp[grp["period"] == "before"]["abundance"].mean()
            post = grp[grp["period"] == "after"]["abundance"].mean()
            return (post - pre) / pre
        changes = df.groupby("treatment").apply(change)
        assert changes["impact"] < changes["control"] - 0.1, \
            f"BACI signal weak: impact change={changes['impact']:.3f}, control change={changes['control']:.3f}"


class TestModelPredictions:
    def test_observed_binary(self):
        df = pd.read_csv(DATA / "model_predictions.csv")
        assert set(df["observed"].unique()).issubset({0, 1})

    def test_predicted_in_range(self):
        df = pd.read_csv(DATA / "model_predictions.csv")
        assert df["predicted"].min() >= 0.0
        assert df["predicted"].max() <= 1.0

    def test_signal_detectable(self):
        from sklearn.metrics import roc_auc_score
        df = pd.read_csv(DATA / "model_predictions.csv")
        auc = roc_auc_score(df["observed"], df["predicted"])
        assert auc > 0.65, f"AUC too low ({auc:.3f}): test data should have signal"
