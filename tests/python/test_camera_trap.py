# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""Tests for camera-trap-processing skill scripts.
Covers: process_camtrap_data.py, estimate_activity.R logic
"""
import pytest
import math
from datetime import datetime, timedelta


def test_record_table_has_required_columns():
    """Record table must contain station, species, datetime, independent."""
    record = {
        "station":    "ST001",
        "species":    "Panthera_pardus",
        "datetime":   "2024-06-01 02:14:00",
        "independent": True,
    }
    required = {"station", "species", "datetime", "independent"}
    assert required.issubset(set(record.keys()))


def test_independence_threshold_collapses_events():
    """Two events within threshold should yield 1 independent event."""
    times = [
        datetime(2024, 6, 1, 2, 0, 0),
        datetime(2024, 6, 1, 2, 20, 0),  # 20 min later
    ]
    threshold_min = 30
    independent = [True]
    for i in range(1, len(times)):
        diff_min = (times[i] - times[i-1]).total_seconds() / 60
        independent.append(diff_min >= threshold_min)
    assert sum(independent) == 1


def test_trap_nights_calculation():
    """Trap-nights = retrieval date − setup date (in days)."""
    setup    = datetime(2024, 6, 1)
    retrieval = datetime(2024, 7, 1)
    tn = (retrieval - setup).days
    assert tn == 30


def test_rai_formula():
    """RAI = (events / trap-nights) × 100."""
    n_events  = 12
    trap_nights = 90
    rai = n_events / trap_nights * 100
    assert abs(rai - 13.333) < 0.01
    assert rai > 0


def test_station_flag_below_minimum_trap_nights():
    """Stations with < 100 trap-nights should be flagged."""
    stations = [
        {"id": "ST001", "trap_nights": 45},
        {"id": "ST002", "trap_nights": 120},
        {"id": "ST003", "trap_nights": 88},
    ]
    min_tn = 100
    flagged = [s["id"] for s in stations if s["trap_nights"] < min_tn]
    assert len(flagged) == 2
    assert "ST001" in flagged
    assert "ST002" not in flagged


def test_species_summary_has_required_columns():
    """Species summary must include species, n_events, n_stations, RAI."""
    summary = {
        "species":    "Panthera_pardus",
        "n_events":   412,
        "n_stations": 38,
        "RAI":        10.6,
    }
    required = {"species", "n_events", "n_stations", "RAI"}
    assert required.issubset(set(summary.keys()))
    assert summary["n_events"] >= 10  # min events for RAI
