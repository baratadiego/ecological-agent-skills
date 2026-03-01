#!/usr/bin/env python3
"""
clean_occurrences.py
Standard occurrence cleaning pipeline using Python.
Usage: python clean_occurrences.py <input_csv> <output_dir>
Requires: pandas, geopandas, shapely
"""
import sys, os, hashlib
from pathlib import Path

import pandas as pd
import numpy as np

def load(path: str) -> pd.DataFrame:
    df = pd.read_csv(path, low_memory=False)
    print(f"Loaded {len(df):,} rows, {len(df.columns)} columns from {path}")
    return df

def check_required_cols(df: pd.DataFrame, required: list) -> None:
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise ValueError(f"Missing required columns: {missing}")

def flag_coordinate_issues(df: pd.DataFrame,
                           lat_col="decimalLatitude",
                           lon_col="decimalLongitude") -> pd.DataFrame:
    df = df.copy()
    df["QA_status"] = "OK"
    lat = pd.to_numeric(df[lat_col], errors="coerce")
    lon = pd.to_numeric(df[lon_col], errors="coerce")

    # Invalid range
    mask_range = (lat.abs() > 90) | (lon.abs() > 180)
    df.loc[mask_range, "QA_status"] = "COORD_OUT_OF_RANGE"

    # Zero coordinates
    mask_zero = (lat == 0) & (lon == 0)
    df.loc[mask_zero, "QA_status"] = "COORD_ZERO"

    # Missing coords
    mask_na = lat.isna() | lon.isna()
    df.loc[mask_na, "QA_status"] = "MISSING_COORDS"

    print(f"  Out-of-range: {mask_range.sum()} | Zero: {mask_zero.sum()} | Missing: {mask_na.sum()}")
    return df

def remove_exact_duplicates(df: pd.DataFrame,
                             cols=("scientificName","decimalLatitude","decimalLongitude","eventDate")
                             ) -> pd.DataFrame:
    cols_present = [c for c in cols if c in df.columns]
    n_before = len(df)
    df = df.drop_duplicates(subset=cols_present, keep="first")
    print(f"  Exact duplicates removed: {n_before - len(df)}")
    return df

def check_temporal(df: pd.DataFrame, date_col="eventDate") -> pd.DataFrame:
    if date_col not in df.columns:
        return df
    dates = pd.to_datetime(df[date_col], errors="coerce")
    future = dates > pd.Timestamp.now()
    df.loc[future & (df["QA_status"] == "OK"), "QA_status"] = "DATE_FUTURE"
    print(f"  Future dates flagged: {future.sum()}")
    return df

def write_outputs(df: pd.DataFrame, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    clean   = df[df["QA_status"] == "OK"]
    flagged = df[df["QA_status"] != "OK"]
    clean.to_csv(output_dir / "data_clean.csv", index=False)
    flagged.to_csv(output_dir / "flagged_records.csv", index=False)

    # QA report
    flag_counts = flagged["QA_status"].value_counts().to_dict()
    lines = [
        "# QA Report — Occurrence Cleaning",
        f"- Raw records: {len(df):,}",
        f"- Clean records: {len(clean):,}",
        f"- Flagged records: {len(flagged):,}",
        "",
        "## Flag Counts",
    ] + [f"- `{k}`: {v}" for k, v in flag_counts.items()]
    (output_dir / "qa_report.md").write_text("\n".join(lines))
    print(f"\nClean: {len(clean):,} | Flagged: {len(flagged):,}")
    print(f"Outputs written to: {output_dir}")

def main():
    input_file = sys.argv[1] if len(sys.argv) > 1 else "data/raw/occurrences.csv"
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("data/processed")

    df = load(input_file)
    check_required_cols(df, ["decimalLatitude", "decimalLongitude"])
    df = flag_coordinate_issues(df)
    df = remove_exact_duplicates(df)
    df = check_temporal(df)
    write_outputs(df, output_dir)

if __name__ == "__main__":
    main()
