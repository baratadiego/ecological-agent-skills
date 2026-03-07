# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""Parse eBird Basic Dataset (EBD) for occurrence records.

Usage: python download_from_ebird.py <ebd_file> <species_name_or_list_csv> <output_dir> [year_from] [year_to] [country_code]

Arguments:
    ebd_file                 : Path to the eBird Basic Dataset text file (.txt / .gz)
                               (pre-downloaded from https://ebird.org/data/download)
    species_name_or_list_csv : Scientific name or path to CSV with column 'scientificName'
    output_dir               : Directory for outputs (created if absent)
    year_from                : Minimum year of observation (default: 2000)
    year_to                  : Maximum year of observation (default: current year)
    country_code             : ISO 3166-1 alpha-2 country code to filter (optional)

Note:
    eBird data requires a pre-downloaded EBD file. Apply for access at:
    https://ebird.org/data/download

Outputs (per species):
    occurrences_raw_eBird_{species}_{date}.csv  — standardised occurrence records
    download_metadata_eBird_{species}.txt        — download provenance and citation

Standard output schema:
    species, decimalLatitude, decimalLongitude, eventDate, countryCode,
    basisOfRecord, coordinateUncertaintyInMeters, datasetName, occurrenceID,
    source, download_doi
Extra eBird columns:
    effort_distance_km, duration_minutes, observer_id
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
    import pandas as pd
except ImportError as e:
    logger.error(
        "Dependencia ausente: %s\n  Instale com: pip install pandas\n  Skill anterior: ecological-data-foundation",
        e,
    )
    sys.exit(1)


# ── Constants ─────────────────────────────────────────────────────────────────
VALID_PROTOCOLS = {"Stationary", "Traveling"}
CHUNK_SIZE      = 500_000  # rows per chunk for large EBD files

# EBD column name mappings (tab-delimited file)
EBD_COLS = {
    "SCIENTIFIC NAME":               "scientific_name",
    "COMMON NAME":                   "common_name",
    "LATITUDE":                      "decimalLatitude",
    "LONGITUDE":                     "decimalLongitude",
    "OBSERVATION DATE":              "eventDate",
    "COUNTRY CODE":                  "countryCode",
    "SAMPLING EVENT IDENTIFIER":     "occurrenceID",
    "PROTOCOL TYPE":                 "protocol_type",
    "EFFORT DISTANCE KM":            "effort_distance_km",
    "DURATION MINUTES":              "duration_minutes",
    "OBSERVER ID":                   "observer_id",
    "APPROVED":                      "approved",
    "REVIEWED":                      "reviewed",
}


# ── Helper functions ──────────────────────────────────────────────────────────

def parse_ebd(ebd_path: Path, species_set: set, year_from: int, year_to: int,
               country_code: str | None) -> "pd.DataFrame":
    """Read EBD in chunks and filter for target species, years, protocols."""
    sep = "\t"
    # Detect gzip
    compression = "gzip" if str(ebd_path).endswith(".gz") else None

    chunks = []
    try:
        reader = pd.read_csv(
            ebd_path,
            sep=sep,
            compression=compression,
            chunksize=CHUNK_SIZE,
            low_memory=False,
            encoding="utf-8",
            on_bad_lines="skip",
        )
    except Exception as e:
        logger.error(
            "Falha ao abrir arquivo EBD '%s': %s\n  Causa provavel: arquivo corrompido ou formato incorreto.\n  Skill anterior: ecological-data-foundation",
            ebd_path, e,
        )
        raise

    n_total = 0
    for i, chunk in enumerate(reader):
        n_total += len(chunk)
        # Normalise column names
        chunk.columns = [c.upper() for c in chunk.columns]

        sci_col = next((c for c in chunk.columns if "SCIENTIFIC" in c), None)
        date_col = next((c for c in chunk.columns if "OBSERVATION DATE" in c), None)
        proto_col = next((c for c in chunk.columns if "PROTOCOL" in c), None)
        approved_col = next((c for c in chunk.columns if "APPROVED" in c), None)
        country_col = next((c for c in chunk.columns if "COUNTRY CODE" in c), None)

        if sci_col is None:
            logger.warning("Coluna de nome cientifico nao encontrada no chunk %d; pulando.", i)
            continue

        # Filter species
        mask = chunk[sci_col].isin(species_set)

        # Filter protocol
        if proto_col:
            mask &= chunk[proto_col].isin(VALID_PROTOCOLS)

        # Filter approved
        if approved_col:
            mask &= chunk[approved_col].astype(str).str.strip().str.upper().isin({"1", "TRUE", "YES"})

        # Filter year
        if date_col:
            years = pd.to_numeric(chunk[date_col].str[:4], errors="coerce")
            mask &= (years >= year_from) & (years <= year_to)

        # Filter country
        if country_col and country_code:
            mask &= chunk[country_col].str.upper() == country_code.upper()

        filtered = chunk[mask]
        if len(filtered) > 0:
            chunks.append(filtered)
            logger.info("Chunk %d: %d/%d registros selecionados", i, len(filtered), len(chunk))

    logger.info("Total de linhas lidas no EBD: %d", n_total)
    if not chunks:
        return pd.DataFrame()
    return pd.concat(chunks, ignore_index=True)


def standardise_ebd(df: "pd.DataFrame", species_name: str) -> "pd.DataFrame":
    """Map EBD columns to the standard occurrence schema."""
    # Find column names (case-insensitive search already done above)
    def find_col(keywords: list[str]) -> str | None:
        for col in df.columns:
            if any(kw in col for kw in keywords):
                return col
        return None

    sci_col      = find_col(["SCIENTIFIC"])
    lat_col      = find_col(["LATITUDE"])
    lon_col      = find_col(["LONGITUDE"])
    date_col     = find_col(["OBSERVATION DATE"])
    country_col  = find_col(["COUNTRY CODE"])
    id_col       = find_col(["SAMPLING EVENT"])
    dist_col     = find_col(["EFFORT DISTANCE"])
    dur_col      = find_col(["DURATION"])
    obs_col      = find_col(["OBSERVER"])

    rows = df[df[sci_col] == species_name].copy() if sci_col else df.copy()

    std = pd.DataFrame({
        "species":                       species_name,
        "decimalLatitude":               pd.to_numeric(rows[lat_col], errors="coerce") if lat_col else None,
        "decimalLongitude":              pd.to_numeric(rows[lon_col], errors="coerce") if lon_col else None,
        "eventDate":                     rows[date_col].astype(str) if date_col else None,
        "countryCode":                   rows[country_col].astype(str) if country_col else None,
        "basisOfRecord":                 "HUMAN_OBSERVATION",
        "coordinateUncertaintyInMeters": None,
        "datasetName":                   "eBird Basic Dataset",
        "occurrenceID":                  rows[id_col].astype(str) if id_col else None,
        "source":                        "eBird",
        "download_doi":                  None,
        "effort_distance_km":            pd.to_numeric(rows[dist_col], errors="coerce") if dist_col else None,
        "duration_minutes":              pd.to_numeric(rows[dur_col], errors="coerce") if dur_col else None,
        "observer_id":                   rows[obs_col].astype(str) if obs_col else None,
    })
    std = std.dropna(subset=["decimalLatitude", "decimalLongitude"])
    return std.reset_index(drop=True)


def save_metadata(output_dir: Path, species_name: str, n_records: int,
                  year_from: int, year_to: int, country_code: str | None,
                  ebd_path: Path) -> None:
    safe_name = species_name.replace(" ", "_")
    today = date.today().isoformat()
    year  = date.today().year
    lines = [
        f"Species: {species_name}",
        f"Source: eBird Basic Dataset (https://ebird.org/data/download)",
        f"EBD file: {ebd_path}",
        f"Protocols: Stationary, Traveling",
        f"Approved only: True",
        f"Year range: {year_from} - {year_to}",
        f"Country filter: {country_code or 'none'}",
        f"n_records: {n_records}",
        f"Download date: {today}",
        (f"Citation: eBird Basic Dataset. Version: {year}-{date.today().month:02d}. "
         "Cornell Lab of Ornithology, Ithaca, New York."),
        "Note: eBird data requires a signed Data Use Agreement. Cite the dataset version used.",
    ]
    meta_path = output_dir / f"download_metadata_eBird_{safe_name}.txt"
    try:
        meta_path.write_text("\n".join(lines), encoding="utf-8")
        logger.info("Metadados gravados: %s", meta_path)
    except OSError as e:
        logger.error(
            "Falha ao gravar metadados em '%s': %s\n  Skill anterior: ecological-data-foundation",
            meta_path, e,
        )
        raise


# ── Entry point ────────────────────────────────────────────────────────────────

def main():
    logger.info("Script: download_from_ebird.py | Skill: %s", SKILL_NAME)

    argv = sys.argv[1:]

    if len(argv) < 3:
        ebd_file      = "data/ebird/ebd_sample.txt"
        species_input = "Jabiru mycteria"
        output_dir    = Path("output/ebird")
        year_from     = 2000
        year_to       = date.today().year
        country_code  = None
        logger.warning("Menos de 3 argumentos fornecidos. Usando valores padrao para teste.")
    else:
        ebd_file      = argv[0]
        species_input = argv[1]
        output_dir    = Path(argv[2])
        year_from     = int(argv[3]) if len(argv) >= 4 else 2000
        year_to       = int(argv[4]) if len(argv) >= 5 else date.today().year
        country_code  = argv[5] if len(argv) >= 6 and argv[5] else None

    ebd_path = Path(ebd_file)

    logger.info("EBD file       : %s", ebd_path)
    logger.info("Species input  : %s", species_input)
    logger.info("Output dir     : %s", output_dir)
    logger.info("Year range     : %d - %d", year_from, year_to)
    logger.info("Country code   : %s", country_code or "nenhum")

    log_decision("protocol", "Stationary,Traveling",
                 "apenas protocolos quantificaveis para modelagem")
    log_decision("approved", True,
                 "apenas listas aprovadas pelo eBird")

    # Check EBD file exists
    log_step(1, "Verificar existencia do arquivo EBD")
    if not ebd_path.exists():
        logger.error(
            "Input nao encontrado: %s\n  Causa provavel: arquivo EBD nao baixado.\n  Verifique: https://ebird.org/data/download\n  Skill anterior: ecological-data-foundation",
            ebd_path,
        )
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    # Build species list
    log_step(2, "Construir lista de especies")
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

    species_set = set(species_list)

    # Parse EBD
    log_step(3, "Analisar arquivo EBD em chunks")
    try:
        ebd_df = parse_ebd(ebd_path, species_set, year_from, year_to, country_code)
    except Exception as e:
        logger.error(
            "Falha ao analisar EBD: %s\n  Causa provavel: arquivo corrompido ou incompativel.\n  Skill anterior: ecological-data-foundation",
            e,
        )
        sys.exit(1)

    logger.info("Total de registros filtrados do EBD: %d", len(ebd_df))

    if len(ebd_df) == 0:
        logger.warning("Nenhum registro encontrado. Verifique nomes das especies e periodo.")
        return

    today_str = date.today().strftime("%Y%m%d")

    # Save per species
    log_step(4, "Padronizar e gravar CSVs por especie")
    for sp in species_list:
        try:
            std = standardise_ebd(ebd_df, sp)
            n_sp = len(std)
            logger.info("Especie '%s': %d registros com coordenadas", sp, n_sp)

            if n_sp == 0:
                logger.warning("Nenhum registro para '%s'.", sp)
                continue
            if n_sp < 30:
                logger.warning(
                    "Registros insuficientes para SDM confiavel para '%s' (n = %d).", sp, n_sp,
                )

            safe_name = sp.replace(" ", "_")
            csv_path  = output_dir / f"occurrences_raw_eBird_{safe_name}_{today_str}.csv"
            std.to_csv(csv_path, index=False)
            logger.info("Gravado: %s", csv_path)

            save_metadata(output_dir, sp, n_sp, year_from, year_to, country_code, ebd_path)

        except Exception as e:
            logger.error(
                "Falha ao processar especie '%s': %s\n  Skill anterior: ecological-data-foundation",
                sp, e,
            )

    logger.info("Todos os processamentos eBird concluidos. Verifique: %s", output_dir)


if __name__ == "__main__":
    main()
