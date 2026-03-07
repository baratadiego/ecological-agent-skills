# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
conftest.py — shared fixtures for ecological-agent-skills pytest suite.
"""
import pytest
import numpy as np
import pandas as pd
from pathlib import Path

DATA = Path(__file__).parent.parent / "data"

@pytest.fixture
def occurrences_raw():
    return pd.read_csv(DATA / "occurrences_raw.csv")

@pytest.fixture
def species_matrix():
    df = pd.read_csv(DATA / "species_site_matrix.csv", index_col=0)
    return df.drop(columns=["group"]), df["group"]

@pytest.fixture
def site_metadata():
    return pd.read_csv(DATA / "site_metadata.csv", index_col=0)

@pytest.fixture
def detection_history():
    df = pd.read_csv(DATA / "detection_history.csv", index_col=0)
    return df.replace("", np.nan).values.astype(float)

@pytest.fixture
def points_with_env():
    return pd.read_csv(DATA / "points_with_env.csv")

@pytest.fixture
def model_predictions():
    return pd.read_csv(DATA / "model_predictions.csv")

@pytest.fixture
def ndvi_series():
    df = pd.read_csv(DATA / "ndvi_monthly_series.csv", parse_dates=["date"])
    return df

@pytest.fixture
def baci_data():
    return pd.read_csv(DATA / "baci_data.csv")

@pytest.fixture
def es_summary():
    return pd.read_csv(DATA / "es_summary_table.csv")

@pytest.fixture
def richness_data():
    return pd.read_csv(DATA / "richness_data.csv")
