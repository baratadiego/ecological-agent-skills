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
        "Dependencia ausente: %s\n  Instale com: pip install pygbif pandas\n  Skill anterior: ecological-data-foundation",
        e,
    )
    sys.exit(1)


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
    """Look up GBIF backbone taxon key for a species name."""
    try:
        result = spp.name_backbone(name=species_name, rank="SPECIES")
    except Exception as e:
        logger.error(
            "Falha ao buscar taxon key no backbone GBIF para '%s': %s\n  Causa provavel: sem conexao com a internet ou API do GBIF indisponivel.\n  Skill anterior: ecological-data-foundation",
            species_name, e,
        )
        raise
    key = result.get("usageKey")
    if key is None:
        logger.warning("Nenhum taxon key GBIF encontrado para '%s'", species_name)
    return key


def count_records(taxon_key: int) -> int:
    """Estimate number of records for a taxon (unfiltered, approximate)."""
    try:
        return occ.count(taxonKey=taxon_key, hasCoordinate=True,
                         occurrenceStatus="PRESENT")
    except Exception as e:
        logger.warning(
            "Falha ao consultar contagem de registros para taxon_key=%d: %s. Assumindo dataset pequeno.",
            taxon_key, e,
        )
        return 0


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
        logger.error(
            "Falha em occ.search (taxon_key=%d): %s\n  Causa provavel: sem conexao com a internet ou API do GBIF indisponivel.\n  Skill anterior: ecological-data-foundation",
            taxon_key, e,
        )
        raise
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

    logger.info("Iniciando download assincrono (DOI sera gerado)...")
    try:
        dl_result = occ.download(predicates)
    except Exception as e:
        logger.error(
            "Falha ao iniciar occ.download (taxon_key=%d): %s\n  Causa provavel: credenciais GBIF ausentes ou invalidas (GBIF_USER, GBIF_PWD, GBIF_EMAIL).\n  Configure via: export GBIF_USER=... (Linux/Mac) ou setx GBIF_USER ... (Windows).\n  Skill anterior: ecological-data-foundation",
            taxon_key, e,
        )
        raise

    dl_key = dl_result[0]
    logger.info("Download key: %s", dl_key)
    logger.info("Aguardando GBIF preparar o download...")

    # Poll until complete
    while True:
        try:
            meta = occ.download_meta(dl_key)
        except Exception as e:
            logger.error(
                "Falha ao consultar status do download '%s': %s\n  Causa provavel: sem conexao com a internet.\n  Skill anterior: ecological-data-foundation",
                dl_key, e,
            )
            raise
        status = meta.get("status", "UNKNOWN")
        logger.info("Status do download: %s", status)
        if status == "SUCCEEDED":
            break
        elif status in ("FAILED", "KILLED", "CANCELLED"):
            logger.error(
                "Download GBIF falhou com status '%s' (key=%s)\n  Causa provavel: predicados invalidos ou erro interno do GBIF.\n  Verifique em: https://www.gbif.org/user/download\n  Skill anterior: ecological-data-foundation",
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
            "Falha ao importar dados do download GBIF (url=%s): %s\n  Causa provavel: arquivo corrompido ou link expirado.\n  Skill anterior: ecological-data-foundation",
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
        logger.info("Metadados gravados: %s", meta_path)
    except OSError as e:
        logger.error(
            "Falha ao gravar metadados em '%s': %s\n  Causa provavel: sem permissao de escrita no diretorio.\n  Skill anterior: ecological-data-foundation",
            meta_path, e,
        )
        raise


# ── Main download logic (single species) ──────────────────────────────────────

def download_species(species_name: str, output_dir: Path,
                     country_code: str | None,
                     year_from: int, year_to: int) -> None:
    logger.info("--- Iniciando download: %s ---", species_name)
    today_str = date.today().strftime("%Y%m%d")
    safe_name = species_name.replace(" ", "_")

    # Lookup taxon key
    log_step(1, f"Buscar taxon key GBIF para '{species_name}'")
    taxon_key = get_taxon_key(species_name)
    if taxon_key is None:
        logger.warning("Pulando '%s' — nenhum taxon key GBIF encontrado.", species_name)
        return

    logger.info("Taxon key GBIF: %d", taxon_key)

    # Estimate record count to decide download method
    log_step(2, "Estimar contagem de registros para escolha do metodo de download")
    approx_n = count_records(taxon_key)
    logger.info("Contagem aproximada de registros (sem filtros): %d", approx_n)

    if approx_n > LARGE_DATASET_THRESHOLD:
        log_decision(
            "download_method", "async_download",
            f"dataset grande ({approx_n} registros) -> download assincrono com DOI para reprodutibilidade",
        )
        log_step(3, "Executar download assincrono (occ.download) com DOI")
        records, doi = async_download(taxon_key, country_code, year_from, year_to)
        dl_key = "see metadata"
    else:
        log_decision(
            "download_method", "search_download",
            f"dataset pequeno ({approx_n} registros) -> occ.search e mais rapido; sem DOI",
        )
        logger.warning("occ.search nao gera DOI. Para publicacoes, use download assincrono.")
        log_step(3, "Executar download via occ.search (dataset pequeno)")
        records, doi = search_download(taxon_key, country_code, year_from, year_to)
        dl_key = None

    n_records = len(records)
    logger.info("Registros recuperados: %d", n_records)

    if n_records < 30:
        logger.warning(
            "Registros insuficientes para SDM confiavel (n = %d). Considere: (1) relaxar filtros, (2) ampliar escopo geografico, (3) usar outras bases de dados (VertNet, iNaturalist).",
            n_records,
        )

    # Save occurrence CSV
    log_step(4, "Gravar CSV de ocorrencias")
    csv_path = output_dir / f"occurrences_raw_GBIF_{safe_name}_{today_str}.csv"
    if records:
        try:
            df = pd.DataFrame(records)
            df.to_csv(csv_path, index=False)
            logger.info("Gravado: %s", csv_path)
        except OSError as e:
            logger.error(
                "Falha ao gravar CSV de ocorrencias para '%s': %s\n  Causa provavel: sem permissao de escrita em '%s'.\n  Skill anterior: ecological-data-foundation",
                species_name, e, output_dir,
            )
            raise
    else:
        logger.warning("Nenhum registro para gravar para '%s'.", species_name)

    # Save metadata
    log_step(5, "Gravar metadados do download")
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
        logger.warning("Menos de 2 argumentos fornecidos. Usando valores padrao para teste.")
    else:
        species_input = argv[0]
        output_dir    = Path(argv[1])
        country_code  = argv[2] if len(argv) >= 3 and argv[2] else None
        year_from     = int(argv[3]) if len(argv) >= 4 else 1950
        year_to       = int(argv[4]) if len(argv) >= 5 else date.today().year

    logger.info("Species input : %s", species_input)
    logger.info("Output dir   : %s", output_dir)
    logger.info("Country code : %s", country_code or "nenhum")
    logger.info("Year range   : %d - %d", year_from, year_to)

    log_decision("year_from", year_from, "limite inferior do periodo; 1950 = pos-era moderna")
    log_decision("year_to",   year_to,   "limite superior do periodo; ano corrente por padrao")
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
    logger.info("Diretorio de saida pronto: %s", output_dir)

    # Build species list
    log_step(0, "Construir lista de especies")
    if species_input.endswith(".csv") and Path(species_input).exists():
        try:
            df_species   = pd.read_csv(species_input)
            if "scientificName" not in df_species.columns:
                logger.error(
                    "Coluna 'scientificName' nao encontrada em: %s\n  Causa provavel: CSV de lista de especies mal formatado.\n  Skill anterior: ecological-data-foundation",
                    species_input,
                )
                sys.exit(1)
            species_list = df_species["scientificName"].dropna().unique().tolist()
            logger.info("Modo batch: %d especies carregadas de %s", len(species_list), species_input)
            log_decision("mode", "batch", "argumento e um CSV valido com coluna scientificName")
        except Exception as e:
            logger.error(
                "Falha ao ler lista de especies '%s': %s\n  Causa provavel: arquivo CSV invalido.\n  Skill anterior: ecological-data-foundation",
                species_input, e,
            )
            sys.exit(1)
    else:
        species_list = [species_input.strip()]
        logger.info("Modo especie unica: %s", species_list[0])
        log_decision("mode", "single_species", "argumento nao e um arquivo CSV existente")

    # Download each species
    for sp in species_list:
        try:
            download_species(sp, output_dir, country_code, year_from, year_to)
        except FileNotFoundError as e:
            logger.error(
                "Arquivo de entrada nao encontrado ao processar '%s': %s\n  Esperado como saida de: ecological-data-foundation\n  Verifique se o passo anterior foi concluido.",
                sp, e,
            )
        except Exception as e:
            logger.error(
                "Falha ao baixar '%s': %s\n  Causa provavel: problema de rede, taxon nao encontrado ou credenciais GBIF invalidas.\n  Skill anterior: ecological-data-foundation",
                sp, e,
            )

    logger.info("Todos os downloads concluidos. Verifique: %s", output_dir)


if __name__ == "__main__":
    main()
