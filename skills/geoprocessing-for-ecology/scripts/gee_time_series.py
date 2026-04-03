# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""Extract MODIS/Landsat time series from Google Earth Engine without local download.

Usage:
    python gee_time_series.py <study_area_geojson> <output_dir>
                              [--start YYYY-MM-DD] [--end YYYY-MM-DD]
                              [--collection modis_ndvi|landsat_sr|modis_lst]
                              [--scale 250|30|1000]
                              [--project GEE_PROJECT_ID]

Arguments:
    study_area_geojson : GeoJSON file with study area polygon (EPSG:4326)
    output_dir         : Directory for output CSVs and GeoTIFFs (created if absent)
    --start            : Start date (default: 2015-01-01)
    --end              : End date   (default: today)
    --collection       : Data product (default: modis_ndvi)
    --scale            : Spatial resolution in metres (default: product native)
    --project          : GEE cloud project ID (overrides GOOGLE_CLOUD_PROJECT env var)

Collections available:
    modis_ndvi   : MOD13Q1 v061 — 16-day NDVI/EVI at 250 m (2000-present)
    modis_lst    : MOD11A2 v061 — 8-day Land Surface Temperature at 1 km
    landsat_sr   : Landsat 8/9 Collection 2 SR — 30 m, cloud-masked composites

Outputs:
    output_dir/gee_time_series.csv       — date × band mean values within AOI
    output_dir/gee_metadata.json         — collection info, scale, date range, band names
    output_dir/gee_composite.tif         — median composite GeoTIFF (optional, if ee.batch)

Authentication:
    Run `earthengine authenticate` once before first use, or set
    GOOGLE_APPLICATION_CREDENTIALS env var for service account auth.

References:
    MODIS NDVI (MOD13Q1): Didan (2021) doi:10.5067/MODIS/MOD13Q1.061
    MODIS LST  (MOD11A2): Wan et al. (2021) doi:10.5067/MODIS/MOD11A2.061
    Landsat C2 SR: USGS (2022) https://www.usgs.gov/landsat-missions/landsat-collection-2
    Earth Engine Python API: Gorelick et al. (2017) doi:10.1016/j.rse.2017.06.031
"""

import argparse
import json
import logging
import sys
from datetime import date, datetime
from pathlib import Path

SKILL_NAME = "geoprocessing-for-ecology"
_LOG_DIR   = Path("logs")
_LOG_DIR.mkdir(parents=True, exist_ok=True)
_log_file  = _LOG_DIR / f"skill_{SKILL_NAME}_gee_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
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


# ── Collection registry ────────────────────────────────────────────────────────

COLLECTIONS = {
    "modis_ndvi": {
        "id":          "MODIS/061/MOD13Q1",
        "bands":       ["NDVI", "EVI"],
        "scale":       250,
        "frequency":   "16-day",
        "qa_band":     "SummaryQA",
        "qa_good":     [0],          # 0 = good quality pixel
        "scale_factor": 0.0001,
        "citation":    "Didan (2021) doi:10.5067/MODIS/MOD13Q1.061",
    },
    "modis_lst": {
        "id":          "MODIS/061/MOD11A2",
        "bands":       ["LST_Day_1km", "LST_Night_1km"],
        "scale":       1000,
        "frequency":   "8-day",
        "qa_band":     "QC_Day",
        "qa_good":     None,         # QC handled via bit mask below
        "scale_factor": 0.02,        # K; subtract 273.15 for °C
        "citation":    "Wan et al. (2021) doi:10.5067/MODIS/MOD11A2.061",
    },
    "landsat_sr": {
        "id":          None,         # dynamically merged L8 + L9
        "bands":       ["SR_B2", "SR_B3", "SR_B4", "SR_B5", "SR_B6", "SR_B7"],
        "band_labels": ["Blue", "Green", "Red", "NIR", "SWIR1", "SWIR2"],
        "scale":       30,
        "frequency":   "scene (~16-day revisit)",
        "qa_band":     "QA_PIXEL",
        "scale_factor": 2.75e-05,
        "offset":      -0.2,
        "citation":    "USGS (2022) Landsat Collection 2 Level-2",
    },
}


# ── GEE helpers ────────────────────────────────────────────────────────────────

def mask_modis_ndvi(image):
    """Mask low-quality MODIS NDVI pixels (SummaryQA != 0)."""
    import ee
    qa  = image.select("SummaryQA")
    mask = qa.eq(0)
    return image.updateMask(mask)


def mask_modis_lst(image):
    """Keep LST pixels with bits 0-1 == 0 (good quality, no mandatory QA flags)."""
    import ee
    qc   = image.select("QC_Day")
    mask = qc.bitwiseAnd(3).eq(0)
    return image.updateMask(mask)


def mask_landsat_sr(image):
    """Mask clouds and cloud shadows from Landsat C2 SR using QA_PIXEL."""
    import ee
    qa    = image.select("QA_PIXEL")
    # Bit 3 = cloud, Bit 4 = cloud shadow
    mask  = qa.bitwiseAnd(1 << 3).eq(0).And(qa.bitwiseAnd(1 << 4).eq(0))
    return image.updateMask(mask)


def scale_modis(image, cfg):
    """Apply MODIS scale factor to spectral bands."""
    import ee
    scaled = image.select(cfg["bands"]).multiply(cfg["scale_factor"])
    return image.addBands(scaled, overwrite=True)


def scale_landsat(image, cfg):
    """Apply Landsat C2 SR scale + offset."""
    import ee
    scaled = image.select(cfg["bands"]) \
                  .multiply(cfg["scale_factor"]) \
                  .add(cfg["offset"])
    return image.addBands(scaled, overwrite=True)


def build_collection(collection_key: str, aoi, start: str, end: str):
    """Build a filtered, masked, scaled ImageCollection."""
    import ee
    cfg = COLLECTIONS[collection_key]

    if collection_key == "landsat_sr":
        l8 = (ee.ImageCollection("LANDSAT/LC08/C02/T1_L2")
                .filterBounds(aoi)
                .filterDate(start, end)
                .map(mask_landsat_sr)
                .map(lambda img: scale_landsat(img, cfg)))
        l9 = (ee.ImageCollection("LANDSAT/LC09/C02/T1_L2")
                .filterBounds(aoi)
                .filterDate(start, end)
                .map(mask_landsat_sr)
                .map(lambda img: scale_landsat(img, cfg)))
        col = l8.merge(l9).sort("system:time_start")
    elif collection_key == "modis_ndvi":
        col = (ee.ImageCollection(cfg["id"])
                 .filterBounds(aoi)
                 .filterDate(start, end)
                 .map(mask_modis_ndvi)
                 .map(lambda img: scale_modis(img, cfg)))
    elif collection_key == "modis_lst":
        col = (ee.ImageCollection(cfg["id"])
                 .filterBounds(aoi)
                 .filterDate(start, end)
                 .map(mask_modis_lst)
                 .map(lambda img: scale_modis(img, cfg)))
    else:
        raise ValueError(f"Unknown collection: {collection_key}")

    return col


def extract_time_series(col, aoi, bands: list, scale: int) -> list[dict]:
    """Extract mean band values within AOI for each image in collection."""
    import ee

    def reduce_image(image):
        means = image.select(bands).reduceRegion(
            reducer=ee.Reducer.mean(),
            geometry=aoi,
            scale=scale,
            maxPixels=1e9,
            bestEffort=True,
        )
        return ee.Feature(None, means.set(
            "date", image.date().format("YYYY-MM-dd"),
            "system_index", image.get("system:index"),
        ))

    features = col.map(reduce_image).getInfo()["features"]
    rows = []
    for f in features:
        props = f["properties"]
        row   = {"date": props.pop("date", ""), "system_index": props.pop("system_index", "")}
        row.update(props)
        rows.append(row)
    return rows


# ── Entry point ────────────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="GEE time series extraction")
    p.add_argument("study_area_geojson", help="GeoJSON file with study area polygon")
    p.add_argument("output_dir",         help="Output directory")
    p.add_argument("--start",      default="2015-01-01", help="Start date YYYY-MM-DD")
    p.add_argument("--end",        default=date.today().isoformat(), help="End date YYYY-MM-DD")
    p.add_argument("--collection", default="modis_ndvi",
                   choices=list(COLLECTIONS.keys()), help="GEE collection")
    p.add_argument("--scale",      type=int, default=None,
                   help="Spatial resolution in metres (default: collection native)")
    p.add_argument("--project",    default=None, help="GEE cloud project ID")
    return p.parse_args()


def main():
    log_step(1, "Parse arguments and validate inputs")
    args       = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    geojson_path = Path(args.study_area_geojson)
    if not geojson_path.exists():
        logger.error(
            "Study area GeoJSON not found: %s\n"
            "  Probable cause: incorrect path.\n"
            "  Check: file exists and is valid GeoJSON (EPSG:4326).\n"
            "  Previous skill: ecological-data-foundation or geoprocessing-for-ecology.",
            geojson_path,
        )
        sys.exit(1)

    collection_key = args.collection
    cfg            = COLLECTIONS[collection_key]
    scale          = args.scale or cfg["scale"]

    log_decision("collection", collection_key,
                 f"requested by user; provides {cfg['frequency']} composites at {cfg['scale']} m")
    log_decision("scale", scale,
                 "native collection resolution unless overridden by user")
    log_decision("date_range", f"{args.start} — {args.end}",
                 "requested by user; default covers 2015-present for post-Landsat-8 continuity")

    # ── Step 2: authenticate GEE ──────────────────────────────────────────────
    log_step(2, "Authenticate and initialise Earth Engine")
    try:
        import ee
    except ImportError:
        logger.error(
            "earthengine-api not installed.\n"
            "  Install: pip install earthengine-api\n"
            "  Then run: earthengine authenticate\n"
            "  Previous skill: geoprocessing-for-ecology",
        )
        sys.exit(1)

    import os
    project = args.project or os.environ.get("GOOGLE_CLOUD_PROJECT")
    try:
        if project:
            ee.Initialize(project=project)
            logger.info("Earth Engine initialised with project: %s", project)
        else:
            ee.Initialize()
            logger.info("Earth Engine initialised (default credentials).")
    except Exception as exc:
        logger.error(
            "Failed to initialise Earth Engine: %s\n"
            "  Probable cause: not authenticated or invalid project ID.\n"
            "  Run: earthengine authenticate\n"
            "  Or set env var GOOGLE_CLOUD_PROJECT to your GEE-enabled project.\n"
            "  Previous skill: geoprocessing-for-ecology",
            exc,
        )
        sys.exit(1)

    # ── Step 3: load study area as EE geometry ────────────────────────────────
    log_step(3, "Load study area geometry")
    try:
        with open(geojson_path, encoding="utf-8") as f:
            geojson = json.load(f)
        # Accept FeatureCollection, Feature, or bare Geometry
        if geojson.get("type") == "FeatureCollection":
            geom_dict = geojson["features"][0]["geometry"]
        elif geojson.get("type") == "Feature":
            geom_dict = geojson["geometry"]
        else:
            geom_dict = geojson  # assume bare Geometry
        aoi = ee.Geometry(geom_dict)
        logger.info("AOI loaded from: %s", geojson_path)
    except Exception as exc:
        logger.error(
            "Failed to parse GeoJSON: %s\n"
            "  Probable cause: invalid GeoJSON or unsupported geometry type.\n"
            "  Check: file is valid GeoJSON with polygon geometry in EPSG:4326.\n"
            "  Previous skill: geoprocessing-for-ecology",
            exc,
        )
        sys.exit(1)

    # ── Step 4: build and filter collection ──────────────────────────────────
    log_step(4, f"Build {collection_key} collection ({args.start} to {args.end})")
    try:
        col   = build_collection(collection_key, aoi, args.start, args.end)
        count = col.size().getInfo()
        logger.info("Collection size: %d images", count)
        if count == 0:
            logger.error(
                "No images found for collection '%s' in the specified date range and AOI.\n"
                "  Check: date range, study area extent, and collection availability.\n"
                "  Previous skill: geoprocessing-for-ecology",
                collection_key,
            )
            sys.exit(1)
    except Exception as exc:
        logger.error(
            "Failed to build GEE collection: %s\n"
            "  Probable cause: GEE API error or invalid collection ID.\n"
            "  Previous skill: geoprocessing-for-ecology",
            exc,
        )
        sys.exit(1)

    # ── Step 5: extract time series ───────────────────────────────────────────
    log_step(5, "Extract mean band values within AOI (reduceRegion)")
    bands = cfg["bands"]
    log_decision("reducer", "mean",
                 "mean within AOI is standard for landscape-level time series; "
                 "captures central tendency across heterogeneous pixels")
    try:
        rows = extract_time_series(col, aoi, bands, scale)
        logger.info("Extracted %d observations across %d bands.", len(rows), len(bands))
    except Exception as exc:
        logger.error(
            "Failed to extract time series from GEE: %s\n"
            "  Probable cause: AOI too large for reduceRegion at requested scale, "
            "or GEE computation timeout.\n"
            "  Try: increase --scale (e.g., 500 or 1000) or reduce date range.\n"
            "  Previous skill: geoprocessing-for-ecology",
            exc,
        )
        sys.exit(1)

    # ── Step 6: save outputs ──────────────────────────────────────────────────
    log_step(6, "Save time series CSV and metadata JSON")
    import csv

    ts_path = output_dir / "gee_time_series.csv"
    if rows:
        fieldnames = ["date", "system_index"] + [b for b in bands if b in rows[0]]
        try:
            with open(ts_path, "w", newline="", encoding="utf-8") as f:
                writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
                writer.writeheader()
                writer.writerows(rows)
            logger.info("Time series saved: %s (%d rows)", ts_path, len(rows))
        except OSError as exc:
            logger.error(
                "Failed to write time series CSV: %s\n"
                "  Probable cause: permission denied or disk full.\n"
                "  Previous skill: geoprocessing-for-ecology",
                exc,
            )
            sys.exit(1)
    else:
        logger.warning("No data rows to write — time series CSV not created.")

    meta = {
        "collection":     collection_key,
        "collection_id":  cfg.get("id") or f"LANDSAT/LC08+LC09/C02/T1_L2 (merged)",
        "bands":          bands,
        "scale_m":        scale,
        "frequency":      cfg["frequency"],
        "start_date":     args.start,
        "end_date":       args.end,
        "n_images":       count,
        "n_rows":         len(rows),
        "scale_factor":   cfg.get("scale_factor"),
        "citation":       cfg["citation"],
        "extraction_date": date.today().isoformat(),
    }
    meta_path = output_dir / "gee_metadata.json"
    try:
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump(meta, f, indent=2)
        logger.info("Metadata saved: %s", meta_path)
    except OSError as exc:
        logger.error("Failed to write metadata JSON: %s", exc)

    logger.info(
        "GEE extraction complete. Outputs in: %s\n"
        "  Next skill: environmental-time-series (trend_analysis.R or trend_analysis.py)",
        output_dir,
    )


if __name__ == "__main__":
    main()
