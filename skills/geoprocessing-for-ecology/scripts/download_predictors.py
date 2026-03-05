"""Download global environmental predictor layers for ecological modelling.

Usage: python download_predictors.py <output_dir> [resolution] [extent_wkt] [source]

Arguments:
    output_dir   : Directory for outputs (created if absent)
    resolution   : WorldClim resolution in arc-minutes: 2.5, 5, or 10 (default: 2.5)
    extent_wkt   : WKT bounding box for clipping (optional).
                   Example: "POLYGON((-80 -30,-80 10,-30 10,-30 -30,-80 -30))"
    source       : Comma-separated list: worldclim,chelsa,era5 (default: worldclim)

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
        "Dependencia ausente: %s\n  Instale com: pip install requests\n  Skill anterior: geoprocessing-for-ecology",
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
        "rasterio/shapely nao instalados. Corte de camadas por extensao nao disponivel. "
        "Instale com: pip install rasterio shapely"
    )


# ── Constants ─────────────────────────────────────────────────────────────────
WORLDCLIM_BASE = "https://biogeo.ucdavis.edu/data/worldclim/v2.1/base"
CHELSA_BASE    = "https://os.zhdk.cloud.switch.ch/envicloud/chelsa/chelsa_V2/GLOBAL/climatologies/1981-2010/bio"

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
    logger.info("Baixando %s de: %s", description or out_path.name, url)
    try:
        resp = requests.get(url, stream=True, timeout=600)
        resp.raise_for_status()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "wb") as f:
            for chunk in resp.iter_content(chunk_size=65536):
                f.write(chunk)
        size_mb = out_path.stat().st_size / (1024 * 1024)
        logger.info("Salvo: %s (%.1f MB)", out_path, size_mb)
        return True
    except requests.RequestException as e:
        logger.error(
            "Falha ao baixar '%s': %s\n  Causa provavel: sem conexao ou servidor indisponivel.\n  Skill anterior: geoprocessing-for-ecology",
            url, e,
        )
        return False


def clip_raster(in_path: Path, geom_wkt: str, out_path: Path) -> bool:
    """Clip a raster to a WKT geometry using rasterio. Returns True on success."""
    if not HAS_RASTERIO:
        logger.warning("rasterio nao disponivel; sem corte de extensao.")
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
        logger.info("Cortado: %s", out_path)
        return True
    except Exception as e:
        logger.warning("Falha ao cortar '%s': %s. Mantendo versao global.", in_path.name, e)
        return False


# ── WorldClim download ────────────────────────────────────────────────────────

def download_worldclim(output_dir: Path, resolution: float, extent_wkt: str | None,
                        meta_rows: list[dict]) -> None:
    """Download WorldClim v2.1 bioclimatic variables."""
    res_str = VALID_RESOLUTIONS.get(resolution, f"{resolution}m")
    wc_dir  = output_dir / "worldclim"
    wc_dir.mkdir(parents=True, exist_ok=True)

    # WorldClim distributes all 19 BIO vars in a single zip
    zip_name = f"wc2.1_{res_str}_bio.zip"
    zip_url  = f"{WORLDCLIM_BASE}/{zip_name}"
    zip_path = wc_dir / zip_name

    if not download_file(zip_url, zip_path, f"WorldClim {res_str} BIO"):
        logger.error(
            "Falha ao baixar WorldClim. Verifique conexao e resolucao: %g\n  Skill anterior: geoprocessing-for-ecology",
            resolution,
        )
        return

    # Extract zip
    import zipfile
    try:
        with zipfile.ZipFile(zip_path, "r") as z:
            z.extractall(wc_dir)
        zip_path.unlink()  # remove zip after extraction
        logger.info("Arquivo WorldClim extraido em: %s", wc_dir)
    except Exception as e:
        logger.error(
            "Falha ao extrair ZIP WorldClim: %s\n  Skill anterior: geoprocessing-for-ecology", e,
        )
        return

    # Clip and register each BIO layer
    for i in range(1, 20):
        tif_name = f"wc2.1_{res_str}_bio_{i}.tif"
        tif_path = wc_dir / tif_name
        if not tif_path.exists():
            logger.warning("Arquivo nao encontrado apos extracao: %s", tif_name)
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

    logger.info("WorldClim: 19 variaveis BIO processadas em %s", wc_dir)


# ── CHELSA download ───────────────────────────────────────────────────────────

def download_chelsa(output_dir: Path, extent_wkt: str | None,
                    meta_rows: list[dict]) -> None:
    """Download CHELSA v2.1 bioclimatic variables."""
    ch_dir = output_dir / "chelsa"
    ch_dir.mkdir(parents=True, exist_ok=True)

    for i in range(1, 20):
        fname    = f"CHELSA_bio{i}_1981-2010_V.2.1.tif"
        url      = f"{CHELSA_BASE}/{fname}"
        out_path = ch_dir / f"CHELSA_bio{i}.tif"

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

    logger.info("CHELSA: 19 variaveis BIO processadas em %s", ch_dir)


# ── ERA5 placeholder ──────────────────────────────────────────────────────────

def download_era5(output_dir: Path, meta_rows: list[dict]) -> None:
    """ERA5-Land download via cdsapi (requires CDS account and ~/.cdsapirc)."""
    logger.info("ERA5-Land: verificando disponibilidade de cdsapi...")
    try:
        import cdsapi
    except ImportError:
        logger.warning(
            "cdsapi nao instalado. Instale com: pip install cdsapi\n  Tambem configure ~/.cdsapirc com sua chave CDS.\n  Instruções: https://cds.climate.copernicus.eu/api-how-to"
        )
        return

    era5_dir = output_dir / "era5"
    era5_dir.mkdir(parents=True, exist_ok=True)
    out_path = era5_dir / "era5_land_temp_precip_monthly.nc"

    log_decision("era5_variables", "2m_temperature,total_precipitation",
                 "temperatura e precipitacao sao os preditores climaticos mais comuns em SDM")

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
        logger.info("ERA5-Land salvo: %s", out_path)
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
            "Falha ao baixar ERA5-Land: %s\n  Causa provavel: cdsapi nao configurado ou chave CDS invalida.\n  Verifique: https://cds.climate.copernicus.eu/api-how-to\n  Skill anterior: geoprocessing-for-ecology",
            e,
        )


# ── Save metadata CSV ─────────────────────────────────────────────────────────

def save_metadata(output_dir: Path, meta_rows: list[dict]) -> None:
    if not meta_rows:
        logger.warning("Nenhuma camada baixada com sucesso. Arquivo de metadata nao criado.")
        return
    meta_path = output_dir / "predictor_metadata.csv"
    fieldnames = ["source", "variable", "resolution", "file", "citation", "licence", "download_date"]
    try:
        with open(meta_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(meta_rows)
        logger.info("Metadata gravado: %s (%d camadas)", meta_path, len(meta_rows))
    except OSError as e:
        logger.error(
            "Falha ao gravar metadata: %s\n  Skill anterior: geoprocessing-for-ecology", e,
        )


# ── Entry point ────────────────────────────────────────────────────────────────

def main():
    logger.info("Script: download_predictors.py | Skill: %s", SKILL_NAME)

    argv = sys.argv[1:]

    if len(argv) < 1:
        output_dir  = Path("data/predictors")
        resolution  = 2.5
        extent_wkt  = None
        sources_str = "worldclim"
        logger.warning("Nenhum argumento fornecido. Usando valores padrao.")
    else:
        output_dir  = Path(argv[0])
        resolution  = float(argv[1]) if len(argv) >= 2 else 2.5
        extent_wkt  = argv[2] if len(argv) >= 3 and argv[2] else None
        sources_str = argv[3] if len(argv) >= 4 else "worldclim"

    sources = [s.strip().lower() for s in sources_str.split(",")]

    logger.info("Output dir   : %s", output_dir)
    logger.info("Resolution   : %g arc-minutes", resolution)
    logger.info("Extent WKT   : %s", extent_wkt or "global (sem corte)")
    logger.info("Sources      : %s", ", ".join(sources))

    log_decision("resolution", resolution,
                 "2.5 arc-min (~4.5 km) e o equilibrio padrao entre detalhe e tamanho de arquivo")

    if resolution not in VALID_RESOLUTIONS:
        logger.warning("Resolucao %g nao e padrao WorldClim. Valores validos: 0.5, 2.5, 5, 10.", resolution)

    output_dir.mkdir(parents=True, exist_ok=True)
    meta_rows: list[dict] = []

    # Download WorldClim
    if "worldclim" in sources:
        log_step(1, "Baixar WorldClim v2.1")
        try:
            download_worldclim(output_dir, resolution, extent_wkt, meta_rows)
        except Exception as e:
            logger.error(
                "Erro ao baixar WorldClim: %s\n  Skill anterior: geoprocessing-for-ecology", e,
            )

    # Download CHELSA
    if "chelsa" in sources:
        log_step(2, "Baixar CHELSA v2.1")
        try:
            download_chelsa(output_dir, extent_wkt, meta_rows)
        except Exception as e:
            logger.error(
                "Erro ao baixar CHELSA: %s\n  Skill anterior: geoprocessing-for-ecology", e,
            )

    # Download ERA5
    if "era5" in sources:
        log_step(3, "Baixar ERA5-Land via cdsapi")
        try:
            download_era5(output_dir, meta_rows)
        except Exception as e:
            logger.error(
                "Erro ao baixar ERA5: %s\n  Skill anterior: geoprocessing-for-ecology", e,
            )

    log_step(4 if len(sources) < 4 else len(sources) + 1, "Gravar metadata de preditores")
    save_metadata(output_dir, meta_rows)

    logger.info("Download de preditores concluido. Verifique: %s", output_dir)


if __name__ == "__main__":
    main()
