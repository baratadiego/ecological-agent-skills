#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
compute_es.py
Compute basic ecosystem service indicators from land cover + biophysical data.
Usage: python compute_es.py <landcover_tif> <carbon_pools_csv> <output_dir>
Services: carbon storage, erosion control (RUSLE C-factor), pollination habitat index
Requires: rasterio, numpy, pandas, geopandas
"""
import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "ecosystem-services-assessment"
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

    log_decision("lc_file", lc_file, "Input land cover raster")
    log_decision("carbon_file", carbon_file, "Carbon pools lookup CSV")
    log_decision("output_dir", str(output_dir), "Directory for ecosystem service outputs")

    if not Path(lc_file).exists():
        logger.error(
            "Input not found: %s\n"
            "  Probable cause: previous step did not complete.\n"
            "  Previous skill que deveria ter produzido este input: geoprocessing-for-ecology",
            lc_file
        )
        sys.exit(1)

    if not Path(carbon_file).exists():
        logger.error(
            "Input not found: %s\n"
            "  Probable cause: previous step did not complete.\n"
            "  Previous skill que deveria ter produzido este input: reproducible-ecology-pipeline",
            carbon_file
        )
        sys.exit(1)

    try:
        log_step(1, "Loading land cover raster")
        lc, meta = load_raster(lc_file)
        n_classes = len(np.unique(lc[~np.isnan(lc)]))
        logger.info("Land cover raster: %s | Classes: %d", lc.shape, n_classes)

        log_step(2, "Loading and validating carbon pools CSV")
        carbon_df = pd.read_csv(carbon_file)
        required_cols = ["lucode", "C_above", "C_below", "C_soil", "C_dead"]
        missing = [c for c in required_cols if c not in carbon_df.columns]
        if missing:
            logger.warning(
                "Carbon pools CSV missing columns: %s. Using zeros for missing fields.", missing
            )
            for c in missing:
                carbon_df[c] = 0

        # ── 1. Carbon storage ──────────────────────────────────────────────────
        log_step(3, "Computing carbon storage layer")
        carbon_map = np.full(lc.shape, np.nan)
        class_names = {}
        for _, row in carbon_df.iterrows():
            mask = lc == row["lucode"]
            total_c = row["C_above"] + row["C_below"] + row["C_soil"] + row["C_dead"]
            carbon_map[mask] = total_c
            if "LULC_name" in carbon_df.columns:
                class_names[int(row["lucode"])] = row["LULC_name"]

        carbon_out = output_dir / "carbon_storage_MgCha.tif"
        with rasterio.open(carbon_out, "w", **meta) as dst:
            dst.write(carbon_map.astype(np.float32), 1)
        logger.info("Carbon: mean = %.1f MgC/ha | Output: %s", np.nanmean(carbon_map), carbon_out)

        # ── 2. RUSLE C-factor (erosion control proxy) ─────────────────────────
        log_step(4, "Computing RUSLE C-factor erosion control layer")
        # Default C-factors (add your own mapping)
        c_factor_defaults = {1: 0.001, 2: 0.005, 3: 0.01, 4: 0.15, 5: 0.30, 6: 1.0}
        log_decision("c_factor_defaults", c_factor_defaults,
                     "Default RUSLE C-factors per LULC class; replace with site-specific values")
        c_map = np.full(lc.shape, np.nan)
        for code, c_val in c_factor_defaults.items():
            c_map[lc == code] = c_val
        # Erosion control ES = avoided erosion = (1 - C_factor); higher = better service
        erosion_control = 1.0 - c_map
        unmapped = np.sum(np.isnan(c_map) & ~np.isnan(lc))
        if unmapped > 0:
            logger.warning(
                "%d pixels have no C-factor mapping (not in c_factor_defaults). "
                "Erosion control will be NaN for those pixels.",
                unmapped
            )
        erosion_out = output_dir / "erosion_control_index.tif"
        with rasterio.open(erosion_out, "w", **meta) as dst:
            dst.write(erosion_control.astype(np.float32), 1)
        logger.info("Erosion control layer written: %s", erosion_out)

        # ── 3. Pollination habitat index ─────────────────────────────────────
        log_step(5, "Computing pollination habitat index layer")
        # Natural / semi-natural = high value (1); crops = partial (0.5); urban/bare = 0
        pollination_suitability = {1: 1.0, 2: 0.8, 3: 0.7, 4: 0.3, 5: 0.1, 6: 0.0}
        log_decision("pollination_suitability", pollination_suitability,
                     "Expert-based pollination suitability scores per LULC class")
        poll_map = np.full(lc.shape, np.nan)
        for code, val in pollination_suitability.items():
            poll_map[lc == code] = val
        poll_out = output_dir / "pollination_habitat.tif"
        with rasterio.open(poll_out, "w", **meta) as dst:
            dst.write(poll_map.astype(np.float32), 1)
        logger.info("Pollination habitat layer written: %s", poll_out)

        # ── Summary table ─────────────────────────────────────────────────────
        log_step(6, "Building zonal summary table")
        class_codes = [int(c) for c in np.unique(lc[~np.isnan(lc)])]
        summary = zonal_summary(lc, carbon_map, class_codes, class_names)
        summary["erosion_control_mean"] = [
            round(float(np.nanmean(erosion_control[lc == c])), 4)
            if np.any(lc == c) else np.nan for c in class_codes]
        summary["pollination_mean"] = [
            round(float(np.nanmean(poll_map[lc == c])), 4)
            if np.any(lc == c) else np.nan for c in class_codes]
        summary_out = output_dir / "es_summary_table.csv"
        summary.to_csv(summary_out, index=False)
        logger.info("ES summary:\n%s", summary.to_string(index=False))
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
        logger.error("Unexpected error in ecosystem services assessment: %s", e)
        raise

if __name__ == "__main__":
    main()
