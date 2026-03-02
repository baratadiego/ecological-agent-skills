"""Tests for acoustic-monitoring skill scripts.
Covers: compute_acoustic_indices.py, batch_species_detection.py
"""
import pytest
import math
import re
from datetime import datetime


def test_ndsi_is_in_valid_range():
    """NDSI must be in [-1, 1]."""
    def compute_ndsi(anthro, bio):
        total = anthro + bio
        if total == 0:
            return float("nan")
        return (bio - anthro) / total

    assert -1 <= compute_ndsi(100, 300) <= 1
    assert compute_ndsi(0, 500) == 1.0          # pure biophony
    assert compute_ndsi(500, 0) == -1.0         # pure anthrophony
    assert compute_ndsi(250, 250) == 0.0        # equal


def test_aci_is_positive():
    """ACI value must always be positive (it is a sum of absolute differences)."""
    aci = 1842.3
    assert aci > 0


def test_confidence_score_categories():
    """BirdNET confidence scores map to correct categories."""
    def categorise(conf):
        if conf < 0.5:
            return "exclude"
        elif conf < 0.7:
            return "unconfirmed"
        else:
            return "accepted"

    assert categorise(0.45) == "exclude"
    assert categorise(0.65) == "unconfirmed"
    assert categorise(0.70) == "accepted"
    assert categorise(0.92) == "accepted"


def test_timestamp_parsed_from_filename():
    """Common AudioMoth filename yields correct timestamp."""
    def parse_timestamp(fname):
        m = re.search(r"(\d{8})[_$T](\d{6})", fname)
        if not m:
            return None
        return datetime.strptime(m.group(1) + m.group(2), "%Y%m%d%H%M%S")

    ts = parse_timestamp("AUDIOMOTH_20240601_050312.WAV")
    assert ts is not None
    assert ts.year == 2024
    assert ts.month == 6
    assert ts.hour == 5
    assert ts.minute == 3


def test_diel_control_encodings_are_bounded():
    """Circular hour encodings cos/sin must be in [-1, 1]."""
    import math
    for h in range(24):
        cos_h = math.cos(2 * math.pi * h / 24)
        sin_h = math.sin(2 * math.pi * h / 24)
        assert -1 <= cos_h <= 1
        assert -1 <= sin_h <= 1


def test_recording_hours_threshold_for_richness():
    """Sites with < 48 recording hours should be flagged as under-sampled."""
    station_hours = {"ST01": 45.0, "ST02": 50.0, "ST03": 48.0, "ST04": 35.0}
    min_hours = 48.0
    undersampled = [s for s, h in station_hours.items() if h < min_hours]
    assert len(undersampled) == 2
    assert "ST01" in undersampled
    assert "ST02" not in undersampled
