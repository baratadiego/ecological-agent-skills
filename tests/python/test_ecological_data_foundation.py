# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Tests for ecological-data-foundation skill scripts.
Run: pytest tests/python/test_ecological_data_foundation.py -v
"""
import pytest
import sys
import math
import csv
import tempfile
import shutil
from pathlib import Path

DATA = Path(__file__).parents[1] / "data"
SCRIPT = Path(__file__).parents[2] / "skills" / "ecological-data-foundation" / "scripts" / "clean_occurrences.py"

# ── import the module functions directly ──────────────────────────────────
sys.path.insert(0, str(SCRIPT.parent))
import importlib.util
spec = importlib.util.spec_from_file_location("clean_occ", SCRIPT)
mod  = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class TestCoordinateFlags:
    def test_zero_coords_flagged(self):
        import pandas as pd
        df = pd.DataFrame({"decimalLatitude":[0.0],"decimalLongitude":[0.0],"QA_status":["OK"]})
        result = mod.flag_coordinate_issues(df)
        assert result.iloc[0]["QA_status"] == "COORD_ZERO"

    def test_out_of_range_lat_flagged(self):
        import pandas as pd
        df = pd.DataFrame({"decimalLatitude":[999.0],"decimalLongitude":[-50.0],"QA_status":["OK"]})
        result = mod.flag_coordinate_issues(df)
        assert result.iloc[0]["QA_status"] == "COORD_OUT_OF_RANGE"

    def test_out_of_range_lon_flagged(self):
        import pandas as pd
        df = pd.DataFrame({"decimalLatitude":[-10.0],"decimalLongitude":[200.0],"QA_status":["OK"]})
        result = mod.flag_coordinate_issues(df)
        assert result.iloc[0]["QA_status"] == "COORD_OUT_OF_RANGE"

    def test_valid_coords_pass(self):
        import pandas as pd
        df = pd.DataFrame({"decimalLatitude":[-12.5],"decimalLongitude":[-55.3],"QA_status":["OK"]})
        result = mod.flag_coordinate_issues(df)
        assert result.iloc[0]["QA_status"] == "OK"

    def test_missing_coords_flagged(self):
        import pandas as pd
        import numpy as np
        df = pd.DataFrame({"decimalLatitude":[np.nan],"decimalLongitude":[-50.0],"QA_status":["OK"]})
        result = mod.flag_coordinate_issues(df)
        assert result.iloc[0]["QA_status"] == "MISSING_COORDS"


class TestDuplicateRemoval:
    def test_exact_duplicates_removed(self):
        import pandas as pd
        df = pd.DataFrame({
            "scientificName": ["Panthera onca"]*3,
            "decimalLatitude": [-12.0]*3,
            "decimalLongitude": [-55.0]*3,
            "eventDate": ["2020-01-01"]*3,
            "QA_status": ["OK"]*3,
        })
        result = mod.remove_exact_duplicates(df)
        assert len(result) == 1

    def test_non_duplicates_retained(self):
        import pandas as pd
        df = pd.DataFrame({
            "scientificName": ["Panthera onca", "Puma concolor"],
            "decimalLatitude": [-12.0, -15.0],
            "decimalLongitude": [-55.0, -52.0],
            "eventDate": ["2020-01-01", "2020-01-01"],
            "QA_status": ["OK", "OK"],
        })
        result = mod.remove_exact_duplicates(df)
        assert len(result) == 2


class TestTemporalFlags:
    def test_future_date_flagged(self):
        import pandas as pd
        df = pd.DataFrame({"eventDate": ["2099-01-01"], "QA_status": ["OK"]})
        result = mod.check_temporal(df)
        assert result.iloc[0]["QA_status"] == "DATE_FUTURE"

    def test_past_date_passes(self):
        import pandas as pd
        df = pd.DataFrame({"eventDate": ["2019-06-15"], "QA_status": ["OK"]})
        result = mod.check_temporal(df)
        assert result.iloc[0]["QA_status"] == "OK"


class TestEndToEnd:
    def test_pipeline_on_test_dataset(self):
        import pandas as pd
        out = tempfile.mkdtemp()
        try:
            mod.main.__globals__['sys'].argv = ["script", str(DATA/"occurrences_raw.csv"), out]
            # Call functions directly instead
            df = mod.load(str(DATA/"occurrences_raw.csv"))
            df = mod.flag_coordinate_issues(df)
            df = mod.remove_exact_duplicates(df)
            df = mod.check_temporal(df)
            clean   = df[df["QA_status"] == "OK"]
            flagged = df[df["QA_status"] != "OK"]
            # 5 known bad records in test dataset
            assert len(flagged) >= 4, f"Expected ≥4 flagged, got {len(flagged)}"
            assert len(clean) > 70,   f"Expected >70 clean, got {len(clean)}"
        finally:
            shutil.rmtree(out)

    def test_required_cols_validation(self):
        import pandas as pd
        df = pd.DataFrame({"species": ["Panthera onca"], "date": ["2020-01-01"]})
        with pytest.raises((ValueError, KeyError, SystemExit)):
            mod.check_required_cols(df, ["decimalLatitude", "decimalLongitude"])
