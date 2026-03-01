"""
Tests for community-ecology-ordination skill scripts.
Run: pytest tests/python/test_community_ecology.py -v
"""
import pytest
import sys
import numpy as np
import pandas as pd
from pathlib import Path
from scipy.spatial.distance import braycurtis

DATA   = Path(__file__).parents[1] / "data"
SCRIPT = Path(__file__).parents[2] / "skills" / "community-ecology-ordination" / "scripts" / "community_analysis.py"

sys.path.insert(0, str(SCRIPT.parent))
import importlib.util
spec = importlib.util.spec_from_file_location("community_analysis", SCRIPT)
mod  = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class TestAlphaDiversity:
    def make_sp(self, data):
        return pd.DataFrame(data, index=[f"s{i}" for i in range(len(data))])

    def test_richness_counts_nonzero(self):
        sp = self.make_sp([[5, 0, 3, 0], [0, 2, 0, 4], [1, 1, 1, 1]])
        div = mod.alpha_diversity(sp)
        assert list(div["richness"]) == [2, 2, 4]

    def test_shannon_zero_for_monoculture(self):
        sp = self.make_sp([[10, 0, 0]])
        div = mod.alpha_diversity(sp)
        assert div["shannon"].iloc[0] == pytest.approx(0.0, abs=1e-6)

    def test_shannon_max_for_equal_abundance(self):
        sp = self.make_sp([[5, 5, 5, 5]])
        div = mod.alpha_diversity(sp)
        expected_h = np.log(4)
        assert div["shannon"].iloc[0] == pytest.approx(expected_h, abs=0.01)

    def test_simpson_zero_for_monoculture(self):
        sp = self.make_sp([[100, 0, 0]])
        div = mod.alpha_diversity(sp)
        assert div["simpson"].iloc[0] == pytest.approx(0.0, abs=1e-6)

    def test_simpson_high_for_even_community(self):
        sp = self.make_sp([[25, 25, 25, 25]])
        div = mod.alpha_diversity(sp)
        assert div["simpson"].iloc[0] > 0.7


class TestBrayCurtis:
    def test_identical_sites_distance_zero(self):
        a = np.array([5.0, 3.0, 0.0, 2.0])
        b = np.array([5.0, 3.0, 0.0, 2.0])
        assert braycurtis(a, b) == pytest.approx(0.0, abs=1e-10)

    def test_non_overlapping_sites_distance_one(self):
        a = np.array([5.0, 0.0, 0.0])
        b = np.array([0.0, 3.0, 2.0])
        assert braycurtis(a, b) == pytest.approx(1.0, abs=1e-10)

    def test_matrix_is_symmetric(self):
        sp = pd.read_csv(DATA / "species_site_matrix.csv", index_col=0).drop(columns=["group"])
        dm = mod.bray_curtis_matrix(sp)
        assert np.allclose(dm, dm.T, atol=1e-10)

    def test_diagonal_is_zero(self):
        sp = pd.read_csv(DATA / "species_site_matrix.csv", index_col=0).drop(columns=["group"])
        dm = mod.bray_curtis_matrix(sp)
        assert np.allclose(np.diag(dm), 0.0, atol=1e-10)

    def test_values_in_range(self):
        sp = pd.read_csv(DATA / "species_site_matrix.csv", index_col=0).drop(columns=["group"])
        dm = mod.bray_curtis_matrix(sp)
        assert dm.min() >= 0.0
        assert dm.max() <= 1.0 + 1e-10


class TestGroupSeparation:
    def test_within_group_lower_than_between(self):
        """Forest sites should be more similar to each other than to pasture sites."""
        sp = pd.read_csv(DATA / "species_site_matrix.csv", index_col=0)
        groups = sp["group"]
        sp = sp.drop(columns=["group"])
        dm = mod.bray_curtis_matrix(sp)
        idx_forest  = [i for i, g in enumerate(groups) if g == "forest"]
        idx_pasture = [i for i, g in enumerate(groups) if g == "pasture"]
        within  = np.mean([dm[i,j] for i in idx_forest  for j in idx_forest  if i<j])
        between = np.mean([dm[i,j] for i in idx_forest  for j in idx_pasture])
        assert within < between, f"Within-forest ({within:.3f}) should be < between ({between:.3f})"


class TestEndToEnd:
    def test_script_produces_outputs(self, tmp_path):
        import subprocess, sys
        result = subprocess.run(
            [sys.executable, str(SCRIPT),
             str(DATA / "species_site_matrix.csv"),
             str(DATA / "site_metadata.csv"),
             str(tmp_path)],
            capture_output=True, text=True
        )
        assert result.returncode == 0, f"Script failed:\n{result.stderr}"
        assert (tmp_path / "diversity_metrics.csv").exists()
        assert (tmp_path / "bray_curtis_matrix.csv").exists()
        div = pd.read_csv(tmp_path / "diversity_metrics.csv")
        assert len(div) == 30
        assert (div["richness"] > 0).all()
