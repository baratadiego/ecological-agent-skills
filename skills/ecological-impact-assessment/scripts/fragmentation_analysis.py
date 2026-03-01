#!/usr/bin/env python3
"""
fragmentation_analysis.py
Compute landscape fragmentation metrics from a land cover raster.
Usage: python fragmentation_analysis.py <landcover_tif> <habitat_class> <output_dir>
Requires: rasterio, numpy, pandas, scipy, skimage
"""
import sys
from pathlib import Path
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

    print(f"Loading: {tif_file} | Habitat class: {habitat_class}")
    mask, (xres, yres), projected = load_habitat_mask(tif_file, habitat_class)
    cell_area_ha = abs(xres * yres) / 10000  # m² → ha (assumes projected CRS)
    if not projected:
        print("WARNING: Raster appears to be in geographic CRS. Area estimates will be approximate.")

    labeled, n_patches = label_patches(mask)
    print(f"Patches found: {n_patches}")

    metrics = compute_metrics(mask, labeled, n_patches, cell_area_ha)
    print("\nFragmentation Metrics:")
    print(metrics.to_string())

    metrics_df = metrics.to_frame(name="value").reset_index().rename(columns={"index": "metric"})
    metrics_df.to_csv(output_dir / "fragmentation_metrics.csv", index=False)
    print(f"\nSaved to: {output_dir / 'fragmentation_metrics.csv'}")

if __name__ == "__main__":
    main()
