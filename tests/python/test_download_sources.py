"""
Tests for v2.2.0 occurrence download scripts and predictor download scripts.
No live API calls — all tests use mock data and pure logic.
Run: pytest tests/python/test_download_sources.py -v
"""
import sys
import importlib.util
import types
from pathlib import Path
import tempfile
from unittest.mock import MagicMock

import pandas as pd
import pytest

SCRIPTS = Path(__file__).parents[2] / "skills" / "ecological-data-foundation" / "scripts"
GEO_SCRIPTS = Path(__file__).parents[2] / "skills" / "geoprocessing-for-ecology" / "scripts"

# ── Standard schema columns ───────────────────────────────────────────────────
STANDARD_SCHEMA = [
    "species", "decimalLatitude", "decimalLongitude", "eventDate",
    "countryCode", "basisOfRecord", "coordinateUncertaintyInMeters",
    "datasetName", "occurrenceID", "source", "download_doi",
]


def make_stub(name: str):
    mod = types.ModuleType(name)
    mod.__spec__ = MagicMock()
    mod.get_observations = MagicMock(return_value={"results": [], "total_results": 0})
    return mod


def inject_stubs(*names: str) -> None:
    for name in names:
        if name not in sys.modules:
            sys.modules[name] = make_stub(name)


def load_module(script_path: Path, mod_name: str):
    inject_stubs(
        "pyinaturalist", "robis", "rredlist", "requests",
        "cdsapi", "pystac_client", "stackstac", "planetary_computer",
        "rasterio", "rasterio.mask", "shapely", "shapely.wkt",
    )
    spec = importlib.util.spec_from_file_location(mod_name, script_path)
    mod  = importlib.util.module_from_spec(spec)
    original_exit = sys.exit
    sys.exit = lambda code=0: None  # prevent sys.exit(1) from killing test collection
    try:
        spec.loader.exec_module(mod)
    finally:
        sys.exit = original_exit
    return mod


# ── Load modules once ─────────────────────────────────────────────────────────
inat_mod  = load_module(SCRIPTS / "download_from_inat.py",  "download_inat")
obis_mod  = load_module(SCRIPTS / "download_from_obis.py",  "download_obis")
iucn_mod  = load_module(SCRIPTS / "download_from_iucn.py",  "download_iucn")
ebird_mod = load_module(SCRIPTS / "download_from_ebird.py", "download_ebird")
pred_mod  = load_module(GEO_SCRIPTS / "download_predictors.py", "download_pred")


# ─────────────────────────────────────────────────────────────────────────────
# 1. Schema validation helpers
# ─────────────────────────────────────────────────────────────────────────────

class TestStandardSchema:
    """Verify that standardise_records functions produce the required column set."""

    def test_inat_standardise_produces_schema(self):
        obs = [{
            "location": "-5.0,-55.0",
            "observed_on": "2022-03-15",
            "place_guess": "Brazil",
            "id": 12345678,
            "positional_accuracy": 10,
        }]
        df = inat_mod.standardise_records(obs, "Panthera onca")
        missing = [c for c in STANDARD_SCHEMA if c not in df.columns]
        assert missing == [], f"Missing schema columns: {missing}"

    def test_inat_standardise_drops_missing_coords(self):
        obs = [
            {"location": "invalid", "observed_on": "2022-01-01", "place_guess": "", "id": 1, "positional_accuracy": None},
            {"location": "-5.0,-55.0", "observed_on": "2022-01-01", "place_guess": "BR", "id": 2, "positional_accuracy": 10},
        ]
        df = inat_mod.standardise_records(obs, "Panthera onca")
        assert len(df) == 1
        assert df.iloc[0]["occurrenceID"] == "2"

    def test_inat_source_column_is_inat(self):
        obs = [{"location": "-5.0,-55.0", "observed_on": "2022-01-01",
                "place_guess": "BR", "id": 99, "positional_accuracy": 5}]
        df = inat_mod.standardise_records(obs, "Myrmecophaga tridactyla")
        assert df.iloc[0]["source"] == "iNaturalist"

    def test_obis_standardise_produces_schema(self):
        records = [{
            "decimalLatitude": -5.0,
            "decimalLongitude": -55.0,
            "eventDate": "2020-06-01",
            "countryCode": "BR",
            "basisOfRecord": "HUMAN_OBSERVATION",
            "coordinateUncertaintyInMeters": 100,
            "datasetName": "OBIS Dataset",
            "occurrenceID": "urn:obis:1234",
            "depth": 0.0,
        }]
        df = obis_mod.standardise_records(records, "Chelonia mydas")
        missing = [c for c in STANDARD_SCHEMA if c not in df.columns]
        assert missing == [], f"Missing schema columns: {missing}"

    def test_obis_extra_columns_present(self):
        records = [{"decimalLatitude": -5.0, "decimalLongitude": -55.0,
                    "depth": 10.0, "occurrenceID": "x1"}]
        df = obis_mod.standardise_records(records, "Chelonia mydas")
        assert "depth" in df.columns
        assert "marine" in df.columns

    def test_obis_source_column_is_obis(self):
        records = [{"decimalLatitude": -5.0, "decimalLongitude": -55.0}]
        df = obis_mod.standardise_records(records, "Chelonia mydas")
        assert df.iloc[0]["source"] == "OBIS"

    def test_iucn_standardise_produces_schema_no_countries(self):
        assessment = {
            "result": [{
                "taxonid": 15951,
                "category": "NT",
                "criteria": "A2cd",
                "population_trend": "Decreasing",
                "assessment_date": "2018-01-01",
            }]
        }
        df = iucn_mod.standardise_records(assessment, [], "Panthera onca")
        missing = [c for c in STANDARD_SCHEMA if c not in df.columns]
        assert missing == [], f"Missing schema columns: {missing}"

    def test_iucn_standardise_with_countries(self):
        assessment = {
            "result": [{"taxonid": 15951, "category": "NT", "criteria": "",
                        "population_trend": "Decreasing", "assessment_date": "2018-01-01"}]
        }
        countries = [{"code": "BR"}, {"code": "CO"}, {"code": "PE"}]
        df = iucn_mod.standardise_records(assessment, countries, "Panthera onca")
        assert len(df) == 3
        assert set(df["countryCode"]) == {"BR", "CO", "PE"}

    def test_iucn_extra_columns_present(self):
        assessment = {"result": [{"taxonid": 1, "category": "LC", "criteria": "",
                                   "population_trend": "Stable", "assessment_date": "2020-01-01"}]}
        df = iucn_mod.standardise_records(assessment, [], "Thalurania furcata")
        assert "rl_category" in df.columns
        assert "assessment_year" in df.columns


# ─────────────────────────────────────────────────────────────────────────────
# 2. OBIS quality flag filtering
# ─────────────────────────────────────────────────────────────────────────────

class TestOBISQualityFlags:

    def test_no_coord_flag_removed(self):
        records = [
            {"decimalLatitude": -5.0, "decimalLongitude": -55.0, "flags": "NO_COORD"},
            {"decimalLatitude": -5.0, "decimalLongitude": -55.0, "flags": ""},
        ]
        filtered = obis_mod.apply_quality_flags(records)
        assert len(filtered) == 1

    def test_zero_coord_flag_removed(self):
        records = [{"decimalLatitude": 0.0, "decimalLongitude": 0.0, "flags": "ZERO_COORD"}]
        filtered = obis_mod.apply_quality_flags(records)
        assert len(filtered) == 0

    def test_on_land_flag_removed(self):
        records = [{"decimalLatitude": -5.0, "decimalLongitude": -55.0, "flags": "ON_LAND"}]
        filtered = obis_mod.apply_quality_flags(records)
        assert len(filtered) == 0

    def test_clean_records_pass_through(self):
        records = [
            {"decimalLatitude": -5.0, "decimalLongitude": -55.0, "flags": ""},
            {"decimalLatitude": -6.0, "decimalLongitude": -56.0, "flags": None},
        ]
        filtered = obis_mod.apply_quality_flags(records)
        assert len(filtered) == 2


# ─────────────────────────────────────────────────────────────────────────────
# 3. eBird EBD parsing helpers
# ─────────────────────────────────────────────────────────────────────────────

class TestEBirdParsing:

    def _make_ebd_df(self, species="Jabiru mycteria", protocol="Stationary",
                      approved="1", year=2021, lat=-5.0, lon=-55.0):
        return pd.DataFrame({
            "SCIENTIFIC NAME":           [species],
            "LATITUDE":                  [lat],
            "LONGITUDE":                 [lon],
            "OBSERVATION DATE":          [f"{year}-06-15"],
            "COUNTRY CODE":              ["BR"],
            "SAMPLING EVENT IDENTIFIER": ["S12345678"],
            "PROTOCOL TYPE":             [protocol],
            "EFFORT DISTANCE KM":        [1.5],
            "DURATION MINUTES":          [60],
            "OBSERVER ID":               ["obsr123"],
            "APPROVED":                  [approved],
            "REVIEWED":                  ["0"],
        })

    def test_standardise_ebd_schema(self):
        df = self._make_ebd_df()
        std = ebird_mod.standardise_ebd(df, "Jabiru mycteria")
        missing = [c for c in STANDARD_SCHEMA if c not in std.columns]
        assert missing == [], f"Missing: {missing}"

    def test_standardise_ebd_extra_columns(self):
        df = self._make_ebd_df()
        std = ebird_mod.standardise_ebd(df, "Jabiru mycteria")
        assert "effort_distance_km" in std.columns
        assert "duration_minutes"   in std.columns
        assert "observer_id"        in std.columns

    def test_standardise_ebd_source_is_ebird(self):
        df = self._make_ebd_df()
        std = ebird_mod.standardise_ebd(df, "Jabiru mycteria")
        assert std.iloc[0]["source"] == "eBird"

    def test_standardise_ebd_wrong_species_empty(self):
        df = self._make_ebd_df(species="Jabiru mycteria")
        std = ebird_mod.standardise_ebd(df, "Ara ararauna")
        assert len(std) == 0


# ─────────────────────────────────────────────────────────────────────────────
# 4. Metadata save functions (no network; writes to temp dir)
# ─────────────────────────────────────────────────────────────────────────────

class TestMetadataSave:

    def test_inat_metadata_written(self, tmp_path):
        inat_mod.save_metadata(tmp_path, "Panthera onca", 42, 2010, 2023, "research")
        meta_file = tmp_path / "download_metadata_iNat_Panthera_onca.txt"
        assert meta_file.exists()
        content = meta_file.read_text(encoding="utf-8")
        assert "iNaturalist" in content
        assert "42" in content

    def test_obis_metadata_written(self, tmp_path):
        obis_mod.save_metadata(tmp_path, "Chelonia mydas", 15, 1990, 2022, None)
        meta_file = tmp_path / "download_metadata_OBIS_Chelonia_mydas.txt"
        assert meta_file.exists()
        content = meta_file.read_text(encoding="utf-8")
        assert "OBIS" in content
        assert "CC0" in content

    def test_iucn_metadata_written(self, tmp_path):
        iucn_mod.save_metadata(tmp_path, "Panthera onca", 15951, "NT", "2018")
        meta_file = tmp_path / "download_metadata_IUCN_Panthera_onca.txt"
        assert meta_file.exists()
        content = meta_file.read_text(encoding="utf-8")
        assert "IUCN" in content
        assert "15951" in content


# ─────────────────────────────────────────────────────────────────────────────
# 5. Predictor download helpers (no network)
# ─────────────────────────────────────────────────────────────────────────────

class TestPredictorHelpers:

    def test_sha256_nonexistent_returns_na(self, tmp_path):
        result = pred_mod.sha256_file(tmp_path / "nonexistent.tif")
        assert result == "N/A"

    def test_sha256_real_file(self, tmp_path):
        f = tmp_path / "test.bin"
        f.write_bytes(b"hello world")
        result = pred_mod.sha256_file(f)
        assert len(result) == 64  # SHA256 hex digest length

    def test_save_metadata_empty_rows(self, tmp_path):
        pred_mod.save_metadata(tmp_path, [])
        # Should not create file (warning only)
        assert not (tmp_path / "predictor_metadata.csv").exists()

    def test_save_metadata_writes_csv(self, tmp_path):
        rows = [{"source": "WorldClim_v2.1", "variable": "BIO1",
                 "resolution": "2.5m", "file": "/tmp/bio1.tif",
                 "citation": "Fick & Hijmans (2017)",
                 "licence": "CC BY 4.0", "download_date": "2026-03-05"}]
        pred_mod.save_metadata(tmp_path, rows)
        meta_path = tmp_path / "predictor_metadata.csv"
        assert meta_path.exists()
        df = pd.read_csv(meta_path)
        assert len(df) == 1
        assert df.iloc[0]["source"] == "WorldClim_v2.1"

    def test_valid_resolutions_dict_contains_key(self):
        assert 2.5 in pred_mod.VALID_RESOLUTIONS
        assert 10  in pred_mod.VALID_RESOLUTIONS

    def test_chelsa_base_url_format(self):
        # Ensure the base URL is correct (no live request)
        assert "chelsa" in pred_mod.CHELSA_BASE.lower()
        assert pred_mod.CHELSA_BASE.startswith("https://")

    def test_worldclim_base_url_format(self):
        assert "worldclim" in pred_mod.WORLDCLIM_BASE.lower()
        assert pred_mod.WORLDCLIM_BASE.startswith("https://")
