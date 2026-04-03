# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""Download occurrence records from GBIF via pygbif.

Usage: python download_from_gbif.py <species_name_or_list_csv> <output_dir> [country_code] [year_from] [year_to]

Arguments:
    species_name_or_list_csv : Species name (e.g., "Panthera onca") or path to CSV
                               with column 'scientificName'
    output_dir               : Directory for outputs (created if absent)
    country_code             : ISO 3166-1 alpha-2 code to restrict records (optional)
    year_from                : Minimum occurrence year (default: 1950)
    year_to                  : Maximum occurrence year (default: current year)

Outputs (per species):
    occurrences_raw_GBIF_{species}_{date}.csv — occurrence records
    download_metadata_{species}.txt            — download info including GBIF DOI
"""

import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "ecological-data-foundation"
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
import time
import csv
from datetime import date

try:
    import pandas as pd
    import pygbif.occurrences as occ
    import pygbif.species as spp
except ImportError as e:
    logger.error(
        "Dependencia missing: %s\n  Instale com: pip install pygbif pandas\n  Previous skill: ecological-data-foundation",
        e,
    )
    sys.exit(1)


# ── Credential check ─────────────────────────────────────────────────────────

def check_gbif_credentials() -> bool:
    """Return True if GBIF_USER / GBIF_PWD / GBIF_EMAIL are all set."""
    missing = [v for v in ("GBIF_USER", "GBIF_PWD", "GBIF_EMAIL") if not os.getenv(v)]
    if missing:
        logger.warning(
            "GBIF async download requires environment variables: %s\n"
            "  These are NOT set — large datasets (>%d records) will fall back to "
            "occ.search, which has no citable DOI.\n"
            "  To enable async download set them before running:\n"
            "    export GBIF_USER=your_username   # Linux/Mac\n"
            "    export GBIF_PWD=your_password\n"
            "    export GBIF_EMAIL=your@email.com\n"
            "    setx GBIF_USER your_username     # Windows (then reopen terminal)",
            ", ".join(missing), LARGE_DATASET_THRESHOLD,
        )
        return False
    logger.info("GBIF credentials: OK (GBIF_USER=%s)", os.getenv("GBIF_USER"))
    return True


# ── Constants ─────────────────────────────────────────────────────────────────
BASIS_OF_RECORD = [
    "HUMAN_OBSERVATION",
    "MACHINE_OBSERVATION",
    "PRESERVED_SPECIMEN",
]
COORD_UNCERTAINTY_MAX = 10000  # metres
POLL_INTERVAL = 30             # seconds between status checks for async downloads
SEARCH_LIMIT = 100000          # max records via occ.search (GBIF API cap)
LARGE_DATASET_THRESHOLD = 50000


# ── Helper functions ──────────────────────────────────────────────────────────

def get_taxon_key(species_name: str) -> int | None:
    """Look up GBIF backbone taxon key for a species name.

    Tries the current pygbif API first; if the keyword-argument interface
    changed (older/newer versions pass ``name`` through to requests.Session
    and fail), falls back to a direct HTTP call to the GBIF Backbone Match API.
    """
    # --- attempt 1: pygbif wrapper ---
    try:
        result = spp.name_backbone(name=species_name, rank="SPECIES")
    except TypeError as e:
        # pygbif version mismatch: "Session.request() got an unexpected
        # keyword argument 'name'" — fall back to direct HTTP call.
        logger.warning(
            "pygbif.species.name_backbone() raised TypeError (%s). "
            "Falling back to direct GBIF API call.", e,
        )
        result = _name_backbone_http(species_name)
    except Exception as e:
        logger.error(
            "Failed to query GBIF backbone for '%s': %s\n"
            "  Probable cause: no internet connection, GBIF API unavailable, "
            "or pygbif version incompatibility.\n"
            "  Check: pip install --upgrade pygbif\n"
            "  Previous skill: ecological-data-foundation",
            species_name, e,
        )
        raise

    if result is None:
        return None
    key = result.get("usageKey")
    if key is None:
        logger.warning("No GBIF taxon key found for '%s'", species_name)
    return key


def _name_backbone_http(species_name: str) -> dict | None:
    """Direct HTTP fallback for GBIF Backbone Taxonomy match API."""
    import requests as _req
    url = "https://api.gbif.org/v1/species/match"
    try:
        resp = _req.get(url, params={"name": species_name, "rank": "SPECIES"},
                        timeout=30)
        resp.raise_for_status()
        return resp.json()
    except _req.RequestException as e:
        logger.error(
            "Direct GBIF backbone API call failed for '%s': %s\n"
            "  Probable cause: no internet connection or GBIF API unavailable.\n"
            "  Previous skill: ecological-data-foundation",
            species_name, e,
        )
        return None


def count_records(taxon_key: int) -> int:
    """Estimate number of records for a taxon (unfiltered, approximate)."""
    try:
        return occ.count(taxonKey=taxon_key, hasCoordinate=True,
                         occurrenceStatus="PRESENT")
    except Exception as e:
        logger.warning(
            "pygbif occ.count failed (%s) — falling back to direct HTTP.", e,
        )
        return _count_records_http(taxon_key)


def _count_records_http(taxon_key: int) -> int:
    """Direct HTTP fallback for GBIF occurrence count."""
    import requests as _req
    try:
        resp = _req.get(
            "https://api.gbif.org/v1/occurrence/count",
            params={"taxonKey": taxon_key, "hasCoordinate": "true",
                    "occurrenceStatus": "PRESENT"},
            timeout=15,
        )
        resp.raise_for_status()
        return int(resp.json())
    except Exception as e:
        logger.warning("Direct GBIF count failed (%s). Assuming small dataset.", e)
        return 0


def _search_records_http(taxon_key: int, country_code: str | None,
                         year_from: int, year_to: int) -> list[dict]:
    """Direct HTTP implementation of paginated GBIF occurrence search.

    Uses the GBIF Occurrence Search API directly, avoiding pygbif's broken
    keyword-argument forwarding in version 0.6.6.
    """
    import requests as _req

    base_url = "https://api.gbif.org/v1/occurrence/search"
    # basisOfRecord must be sent as multiple params (not comma-joined)
    basis_params = [("basisOfRecord", b) for b in BASIS_OF_RECORD]

    all_records: list[dict] = []
    offset = 0
    page_size = 300  # GBIF allows up to 300 per page

    while True:
        params = [
            ("taxonKey",                    taxon_key),
            ("hasCoordinate",               "true"),
            ("occurrenceStatus",            "PRESENT"),
            ("coordinateUncertaintyInMeters", f"0,{COORD_UNCERTAINTY_MAX}"),
            ("year",                        f"{year_from},{year_to}"),
            ("limit",                       page_size),
            ("offset",                      offset),
        ] + basis_params

        if country_code:
            params.append(("country", country_code))

        try:
            resp = _req.get(base_url, params=params, timeout=60)
            resp.raise_for_status()
        except _req.RequestException as e:
            logger.error(
                "GBIF occurrence search HTTP error at offset %d: %s\n"
                "  Previous skill: ecological-data-foundation",
                offset, e,
            )
            break

        data    = resp.json()
        results = data.get("results", [])
        all_records.extend(results)

        end_of_records = data.get("endOfRecords", True)
        total          = data.get("count", len(all_records))
        logger.info("  Fetched %d / %d records (offset=%d)…",
                    len(all_records), total, offset)

        if end_of_records or len(all_records) >= SEARCH_LIMIT:
            break
        offset += page_size

    return all_records


def search_download(taxon_key: int, country_code: str | None,
                    year_from: int, year_to: int) -> tuple[list[dict], str]:
    """Download via occ.search (< LARGE_DATASET_THRESHOLD records). No DOI."""
    filters = dict(
        taxonKey=taxon_key,
        hasCoordinate=True,
        occurrenceStatus="PRESENT",
        basisOfRecord=",".join(BASIS_OF_RECORD),
        coordinateUncertaintyInMeters=f"0,{COORD_UNCERTAINTY_MAX}",
        year=f"{year_from},{year_to}",
        limit=SEARCH_LIMIT,
        fields="minimal",
    )
    if country_code:
        filters["country"] = country_code

    try:
        result = occ.search(**filters)
    except Exception as e:
        logger.warning(
            "pygbif occ.search failed (%s) — falling back to direct HTTP.", e,
        )
        records = _search_records_http(taxon_key, country_code, year_from, year_to)
        return records, None

    records = result.get("results", [])
    return records, None  # None = no DOI available


def async_download(taxon_key: int, country_code: str | None,
                   year_from: int, year_to: int) -> tuple[list[dict], str]:
    """Download via occ.download (reproducible, DOI generated). For large datasets."""
    predicates = [
        f"taxonKey = {taxon_key}",
        "hasCoordinate = TRUE",
        "occurrenceStatus = PRESENT",
        f"basisOfRecord in {','.join(BASIS_OF_RECORD)}",
        f"coordinateUncertaintyInMeters <= {COORD_UNCERTAINTY_MAX}",
        f"year >= {year_from}",
        f"year <= {year_to}",
    ]
    if country_code:
        predicates.append(f"country = {country_code}")

    logger.info("Starting asynchronous download (DOI will be generated)...")
    try:
        dl_result = occ.download(predicates)
    except Exception as e:
        logger.error(
            "Failed to start occ.download (taxon_key=%d): %s\n  Probable cause: GBIF credentials missing or invalid (GBIF_USER, GBIF_PWD, GBIF_EMAIL).\n  Configure via: export GBIF_USER=... (Linux/Mac) or setx GBIF_USER ... (Windows).\n  Previous skill: ecological-data-foundation",
            taxon_key, e,
        )
        raise

    dl_key = dl_result[0]
    logger.info("Download key: %s", dl_key)
    logger.info("Waiting for GBIF to prepare download...")

    # Poll until complete
    while True:
        try:
            meta = occ.download_meta(dl_key)
        except Exception as e:
            logger.error(
                "Failed to consultar status do download '%s': %s\n  Probable cause: no internet connection.\n  Previous skill: ecological-data-foundation",
                dl_key, e,
            )
            raise
        status = meta.get("status", "UNKNOWN")
        logger.info("Download status: %s", status)
        if status == "SUCCEEDED":
            break
        elif status in ("FAILED", "KILLED", "CANCELLED"):
            logger.error(
                "Download GBIF falhou com status '%s' (key=%s)\n  Probable cause: predicados invalidos ou erro interno do GBIF.\n  Check em: https://www.gbif.org/user/download\n  Previous skill: ecological-data-foundation",
                status, dl_key,
            )
            raise RuntimeError(f"GBIF download failed with status: {status}")
        time.sleep(POLL_INTERVAL)

    doi = meta.get("doi", "")
    logger.info("DOI gerado: %s", doi)

    # Get download URL and fetch via pandas
    download_url = meta.get("downloadLink", "")
    logger.info("Buscando dados de: %s", download_url)
    try:
        df = pd.read_csv(download_url, sep="\t", on_bad_lines="skip", low_memory=False)
    except Exception as e:
        logger.error(
            "Failed to importar dados do download GBIF (url=%s): %s\n  Probable cause: corrupted file ou link expirado.\n  Previous skill: ecological-data-foundation",
            download_url, e,
        )
        raise
    records = df.to_dict("records")
    return records, doi


def save_metadata(output_dir: Path, species_name: str, taxon_key: int,
                  dl_key: str | None, doi: str | None,
                  n_records: int, country_code: str | None,
                  year_from: int, year_to: int) -> None:
    """Write download_metadata.txt with citation information."""
    safe_name = species_name.replace(" ", "_")
    meta_path = output_dir / f"download_metadata_{safe_name}.txt"

    today = date.today().isoformat()
    year  = date.today().year

    if doi:
        citation = (f"GBIF.org ({year}) GBIF Occurrence Download. "
                    f"https://doi.org/{doi} Accessed on {today}")
    else:
        citation = ("occ.search used — no citable DOI. "
                    "Re-run with async download for publication.")

    lines = [
        f"Species: {species_name}",
        f"GBIF taxon key: {taxon_key}",
        f"Download key: {dl_key or 'N/A (occ.search used)'}",
        f"DOI: {doi or 'NOT AVAILABLE'}",
        f"Citation: {citation}",
        f"Download date: {today}",
        f"n_records: {n_records}",
        f"year_from: {year_from}",
        f"year_to: {year_to}",
        f"country_filter: {country_code or 'none'}",
        f"basisOfRecord: {', '.join(BASIS_OF_RECORD)}",
        f"coordinateUncertainty_max_m: {COORD_UNCERTAINTY_MAX}",
    ]

    try:
        meta_path.write_text("\n".join(lines))
        logger.info("Metadata saved: %s", meta_path)
    except OSError as e:
        logger.error(
            "Failed to gravar metadados em '%s': %s\n  Probable cause: sem permissao de escrita no directory.\n  Previous skill: ecological-data-foundation",
            meta_path, e,
        )
        raise


# ── Main download logic (single species) ──────────────────────────────────────

def download_species(species_name: str, output_dir: Path,
                     country_code: str | None,
                     year_from: int, year_to: int,
                     has_credentials: bool = True) -> None:
    logger.info("--- Iniciando download: %s ---", species_name)
    today_str = date.today().strftime("%Y%m%d")
    safe_name = species_name.replace(" ", "_")

    # Lookup taxon key
    log_step(1, f"Fetch GBIF taxon key for '{species_name}'")
    taxon_key = get_taxon_key(species_name)
    if taxon_key is None:
        logger.warning("Skipping '%s' — no GBIF taxon key found.", species_name)
        return

    logger.info("Taxon key GBIF: %d", taxon_key)

    # Estimate record count to decide download method
    log_step(2, "Estimate record count for download method selection")
    approx_n = count_records(taxon_key)
    logger.info("Approximate record count (without filters): %d", approx_n)

    if approx_n > LARGE_DATASET_THRESHOLD and has_credentials:
        log_decision(
            "download_method", "async_download",
            f"large dataset ({approx_n} records) — async download with DOI for reproducibility",
        )
        log_step(3, "Run asynchronous download (occ.download) with DOI")
        records, doi = async_download(taxon_key, country_code, year_from, year_to)
        dl_key = "see metadata"
    else:
        if approx_n > LARGE_DATASET_THRESHOLD and not has_credentials:
            logger.warning(
                "Dataset is large (%d records) but GBIF credentials are missing — "
                "using occ.search fallback (no DOI, max %d records).",
                approx_n, SEARCH_LIMIT,
            )
        log_decision(
            "download_method", "search_download",
            f"small dataset ({approx_n} records) or no credentials — occ.search is faster; no DOI",
        )
        logger.warning("occ.search does not generate a DOI. For publications, use async download.")
        log_step(3, "Download via occ.search")
        records, doi = search_download(taxon_key, country_code, year_from, year_to)
        dl_key = None

    n_records = len(records)
    logger.info("Records retrieved: %d", n_records)

    if n_records < 30:
        geo_tip = (
            f" Try downloading without a country filter (omit country_code='{country_code}')"
            f" and filtering geographically after cleaning."
            if country_code else
            " Consider broadening the year range or using additional data sources (iNaturalist, VertNet)."
        )
        logger.warning(
            "Insufficient records for reliable SDM (n = %d).%s",
            n_records, geo_tip,
        )

    # Save occurrence CSV
    log_step(4, "Write occurrences CSV")
    csv_path = output_dir / f"occurrences_raw_GBIF_{safe_name}_{today_str}.csv"
    if records:
        try:
            df = pd.DataFrame(records)
            df.to_csv(csv_path, index=False)
            logger.info("Written: %s", csv_path)
        except OSError as e:
            logger.error(
                "Failed to write occurrence CSV for '%s': %s\n  Probable cause: no write permission in '%s'.\n  Previous skill: ecological-data-foundation",
                species_name, e, output_dir,
            )
            raise
    else:
        logger.warning("No records to write for '%s'.", species_name)

    # Save metadata
    log_step(5, "Save download metadata")
    save_metadata(output_dir, species_name, taxon_key, dl_key, doi,
                  n_records, country_code, year_from, year_to)


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    logger.info("Script: download_from_gbif.py | Skill: %s", SKILL_NAME)

    argv = sys.argv[1:]

    if len(argv) < 2:
        species_input = "Panthera onca"
        output_dir    = Path("output/gbif")
        country_code  = None
        year_from     = 1950
        year_to       = date.today().year
        logger.warning("Fewer than 2 arguments provided. Using default values for testing.")
    else:
        species_input = argv[0]
        output_dir    = Path(argv[1])
        country_code  = argv[2] if len(argv) >= 3 and argv[2] else None
        year_from     = int(argv[3]) if len(argv) >= 4 else 1950
        year_to       = int(argv[4]) if len(argv) >= 5 else date.today().year

    logger.info("Species input : %s", species_input)
    logger.info("Output dir   : %s", output_dir)
    logger.info("Country code : %s", country_code or "none")
    logger.info("Year range   : %d - %d", year_from, year_to)

    log_decision("year_from", year_from, "lower bound of period; 1950 = post-modern era")
    log_decision("year_to",   year_to,   "upper bound of period; current year by default")
    log_decision(
        "coord_uncertainty_max_m", COORD_UNCERTAINTY_MAX,
        "excluir registros com incerteza > 10 km (imprecisao inaceitavel para SDM)",
    )
    log_decision(
        "basis_of_record",
        BASIS_OF_RECORD,
        "apenas observacoes de campo/especimes; exclui literatura e fosseis",
    )

    output_dir.mkdir(parents=True, exist_ok=True)
    logger.info("Output directory ready: %s", output_dir)

    # Validate GBIF credentials upfront so the user knows before any download starts
    _has_credentials = check_gbif_credentials()

    # Build species list
    log_step(0, "Build species list")
    if species_input.endswith(".csv") and Path(species_input).exists():
        try:
            df_species   = pd.read_csv(species_input)
            if "scientificName" not in df_species.columns:
                logger.error(
                    "Coluna 'scientificName' nao encontrada em: %s\n  Probable cause: CSV de lista de especies mal formatado.\n  Previous skill: ecological-data-foundation",
                    species_input,
                )
                sys.exit(1)
            species_list = df_species["scientificName"].dropna().unique().tolist()
            logger.info("Batch mode: %d species loaded from %s", len(species_list), species_input)
            log_decision("mode", "batch", "argument is a valid CSV with scientificName column")
        except Exception as e:
            logger.error(
                "Failed to read lista de especies '%s': %s\n  Probable cause: CSV file invalido.\n  Previous skill: ecological-data-foundation",
                species_input, e,
            )
            sys.exit(1)
    else:
        species_list = [species_input.strip()]
        logger.info("Modo especie unica: %s", species_list[0])
        log_decision("mode", "single_species", "argument is not an existing CSV file")

    # Download each species
    for sp in species_list:
        try:
            download_species(sp, output_dir, country_code, year_from, year_to,
                             has_credentials=_has_credentials)
        except FileNotFoundError as e:
            logger.error(
                "Input file not found ao processar '%s': %s\n  Esperado como saida de: ecological-data-foundation\n  Check se o passo anterior foi completed.",
                sp, e,
            )
        except Exception as e:
            logger.error(
                "Failed to download '%s': %s\n  Probable cause: network error, taxon not found, or invalid GBIF credentials.\n  Previous skill: ecological-data-foundation",
                sp, e,
            )

    logger.info("All downloads completed. Check: %s", output_dir)


if __name__ == "__main__":
    main()
