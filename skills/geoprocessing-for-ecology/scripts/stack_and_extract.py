#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
stack_and_extract.py
Clip rasters to study area and extract values at points.
Usage: python stack_and_extract.py <raster_dir> <points_csv> <studyarea_shp> <output_dir>
Requires: rasterio, geopandas, rasterstats, numpy, pandas
"""
import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "geoprocessing-for-ecology"
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

import os
import numpy as np
import pandas as pd
import geopandas as gpd
import rasterio
from rasterio.mask import mask as rio_mask
from rasterio.warp import reproject, Resampling, calculate_default_transform
from shapely.geometry import mapping


def reproject_raster(src_path, dst_path, dst_crs):
    with rasterio.open(src_path) as src:
        transform, width, height = calculate_default_transform(
            src.crs, dst_crs, src.width, src.height, *src.bounds)
        kwargs = src.meta.copy()
        kwargs.update({"crs": dst_crs, "transform": transform, "width": width, "height": height})
        with rasterio.open(dst_path, "w", **kwargs) as dst:
            for i in range(1, src.count + 1):
                reproject(source=rasterio.band(src, i), destination=rasterio.band(dst, i),
                          src_transform=src.transform, src_crs=src.crs,
                          dst_transform=transform, dst_crs=dst_crs,
                          resampling=Resampling.bilinear)

def clip_to_area(raster_path, area_geom, out_path):
    with rasterio.open(raster_path) as src:
        out_image, out_transform = rio_mask(src, [mapping(area_geom)], crop=True)
        out_meta = src.meta.copy()
        out_meta.update({"transform": out_transform, "width": out_image.shape[2],
                         "height": out_image.shape[1]})
        with rasterio.open(out_path, "w", **out_meta) as dst:
            dst.write(out_image)

def extract_values(raster_paths, points_df, lon_col="decimalLongitude", lat_col="decimalLatitude"):
    from rasterstats import point_query
    result_df = points_df.copy()
    coords = list(zip(points_df[lon_col], points_df[lat_col]))
    for rpath in raster_paths:
        varname = Path(rpath).stem
        vals = point_query(coords, rpath, interpolate="bilinear")
        result_df[varname] = vals
    return result_df

def main():
    raster_dir  = sys.argv[1] if len(sys.argv) > 1 else "data/predictors/raw"
    points_file = sys.argv[2] if len(sys.argv) > 2 else "data/processed/data_clean.csv"
    area_file   = sys.argv[3] if len(sys.argv) > 3 else "data/spatial/study_area.shp"
    output_dir  = Path(sys.argv[4]) if len(sys.argv) > 4 else Path("data/processed")
    output_dir.mkdir(parents=True, exist_ok=True)

    log_decision("raster_dir", raster_dir, "Directory containing raw predictor GeoTIFFs")
    log_decision("points_file", points_file, "CSV of occurrence/sample points with coordinates")
    log_decision("area_file", area_file, "Shapefile defining the study area extent for clipping")
    log_decision("output_dir", str(output_dir), "Directory for clipped rasters and extracted values")

    if not Path(raster_dir).exists():
        logger.error(
            "Input nao encontrado: %s\n"
            "  Causa provavel: passo anterior nao concluiu.\n"
            "  Skill anterior que deveria ter produzido este input: reproducible-ecology-pipeline",
            raster_dir
        )
        sys.exit(1)

    if not Path(points_file).exists():
        logger.error(
            "Input nao encontrado: %s\n"
            "  Causa provavel: passo anterior nao concluiu.\n"
            "  Skill anterior que deveria ter produzido este input: reproducible-ecology-pipeline",
            points_file
        )
        sys.exit(1)

    if not Path(area_file).exists():
        logger.error(
            "Input nao encontrado: %s\n"
            "  Causa provavel: passo anterior nao concluiu.\n"
            "  Skill anterior que deveria ter produzido este input: reproducible-ecology-pipeline",
            area_file
        )
        sys.exit(1)

    try:
        log_step(1, "Discovering raster files in raster directory")
        tif_files = sorted(Path(raster_dir).glob("*.tif"))
        logger.info("Rasters found: %d", len(tif_files))
        if len(tif_files) == 0:
            logger.warning(
                "No .tif files found in %s. Check raster_dir path or file extension.", raster_dir
            )

        log_step(2, "Loading study area geometry")
        area = gpd.read_file(area_file)
        area_geom = area.geometry.unary_union

        log_step(3, "Clipping rasters to study area extent")
        clipped_dir = output_dir / "predictors_clipped"
        clipped_dir.mkdir(exist_ok=True)
        clipped_paths = []
        for tif in tif_files:
            out_path = clipped_dir / tif.name
            clip_to_area(str(tif), area_geom, str(out_path))
            clipped_paths.append(str(out_path))
            logger.info("  Clipped: %s", tif.name)

        log_step(4, "Loading point data and extracting raster values")
        pts = pd.read_csv(points_file)
        logger.info("Points loaded: %d", len(pts))
        pts_env = extract_values(clipped_paths, pts)
        pts_env.to_csv(output_dir / "points_with_env.csv", index=False)

        complete = pts_env.dropna().shape[0]
        incomplete = len(pts) - complete
        logger.info(
            "Points with complete env data: %d/%d", complete, len(pts)
        )
        if incomplete > 0:
            logger.warning(
                "%d points have missing values after extraction — likely fall outside raster extent.",
                incomplete
            )
        logger.info("Output written to: %s", output_dir / "points_with_env.csv")

    except FileNotFoundError as e:
        logger.error(
            "Input file not found: %s\n"
            "  Expected output from: reproducible-ecology-pipeline\n"
            "  Check that previous step completed.",
            e
        )
        raise
    except Exception as e:
        logger.error("Unexpected error in stack and extract: %s", e)
        raise

if __name__ == "__main__":
    main()
