#!/usr/bin/env python3
"""
compute_es.py
Compute basic ecosystem service indicators from land cover + biophysical data.
Usage: python compute_es.py <landcover_tif> <carbon_pools_csv> <output_dir>
Services: carbon storage, erosion control (RUSLE C-factor), pollination habitat index
Requires: rasterio, numpy, pandas, geopandas
"""
import sys
from pathlib import Path
import numpy as np
import pandas as pd
import rasterio
from rasterio.transform import rowcol

def load_raster(path: str) -> tuple:
    with rasterio.open(path) as src:
        data = src.read(1).astype(float)
        meta = src.meta.copy()
    return data, meta

def zonal_summary(lc: np.ndarray, es_layer: np.ndarray,
                  class_codes: list, class_names: dict) -> pd.DataFrame:
    rows = []
    for code in class_codes:
        mask = lc == code
        if mask.sum() > 0:
            rows.append({"lulc_code": code,
                         "lulc_name": class_names.get(code, str(code)),
                         "n_pixels":  int(mask.sum()),
                         "mean_es":   round(float(np.nanmean(es_layer[mask])), 4),
                         "total_es":  round(float(np.nansum(es_layer[mask])), 2)})
    return pd.DataFrame(rows).sort_values("lulc_code")

def main():
    lc_file      = sys.argv[1] if len(sys.argv) > 1 else "data/landcover.tif"
    carbon_file  = sys.argv[2] if len(sys.argv) > 2 else "data/carbon_pools.csv"
    output_dir   = Path(sys.argv[3]) if len(sys.argv) > 3 else Path("outputs/ecosystem_services")
    output_dir.mkdir(parents=True, exist_ok=True)

    lc, meta = load_raster(lc_file)
    print(f"Land cover raster: {lc.shape} | Classes: {len(np.unique(lc[~np.isnan(lc)]))}")

    carbon_df = pd.read_csv(carbon_file)
    required_cols = ["lucode", "C_above", "C_below", "C_soil", "C_dead"]
    missing = [c for c in required_cols if c not in carbon_df.columns]
    if missing:
        print(f"Carbon pools CSV missing columns: {missing}. Using zeros.")
        for c in missing:
            carbon_df[c] = 0

    # ── 1. Carbon storage ──────────────────────────────────────────────────
    carbon_map = np.full(lc.shape, np.nan)
    class_names = {}
    for _, row in carbon_df.iterrows():
        mask = lc == row["lucode"]
        total_c = row["C_above"] + row["C_below"] + row["C_soil"] + row["C_dead"]
        carbon_map[mask] = total_c
        if "LULC_name" in carbon_df.columns:
            class_names[int(row["lucode"])] = row["LULC_name"]

    with rasterio.open(output_dir / "carbon_storage_MgCha.tif", "w", **meta) as dst:
        dst.write(carbon_map.astype(np.float32), 1)
    print(f"Carbon: mean = {np.nanmean(carbon_map):.1f} MgC/ha")

    # ── 2. RUSLE C-factor (erosion control proxy) ─────────────────────────
    # Default C-factors (add your own mapping)
    c_factor_defaults = {1: 0.001, 2: 0.005, 3: 0.01, 4: 0.15, 5: 0.30, 6: 1.0}
    c_map = np.full(lc.shape, np.nan)
    for code, c_val in c_factor_defaults.items():
        c_map[lc == code] = c_val
    # Erosion control ES = avoided erosion = (1 - C_factor); higher = better service
    erosion_control = 1.0 - c_map
    with rasterio.open(output_dir / "erosion_control_index.tif", "w", **meta) as dst:
        dst.write(erosion_control.astype(np.float32), 1)

    # ── 3. Pollination habitat index ─────────────────────────────────────
    # Natural / semi-natural = high value (1); crops = partial (0.5); urban/bare = 0
    pollination_suitability = {1: 1.0, 2: 0.8, 3: 0.7, 4: 0.3, 5: 0.1, 6: 0.0}
    poll_map = np.full(lc.shape, np.nan)
    for code, val in pollination_suitability.items():
        poll_map[lc == code] = val
    with rasterio.open(output_dir / "pollination_habitat.tif", "w", **meta) as dst:
        dst.write(poll_map.astype(np.float32), 1)

    # ── Summary table ─────────────────────────────────────────────────────
    class_codes = [int(c) for c in np.unique(lc[~np.isnan(lc)])]
    summary = zonal_summary(lc, carbon_map, class_codes, class_names)
    summary["erosion_control_mean"] = [
        round(float(np.nanmean(erosion_control[lc == c])), 4)
        if np.any(lc == c) else np.nan for c in class_codes]
    summary["pollination_mean"] = [
        round(float(np.nanmean(poll_map[lc == c])), 4)
        if np.any(lc == c) else np.nan for c in class_codes]
    summary.to_csv(output_dir / "es_summary_table.csv", index=False)
    print(f"\nES summary:\n{summary.to_string(index=False)}")
    print(f"\nOutputs written to: {output_dir}")

if __name__ == "__main__":
    main()
