#!/usr/bin/env python3
"""
spatial_cv.py
Spatial block cross-validation for ecological models.
Usage: python spatial_cv.py <points_with_env_csv> <output_dir> [n_folds] [block_size_km]
Requires: pandas, numpy, sklearn, geopandas, matplotlib
"""
import sys
from pathlib import Path
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
    return pd.DataFrame(pairs).sort_values("spearman_r", ascending=False)

def main():
    data_file     = sys.argv[1] if len(sys.argv) > 1 else "data/processed/points_with_env.csv"
    output_dir    = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("outputs/cv")
    n_folds       = int(sys.argv[3]) if len(sys.argv) > 3 else 5
    block_size_km = float(sys.argv[4]) if len(sys.argv) > 4 else 300.0
    output_dir.mkdir(parents=True, exist_ok=True)

    dat = pd.read_csv(data_file)
    lon_col = next((c for c in dat.columns if "lon" in c.lower()), None)
    lat_col = next((c for c in dat.columns if "lat" in c.lower()), None)
    if not lon_col or not lat_col:
        raise ValueError("Cannot find lon/lat columns. Name them decimalLongitude/decimalLatitude.")

    block_size_deg = block_size_km / 111.0  # approx degrees
    np.random.seed(42)
    dat["cv_fold"] = assign_spatial_blocks(dat, lon_col, lat_col, block_size_deg, n_folds)

    # Fold summary
    fold_summary = dat.groupby("cv_fold").agg(n=("cv_fold","count"))
    if "pa" in dat.columns or "presence" in dat.columns:
        resp_col = "pa" if "pa" in dat.columns else "presence"
        fold_summary["n_presence"] = dat.groupby("cv_fold")[resp_col].sum().values
    print(f"\nCV Fold summary (block_size ≈ {block_size_km} km):")
    print(fold_summary.to_string())
    dat.to_csv(output_dir / "data_with_cv_folds.csv", index=False)

    # Collinearity
    skip_cols = {lon_col, lat_col, "pa", "presence", "cv_fold", "QA_status", "species"}
    predictors = [c for c in dat.select_dtypes(include=np.number).columns if c not in skip_cols]
    if predictors:
        cor_pairs = collinearity_report(dat, predictors)
        cor_pairs.to_csv(output_dir / "high_correlation_pairs.csv", index=False)
        print(f"\nHighly correlated pairs (|r| > 0.7): {len(cor_pairs)}")
        print(cor_pairs.to_string(index=False) if len(cor_pairs) > 0 else "  None found.")

    # Spatial plot
    fig, ax = plt.subplots(figsize=(8, 6))
    scatter = ax.scatter(dat[lon_col], dat[lat_col], c=dat["cv_fold"],
                         cmap="Set1", s=15, alpha=0.7)
    plt.colorbar(scatter, ax=ax, label="CV Fold")
    ax.set_xlabel("Longitude"); ax.set_ylabel("Latitude")
    ax.set_title(f"Spatial CV — {n_folds} folds, block ≈ {block_size_km} km")
    plt.tight_layout()
    plt.savefig(output_dir / "cv_fold_map.png", dpi=150)
    plt.close()
    print(f"\nOutputs written to: {output_dir}")

if __name__ == "__main__":
    main()
