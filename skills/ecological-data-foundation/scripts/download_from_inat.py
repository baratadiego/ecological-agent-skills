# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""Download occurrence records from iNaturalist via pyinaturalist.

Usage: python download_from_inat.py <species_name_or_list_csv> <output_dir> [year_from] [year_to] [quality_grade]

Arguments:
    species_name_or_list_csv : Species name (e.g., "Panthera onca") or path to CSV
                               with column 'scientificName'
    output_dir               : Directory for outputs (created if absent)
    year_from                : Minimum observation year (default: 2000)
    year_to                  : Maximum observation year (default: current year)
    quality_grade            : 'research' or 'any' (default: 'research')

Outputs (per species):
    occurrences_raw_iNat_{species}_{date}.csv  — standardised occurrence records
    download_metadata_iNat_{species}.txt        — download provenance and citation

Standard output schema:
    species, decimalLatitude, decimalLongitude, eventDate, countryCode,
    basisOfRecord, coordinateUncertaintyInMeters, datasetName, occurrenceID,
    source, download_doi
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
    import pyinaturalist
    from pyinaturalist import get_observations
except ImportError as e:
    logger.error(
        "Dependencia ausente: %s\n  Instale com: pip install pyinaturalist pandas\n  Skill anterior: ecological-data-foundation",
        e,
    )
    sys.exit(1)


# ── Constants ─────────────────────────────────────────────────────────────────
MAX_RESULTS_PER_PAGE = 200   # iNaturalist API page size limit
MAX_TOTAL_RESULTS    = 10000 # practical cap for single-species query


# ── Helper functions ──────────────────────────────────────────────────────────

def fetch_observations(taxon_name: str, year_from: int, year_to: int,
                        quality_grade: str) -> list[dict]:
    """Fetch all research-grade observations for a taxon, handling pagination."""
    all_results = []
    page = 1
    while True:
        try:
            response = get_observations(
                taxon_name=taxon_name,
                quality_grade=quality_grade,
                geo=True,
                captive=False,
                d1=f"{year_from}-01-01",
                d2=f"{year_to}-12-31",
                per_page=MAX_RESULTS_PER_PAGE,
                page=page,
                order="desc",
                order_by="created_at",
            )
        except Exception as e:
            logger.error(
                "Falha em get_observations (pagina=%d, taxon='%s'): %s\n  Causa provavel: sem conexao com a internet ou API iNaturalist indisponivel.\n  Skill anterior: ecological-data-foundation",
                page, taxon_name, e,
            )
            raise

        results = response.get("results", [])
        if not results:
            break
        all_results.extend(results)
        logger.info("Pagina %d: %d registros recuperados (total acumulado: %d)",
                    page, len(results), len(all_results))

        total_results = response.get("total_results", 0)
        if len(all_results) >= min(total_results, MAX_TOTAL_RESULTS):
            break
        if len(results) < MAX_RESULTS_PER_PAGE:
            break
        page += 1

    return all_results


def standardise_records(observations: list[dict], species_name: str) -> "pd.DataFrame":
    """Convert iNaturalist observation dicts to the standard occurrence schema."""
    rows = []
    for obs in observations:
        loc = obs.get("location", "")
        lat, lon = None, None
        if loc and "," in str(loc):
            parts = str(loc).split(",")
            try:
                lat, lon = float(parts[0]), float(parts[1])
            except ValueError:
                pass

        taxon    = obs.get("taxon", {}) or {}
        place    = obs.get("place_guess", "")

        rows.append({
            "species":                       species_name,
            "decimalLatitude":               lat,
            "decimalLongitude":              lon,
            "eventDate":                     obs.get("observed_on", ""),
            "countryCode":                   place,
            "basisOfRecord":                 "HUMAN_OBSERVATION",
            "coordinateUncertaintyInMeters": obs.get("positional_accuracy"),
            "datasetName":                   "iNaturalist",
            "occurrenceID":                  str(obs.get("id", "")),
            "source":                        "iNaturalist",
            "download_doi":                  None,
        })
    df = pd.DataFrame(rows)
    # Drop records missing coordinates
    df = df.dropna(subset=["decimalLatitude", "decimalLongitude"])
    return df


def save_metadata(output_dir: Path, species_name: str, n_records: int,
                  year_from: int, year_to: int, quality_grade: str) -> None:
    safe_name = species_name.replace(" ", "_")
    today = date.today().isoformat()
    year  = date.today().year
    lines = [
        f"Species: {species_name}",
        f"Source: iNaturalist (https://www.inaturalist.org)",
        f"Quality grade: {quality_grade}",
        f"Year range: {year_from} - {year_to}",
        f"Captive excluded: True",
        f"Geo-referenced only: True",
        f"n_records: {n_records}",
        f"Download date: {today}",
        (f"Citation: iNaturalist contributors and the California Academy of Sciences ({year}). "
         f"iNaturalist Research-grade Observations. iNaturalist.org. Accessed {today}."),
        "License: CC BY-NC (individual records may vary; see iNaturalist for details)",
        "Note: iNaturalist does not issue download DOIs; record the access date for reproducibility.",
    ]
    meta_path = output_dir / f"download_metadata_iNat_{safe_name}.txt"
    try:
        meta_path.write_text("\n".join(lines), encoding="utf-8")
        logger.info("Metadados gravados: %s", meta_path)
    except OSError as e:
        logger.error(
            "Falha ao gravar metadados em '%s': %s\n  Causa provavel: sem permissao de escrita.\n  Skill anterior: ecological-data-foundation",
            meta_path, e,
        )
        raise


# ── Main download logic ────────────────────────────────────────────────────────

def download_species(species_name: str, output_dir: Path,
                     year_from: int, year_to: int, quality_grade: str) -> None:
    logger.info("--- Iniciando download iNaturalist: %s ---", species_name)
    today_str = date.today().strftime("%Y%m%d")
    safe_name = species_name.replace(" ", "_")

    log_step(1, f"Buscar observacoes iNaturalist para '{species_name}'")
    observations = fetch_observations(species_name, year_from, year_to, quality_grade)
    logger.info("Total de observacoes recuperadas: %d", len(observations))

    if not observations:
        logger.warning("Nenhum registro encontrado para '%s'.", species_name)
        return

    log_step(2, "Padronizar registros para schema de saida")
    df = standardise_records(observations, species_name)
    n_final = len(df)
    logger.info("Registros com coordenadas validas: %d", n_final)

    if n_final < 30:
        logger.warning(
            "Registros insuficientes para SDM confiavel (n = %d). Considere: (1) ampliar periodo, (2) usar quality='any', (3) combinar com GBIF.",
            n_final,
        )

    log_step(3, "Gravar CSV de ocorrencias")
    csv_path = output_dir / f"occurrences_raw_iNat_{safe_name}_{today_str}.csv"
    try:
        df.to_csv(csv_path, index=False)
        logger.info("Gravado: %s (%d registros)", csv_path, n_final)
    except OSError as e:
        logger.error(
            "Falha ao gravar CSV para '%s': %s\n  Causa provavel: sem permissao de escrita em '%s'.\n  Skill anterior: ecological-data-foundation",
            species_name, e, output_dir,
        )
        raise

    log_step(4, "Gravar metadados do download")
    save_metadata(output_dir, species_name, n_final, year_from, year_to, quality_grade)


# ── Entry point ────────────────────────────────────────────────────────────────

def main():
    logger.info("Script: download_from_inat.py | Skill: %s", SKILL_NAME)

    argv = sys.argv[1:]

    if len(argv) < 2:
        species_input = "Panthera onca"
        output_dir    = Path("output/inat")
        year_from     = 2000
        year_to       = date.today().year
        quality_grade = "research"
        logger.warning("Menos de 2 argumentos fornecidos. Usando valores padrao para teste.")
    else:
        species_input = argv[0]
        output_dir    = Path(argv[1])
        year_from     = int(argv[2]) if len(argv) >= 3 else 2000
        year_to       = int(argv[3]) if len(argv) >= 4 else date.today().year
        quality_grade = argv[4] if len(argv) >= 5 else "research"

    logger.info("Species input  : %s", species_input)
    logger.info("Output dir     : %s", output_dir)
    logger.info("Year range     : %d - %d", year_from, year_to)
    logger.info("Quality grade  : %s", quality_grade)

    log_decision("quality_grade", quality_grade,
                 "research = comunidade validou ID + geo; recomendado para SDM")
    log_decision("captive", False,
                 "excluir organismos em cativeiro/cultivados")
    log_decision("year_from", year_from,
                 "filtro temporal; 2000 equilibra dataset e qualidade de GPS")

    output_dir.mkdir(parents=True, exist_ok=True)

    # Build species list
    log_step(0, "Construir lista de especies")
    if species_input.endswith(".csv") and Path(species_input).exists():
        try:
            df_sp = pd.read_csv(species_input)
            if "scientificName" not in df_sp.columns:
                logger.error(
                    "Coluna 'scientificName' nao encontrada em: %s\n  Causa provavel: CSV mal formatado.\n  Skill anterior: ecological-data-foundation",
                    species_input,
                )
                sys.exit(1)
            species_list = df_sp["scientificName"].dropna().unique().tolist()
            logger.info("Modo batch: %d especies carregadas", len(species_list))
            log_decision("mode", "batch", "CSV valido com coluna scientificName")
        except Exception as e:
            logger.error(
                "Falha ao ler lista de especies '%s': %s\n  Skill anterior: ecological-data-foundation",
                species_input, e,
            )
            sys.exit(1)
    else:
        species_list = [species_input.strip()]
        logger.info("Modo especie unica: %s", species_list[0])
        log_decision("mode", "single_species", "argumento nao e arquivo CSV")

    for sp in species_list:
        try:
            download_species(sp, output_dir, year_from, year_to, quality_grade)
        except FileNotFoundError as e:
            logger.error(
                "Arquivo de entrada nao encontrado ao processar '%s': %s\n  Esperado como saida de: ecological-data-foundation\n  Skill anterior: ecological-data-foundation",
                sp, e,
            )
        except Exception as e:
            logger.error(
                "Falha ao baixar '%s' do iNaturalist: %s\n  Causa provavel: problema de rede ou especie nao encontrada.\n  Skill anterior: ecological-data-foundation",
                sp, e,
            )

    logger.info("Todos os downloads iNaturalist concluidos. Verifique: %s", output_dir)


if __name__ == "__main__":
    main()
