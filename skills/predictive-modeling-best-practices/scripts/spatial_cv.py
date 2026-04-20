#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
spatial_cv.py
Spatial block cross-validation for ecological models.
Usage: python spatial_cv.py <points_with_env_csv> <output_dir> [n_folds] [block_size_km]
Requires: pandas, numpy, sklearn, geopandas, matplotlib
"""
import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "predictive-modeling-best-practices"
_LOG_DIR   = Path("logs")
_LOG_DIR.mkdir(parents=True, exist_ok=True)
_log_file  = _LOG_DIR / f"skill_{SKILL_NAME}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(levelname)s] [" + SKILL_NAME + "] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(_log_file, encoding="utf-8"),
    ],
)
logger = logging.getLogger(SKILL_NAME)

def log_step(n: int, desc: str) -> None:
    logger.info("-- STEP %d: %s", n, desc)

def log_decision(var: str, val, why: str) -> None:
    logger.info("DECISION | %s = %s | %s", var, val, why)

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt


def assign_spatial_blocks(df, lon_col, lat_col, block_size_deg, n_folds):
    """Assign spatial blocks by grid, then allocate to CV folds."""
    lon_blocks = np.floor(df[lon_col] / block_size_deg).astype(int)
    lat_blocks = np.floor(df[lat_col] / block_size_deg).astype(int)
    block_ids  = (lon_blocks.astype(str) + "_" + lat_blocks.astype(str))
    unique_blocks = block_ids.unique()
    np.random.shuffle(unique_blocks)
    fold_map = {blk: (i % n_folds) + 1 for i, blk in enumerate(unique_blocks)}
    return block_ids.map(fold_map)

def collinearity_report(df: pd.DataFrame, predictors: list, r_thresh=0.7) -> pd.DataFrame:
    cor = df[predictors].corr(method="spearman").abs()
    pairs = []
    for i in range(len(predictors)):
        for j in range(i+1, len(predictors)):
            r = cor.iloc[i, j]
            if r > r_thresh:
                pairs.append({"var1": predictors[i], "var2": predictors[j], "spearman_r": round(r, 4)})
    out = pd.DataFrame(pairs, columns=["var1", "var2", "spearman_r"])
    return out.sort_values("spearman_r", ascending=False) if not out.empty else out

def main():
    data_file     = sys.argv[1] if len(sys.argv) > 1 else "data/processed/points_with_env.csv"
    output_dir    = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("outputs/cv")
    n_folds       = int(sys.argv[3]) if len(sys.argv) > 3 else 5
    block_size_km = float(sys.argv[4]) if len(sys.argv) > 4 else 300.0
    output_dir.mkdir(parents=True, exist_ok=True)

    log_decision("data_file", data_file,
                 "Input CSV of occurrence points with extracted environmental predictors")
    log_decision("n_folds", n_folds,
                 "Number of spatial CV folds for model evaluation")
    log_decision("block_size_km", block_size_km,
                 "Spatial block size in km; should exceed spatial autocorrelation range")
    log_decision("output_dir", str(output_dir), "Directory for CV fold assignments and plots")

    if not Path(data_file).exists():
        logger.error(
            "Input not found: %s\n"
            "  Probable cause: previous step did not complete.\n"
            "  Previous skill que deveria ter produzido este input: geoprocessing-for-ecology",
            data_file
        )
        sys.exit(1)

    try:
        log_step(1, "Loading point data with environmental predictors")
        dat = pd.read_csv(data_file)
        logger.info("Loaded %d records with %d columns", len(dat), len(dat.columns))

        lon_col = next((c for c in dat.columns if "lon" in c.lower()), None)
        lat_col = next((c for c in dat.columns if "lat" in c.lower()), None)
        if not lon_col or not lat_col:
            raise ValueError(
                "Cannot find lon/lat columns. Name them decimalLongitude/decimalLatitude."
            )
        logger.info("Coordinate columns identified: lon='%s', lat='%s'", lon_col, lat_col)

        n_missing_coords = dat[[lon_col, lat_col]].isna().any(axis=1).sum()
        if n_missing_coords > 0:
            logger.warning(
                "%d records have missing coordinates and will produce NaN fold assignments.",
                n_missing_coords
            )

        log_step(2, "Assigning spatial blocks and CV fold labels")
        block_size_deg = block_size_km / 111.0  # approx degrees
        log_decision("block_size_deg", round(block_size_deg, 4),
                     "Converted from km using 1 degree ~ 111 km (approximate)")
        np.random.seed(42)
        log_decision("random_seed", 42, "Fixed seed for reproducible fold assignment")
        dat["cv_fold"] = assign_spatial_blocks(dat, lon_col, lat_col, block_size_deg, n_folds)

        log_step(3, "Summarising fold composition")
        # Fold summary
        fold_summary = dat.groupby("cv_fold").agg(n=("cv_fold","count"))
        if "pa" in dat.columns or "presence" in dat.columns:
            resp_col = "pa" if "pa" in dat.columns else "presence"
            fold_summary["n_presence"] = dat.groupby("cv_fold")[resp_col].sum().values

        # Check fold balance
        fold_counts = fold_summary["n"].values
        min_fold = fold_counts.min()
        max_fold = fold_counts.max()
        if max_fold > 3 * min_fold:
            logger.warning(
                "Fold sizes are highly imbalanced (min=%d, max=%d). "
                "Consider adjusting block_size_km.",
                min_fold, max_fold
            )

        logger.info("CV Fold summary (block_size ~%s km):\n%s",
                    block_size_km, fold_summary.to_string())
        dat.to_csv(output_dir / "data_with_cv_folds.csv", index=False)

        log_step(4, "Running collinearity screening on predictors")
        # Collinearity
        skip_cols = {lon_col, lat_col, "pa", "presence", "cv_fold", "QA_status", "species"}
        predictors = [c for c in dat.select_dtypes(include=np.number).columns if c not in skip_cols]
        if predictors:
            cor_pairs = collinearity_report(dat, predictors)
            cor_pairs.to_csv(output_dir / "high_correlation_pairs.csv", index=False)
            logger.info("Highly correlated pairs (|r| > 0.7): %d", len(cor_pairs))
            if len(cor_pairs) > 0:
                logger.warning(
                    "%d predictor pairs exceed |r| = 0.7 Spearman correlation threshold. "
                    "Consider removing redundant variables before modelling.",
                    len(cor_pairs)
                )
                logger.info("%s", cor_pairs.to_string(index=False))
            else:
                logger.info("No highly correlated pairs found.")
        else:
            logger.warning("No numeric predictor columns found for collinearity screening.")

        log_step(5, "Generating spatial CV fold map plot")
        # Spatial plot
        fig, ax = plt.subplots(figsize=(8, 6))
        scatter = ax.scatter(dat[lon_col], dat[lat_col], c=dat["cv_fold"],
                             cmap="Set1", s=15, alpha=0.7)
        plt.colorbar(scatter, ax=ax, label="CV Fold")
        ax.set_xlabel("Longitude"); ax.set_ylabel("Latitude")
        ax.set_title(f"Spatial CV — {n_folds} folds, block ~{block_size_km} km")
        plt.tight_layout()
        plt.savefig(output_dir / "cv_fold_map.png", dpi=150)
        plt.close()
        logger.info("Outputs written to: %s", output_dir)

    except FileNotFoundError as e:
        logger.error(
            "Input file not found: %s\n"
            "  Expected output from: geoprocessing-for-ecology\n"
            "  Check that previous step completed.",
            e
        )
        raise
    except Exception as e:
        logger.error("Unexpected error in spatial CV: %s", e)
        raise

if __name__ == "__main__":
    main()
