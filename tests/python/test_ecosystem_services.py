"""
Tests for ecosystem-services-assessment skill scripts.
Run: pytest tests/python/test_ecosystem_services.py -v
"""
import pytest
import sys
import numpy as np
import pandas as pd
from pathlib import Path

DATA   = Path(__file__).parents[1] / "data"
SCRIPT = Path(__file__).parents[2] / "skills" / "ecosystem-services-assessment" / "scripts" / "compute_es.py"

sys.path.insert(0, str(SCRIPT.parent))
import importlib.util
spec = importlib.util.spec_from_file_location("compute_es", SCRIPT)
mod  = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class TestZonalSummary:
    def make_lc(self):
        # 4x4 grid: classes 1, 2, 3 each in rows
        lc = np.array([[1,1,1,1],[2,2,2,2],[3,3,3,3],[1,2,3,1]], dtype=float)
        es = lc * 10.0  # class 1=10, 2=20, 3=30
        return lc, es

    def test_class_pixel_counts(self):
        lc, es = self.make_lc()
        summary = mod.zonal_summary(lc, es, [1,2,3], {1:"Forest",2:"Savanna",3:"Pasture"})
        counts = dict(zip(summary["lulc_code"], summary["n_pixels"]))
        assert counts[1] == 6
        assert counts[2] == 5
        assert counts[3] == 5

    def test_mean_es_correct(self):
        lc, es = self.make_lc()
        summary = mod.zonal_summary(lc, es, [1,2,3], {})
        means = dict(zip(summary["lulc_code"], summary["mean_es"]))
        assert means[1] == pytest.approx(10.0, abs=0.01)
        assert means[2] == pytest.approx(20.0, abs=0.01)
        assert means[3] == pytest.approx(30.0, abs=0.01)

    def test_all_classes_represented(self):
        lc, es = self.make_lc()
        summary = mod.zonal_summary(lc, es, [1,2,3], {})
        assert set(summary["lulc_code"]) == {1, 2, 3}

    def test_empty_class_excluded(self):
        lc = np.array([[1,1],[1,1]], dtype=float)
        es = np.ones((2,2)) * 5.0
        # Class 99 not present in raster
        summary = mod.zonal_summary(lc, es, [1, 99], {})
        assert 99 not in summary["lulc_code"].values


class TestESData:
    def test_es_summary_has_required_columns(self):
        df = pd.read_csv(DATA / "es_summary_table.csv")
        required = ["lulc_code","lulc_name","n_pixels","mean_es","total_es",
                    "erosion_control_mean","pollination_mean"]
        for col in required:
            assert col in df.columns, f"Missing column: {col}"

    def test_forest_higher_carbon_than_pasture(self):
        df = pd.read_csv(DATA / "es_summary_table.csv")
        forest  = df[df["lulc_name"] == "Dense forest"]["mean_es"].iloc[0]
        pasture = df[df["lulc_name"] == "Pasture"]["mean_es"].iloc[0]
        assert forest > pasture, f"Forest ({forest}) should have more carbon than pasture ({pasture})"

    def test_forest_higher_pollination_than_urban(self):
        df = pd.read_csv(DATA / "es_summary_table.csv")
        forest = df[df["lulc_name"] == "Dense forest"]["pollination_mean"].iloc[0]
        urban  = df[df["lulc_name"] == "Urban"]["pollination_mean"].iloc[0]
        assert forest > urban

    def test_erosion_control_in_range(self):
        df = pd.read_csv(DATA / "es_summary_table.csv")
        assert (df["erosion_control_mean"] >= 0).all()
        assert (df["erosion_control_mean"] <= 1).all()

    def test_carbon_values_positive(self):
        df = pd.read_csv(DATA / "es_summary_table.csv")
        assert (df["mean_es"] >= 0).all()
