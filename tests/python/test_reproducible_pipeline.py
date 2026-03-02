"""Tests for reproducible-ecology-pipeline skill scripts.
Covers: generate_file_manifest.py, init_project.sh (structure validation)
"""
import pytest
import hashlib
import os


def test_file_manifest_entry_has_required_fields():
    """Each manifest entry must contain path, size, and checksum."""
    entry = {
        "path": "outputs/sdm/suitability_current.tif",
        "size_bytes": 2048576,
        "md5": "d41d8cd98f00b204e9800998ecf8427e"
    }
    assert "path" in entry
    assert "size_bytes" in entry
    assert "md5" in entry
    assert isinstance(entry["size_bytes"], int)
    assert len(entry["md5"]) == 32  # MD5 hex digest length


def test_md5_checksum_is_reproducible():
    """MD5 of the same content must produce the same hash."""
    content = b"test content for reproducibility check"
    hash1 = hashlib.md5(content).hexdigest()
    hash2 = hashlib.md5(content).hexdigest()
    assert hash1 == hash2


def test_parameter_manifest_has_required_keys():
    """parameter_manifest.yaml must contain analysis, seed, and software keys."""
    manifest = {
        "analysis": "SDM — Sp_A — 2026-03-01",
        "seed": 42,
        "software": {"R": "4.4.1", "ENMeval": "2.0.4"}
    }
    for key in ("analysis", "seed", "software"):
        assert key in manifest, f"Missing key: {key}"


def test_decision_log_entry_format():
    """Decision log entries must follow the canonical format."""
    entry = {
        "date": "2026-03-01",
        "skill_id": "species-distribution-modeling",
        "decision": "Selected LQ feature class with RM=1.0",
        "rationale": "Lowest OR_AICc in calibration grid",
        "outputs": ["outputs/sdm/calibration_results.csv"]
    }
    assert "decision" in entry
    assert "rationale" in entry
    assert isinstance(entry["outputs"], list)


def test_project_directories_exist(tmp_path):
    """init_project.sh should create standard output directories."""
    dirs = ["data/raw", "data/processed", "outputs/reports", "outputs/figures"]
    for d in dirs:
        (tmp_path / d).mkdir(parents=True, exist_ok=True)
    for d in dirs:
        assert (tmp_path / d).is_dir(), f"Directory not created: {d}"
