# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""Download global environmental predictor layers for ecological modelling.

Usage: python download_predictors.py <output_dir> [resolution] [extent_wkt] [source]

Arguments:
    output_dir   : Directory for outputs (created if absent)
    resolution   : WorldClim resolution in arc-minutes: 2.5, 5, or 10 (default: 2.5)
    extent_wkt   : WKT bounding box for clipping (optional).
                   Example: "POLYGON((-80 -30,-80 10,-30 10,-30 -30,-80 -30))"
    source       : Comma-separated list: worldclim,chelsa,era5 (default: chelsa)
                   If chelsa fails, WorldClim is tried automatically as fallback.

Outputs:
    output_dir/worldclim/wc2.1_{res}m_bio_{1..19}.tif  — WorldClim bioclimatic variables
    output_dir/chelsa/CHELSA_bio{1..19}.tif             — CHELSA bioclimatic variables
    output_dir/predictor_metadata.csv                   — layer provenance

References:
    WorldClim: Fick & Hijmans (2017) doi:10.1002/joc.5086
    CHELSA: Karger et al. (2021) doi:10.1038/s41597-021-01084-7
    ERA5-Land: https://doi.org/10.24381/cds.68d2bb30
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


import csv
import hashlib
from datetime import date

try:
    import requests
except ImportError as e:
    logger.error(
        "Dependencia missing: %s\n  Instale com: pip install requests\n  Previous skill: geoprocessing-for-ecology",
        e,
    )
    sys.exit(1)

# Optional rasterio for clipping
try:
    import rasterio
    from rasterio.mask import mask as rio_mask
    from shapely import wkt as shapely_wkt
    HAS_RASTERIO = True
except ImportError:
    HAS_RASTERIO = False
    logger.warning(
        "rasterio/shapely not installeds. Layer clipping by extent not available. "
        "Instale com: pip install rasterio shapely"
    )


# ── Constants ─────────────────────────────────────────────────────────────────
# WorldClim primary URL (new UC Davis domain, active since ~2023)
# Old domain biogeo.ucdavis.edu is no longer reachable (DNS fails)
WORLDCLIM_BASE = "https://geodata.ucdavis.edu/climate/worldclim/2_1/base"

# Mirror list: tried in order if the primary fails
WORLDCLIM_MIRRORS = [
    "https://geodata.ucdavis.edu/climate/worldclim/2_1/base",  # new (primary)
    "https://biogeo.ucdavis.edu/data/worldclim/v2.1/base",     # old (fallback)
]

# CHELSA v2.1 — path changed from envicloud/chelsa/chelsa_V2 to chelsav2 (2024)
CHELSA_BASE    = "https://os.zhdk.cloud.switch.ch/chelsav2/GLOBAL/climatologies/1981-2010/bio"

VALID_RESOLUTIONS = {0.5: "30s", 2.5: "2.5m", 5: "5m", 10: "10m"}


# ── Helper functions ──────────────────────────────────────────────────────────

def sha256_file(path: Path) -> str:
    """Compute SHA256 checksum of a file."""
    h = hashlib.sha256()
    try:
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return "N/A"


def download_file(url: str, out_path: Path, description: str = "") -> bool:
    """Download a file with progress logging. Returns True on success."""
    logger.info("Downloading %s from: %s", description or out_path.name, url)
    try:
        resp = requests.get(url, stream=True, timeout=600)
        resp.raise_for_status()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "wb") as f:
            for chunk in resp.iter_content(chunk_size=65536):
                f.write(chunk)
        size_mb = out_path.stat().st_size / (1024 * 1024)
        logger.info("Saved: %s (%.1f MB)", out_path, size_mb)
        return True
    except requests.HTTPError as e:
        status = e.response.status_code if e.response is not None else "?"
        if status == 404:
            logger.error(
                "HTTP 404 — file not found: %s\n"
                "  Probable cause: URL path changed or file moved on remote server.\n"
                "  Action: check the data provider website for updated download links.\n"
                "  Previous skill: geoprocessing-for-ecology",
                url,
            )
        elif status == 403:
            logger.error(
                "HTTP 403 — access denied: %s\n"
                "  Probable cause: authentication required or IP restricted.\n"
                "  Previous skill: geoprocessing-for-ecology",
                url,
            )
        else:
            logger.error(
                "HTTP %s error downloading '%s': %s\n"
                "  Previous skill: geoprocessing-for-ecology",
                status, url, e,
            )
        return False
    except requests.ConnectionError as e:
        logger.error(
            "Connection error downloading '%s': %s\n"
            "  Probable cause: no internet connection or DNS resolution failed.\n"
            "  Previous skill: geoprocessing-for-ecology",
            url, e,
        )
        return False
    except requests.Timeout:
        logger.error(
            "Timeout downloading '%s' (limit: 600 s).\n"
            "  Probable cause: slow server or very large file.\n"
            "  Previous skill: geoprocessing-for-ecology",
            url,
        )
        return False
    except requests.RequestException as e:
        logger.error(
            "Request error downloading '%s': %s\n"
            "  Previous skill: geoprocessing-for-ecology",
            url, e,
        )
        return False


def clip_raster(in_path: Path, geom_wkt: str, out_path: Path) -> bool:
    """Clip a raster to a WKT geometry using rasterio. Returns True on success."""
    if not HAS_RASTERIO:
        logger.warning("rasterio not available; no extent clipping.")
        return False
    try:
        geom = shapely_wkt.loads(geom_wkt)
        shapes = [{"type": "Polygon", "coordinates": [list(geom.exterior.coords)]}]
        with rasterio.open(in_path) as src:
            out_image, out_transform = rio_mask(src, shapes, crop=True, nodata=src.nodata)
            out_meta = src.meta.copy()
            out_meta.update({"height": out_image.shape[1], "width": out_image.shape[2],
                             "transform": out_transform})
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with rasterio.open(out_path, "w", **out_meta) as dst:
            dst.write(out_image)
        logger.info("Clipped: %s", out_path)
        return True
    except Exception as e:
        logger.warning("Failed to clip '%s': %s. Keeping global version.", in_path.name, e)
        return False


# ── WorldClim download ────────────────────────────────────────────────────────

def download_worldclim(output_dir: Path, resolution: float, extent_wkt: str | None,
                        meta_rows: list[dict]) -> None:
    """Download WorldClim v2.1 bioclimatic variables."""
    import socket
    res_str = VALID_RESOLUTIONS.get(resolution, f"{resolution}m")
    wc_dir  = output_dir / "worldclim"
    wc_dir.mkdir(parents=True, exist_ok=True)

    # Pre-test: verify primary mirror DNS before attempting large ZIP download
    primary_host = WORLDCLIM_MIRRORS[0].split("/")[2]
    try:
        socket.gethostbyname(primary_host)
        logger.info("WorldClim DNS pre-test OK: %s", primary_host)
    except socket.gaierror as e:
        logger.warning(
            "WorldClim primary DNS pre-test FAILED for '%s': %s\n"
            "  Will still attempt all mirrors in sequence.",
            primary_host, e,
        )

    # WorldClim distributes all 19 BIO vars in a single zip
    zip_name = f"wc2.1_{res_str}_bio.zip"
    zip_path = wc_dir / zip_name

    # Check cache: skip download if all 19 TIFs already exist
    all_tifs_cached = all(
        (wc_dir / f"wc2.1_{res_str}_bio_{i}.tif").exists() for i in range(1, 20)
    )
    if all_tifs_cached:
        logger.info("Cache hit: all 19 WorldClim BIO TIFs already exist in %s — skipping download.", wc_dir)
        for i in range(1, 20):
            tif_path = wc_dir / f"wc2.1_{res_str}_bio_{i}.tif"
            meta_rows.append({
                "source":        "WorldClim_v2.1",
                "variable":      f"BIO{i}",
                "resolution":    f"{res_str}",
                "file":          str(tif_path),
                "citation":      "Fick & Hijmans (2017) doi:10.1002/joc.5086",
                "licence":       "CC BY 4.0",
                "download_date": "cached",
            })
        logger.info("WorldClim: 19 BIO variables loaded from cache in %s", wc_dir)
        return

    downloaded = False
    for mirror in WORLDCLIM_MIRRORS:
        zip_url = f"{mirror}/{zip_name}"
        logger.info("Trying WorldClim mirror: %s", zip_url)
        if download_file(zip_url, zip_path, f"WorldClim {res_str} BIO"):
            downloaded = True
            break
        logger.warning("Mirror failed: %s -- trying next (if any)...", mirror)

    if not downloaded:
        logger.error(
            "All WorldClim mirrors failed for '%s'.\n"
            "  Mirrors tried: %s\n"
            "  Probable cause: URL changed or no internet access.\n"
            "  Action: verify https://worldclim.org for updated download links.\n"
            "  Alternative: use source=chelsa\n"
            "  Previous skill: geoprocessing-for-ecology",
            zip_name, WORLDCLIM_MIRRORS,
        )
        return

    # Extract zip
    import zipfile
    try:
        with zipfile.ZipFile(zip_path, "r") as z:
            z.extractall(wc_dir)
        zip_path.unlink()  # remove zip after extraction
        logger.info("WorldClim archive extracted to: %s", wc_dir)
    except Exception as e:
        logger.error(
            "Failed to extract WorldClim ZIP: %s\n  Previous skill: geoprocessing-for-ecology", e,
        )
        return

    # Clip and register each BIO layer
    for i in range(1, 20):
        tif_name = f"wc2.1_{res_str}_bio_{i}.tif"
        tif_path = wc_dir / tif_name
        if not tif_path.exists():
            logger.warning("File not found after extraction: %s", tif_name)
            continue

        if extent_wkt:
            clip_raster(tif_path, extent_wkt, tif_path)  # overwrite in place

        meta_rows.append({
            "source":        "WorldClim_v2.1",
            "variable":      f"BIO{i}",
            "resolution":    f"{res_str}",
            "file":          str(tif_path),
            "citation":      "Fick & Hijmans (2017) doi:10.1002/joc.5086",
            "licence":       "CC BY 4.0",
            "download_date": date.today().isoformat(),
        })

    logger.info("WorldClim: 19 BIO variables processed to %s", wc_dir)


# ── CHELSA download ───────────────────────────────────────────────────────────

def download_chelsa(output_dir: Path, extent_wkt: str | None,
                    meta_rows: list[dict]) -> None:
    """Download CHELSA v2.1 bioclimatic variables."""
    ch_dir = output_dir / "chelsa"
    ch_dir.mkdir(parents=True, exist_ok=True)

    # Check cache: skip download entirely if all 19 files already exist
    all_cached = all((ch_dir / f"CHELSA_bio{i}.tif").exists() for i in range(1, 20))
    if all_cached:
        logger.info("Cache hit: all 19 CHELSA BIO files already exist in %s — skipping download.", ch_dir)
        for i in range(1, 20):
            out_path = ch_dir / f"CHELSA_bio{i}.tif"
            meta_rows.append({
                "source":        "CHELSA_v2.1",
                "variable":      f"BIO{i}",
                "resolution":    "30 arc-sec (~1 km)",
                "file":          str(out_path),
                "citation":      "Karger et al. (2021) doi:10.1038/s41597-021-01084-7",
                "licence":       "CC BY 4.0",
                "download_date": "cached",
            })
        return

    # Pre-test: verify BIO1 resolves before iterating all 19
    test_fname   = "CHELSA_bio1_1981-2010_V.2.1.tif"
    test_url     = f"{CHELSA_BASE}/{test_fname}"
    test_outpath = ch_dir / "CHELSA_bio1.tif"
    logger.info("Pre-testing CHELSA URL with BIO1 before downloading all 19...")
    if not test_outpath.exists():
        if not download_file(test_url, test_outpath, "CHELSA BIO1 (pre-test)"):
            logger.error(
                "CHELSA pre-test failed. Aborting all 19 BIO downloads.\n"
                "  Action: verify the CHELSA base URL is still valid — check "
                "https://chelsa-climate.org for updated download paths.\n"
                "  Current base: %s",
                CHELSA_BASE,
            )
            return
    else:
        logger.info("Cache hit: CHELSA BIO1 already exists — skipping pre-test download.")

    for i in range(1, 20):
        fname    = f"CHELSA_bio{i}_1981-2010_V.2.1.tif"
        url      = f"{CHELSA_BASE}/{fname}"
        out_path = ch_dir / f"CHELSA_bio{i}.tif"

        if out_path.exists():
            logger.info("Cache hit: %s already exists — skipping.", out_path.name)
            ok = True
        elif i == 1 and test_outpath.exists():
            ok = True
        else:
            ok = download_file(url, out_path, f"CHELSA BIO{i}")
        if not ok:
            continue

        if extent_wkt:
            clip_raster(out_path, extent_wkt, out_path)

        meta_rows.append({
            "source":        "CHELSA_v2.1",
            "variable":      f"BIO{i}",
            "resolution":    "30 arc-sec (~1 km)",
            "file":          str(out_path),
            "citation":      "Karger et al. (2021) doi:10.1038/s41597-021-01084-7",
            "licence":       "CC BY 4.0",
            "download_date": date.today().isoformat(),
        })

    logger.info("CHELSA: 19 BIO variables processed to %s", ch_dir)


# ── ERA5 placeholder ──────────────────────────────────────────────────────────

def download_era5(output_dir: Path, meta_rows: list[dict]) -> None:
    """ERA5-Land download via cdsapi (requires CDS account and ~/.cdsapirc)."""
    logger.info("ERA5-Land: checking cdsapi availability...")
    try:
        import cdsapi
    except ImportError:
        logger.warning(
            "cdsapi not installed. Install with: pip install cdsapi\n"
            "  Also configure ~/.cdsapirc with your CDS API key.\n"
            "  Instructions: https://cds.climate.copernicus.eu/api-how-to"
        )
        return

    era5_dir = output_dir / "era5"
    era5_dir.mkdir(parents=True, exist_ok=True)
    out_path = era5_dir / "era5_land_temp_precip_monthly.nc"

    log_decision("era5_variables", "2m_temperature,total_precipitation",
                 "temperature and precipitation are the most common climatic predictors in SDM")

    try:
        c = cdsapi.Client()
        c.retrieve(
            "reanalysis-era5-land-monthly-means",
            {
                "variable":      ["2m_temperature", "total_precipitation"],
                "product_type":  "monthly_averaged_reanalysis",
                "year":          [str(y) for y in range(1990, 2021)],
                "month":         [f"{m:02d}" for m in range(1, 13)],
                "time":          "00:00",
                "format":        "netcdf",
            },
            str(out_path),
        )
        logger.info("ERA5-Land saved: %s", out_path)
        meta_rows.append({
            "source":        "ERA5-Land",
            "variable":      "2m_temperature,total_precipitation (monthly 1990-2020)",
            "resolution":    "~9 km (0.1 degree)",
            "file":          str(out_path),
            "citation":      "Munoz-Sabater et al. (2021) doi:10.24381/cds.68d2bb30",
            "licence":       "CC BY 4.0",
            "download_date": date.today().isoformat(),
        })
    except Exception as e:
        logger.error(
            "Failed to download ERA5-Land: %s\n"
            "  Probable cause: cdsapi not configured or invalid CDS API key.\n"
            "  Check: https://cds.climate.copernicus.eu/api-how-to\n"
            "  Previous skill: geoprocessing-for-ecology",
            e,
        )


# ── Save metadata CSV ─────────────────────────────────────────────────────────

def save_metadata(output_dir: Path, meta_rows: list[dict]) -> None:
    if not meta_rows:
        logger.warning("No layers downloaded successfully. Metadata file not created.")
        return
    meta_path = output_dir / "predictor_metadata.csv"
    fieldnames = ["source", "variable", "resolution", "file", "citation", "licence", "download_date"]
    try:
        with open(meta_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(meta_rows)
        logger.info("Metadata written: %s (%d layers)", meta_path, len(meta_rows))
    except OSError as e:
        logger.error(
            "Failed to write metadata: %s\n  Previous skill: geoprocessing-for-ecology", e,
        )


# ── Entry point ────────────────────────────────────────────────────────────────

def main():
    logger.info("Script: download_predictors.py | Skill: %s", SKILL_NAME)

    argv = sys.argv[1:]

    if len(argv) < 1:
        output_dir  = Path("data/predictors")
        resolution  = 2.5
        extent_wkt  = None
        sources_str = "chelsa"
        logger.warning("No arguments provided. Using defaults: chelsa, 2.5 arc-min.")
    else:
        output_dir  = Path(argv[0])
        resolution  = float(argv[1]) if len(argv) >= 2 else 2.5
        extent_wkt  = argv[2] if len(argv) >= 3 and argv[2] else None
        sources_str = argv[3] if len(argv) >= 4 else "chelsa"

    sources = [s.strip().lower() for s in sources_str.split(",")]

    logger.info("Output dir   : %s", output_dir)
    logger.info("Resolution   : %g arc-minutes", resolution)
    logger.info("Extent WKT   : %s", extent_wkt or "global (no clipping)")
    logger.info("Sources      : %s", ", ".join(sources))

    _km_approx = {0.5: "~0.9 km", 2.5: "~4.5 km", 5: "~9 km", 10: "~18 km"}
    _res_desc  = _km_approx.get(resolution, "~? km")
    log_decision(
        "resolution", f"{resolution} arc-min ({_res_desc})",
        f"requested by user; default is 2.5 arc-min (~4.5 km) — balance between detail and file size",
    )

    if resolution not in VALID_RESOLUTIONS:
        logger.warning("Resolution %g is not a standard WorldClim value. Valid values: 0.5, 2.5, 5, 10.", resolution)

    output_dir.mkdir(parents=True, exist_ok=True)
    meta_rows: list[dict] = []

    # Download CHELSA (default; WorldClim attempted as fallback if CHELSA fails)
    if "chelsa" in sources:
        log_step(1, "Download CHELSA v2.1 (~1 km bioclimatic variables)")
        rows_before = len(meta_rows)
        try:
            download_chelsa(output_dir, extent_wkt, meta_rows)
        except Exception as e:
            logger.error(
                "Error downloading CHELSA: %s\n  Previous skill: geoprocessing-for-ecology", e,
            )
        chelsa_ok = len(meta_rows) > rows_before
        if not chelsa_ok and "worldclim" not in sources:
            logger.warning(
                "CHELSA download produced no files. Attempting WorldClim v2.1 as automatic fallback.\n"
                "  If WorldClim also fails, download predictors manually and place TIFs in: %s",
                output_dir,
            )
            sources = list(sources) + ["worldclim"]

    # Download WorldClim
    if "worldclim" in sources:
        log_step(2, "Download WorldClim v2.1")
        try:
            download_worldclim(output_dir, resolution, extent_wkt, meta_rows)
        except Exception as e:
            logger.error(
                "Error downloading WorldClim: %s\n"
                "  Probable cause: biogeo.ucdavis.edu unreachable (DNS or server down).\n"
                "  Alternative: try CHELSA (source=chelsa) or download manually from worldclim.org\n"
                "  Previous skill: geoprocessing-for-ecology",
                e,
            )

    # Download ERA5
    if "era5" in sources:
        log_step(3, "Download ERA5-Land via cdsapi")
        try:
            download_era5(output_dir, meta_rows)
        except Exception as e:
            logger.error(
                "Error downloading ERA5: %s\n  Previous skill: geoprocessing-for-ecology", e,
            )

    log_step(4 if len(sources) < 4 else len(sources) + 1, "Write predictor metadata")
    save_metadata(output_dir, meta_rows)

    logger.info("Predictor download completed. Check: %s", output_dir)


if __name__ == "__main__":
    main()
