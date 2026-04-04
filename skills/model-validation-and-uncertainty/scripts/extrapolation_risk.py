# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: python extrapolation_risk.py <training_raster_stack.tif> <projection_raster_stack.tif> <output_dir>
#
# Arguments:
#   training_raster_stack.tif   : Multi-band GeoTIFF used for model calibration
#   projection_raster_stack.tif : Multi-band GeoTIFF for the projection area/period
#   output_dir                  : Directory for outputs (created if absent)
#
# Outputs:
#   mop_layer.tif              - MOP raster (0 = strict extrapolation, 1 = fully within range)
#   mess_layer.tif             - MESS raster (negative = novel environment)
#   extrapolation_summary.csv  - Summary statistics (% area per threshold)
#   extrapolation_plots.png    - Side-by-side MOP and MESS maps

import sys
import os
import logging
import datetime
import numpy as np
import pandas as pd
from scipy.spatial.distance import cdist
import rasterio
from rasterio.transform import from_bounds
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors

# -- Inline logger ------------------------------------------------------------
SKILL_NAME = "model-validation-and-uncertainty"
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(SKILL_NAME)
os.makedirs("logs", exist_ok=True)


def log_decision(variable: str, value: str, reason: str) -> None:
    """Log a methodological decision."""
    logger.info("DECISION | %s = %s | %s", variable, value, reason)



def main():
    # -- 1. Parse arguments -------------------------------------------------------
    logger.info("-- STEP 1: Parse arguments and validate inputs")
    if len(sys.argv) < 4:
        logger.warning("Fewer than 3 arguments provided. Using default paths for testing.")
        train_path = "data/predictors/env_train.tif"
        proj_path = "data/predictors/env_proj.tif"
        output_dir = "output/extrapolation"
    else:
        train_path = sys.argv[1]
        proj_path = sys.argv[2]
        output_dir = sys.argv[3]

    log_decision("train_path", train_path, "raster stack used for model calibration")
    log_decision("proj_path", proj_path, "raster stack for the projection area/period")

    if not os.path.isfile(train_path):
        logger.error(
            "Failed to validate inputs: training raster not found: %s\n"
            "Probable cause: incorrect path or GeoTIFF file not generated\n"
            "Check: the training_raster_stack.tif argument and the working directory\n"
            "Previous skill: species-distribution-modelling",
            train_path,
        )
        sys.exit(1)

    if not os.path.isfile(proj_path):
        logger.error(
            "Failed in validate inputs: projection raster not found: %s\n"
            "Probable cause: incorrect path or GeoTIFF file not yet generated\n"
            "Check: the projection_raster_stack.tif argument and working directory\n"
            "Previous skill: species-distribution-modelling",
            proj_path,
        )
        sys.exit(1)

    # -- 2. Create output directory ------------------------------------------------
    os.makedirs(output_dir, exist_ok=True)

    # -- 3. Load raster stacks ----------------------------------------------------
    logger.info("-- STEP 2: Load raster stacks")
    try:
        logger.info("Loading training stack: %s", train_path)
        train_ds = rasterio.open(train_path)
        train_bands = train_ds.read()  # shape: (n_bands, rows, cols)
        train_names = [
            train_ds.descriptions[i] if train_ds.descriptions[i] else f"band_{i+1}"
            for i in range(train_ds.count)
        ]

        logger.info("Loading projection stack: %s", proj_path)
        proj_ds = rasterio.open(proj_path)
        proj_bands = proj_ds.read()
        proj_names = [
            proj_ds.descriptions[i] if proj_ds.descriptions[i] else f"band_{i+1}"
            for i in range(proj_ds.count)
        ]
    except Exception as e:
        logger.error(
            "Failed in load rasters: %s\n"
            "Probable cause: corrupted GeoTIFF file or format not supported\n"
            "Check: TIF file integrity using gdalinfo\n"
            "Previous skill: species-distribution-modelling",
            e,
        )
        sys.exit(1)

    # Validate that both stacks have the same layers
    if set(train_names) != set(proj_names):
        missing = set(train_names) - set(proj_names)
        logger.error(
            "Failed in validate layers: layer names differ between training and projection stacks.\n"
            "Layers missing in projection: %s\n"
            "Probable cause: stacks generated with different variables\n"
            "Check: that both TIFs have the same named bands\n"
            "Previous skill: species-distribution-modelling",
            ", ".join(missing),
        )
        sys.exit(1)

    # Reorder projection layers to match training layer order
    proj_order = [proj_names.index(n) for n in train_names]
    proj_bands = proj_bands[proj_order]
    n_vars = train_ds.count
    logger.info("Variables (%d): %s", n_vars, ", ".join(train_names))

    # -- 4. Extract calibration reference values -----------------------------------
    logger.info("-- STEP 3: Extract calibration reference values")
    try:
        # Reshape to (n_pixels, n_bands) and remove NA rows
        train_flat = train_bands.reshape(n_vars, -1).T  # (n_pixels, n_vars)
        train_nodata = train_ds.nodata
        mask_train = np.all(np.isfinite(train_flat), axis=1)
        if train_nodata is not None:
            mask_train &= np.all(train_flat != train_nodata, axis=1)
        cal_vals = train_flat[mask_train]
        logger.info("Calibration pixels extracted: %d", cal_vals.shape[0])

        if cal_vals.shape[0] < 100:
            logger.warning(
                "Only %d non-NA calibration pixels. MOP estimates may be unstable.",
                cal_vals.shape[0],
            )

        # Scale calibration values for MOP distance computation
        cal_center = np.nanmean(cal_vals, axis=0)
        cal_sd = np.nanstd(cal_vals, axis=0, ddof=1)

        zero_sd_vars = [train_names[i] for i, s in enumerate(cal_sd) if s == 0]
        if zero_sd_vars:
            logger.warning(
                "Variables with zero variance (will be set to sd=1): %s",
                ", ".join(zero_sd_vars),
            )

        cal_sd[cal_sd == 0] = 1.0
        cal_scaled = (cal_vals - cal_center) / cal_sd
        n_cal = cal_scaled.shape[0]
        log_decision(
            "mop_scaling",
            "z-score using calibration mean/sd",
            "ensures all variables contribute equally to Euclidean distance",
        )
    except Exception as e:
        logger.error(
            "Failed in extract calibration values: %s\n"
            "Probable cause: training raster with all NA pixels\n"
            "Check: training raster mask and extent\n"
            "Previous skill: species-distribution-modelling",
            e,
        )
        sys.exit(1)

    # -- 5. Compute MOP (Mobility-Oriented Parity) --------------------------------
    # Reference: Owens et al. 2013. Ecol. Model. 263:10-18.
    # DOI: 10.1016/j.ecolmodel.2013.04.011
    #
    # For each projection pixel, MOP = proportion of calibration points that are
    # "closer" (in standardised Euclidean space) than the projection pixel.
    # MOP = 0 means the pixel is beyond ALL calibration points -- strict extrapolation.

    logger.info("-- STEP 4: Compute MOP layer (Owens et al. 2013)")
    log_decision(
        "mop_percentile",
        "10th percentile of pixel-to-calibration distances",
        "standard implementation following Owens et al. 2013",
    )
    try:
        logger.info("Computing MOP layer (this may take a few minutes)...")

        # Compute pairwise distances among calibration points (reference distribution)
        cal_pairwise_dist = cdist(cal_scaled, cal_scaled, metric="euclidean")
        # 10th percentile of non-zero distances per calibration point
        cal_ref_dist = np.array(
            [
                np.percentile(row[row > 0], 10) if np.any(row > 0) else 0.0
                for row in cal_pairwise_dist
            ]
        )

        # Projection pixels: reshape and scale
        proj_flat = proj_bands.reshape(n_vars, -1).T  # (n_pixels, n_vars)
        proj_nodata = proj_ds.nodata
        mask_proj = np.all(np.isfinite(proj_flat), axis=1)
        if proj_nodata is not None:
            mask_proj &= np.all(proj_flat != proj_nodata, axis=1)

        proj_valid = proj_flat[mask_proj]
        proj_scaled = (proj_valid - cal_center) / cal_sd

        # Compute MOP for each valid projection pixel
        # Process in chunks to manage memory
        chunk_size = 5000
        mop_valid = np.empty(proj_scaled.shape[0], dtype=np.float64)

        for start in range(0, proj_scaled.shape[0], chunk_size):
            end = min(start + chunk_size, proj_scaled.shape[0])
            chunk = proj_scaled[start:end]
            # Distance from each chunk pixel to every calibration point
            d_chunk = cdist(chunk, cal_scaled, metric="euclidean")
            for i in range(d_chunk.shape[0]):
                px_ref_dist = np.percentile(d_chunk[i], 10)
                mop_valid[start + i] = np.sum(cal_ref_dist >= px_ref_dist) / n_cal

        # Reconstruct full raster
        mop_full = np.full(proj_flat.shape[0], np.nan, dtype=np.float64)
        mop_full[mask_proj] = mop_valid
        mop_rast = mop_full.reshape(proj_bands.shape[1], proj_bands.shape[2])

        # Save MOP raster
        mop_path = os.path.join(output_dir, "mop_layer.tif")
        profile = proj_ds.profile.copy()
        profile.update(count=1, dtype="float64", nodata=np.nan)
        with rasterio.open(mop_path, "w", **profile) as dst:
            dst.write(mop_rast, 1)
            dst.set_band_description(1, "MOP")
        logger.info("Saved: %s", mop_path)

    except Exception as e:
        logger.error(
            "Failed in MOP computation: %s\n"
            "Probable cause: insufficient memory for large rasters or unexpected NA values\n"
            "Check: projection raster size and available memory\n"
            "Previous skill: model-validation-and-uncertainty (calibration extraction)",
            e,
        )
        sys.exit(1)

    # -- 6. Compute MESS (Multivariate Environmental Similarity Surfaces) ----------
    # Reference: Elith et al. 2010. Meth. Ecol. Evol. 1:330-342.
    # DOI: 10.1111/j.2041-210X.2010.00036.x
    #
    # MESS < 0 indicates novel environment relative to calibration reference set.

    logger.info("-- STEP 5: Compute MESS layer (Elith et al. 2010)")
    try:
        logger.info("Computing MESS layer...")

        def compute_mess_pixel(px_env: np.ndarray, cal_data: np.ndarray) -> float:
            """Compute MESS for a single pixel across all variables.

            For each variable, similarity is:
              - If px < min(cal): 100 * (px - min) / (max - min)   [negative]
              - If px > max(cal): 100 * (max - px) / (max - min)   [negative]
              - Otherwise: min(f, 100-f) where f = 100 * (sum(cal <= px) / n)
            MESS = min across all variables.
            """
            n = cal_data.shape[0]
            sims = np.empty(cal_data.shape[1])
            for j in range(cal_data.shape[1]):
                col = cal_data[:, j]
                mn, mx = col.min(), col.max()
                rng = mx - mn
                if rng == 0:
                    sims[j] = 0.0
                    continue
                v = px_env[j]
                if v < mn:
                    sims[j] = 100.0 * (v - mn) / rng
                elif v > mx:
                    sims[j] = 100.0 * (mx - v) / rng
                else:
                    f = 100.0 * np.sum(col <= v) / n
                    sims[j] = min(f, 100.0 - f)
            return np.min(sims)

        # Compute MESS for all valid projection pixels
        mess_valid = np.array(
            [compute_mess_pixel(proj_valid[i], cal_vals) for i in range(proj_valid.shape[0])]
        )

        mess_full = np.full(proj_flat.shape[0], np.nan, dtype=np.float64)
        mess_full[mask_proj] = mess_valid
        mess_rast = mess_full.reshape(proj_bands.shape[1], proj_bands.shape[2])

        # Save MESS raster
        mess_path = os.path.join(output_dir, "mess_layer.tif")
        profile_mess = proj_ds.profile.copy()
        profile_mess.update(count=1, dtype="float64", nodata=np.nan)
        with rasterio.open(mess_path, "w", **profile_mess) as dst:
            dst.write(mess_rast, 1)
            dst.set_band_description(1, "MESS")
        logger.info("Saved: %s", mess_path)

    except Exception as e:
        logger.error(
            "Failed in MESS computation: %s\n"
            "Probable cause: incompatibility between rasterio or raster without CRS\n"
            "Check: rasterio version and that rasters have CRS defined\n"
            "Previous skill: model-validation-and-uncertainty (calibration extraction)",
            e,
        )
        sys.exit(1)

    # -- 7. Compute summary statistics --------------------------------------------
    logger.info("-- STEP 6: Compute extrapolation summary statistics")
    try:
        mop_v = mop_full[~np.isnan(mop_full)]
        mess_v = mess_full[~np.isnan(mess_full)]
        n_proj = len(mop_v)

        pct_mop_zero = round(100.0 * np.sum(mop_v == 0) / n_proj, 2)
        pct_mop_025 = round(100.0 * np.sum(mop_v < 0.25) / n_proj, 2)
        pct_mop_050 = round(100.0 * np.sum(mop_v < 0.50) / n_proj, 2)
        pct_mess_neg = round(100.0 * np.sum(mess_v < 0) / len(mess_v), 2)

        summary_df = pd.DataFrame(
            {
                "metric": [
                    "pct_area_MOP_zero",
                    "pct_area_MOP_lt_0.25",
                    "pct_area_MOP_lt_0.50",
                    "pct_area_MESS_negative",
                ],
                "value": [pct_mop_zero, pct_mop_025, pct_mop_050, pct_mess_neg],
                "interpretation": [
                    "Strict extrapolation (MOP = 0)",
                    "High novelty (MOP < 0.25)",
                    "Moderate-high novelty (MOP < 0.50)",
                    "Novel environment in MESS (MESS < 0)",
                ],
            }
        )

        csv_path = os.path.join(output_dir, "extrapolation_summary.csv")
        summary_df.to_csv(csv_path, index=False)
        logger.info("Saved: %s", csv_path)

    except Exception as e:
        logger.error(
            "Failed in summary statistics: %s\n"
            "Probable cause: invalid MOP or MESS rasters\n"
            "Check: previous steps for error messages\n"
            "Previous skill: model-validation-and-uncertainty (MOP/MESS computation)",
            e,
        )
        sys.exit(1)

    # -- 8. Automatic warning if extrapolation is severe ---------------------------
    if pct_mop_025 > 30:
        logger.warning(
            "EXTRAPOLATION WARNING: %.1f%% of the projection area has MOP < 0.25 "
            "(high novelty relative to calibration). Predictions in these areas should "
            "be treated with extreme caution. Recommendation: mask MOP < 0.25 pixels in "
            "publication figures and add explicit caveats in the methods section.",
            pct_mop_025,
        )

    if pct_mop_zero > 10:
        logger.warning(
            "STRICT EXTRAPOLATION WARNING: %.1f%% of the projection area has MOP = 0 "
            "(model extrapolates beyond all calibration data). These pixels MUST be "
            "masked in publication figures.",
            pct_mop_zero,
        )

    # -- 9. Side-by-side diagnostic plots -----------------------------------------
    logger.info("-- STEP 7: Generate extrapolation diagnostic plots")
    try:
        fig, axes = plt.subplots(1, 2, figsize=(16, 7), dpi=150)

        # MOP map
        cmap_mop = plt.cm.terrain_r
        im_mop = axes[0].imshow(mop_rast, cmap=cmap_mop, vmin=0, vmax=1)
        axes[0].set_title("MOP (0 = strict extrapolation)")
        axes[0].set_xlabel(f"MOP = 0: {pct_mop_zero}% | MOP < 0.25: {pct_mop_025}%")
        axes[0].set_xticks([])
        axes[0].set_yticks([])
        fig.colorbar(im_mop, ax=axes[0], fraction=0.046, pad=0.04)

        # MESS map (diverging palette: red = novel, blue = similar)
        cmap_mess = mcolors.LinearSegmentedColormap.from_list(
            "mess_diverge", ["red", "white", "steelblue"]
        )
        vabs = max(abs(np.nanmin(mess_rast)), abs(np.nanmax(mess_rast)))
        im_mess = axes[1].imshow(mess_rast, cmap=cmap_mess, vmin=-vabs, vmax=vabs)
        axes[1].set_title("MESS (negative = novel environment)")
        axes[1].set_xlabel(f"MESS < 0: {pct_mess_neg}%")
        axes[1].set_xticks([])
        axes[1].set_yticks([])
        fig.colorbar(im_mess, ax=axes[1], fraction=0.046, pad=0.04)

        plt.tight_layout()
        plot_path = os.path.join(output_dir, "extrapolation_plots.png")
        fig.savefig(plot_path)
        plt.close(fig)
        logger.info("Saved: %s", plot_path)

    except Exception as e:
        logger.error(
            "Failed in diagnostic plots: %s\n"
            "Probable cause: graphics backend not available or invalid rasters\n"
            "Check: matplotlib backend availability and raster integrity\n"
            "Previous skill: model-validation-and-uncertainty (MOP/MESS computation)",
            e,
        )
        sys.exit(1)

    # -- 10. Final summary --------------------------------------------------------
    logger.info("========== EXTRAPOLATION SUMMARY ==========")
    logger.info("%% area MOP = 0    (strict extrapolation): %.2f%%", pct_mop_zero)
    logger.info("%% area MOP < 0.25 (high novelty)        : %.2f%%", pct_mop_025)
    logger.info("%% area MOP < 0.50 (moderate novelty)    : %.2f%%", pct_mop_050)
    logger.info("%% area MESS < 0   (novel environment)   : %.2f%%", pct_mess_neg)
    logger.info("===========================================")

    # Clean up
    train_ds.close()
    proj_ds.close()


if __name__ == "__main__":
    main()
