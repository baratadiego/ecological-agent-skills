#!/usr/bin/env python3
"""
occupancy_analysis.py
Single-season occupancy analysis scaffold.
For full occupancy modelling in Python, interface with JAGS or use pyoccupancy.
This script demonstrates data formatting and naive occupancy computation.
Usage: python occupancy_analysis.py <detection_history_csv> <output_dir>
Requires: pandas, numpy
"""
import sys
from pathlib import Path
import numpy as np
import pandas as pd

def compute_naive_occ(dh: np.ndarray) -> float:
    detected = np.nansum(dh, axis=1) > 0
    return detected.sum() / len(detected)

def detection_summary(dh: np.ndarray) -> pd.DataFrame:
    return pd.DataFrame({
        "occasion":       [f"occ{i+1}" for i in range(dh.shape[1])],
        "n_surveyed":     [np.sum(~np.isnan(dh[:, i])) for i in range(dh.shape[1])],
        "n_detections":   [int(np.nansum(dh[:, i])) for i in range(dh.shape[1])],
        "detection_rate": [round(np.nanmean(dh[:, i]), 3) for i in range(dh.shape[1])],
    })

def validate_detection_history(dh: np.ndarray) -> None:
    valid = np.isin(dh[~np.isnan(dh)], [0, 1])
    if not valid.all():
        raise ValueError("Detection history contains values other than 0, 1, or NA.")
    all_na = np.all(np.isnan(dh), axis=1)
    if all_na.any():
        raise ValueError(f"{all_na.sum()} sites have all-NA detection histories. Remove them.")

def main():
    dh_file    = sys.argv[1] if len(sys.argv) > 1 else "data/detection_history.csv"
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("outputs/occupancy")
    output_dir.mkdir(parents=True, exist_ok=True)

    dh_df = pd.read_csv(dh_file, index_col=0)
    dh = dh_df.values.astype(float)
    print(f"Sites: {dh.shape[0]} | Occasions: {dh.shape[1]}")

    validate_detection_history(dh)
    naive = compute_naive_occ(dh)
    print(f"Naive occupancy: {naive:.3f} ({int(naive * dh.shape[0])}/{dh.shape[0]} sites)")

    det_summary = detection_summary(dh)
    det_summary.to_csv(output_dir / "detection_summary.csv", index=False)
    print(f"\nDetection summary:\n{det_summary.to_string(index=False)}")

    # For full occupancy modelling, use R (unmarked) or JAGS via pyjags.
    # Example JAGS model call:
    #   import pyjags
    #   model_code = open("scripts/occu_model.jags").read()
    #   model = pyjags.Model(model_code, data={...}, chains=3)
    print(f"\nFor full occupancy modelling, use scripts/occupancy_analysis.R (unmarked package).")
    print(f"Outputs written to: {output_dir}")

if __name__ == "__main__":
    main()
