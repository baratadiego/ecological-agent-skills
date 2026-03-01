#!/usr/bin/env python3
"""
stack_and_extract.py
Clip rasters to study area and extract values at points.
Usage: python stack_and_extract.py <raster_dir> <points_csv> <studyarea_shp> <output_dir>
Requires: rasterio, geopandas, rasterstats, numpy, pandas
"""
import sys, os
from pathlib import Path
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

    tif_files = sorted(Path(raster_dir).glob("*.tif"))
    print(f"Rasters found: {len(tif_files)}")

    area = gpd.read_file(area_file)
    area_geom = area.geometry.unary_union

    clipped_dir = output_dir / "predictors_clipped"
    clipped_dir.mkdir(exist_ok=True)
    clipped_paths = []
    for tif in tif_files:
        out_path = clipped_dir / tif.name
        clip_to_area(str(tif), area_geom, str(out_path))
        clipped_paths.append(str(out_path))
        print(f"  Clipped: {tif.name}")

    pts = pd.read_csv(points_file)
    print(f"Points loaded: {len(pts)}")
    pts_env = extract_values(clipped_paths, pts)
    pts_env.to_csv(output_dir / "points_with_env.csv", index=False)
    complete = pts_env.dropna().shape[0]
    print(f"Points with complete env data: {complete}/{len(pts)}")
    print(f"Output written to: {output_dir / 'points_with_env.csv'}")

if __name__ == "__main__":
    main()
