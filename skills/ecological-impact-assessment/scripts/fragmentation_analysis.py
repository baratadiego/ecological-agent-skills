#!/usr/bin/env python3
"""
fragmentation_analysis.py
Compute landscape fragmentation metrics from a land cover raster.
Usage: python fragmentation_analysis.py <landcover_tif> <habitat_class> <output_dir>
Requires: rasterio, numpy, pandas, scipy, skimage
"""
import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "ecological-impact-assessment"
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
from scipy import ndimage


def load_habitat_mask(tif_path: str, habitat_class: int) -> tuple:
    with rasterio.open(tif_path) as src:
        lc = src.read(1).astype(float)
        res = src.res  # (x_res, y_res) in map units
        crs_is_projected = src.crs.is_projected if src.crs else False
    mask = (lc == habitat_class).astype(int)
    return mask, res, crs_is_projected

def label_patches(mask: np.ndarray):
    struct = ndimage.generate_binary_structure(2, 2)  # 8-connectivity
    labeled, n_patches = ndimage.label(mask, structure=struct)
    return labeled, n_patches

def compute_metrics(mask: np.ndarray, labeled: np.ndarray, n_patches: int,
                    cell_area_ha: float) -> pd.Series:
    total_cells = mask.sum()
    total_area_ha = total_cells * cell_area_ha
    patch_sizes = ndimage.sum(mask, labeled, range(1, n_patches + 1))
    patch_areas_ha = np.array(patch_sizes) * cell_area_ha
    landscape_area_ha = mask.size * cell_area_ha

    largest_patch_ha = patch_areas_ha.max() if len(patch_areas_ha) > 0 else 0
    lpi = (largest_patch_ha / landscape_area_ha) * 100

    # Effective mesh size: MESH = Σ(Ai²) / A_landscape
    mesh = np.sum(patch_areas_ha ** 2) / landscape_area_ha

    return pd.Series({
        "total_habitat_ha":     round(total_area_ha, 2),
        "landscape_area_ha":    round(landscape_area_ha, 2),
        "habitat_cover_pct":    round(100 * total_area_ha / landscape_area_ha, 2),
        "n_patches":            int(n_patches),
        "mean_patch_size_ha":   round(float(patch_areas_ha.mean()), 2) if len(patch_areas_ha) > 0 else 0,
        "median_patch_size_ha": round(float(np.median(patch_areas_ha)), 2) if len(patch_areas_ha) > 0 else 0,
        "largest_patch_ha":     round(float(largest_patch_ha), 2),
        "lpi_pct":              round(float(lpi), 3),
        "mesh_ha":              round(float(mesh), 2),
    })

def main():
    tif_file      = sys.argv[1] if len(sys.argv) > 1 else "data/landcover.tif"
    habitat_class = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    output_dir    = Path(sys.argv[3]) if len(sys.argv) > 3 else Path("outputs/fragmentation")
    output_dir.mkdir(parents=True, exist_ok=True)

    log_decision("tif_file", tif_file, "Input land cover raster path")
    log_decision("habitat_class", habitat_class, "Target habitat class code to extract")
    log_decision("output_dir", str(output_dir), "Directory for fragmentation metric outputs")

    if not Path(tif_file).exists():
        logger.error(
            "Input nao encontrado: %s\n"
            "  Causa provavel: passo anterior nao concluiu.\n"
            "  Skill anterior que deveria ter produzido este input: geoprocessing-for-ecology",
            tif_file
        )
        sys.exit(1)

    try:
        log_step(1, "Loading habitat mask from raster")
        logger.info("Loading: %s | Habitat class: %s", tif_file, habitat_class)
        mask, (xres, yres), projected = load_habitat_mask(tif_file, habitat_class)
        cell_area_ha = abs(xres * yres) / 10000  # m² → ha (assumes projected CRS)
        log_decision("cell_area_ha", round(cell_area_ha, 6), "Derived from pixel resolution; assumes projected CRS")
        if not projected:
            logger.warning(
                "Raster appears to be in geographic CRS. Area estimates will be approximate."
            )

        log_step(2, "Labeling habitat patches with 8-connectivity")
        labeled, n_patches = label_patches(mask)
        logger.info("Patches found: %d", n_patches)
        if n_patches == 0:
            logger.warning("No patches found for habitat class %d. Check class code.", habitat_class)

        log_step(3, "Computing fragmentation metrics")
        metrics = compute_metrics(mask, labeled, n_patches, cell_area_ha)
        logger.info("Fragmentation Metrics:\n%s", metrics.to_string())

        log_step(4, "Writing outputs")
        metrics_df = metrics.to_frame(name="value").reset_index().rename(columns={"index": "metric"})
        out_csv = output_dir / "fragmentation_metrics.csv"
        metrics_df.to_csv(out_csv, index=False)
        logger.info("Saved to: %s", out_csv)

    except FileNotFoundError as e:
        logger.error(
            "Input file not found: %s\n"
            "  Expected output from: geoprocessing-for-ecology\n"
            "  Check that previous step completed.",
            e
        )
        raise
    except Exception as e:
        logger.error("Unexpected error in fragmentation analysis: %s", e)
        raise

if __name__ == "__main__":
    main()
