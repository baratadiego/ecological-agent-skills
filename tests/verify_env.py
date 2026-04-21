#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
verify_env.py — Functional smoke test for the Python geospatial stack.

Beyond checking whether packages import, this script exercises the native
libraries (GDAL/GEOS/PROJ) that commonly mismatch across conda envs,
DevContainers, WSL, and macOS. A green run here means rasterio, geopandas,
shapely, and pyproj can actually manipulate geometries and rasters end-to-end.

Usage:
    python tests/verify_env.py

Exit codes:
    0 = all checks passed
    1 = at least one check failed (details printed)
"""

from __future__ import annotations

import importlib
import sys
import tempfile
import traceback
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
FIXTURE_RASTER = REPO_ROOT / "tests" / "data" / "rasters" / "bio1.tif"

results: list[tuple[str, bool, str]] = []


def record(name: str, ok: bool, detail: str = "") -> None:
    results.append((name, ok, detail))
    status = "PASS" if ok else "FAIL"
    print(f"  [{status}] {name}" + (f" — {detail}" if detail else ""))


def check_import(
    module: str,
    min_version: str | None = None,
    optional: bool = False,
) -> None:
    try:
        mod = importlib.import_module(module)
    except Exception as exc:
        label = f"import {module}" + (" (optional)" if optional else "")
        if optional:
            # Record as passing but flag in detail so the summary stays green.
            record(label, True, f"skipped — {type(exc).__name__}: {exc}")
        else:
            record(label, False, f"{type(exc).__name__}: {exc}")
        return
    version = getattr(mod, "__version__", "?")
    detail = f"v{version}"
    if min_version and version != "?":
        from packaging.version import Version  # type: ignore

        if Version(version) < Version(min_version):
            record(f"import {module}", False, f"{detail} < required {min_version}")
            return
    record(f"import {module}" + (" (optional)" if optional else ""), True, detail)


def check_pyproj_crs() -> None:
    try:
        import pyproj

        crs = pyproj.CRS.from_epsg(3857)
        tr = pyproj.Transformer.from_crs(4326, 3857, always_xy=True)
        x, y = tr.transform(-47.9, -15.8)
        record(
            "pyproj CRS + transform",
            True,
            f"WGS84 -> Web Mercator ({x:.0f}, {y:.0f}); proj={pyproj.proj_version_str}",
        )
    except Exception as exc:
        record("pyproj CRS + transform", False, f"{type(exc).__name__}: {exc}")


def check_shapely_geos() -> None:
    try:
        from shapely.geometry import Point, box

        a = box(0, 0, 10, 10)
        b = Point(5, 5).buffer(2)
        inter = a.intersection(b)
        assert inter.area > 0, "empty intersection"
        record(
            "shapely GEOS ops",
            True,
            f"intersection.area={inter.area:.2f}",
        )
    except Exception as exc:
        record("shapely GEOS ops", False, f"{type(exc).__name__}: {exc}")


def check_geopandas_roundtrip() -> None:
    try:
        import geopandas as gpd
        from shapely.geometry import Point

        gdf = gpd.GeoDataFrame(
            {"id": [1, 2, 3]},
            geometry=[Point(0, 0), Point(1, 1), Point(2, 2)],
            crs="EPSG:4326",
        )
        projected = gdf.to_crs(3857)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "pts.gpkg"
            projected.to_file(path, driver="GPKG")
            back = gpd.read_file(path)
        assert len(back) == 3, f"expected 3 rows, got {len(back)}"
        record(
            "geopandas reproject + GPKG I/O",
            True,
            f"3 points round-tripped (EPSG:{back.crs.to_epsg()})",
        )
    except Exception as exc:
        record(
            "geopandas reproject + GPKG I/O",
            False,
            f"{type(exc).__name__}: {exc}",
        )


def check_rasterio_gdal() -> None:
    try:
        import rasterio
        from rasterio.warp import Resampling, calculate_default_transform, reproject

        if not FIXTURE_RASTER.exists():
            record(
                "rasterio read + reproject",
                False,
                f"fixture missing: {FIXTURE_RASTER.relative_to(REPO_ROOT)}",
            )
            return

        with rasterio.open(FIXTURE_RASTER) as src:
            src_crs = src.crs
            src_bounds = src.bounds
            data = src.read(1)
            dst_crs = "EPSG:4326"
            transform, w, h = calculate_default_transform(
                src_crs, dst_crs, src.width, src.height, *src_bounds
            )
            dst = rasterio.io.MemoryFile().open(
                driver="GTiff",
                width=w,
                height=h,
                count=1,
                dtype=data.dtype,
                crs=dst_crs,
                transform=transform,
            )
            reproject(
                source=data,
                destination=rasterio.band(dst, 1),
                src_transform=src.transform,
                src_crs=src_crs,
                dst_transform=transform,
                dst_crs=dst_crs,
                resampling=Resampling.bilinear,
            )
            dst.close()
        record(
            "rasterio read + reproject",
            True,
            f"source EPSG:{src_crs.to_epsg()} -> 4326, {data.shape} array",
        )
    except Exception as exc:
        record(
            "rasterio read + reproject",
            False,
            f"{type(exc).__name__}: {exc}",
        )


def check_vector_drivers() -> None:
    """Check that at least one vector I/O backend exposes GPKG/SHP/GeoJSON.

    geopandas 1.0+ prefers pyogrio; fiona is only required on legacy stacks.
    """
    required = {"GPKG", "ESRI Shapefile", "GeoJSON"}
    backends: list[tuple[str, set[str]]] = []

    try:
        import pyogrio  # type: ignore

        drivers = set(pyogrio.list_drivers().keys())
        backends.append(("pyogrio", drivers))
    except Exception:
        pass

    try:
        import fiona  # type: ignore

        backends.append(("fiona", set(fiona.supported_drivers.keys())))
    except Exception:
        pass

    if not backends:
        record(
            "vector I/O drivers",
            False,
            "neither pyogrio nor fiona is importable",
        )
        return

    for name, drivers in backends:
        missing = required - drivers
        if missing:
            record(
                f"{name} drivers",
                False,
                f"missing: {sorted(missing)}",
            )
        else:
            record(
                f"{name} drivers",
                True,
                f"{len(drivers)} drivers registered (GPKG/SHP/GeoJSON OK)",
            )


def main() -> int:
    print("=== Python geospatial smoke test ===")
    print(f"  interpreter: {sys.executable}")
    print(f"  python:      {sys.version.split()[0]}")
    print()

    print("--- Imports ---")
    for pkg in ["numpy", "pandas", "scipy", "matplotlib"]:
        check_import(pkg)
    for pkg in ["rasterio", "geopandas", "shapely", "pyproj"]:
        check_import(pkg)
    # Either pyogrio or fiona satisfies vector I/O. At least one must work
    # (checked functionally below); import status is informational.
    check_import("pyogrio", optional=True)
    check_import("fiona", optional=True)
    print()

    print("--- Functional checks ---")
    check_pyproj_crs()
    check_shapely_geos()
    check_geopandas_roundtrip()
    check_rasterio_gdal()
    check_vector_drivers()
    print()

    passed = sum(1 for _, ok, _ in results if ok)
    failed = len(results) - passed
    print(f"=== Summary: {passed}/{len(results)} passed, {failed} failed ===")

    if failed:
        print()
        print("Failed checks:")
        for name, ok, detail in results:
            if not ok:
                print(f"  - {name}: {detail}")
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        traceback.print_exc()
        sys.exit(2)
