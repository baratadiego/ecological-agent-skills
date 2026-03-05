"""Download marine occurrence records from OBIS (Ocean Biodiversity Information System).

Usage: python download_from_obis.py <species_name_or_list_csv> <output_dir> [year_from] [year_to] [wkt_geometry]

Arguments:
    species_name_or_list_csv : Species name (e.g., "Chelonia mydas") or path to CSV
                               with column 'scientificName'
    output_dir               : Directory for outputs (created if absent)
    year_from                : Minimum year of observation (default: 1950)
    year_to                  : Maximum year of observation (default: current year)
    wkt_geometry             : WKT polygon to restrict query (optional)

Outputs (per species):
    occurrences_raw_OBIS_{species}_{date}.csv  — standardised occurrence records
    download_metadata_OBIS_{species}.txt        — download provenance and citation

Standard output schema:
    species, decimalLatitude, decimalLongitude, eventDate, countryCode,
    basisOfRecord, coordinateUncertaintyInMeters, datasetName, occurrenceID,
    source, download_doi
Extra OBIS columns:
    depth, marine
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


from datetime import date

try:
    import requests
    import pandas as pd
except ImportError as e:
    logger.error(
        "Dependencia ausente: %s\n  Instale com: pip install requests pandas\n  Skill anterior: ecological-data-foundation",
        e,
    )
    sys.exit(1)


# ── Constants ─────────────────────────────────────────────────────────────────
OBIS_API_BASE = "https://api.obis.org/v3"
PAGE_SIZE     = 5000  # OBIS max per request
BAD_FLAGS     = {"NO_COORD", "ZERO_COORD", "ON_LAND", "DEPTH_EXCEEDS_BATH"}


# ── Helper functions ──────────────────────────────────────────────────────────

def fetch_obis(scientificname: str, year_from: int, year_to: int,
               wkt_geometry: str | None) -> list[dict]:
    """Fetch all OBIS records for a species, handling pagination."""
    url    = f"{OBIS_API_BASE}/occurrence"
    offset = 0
    all_results: list[dict] = []

    while True:
        params: dict = {
            "scientificname": scientificname,
            "absence":        "exclude",
            "startdate":      f"{year_from}-01-01",
            "enddate":        f"{year_to}-12-31",
            "size":           PAGE_SIZE,
            "offset":         offset,
        }
        if wkt_geometry:
            params["geometry"] = wkt_geometry

        try:
            resp = requests.get(url, params=params, timeout=60)
            resp.raise_for_status()
            data = resp.json()
        except requests.RequestException as e:
            logger.error(
                "Falha na requisicao OBIS (offset=%d, especie='%s'): %s\n  Causa provavel: sem conexao com a internet ou API OBIS indisponivel.\n  Verifique: https://api.obis.org/\n  Skill anterior: ecological-data-foundation",
                offset, scientificname, e,
            )
            raise

        results = data.get("results", [])
        if not results:
            break

        all_results.extend(results)
        logger.info("Pagina offset=%d: %d registros recuperados (total: %d)",
                    offset, len(results), len(all_results))

        total = data.get("total", 0)
        if len(all_results) >= total:
            break
        if len(results) < PAGE_SIZE:
            break
        offset += PAGE_SIZE

    return all_results


def apply_quality_flags(records: list[dict]) -> list[dict]:
    """Remove records with known OBIS quality issues."""
    filtered = []
    n_flagged = 0
    for rec in records:
        flags_raw = rec.get("flags", "") or ""
        flags = set(str(flags_raw).upper().split(","))
        if flags & BAD_FLAGS:
            n_flagged += 1
            continue
        filtered.append(rec)
    if n_flagged > 0:
        logger.warning("%d registros removidos por flags OBIS de qualidade.", n_flagged)
    return filtered


def standardise_records(records: list[dict], species_name: str) -> "pd.DataFrame":
    """Convert OBIS record dicts to the standard occurrence schema."""
    rows = []
    for rec in records:
        rows.append({
            "species":                       species_name,
            "decimalLatitude":               rec.get("decimalLatitude"),
            "decimalLongitude":              rec.get("decimalLongitude"),
            "eventDate":                     rec.get("eventDate") or rec.get("date_start", ""),
            "countryCode":                   rec.get("countryCode", ""),
            "basisOfRecord":                 rec.get("basisOfRecord", "OCCURRENCE"),
            "coordinateUncertaintyInMeters": rec.get("coordinateUncertaintyInMeters"),
            "datasetName":                   rec.get("datasetName", ""),
            "occurrenceID":                  str(rec.get("occurrenceID", rec.get("id", ""))),
            "source":                        "OBIS",
            "download_doi":                  None,
            "depth":                         rec.get("depth"),
            "marine":                        True,
        })

    df = pd.DataFrame(rows)
    df["decimalLatitude"]  = pd.to_numeric(df["decimalLatitude"],  errors="coerce")
    df["decimalLongitude"] = pd.to_numeric(df["decimalLongitude"], errors="coerce")
    df = df.dropna(subset=["decimalLatitude", "decimalLongitude"])
    return df.reset_index(drop=True)


def save_metadata(output_dir: Path, species_name: str, n_records: int,
                  year_from: int, year_to: int, wkt_geometry: str | None) -> None:
    safe_name = species_name.replace(" ", "_")
    today = date.today().isoformat()
    year  = date.today().year
    lines = [
        f"Species: {species_name}",
        f"Source: Ocean Biodiversity Information System (OBIS) — https://obis.org",
        f"API endpoint: {OBIS_API_BASE}/occurrence",
        f"Absence records excluded: True",
        f"OBIS quality flags applied: True (NO_COORD, ZERO_COORD, ON_LAND, DEPTH_EXCEEDS_BATH removed)",
        f"Year range: {year_from} - {year_to}",
        f"WKT geometry: {wkt_geometry or 'none (global)'}",
        f"n_records: {n_records}",
        f"Download date: {today}",
        (f"Citation: OBIS ({year}) Ocean Biodiversity Information System. "
         "Intergovernmental Oceanographic Commission of UNESCO. "
         f"www.obis.org. Accessed on {today}."),
        "License: CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/)",
    ]
    meta_path = output_dir / f"download_metadata_OBIS_{safe_name}.txt"
    try:
        meta_path.write_text("\n".join(lines), encoding="utf-8")
        logger.info("Metadados gravados: %s", meta_path)
    except OSError as e:
        logger.error(
            "Falha ao gravar metadados: %s\n  Skill anterior: ecological-data-foundation", e,
        )
        raise


# ── Main download logic ────────────────────────────────────────────────────────

def download_species(species_name: str, output_dir: Path,
                     year_from: int, year_to: int,
                     wkt_geometry: str | None) -> None:
    logger.info("--- Iniciando download OBIS: %s ---", species_name)
    today_str = date.today().strftime("%Y%m%d")
    safe_name = species_name.replace(" ", "_")

    log_step(1, f"Buscar registros OBIS para '{species_name}'")
    records = fetch_obis(species_name, year_from, year_to, wkt_geometry)
    logger.info("Registros brutos recuperados: %d", len(records))

    if not records:
        logger.warning("Nenhum registro OBIS encontrado para '%s'.", species_name)
        return

    log_step(2, "Aplicar filtros de qualidade OBIS")
    records = apply_quality_flags(records)
    logger.info("Registros apos filtros OBIS: %d", len(records))

    log_step(3, "Padronizar registros para schema de saida")
    df = standardise_records(records, species_name)
    n_final = len(df)
    logger.info("Registros com coordenadas validas: %d", n_final)

    if n_final < 30:
        logger.warning(
            "Registros insuficientes para analise confiavel (n = %d). Considere relaxar filtros.",
            n_final,
        )

    log_step(4, "Gravar CSV de ocorrencias")
    csv_path = output_dir / f"occurrences_raw_OBIS_{safe_name}_{today_str}.csv"
    try:
        df.to_csv(csv_path, index=False)
        logger.info("Gravado: %s (%d registros)", csv_path, n_final)
    except OSError as e:
        logger.error(
            "Falha ao gravar CSV: %s\n  Skill anterior: ecological-data-foundation", e,
        )
        raise

    log_step(5, "Gravar metadados do download")
    save_metadata(output_dir, species_name, n_final, year_from, year_to, wkt_geometry)


# ── Entry point ────────────────────────────────────────────────────────────────

def main():
    logger.info("Script: download_from_obis.py | Skill: %s", SKILL_NAME)

    argv = sys.argv[1:]

    if len(argv) < 2:
        species_input = "Chelonia mydas"
        output_dir    = Path("output/obis")
        year_from     = 1950
        year_to       = date.today().year
        wkt_geometry  = None
        logger.warning("Menos de 2 argumentos fornecidos. Usando valores padrao para teste.")
    else:
        species_input = argv[0]
        output_dir    = Path(argv[1])
        year_from     = int(argv[2]) if len(argv) >= 3 else 1950
        year_to       = int(argv[3]) if len(argv) >= 4 else date.today().year
        wkt_geometry  = argv[4] if len(argv) >= 5 and argv[4] else None

    logger.info("Species input  : %s", species_input)
    logger.info("Output dir     : %s", output_dir)
    logger.info("Year range     : %d - %d", year_from, year_to)
    logger.info("WKT geometry   : %s", wkt_geometry or "nenhum (global)")

    log_decision("absence", "exclude",
                 "apenas registros de presenca confirmada")
    log_decision("quality_flags", str(BAD_FLAGS),
                 "registros com flags de qualidade OBIS sao removidos")

    output_dir.mkdir(parents=True, exist_ok=True)

    # Build species list
    log_step(0, "Construir lista de especies")
    if species_input.endswith(".csv") and Path(species_input).exists():
        try:
            df_sp = pd.read_csv(species_input)
            if "scientificName" not in df_sp.columns:
                logger.error(
                    "Coluna 'scientificName' nao encontrada em: %s\n  Skill anterior: ecological-data-foundation",
                    species_input,
                )
                sys.exit(1)
            species_list = df_sp["scientificName"].dropna().unique().tolist()
            logger.info("Modo batch: %d especies carregadas", len(species_list))
        except Exception as e:
            logger.error(
                "Falha ao ler lista de especies: %s\n  Skill anterior: ecological-data-foundation", e,
            )
            sys.exit(1)
    else:
        species_list = [species_input.strip()]
        logger.info("Modo especie unica: %s", species_list[0])

    for sp in species_list:
        try:
            download_species(sp, output_dir, year_from, year_to, wkt_geometry)
        except FileNotFoundError as e:
            logger.error(
                "Arquivo de entrada nao encontrado ao processar '%s': %s\n  Skill anterior: ecological-data-foundation",
                sp, e,
            )
        except Exception as e:
            logger.error(
                "Falha ao baixar '%s' do OBIS: %s\n  Causa provavel: problema de rede ou especie nao encontrada.\n  Skill anterior: ecological-data-foundation",
                sp, e,
            )

    logger.info("Todos os downloads OBIS concluidos. Verifique: %s", output_dir)


if __name__ == "__main__":
    main()
